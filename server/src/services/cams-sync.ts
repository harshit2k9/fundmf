import { FieldValue, Timestamp } from "firebase-admin/firestore";

import { config, gmailQuery } from "../config";
import { firestore } from "../firebase";
import { HttpError } from "../http-error";
import { logger } from "../logger";
import type { ParsedTransaction, SyncSummary, SyncTrigger } from "../types";
import {
  FolioDirectory,
  extractRows,
  headerTokens,
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
import { extractStatementFiles, type StatementFile } from "./zip";

/** Where the folio -> PAN directory is cached between sync runs. */
const FOLIO_DOCUMENT = "settings/folio_directory";
/** Firestore documents are capped at 1 MiB; stay well below it. */
const MAX_STORED_FOLIOS = 5000;

/** Serialises manual triggers inside one process so two runs cannot overlap. */
let inProgress = false;

export function isSyncRunning(): boolean {
  return inProgress;
}

interface MessageBundle {
  messageId: string;
  files: StatementFile[];
  /** Attachments that could not be read; the message stays unread. */
  failures: number;
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
): Promise<MessageBundle> {
  const detail = await gmail.users.messages.get({
    userId: "me",
    id: messageId,
    format: "full",
  });

  const parts = collectStatementParts(detail.data.payload);
  if (parts.length === 0) {
    // Leave it unread so a human can inspect it.
    errors.push(`Message ${messageId}: no zip or CSV attachment found`);
    return { messageId, files: [], failures: 1 };
  }

  const files: StatementFile[] = [];
  let failures = 0;

  for (const part of parts) {
    const filename = part.filename ?? "attachment";
    try {
      const data = await downloadAttachmentBuffer(gmail, messageId, part);
      if (data.length === 0) {
        failures += 1;
        errors.push(`Message ${messageId}/${filename}: empty download`);
        continue;
      }

      if (filename.toLowerCase().endsWith(".zip")) {
        const extracted = await extractStatementFiles(
          data,
          config.camsZipPassword,
          filename,
        );
        files.push(...extracted);
      } else {
        const text = decodeCsv(data);
        if (text.trim().length === 0) {
          failures += 1;
          errors.push(`Message ${messageId}/${filename}: empty statement`);
          continue;
        }
        files.push({ filename, text });
      }
    } catch (error) {
      failures += 1;
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

  // An empty bundle is still useful: the message was consumed and carried no
  // statement (for example a KYC form bundle), so it must not be rescanned.
  return { messageId, files, failures };
}

/**
 * The investor master is a one-off CSV. When a previous run consumed it before
 * folios were cached, fetch it again so transactions can still be mapped to a
 * PAN.
 */
async function backfillFolioMaster(
  gmail: ReturnType<typeof createGmailClient>,
  directory: FolioDirectory,
): Promise<number> {
  const list = await gmail.users.messages.list({
    userId: "me",
    q:
      `from:${config.camsSender} has:attachment ` +
      '(filename:csv OR subject:"CSV with Headers")',
    maxResults: 5,
  });

  let rows = 0;
  for (const message of list.data.messages ?? []) {
    const messageId = message.id;
    if (!messageId) continue;

    try {
      const detail = await gmail.users.messages.get({
        userId: "me",
        id: messageId,
        format: "full",
      });

      for (const part of collectStatementParts(detail.data.payload)) {
        const filename = part.filename ?? "attachment";
        const data = await downloadAttachmentBuffer(gmail, messageId, part);
        if (data.length === 0) continue;

        const files = filename.toLowerCase().endsWith(".zip")
          ? await extractStatementFiles(
              data,
              config.camsZipPassword,
              filename,
            )
          : [{ filename, text: decodeCsv(data) }];

        for (const file of files) {
          if (!isFolioMasterCsv(file.text)) continue;
          rows += parseFolioMaster(file.text, directory);
        }
      }
    } catch (error) {
      logger.warn("Could not read the investor master", {
        messageId,
        error,
      });
    }
  }

  return rows;
}

/** Reads the folio directory cached by earlier runs, if any. */
async function loadFolioDirectory(): Promise<FolioDirectory> {
  try {
    const snapshot = await firestore().doc(FOLIO_DOCUMENT).get();
    if (!snapshot.exists) return new FolioDirectory();
    return FolioDirectory.fromRecords(snapshot.data()?.accounts);
  } catch (error) {
    logger.warn("Could not read the stored folio directory", error);
    return new FolioDirectory();
  }
}

/** Caches the folio directory so transaction-only emails can still be mapped. */
async function storeFolioDirectory(directory: FolioDirectory): Promise<void> {
  const records = directory.records();
  if (records.length === 0 || records.length > MAX_STORED_FOLIOS) return;

  try {
    await firestore()
      .doc(FOLIO_DOCUMENT)
      .set(
        {
          accounts: records,
          count: records.length,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
  } catch (error) {
    logger.warn("Could not store the folio directory", error);
  }
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
        bundles.push(bundle);
      } catch (error) {
        errors.push(`Message ${messageId}: ${describeError(error)}`);
        logger.error("CAMS message download failed", { messageId, error });
      }
    }

    // Phase 2: the investor master ("CSV with Headers") is the static client
    // detail. It maps every folio to a PAN and to its scheme names.
    const directory = await loadFolioDirectory();
    let masterRows = 0;
    for (const bundle of bundles) {
      for (const file of bundle.files) {
        if (!isFolioMasterCsv(file.text)) continue;
        const rows = parseFolioMaster(file.text, directory);
        masterRows += rows;
        if (rows === 0) {
          errors.push(
            `Message ${bundle.messageId}/${file.filename}: no investor rows found`,
          );
        }
      }
    }
    // No master in this batch: the message may have been consumed by an
    // earlier run, so look for the investor master again before mapping.
    if (directory.size === 0) {
      masterRows += await backfillFolioMaster(gmail, directory);
    }

    if (masterRows > 0) await storeFolioDirectory(directory);
    foliosMapped = directory.size;

    const resolveUid = createUidResolver();

    // Phase 3: replay the transaction tape against the folio directory.
    for (const bundle of bundles) {
      attachmentsParsed += bundle.files.length;
      let parsedAny = false;

      for (const file of bundle.files) {
        const rows = extractRows(file.text);
        // Not a statement: forms, letters and other documents that arrive in
        // the same mailbox have no CAMS header row.
        if (rows.length === 0) continue;
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
              "known yet, so folios could not be mapped to a PAN",
          );
        } else {
          const columns = headerTokens(file.text).slice(0, 24).join(", ");
          errors.push(
            `Message ${bundle.messageId}/${file.filename}: no rows could be ` +
              `mapped to a PAN or amount (columns: ${columns || "none detected"})`,
          );
        }
      }

      // Leave an attachment we could not read unread (and unlabelled) so a
      // human — or the next parser version — can pick it up again.
      if (bundle.failures > 0) continue;

      if (!parsedAny && bundle.files.length > 0) {
        errors.push(
          `Message ${bundle.messageId}: statement rows were found but none ` +
            "could be mapped to a PAN",
        );
        continue;
      }

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
