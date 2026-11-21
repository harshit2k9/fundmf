import { FieldValue, Timestamp } from "firebase-admin/firestore";

import { config, gmailQuery } from "../config";
import { firestore } from "../firebase";
import { HttpError } from "../http-error";
import { logger } from "../logger";
import type { ParsedTransaction, SyncSummary, SyncTrigger } from "../types";
import {
  FolioDirectory,
  extractRows,
  isFolioMasterCsv,
  mapTransactionRow,
  parseFolioMaster,
} from "./cams-csv";
import {
  collectStatementParts,
  createGmailClient,
  downloadAttachmentBuffer,
  ensureProcessedLabel,
  markProcessed,
} from "./gmail";
import { extractCsvFiles, type StatementFile } from "./zip";

/** Serialises manual triggers inside one process so two runs cannot overlap. */
let inProgress = false;

export function isSyncRunning(): boolean {
  return inProgress;
}

interface MessageBundle {
  messageId: string;
  files: StatementFile[];
}

function describeError(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

function decodeCsv(buffer: Buffer): string {
  // CAMS exports are UTF-8; the parser also tolerates a BOM.
  return buffer.toString("utf8").replace(/^\uFEFF/, "");
}

/**
 * Downloads one email's statement attachments and unpacks any password
 * protected zip into CSV texts.
 */
async function readMessage(
  gmail: ReturnType<typeof createGmailClient>,
  messageId: string,
  errors: string[],
): Promise<MessageBundle | null> {
  const detail = await gmail.users.messages.get({
    userId: "me",
    id: messageId,
    format: "full",
  });

  const parts = collectStatementParts(detail.data.payload);
  if (parts.length === 0) {
    // Leave it unread so a human can inspect it.
    errors.push(`Message ${messageId}: no zip or CSV attachment found`);
    return null;
  }

  const files: StatementFile[] = [];

  for (const part of parts) {
    const filename = part.filename ?? "attachment";
    try {
      const data = await downloadAttachmentBuffer(gmail, messageId, part);
      if (data.length === 0) {
        errors.push(`Message ${messageId}/${filename}: empty download`);
        continue;
      }

      if (filename.toLowerCase().endsWith(".zip")) {
        const extracted = await extractCsvFiles(
          data,
          config.camsZipPassword,
          filename,
        );
        files.push(...extracted);
      } else {
        const text = decodeCsv(data);
        if (text.trim().length === 0) {
          errors.push(`Message ${messageId}/${filename}: empty statement`);
          continue;
        }
        files.push({ filename, text });
      }
    } catch (error) {
      errors.push(
        `Message ${messageId}/${filename}: ${describeError(error)}`,
      );
      logger.error("CAMS attachment failed", {
        messageId,
        filename,
        error,
      });
    }
  }

  if (files.length === 0) return null;
  return { messageId, files };
}

/** Caches PAN -> uid lookups for the duration of one run. */
function createUidResolver(): (pan: string) => Promise<string> {
  const cache = new Map<string, string>();

  return async (pan: string): Promise<string> => {
    const cached = cache.get(pan);
    if (cached !== undefined) return cached;

    const snapshot = await firestore()
      .collection("users")
      .where("pan", "==", pan)
      .limit(1)
      .get();
    const uid = snapshot.empty ? "" : String(snapshot.docs[0].data().uid ?? "");
    cache.set(pan, uid);
    return uid;
  };
}

/**
 * Writes one transaction. Returns "duplicate" when the RTA transaction number
 * has already been imported, which keeps re-syncs idempotent.
 */
async function writeTransaction(
  transaction: ParsedTransaction,
  messageId: string,
  resolveUid: (pan: string) => Promise<string>,
): Promise<"created" | "duplicate"> {
  const ref = firestore()
    .collection("transactions")
    .doc(transaction.transactionId);
  const existing = await ref.get();
  if (existing.exists) return "duplicate";

  const uid = await resolveUid(transaction.pan);

  await ref.set({
    transactionId: transaction.transactionId,
    pan: transaction.pan,
    uid,
    folioNumber: transaction.folioNumber,
    schemeName: transaction.schemeName,
    schemeCode: transaction.schemeCode,
    transactionDate: Timestamp.fromDate(transaction.transactionDate),
    transactionType: transaction.transactionType,
    amount: transaction.amount,
    units: transaction.units,
    purchaseNav: transaction.purchaseNav,
    sourceMessageId: messageId,
    processedAt: FieldValue.serverTimestamp(),
  });

  return "created";
}

/**
 * Runs the full ingestion: Gmail → zip/CSV → folio mapping → Firestore. Used by
 * both the HTTP endpoint and the daily Render cron job.
 */
export async function runCamsSync(
  trigger: SyncTrigger,
  actor = "",
): Promise<SyncSummary> {
  if (inProgress) {
    throw HttpError.conflict(
      "A CAMS sync is already running. Try again in a minute.",
    );
  }

  inProgress = true;
  const startedAt = new Date();
  const errors: string[] = [];

  let messagesScanned = 0;
  let attachmentsParsed = 0;
  let foliosMapped = 0;
  let unmappedRows = 0;
  let transactionsCreated = 0;
  let duplicatesSkipped = 0;
  let fatalError = "";

  try {
    const gmail = createGmailClient();
    const labelId = await ensureProcessedLabel(gmail);

    const list = await gmail.users.messages.list({
      userId: "me",
      q: gmailQuery,
      maxResults: config.maxMessages,
    });
    const messages = list.data.messages ?? [];
    messagesScanned = messages.length;

    // Phase 1: download every unread statement (unpacking the password
    // protected zip) before writing anything.
    const bundles: MessageBundle[] = [];
    for (const message of messages) {
      const messageId = message.id;
      if (!messageId) continue;

      try {
        const bundle = await readMessage(gmail, messageId, errors);
        if (bundle) bundles.push(bundle);
      } catch (error) {
        errors.push(`Message ${messageId}: ${describeError(error)}`);
        logger.error("CAMS message download failed", { messageId, error });
      }
    }

    // Phase 2: the investor master ("CSV with Headers") is the static client
    // detail. It maps every folio to a PAN and to its scheme names.
    const directory = new FolioDirectory();
    for (const bundle of bundles) {
      for (const file of bundle.files) {
        if (!isFolioMasterCsv(file.text)) continue;
        const rows = parseFolioMaster(file.text, directory);
        if (rows === 0) {
          errors.push(
            `Message ${bundle.messageId}/${file.filename}: no investor rows found`,
          );
        }
      }
    }
    foliosMapped = directory.size;

    const resolveUid = createUidResolver();

    // Phase 3: replay the transaction tape against the folio directory.
    for (const bundle of bundles) {
      attachmentsParsed += bundle.files.length;
      let parsedAny = false;

      for (const file of bundle.files) {
        const rows = extractRows(file.text);
        if (rows.length === 0) {
          errors.push(
            `Message ${bundle.messageId}/${file.filename}: no statement rows found`,
          );
          continue;
        }
        if (isFolioMasterCsv(file.text)) {
          parsedAny = true;
          continue;
        }

        let fileRows = 0;
        for (const row of rows) {
          const mapped = mapTransactionRow(row, directory);
          if (mapped.unmapped) {
            unmappedRows += 1;
            continue;
          }
          if (!mapped.transaction) continue;

          fileRows += 1;
          const outcome = await writeTransaction(
            mapped.transaction,
            bundle.messageId,
            resolveUid,
          );
          if (outcome === "created") {
            transactionsCreated += 1;
          } else {
            duplicatesSkipped += 1;
          }
        }

        if (fileRows > 0) {
          parsedAny = true;
        } else if (directory.size === 0) {
          errors.push(
            `Message ${bundle.messageId}/${file.filename}: no investor master ` +
              "in this batch, so folios could not be mapped to a PAN",
          );
        }
      }

      // Leave a statement we could not read unread (and unlabelled) so a
      // human — or the next parser version — can pick it up again.
      if (!parsedAny) continue;

      await markProcessed(gmail, bundle.messageId, labelId);
      logger.info("Processed CAMS email", {
        messageId: bundle.messageId,
        files: bundle.files.length,
      });
    }

    if (unmappedRows > 0) {
      errors.push(
        `${unmappedRows} transaction row(s) skipped: folio not present in the ` +
          "investor master CSV",
      );
    }
  } catch (error) {
    fatalError = describeError(error);
    errors.push(fatalError);
    logger.error("CAMS sync aborted", error);
  } finally {
    inProgress = false;
  }

  const finishedAt = new Date();
  const durationMs = finishedAt.getTime() - startedAt.getTime();
  const status: SyncSummary["status"] = fatalError
    ? "failed"
    : errors.length > 0
      ? "partial"
      : "success";

  const summary: SyncSummary = {
    status,
    trigger,
    messagesScanned,
    attachmentsParsed,
    foliosMapped,
    unmappedRows,
    transactionsCreated,
    duplicatesSkipped,
    errors: errors.slice(0, 50),
    durationMs,
    startedAt: startedAt.toISOString(),
    finishedAt: finishedAt.toISOString(),
  };

  try {
    await firestore()
      .collection("sync_logs")
      .add({
        ...summary,
        startedAt: Timestamp.fromDate(startedAt),
        finishedAt: Timestamp.fromDate(finishedAt),
        actor,
        errorMessage: fatalError,
      });
  } catch (error) {
    logger.error("Could not write sync log", error);
  }

  logger.info("CAMS sync finished", summary);
  return summary;
}
