import { FieldValue, Timestamp } from "firebase-admin/firestore";

import { config, gmailQuery } from "../config";
import { firestore } from "../firebase";
import { HttpError } from "../http-error";
import { logger } from "../logger";
import type { ParsedTransaction, SyncSummary, SyncTrigger } from "../types";
import { extractRows, mapRow } from "./cams-csv";
import {
  collectCsvParts,
  createGmailClient,
  downloadAttachment,
  ensureProcessedLabel,
  markProcessed,
} from "./gmail";

/** Serialises manual triggers inside one process so two runs cannot overlap. */
let inProgress = false;

export function isSyncRunning(): boolean {
  return inProgress;
}

async function resolveUidForPan(pan: string): Promise<string> {
  const snapshot = await firestore()
    .collection("users")
    .where("pan", "==", pan)
    .limit(1)
    .get();
  if (snapshot.empty) return "";
  const data = snapshot.docs[0].data();
  return typeof data.uid === "string" ? data.uid : "";
}

/**
 * Writes one transaction. Returns "duplicate" when the CAMS Transaction_ID has
 * already been imported, which keeps re-syncs idempotent.
 */
async function writeTransaction(
  transaction: ParsedTransaction,
  messageId: string,
): Promise<"created" | "duplicate"> {
  const ref = firestore()
    .collection("transactions")
    .doc(transaction.transactionId);
  const existing = await ref.get();
  if (existing.exists) return "duplicate";

  const uid = await resolveUidForPan(transaction.pan);

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

function describeError(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

/**
 * Runs the full ingestion: Gmail → CSV → Firestore. Used by both the HTTP
 * endpoint and the Render cron job.
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

    for (const message of messages) {
      const messageId = message.id;
      if (!messageId) continue;

      try {
        const detail = await gmail.users.messages.get({
          userId: "me",
          id: messageId,
          format: "full",
        });

        const csvParts = collectCsvParts(detail.data.payload);
        if (csvParts.length === 0) {
          // Leave it unread so a human can inspect it.
          errors.push(`Message ${messageId}: no CSV attachment found`);
          continue;
        }

        for (const part of csvParts) {
          const csvText = await downloadAttachment(gmail, messageId, part);
          if (!csvText) {
            errors.push(
              `Message ${messageId}/${part.filename ?? "attachment"}: empty download`,
            );
            continue;
          }

          attachmentsParsed += 1;
          const rows = extractRows(csvText);
          if (rows.length === 0) {
            errors.push(
              `Message ${messageId}/${part.filename ?? "attachment"}: no CAMS rows found`,
            );
            continue;
          }

          for (const row of rows) {
            const transaction = mapRow(row);
            if (!transaction) continue;

            const outcome = await writeTransaction(transaction, messageId);
            if (outcome === "created") {
              transactionsCreated += 1;
            } else {
              duplicatesSkipped += 1;
            }
          }
        }

        await markProcessed(gmail, messageId, labelId);
        logger.info("Processed CAMS email", {
          messageId,
          parts: csvParts.length,
        });
      } catch (error) {
        errors.push(`Message ${messageId}: ${describeError(error)}`);
        logger.error("CAMS message failed", { messageId, error });
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
