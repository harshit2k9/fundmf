import { FieldPath, FieldValue, Timestamp } from "firebase-admin/firestore";

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
/** Where the mapper's own version is cached, to trigger a one-off repair. */
const SYNC_STATE = "settings/sync_state";
/** Bump when the mapping changes so already imported rows are rewritten. */
const DATA_VERSION = 3;

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

interface UpsertResult {
  created: number;
  updated: number;
  unchanged: number;
}

/** True when a stored document already carries exactly this mapping. */
function sameTransaction(
  stored: Record<string, unknown>,
  transaction: ParsedTransaction,
): boolean {
  const number = (value: unknown): number =>
    typeof value === "number" ? value : Number(value ?? 0);

  return (
    String(stored.schemeName ?? "") === transaction.schemeName &&
    String(stored.transactionType ?? "") === transaction.transactionType &&
    String(stored.pan ?? "") === transaction.pan &&
    String(stored.folioNumber ?? "") === transaction.folioNumber &&
    number(stored.schemeCode) === transaction.schemeCode &&
    number(stored.amount) === transaction.amount &&
    number(stored.units) === transaction.units &&
    number(stored.purchaseNav) === transaction.purchaseNav
  );
}

/**
 * Writes mapped rows in bulk so re-syncs stay idempotent **and** refresh rows
 * that an older build imported with the wrong scheme, type or units.
 */
async function upsertTransactions(
  transactions: ParsedTransaction[],
  messageId: string,
  resolveUid: (pan: string) => Promise<string>,
): Promise<UpsertResult> {
  const result: UpsertResult = { created: 0, updated: 0, unchanged: 0 };
  if (transactions.length === 0) return result;

  const unique = [...new Map(transactions.map((t) => [t.transactionId, t])).values()];
  const database = firestore();
  const collection = database.collection("transactions");

  for (let start = 0; start < unique.length; start += 100) {
    const chunk = unique.slice(start, start + 100);
    const refs = chunk.map((transaction) => collection.doc(transaction.transactionId));
    const snapshots = await database.getAll(...refs);
    const batch = database.batch();

    for (let index = 0; index < chunk.length; index += 1) {
      const transaction = chunk[index];
      const snapshot = snapshots[index];
      const stored = snapshot.data() ?? {};
      // Never drop an existing link to an investor profile.
      const uid = (await resolveUid(transaction.pan)) || String(stored.uid ?? "");

      const payload = {
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
      };

      if (!snapshot.exists) {
        batch.set(refs[index], payload);
        result.created += 1;
      } else if (sameTransaction(stored, transaction)) {
        result.unchanged += 1;
      } else {
        batch.set(refs[index], payload, { merge: true });
        result.updated += 1;
      }
    }

    await batch.commit();
  }

  return result;
}

/** Version of the mapping that produced the stored transactions. */
async function readDataVersion(): Promise<number> {
  try {
    const snapshot = await firestore().doc(SYNC_STATE).get();
    const value = Number(snapshot.data()?.dataVersion ?? 0);
    return Number.isFinite(value) ? value : 0;
  } catch (error) {
    logger.warn("Could not read the sync state", error);
    return 0;
  }
}

async function writeDataVersion(): Promise<void> {
  try {
    await firestore()
      .doc(SYNC_STATE)
      .set(
        { dataVersion: DATA_VERSION, updatedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
  } catch (error) {
    logger.warn("Could not store the sync state", error);
  }
}

/**
 * Deletes documents written by the old parser, whose ids kept CAMS' single
 * quotes ('H'-1046363830). They are re-created with clean ids by the repair.
 */
async function purgeLegacyTransactions(): Promise<number> {
  const database = firestore();
  const collection = database.collection("transactions");
  let deleted = 0;

  for (let pass = 0; pass < 25; pass += 1) {
    const snapshot = await collection
      .where(FieldPath.documentId(), ">=", "'")
      .where(FieldPath.documentId(), "<=", "'\uf8ff")
      .limit(400)
      .get();
    if (snapshot.empty) break;

    const batch = database.batch();
    for (const doc of snapshot.docs) batch.delete(doc.ref);
    await batch.commit();
    deleted += snapshot.size;
  }

  return deleted;
}

/**
 * Re-reads the most recent statements (already read or not) and rewrites every
 * row from the current mapping. This is what repairs documents imported by an
 * older build, where every scheme was "Scheme '02'" and every SIP was Other.
 */
async function repairRecentStatements(
  gmail: ReturnType<typeof createGmailClient>,
  directory: FolioDirectory,
  resolveUid: (pan: string) => Promise<string>,
): Promise<UpsertResult & { rows: number }> {
  const total = { created: 0, updated: 0, unchanged: 0, rows: 0 };

  const list = await gmail.users.messages.list({
    userId: "me",
    q: `from:${config.camsSender} has:attachment (filename:zip OR filename:csv)`,
    maxResults: Math.min(config.maxMessages, 8),
  });

  for (const message of list.data.messages ?? []) {
    const messageId = message.id;
    if (!messageId) continue;

    try {
      // Attachment errors are already reported by the normal pass.
      const bundle = await readMessage(gmail, messageId, []);
      const mapped: ParsedTransaction[] = [];

      for (const file of bundle.files) {
        for (const row of extractRows(file.text)) {
          const entry = mapTransactionRow(row, directory);
          if (entry.transaction) mapped.push(entry.transaction);
        }
      }

      if (mapped.length === 0) continue;
      const result = await upsertTransactions(mapped, messageId, resolveUid);
      total.created += result.created;
      total.updated += result.updated;
      total.unchanged += result.unchanged;
      total.rows += mapped.length;
    } catch (error) {
      logger.warn("Could not re-check an earlier statement", { messageId, error });
    }
  }

  return total;
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
  let transactionsUpdated = 0;
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
    // earlier run, so re-read the investor master before mapping. This also
    // refreshes the scheme catalogue (PRODUCT -> SCH_NAME) of new clients.
    if (masterRows === 0) {
      masterRows += await backfillFolioMaster(gmail, directory);
    }

    if (masterRows > 0) await storeFolioDirectory(directory);
    foliosMapped = directory.size;

    const resolveUid = createUidResolver();

    // Phase 3: replay the transaction tape against the folio directory.
    for (const bundle of bundles) {
      attachmentsParsed += bundle.files.length;

      for (const file of bundle.files) {
        const rows = extractRows(file.text);
        // Not a statement: forms, letters and other documents that arrive in
        // the same mailbox have no CAMS header row.
        if (rows.length === 0) {
          logger.warn("Ignored a CAMS CSV with no recognised header", {
            messageId: bundle.messageId,
            filename: file.filename,
            columns: headerTokens(file.text).slice(0, 24).join(", "),
          });
          continue;
        }
        if (isFolioMasterCsv(file.text)) continue;

        let fileRows = 0;
        const mappedRows: ParsedTransaction[] = [];
        for (const row of rows) {
          const mapped = mapTransactionRow(row, directory);
          if (mapped.unmapped) {
            unmappedRows += 1;
            continue;
          }
          if (!mapped.transaction) continue;

          fileRows += 1;
          mappedRows.push(mapped.transaction);
        }

        if (mappedRows.length > 0) {
          const outcome = await upsertTransactions(
            mappedRows,
            bundle.messageId,
            resolveUid,
          );
          transactionsCreated += outcome.created;
          transactionsUpdated += outcome.updated;
          duplicatesSkipped += outcome.unchanged;
        }

        if (fileRows === 0 && directory.size === 0) {
          errors.push(
            `Message ${bundle.messageId}/${file.filename}: no investor master ` +
              "known yet, so folios could not be mapped to a PAN",
          );
        } else if (fileRows === 0) {
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

      await markProcessed(gmail, bundle.messageId, labelId);
      logger.info("Processed CAMS email", {
        messageId: bundle.messageId,
        files: bundle.files.length,
      });
    }

    // Rows whose folio is not in the client master belong to investors who are
    // not provisioned in Fundmf; they are counted, not reported as a failure.
    if (unmappedRows > 0) {
      logger.info("Skipped rows without a client master folio", { unmappedRows });
    }

    // A newer mapping rewrites rows imported by an older build (wrong scheme
    // name, "Other" instead of SIP/Purchase, RTA code stored as an AMFI code).
    if ((await readDataVersion()) < DATA_VERSION) {
      try {
        const purged = await purgeLegacyTransactions();
        if (purged > 0) logger.info("Removed legacy CAMS rows", { purged });

        const repaired = await repairRecentStatements(
          gmail,
          directory,
          resolveUid,
        );
        transactionsCreated += repaired.created;
        transactionsUpdated += repaired.updated;
        duplicatesSkipped += repaired.unchanged;
        if (repaired.rows > 0) await writeDataVersion();
        logger.info("Repaired earlier CAMS rows", repaired);
      } catch (error) {
        errors.push(`Repair pass failed: ${describeError(error)}`);
        logger.error("CAMS repair pass failed", error);
      }
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
    transactionsUpdated,
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
