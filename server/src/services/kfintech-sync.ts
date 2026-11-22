import { FieldValue, Timestamp } from "firebase-admin/firestore";

import { config, kfintechGmailQuery } from "../config";
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
  createGmailClient,
  downloadUrl,
  ensureProcessedLabel,
  markProcessed,
} from "./gmail";
import { extractStatementFiles, type StatementFile } from "./zip";

const FOLIO_DOCUMENT = "settings/folio_directory";
const MAX_STORED_FOLIOS = 5000;

let inProgress = false;

export function isKfintechSyncRunning(): boolean {
  return inProgress;
}

interface MessageBundle {
  messageId: string;
  files: StatementFile[];
  failures: number;
}

function describeError(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

function decodeCsv(buffer: Buffer): string {
  return buffer.toString("utf8").replace(/^\uFEFF/, "");
}

function decodeHtmlEntities(value: string): string {
  return value
    .replace(/&amp;/gi, "&")
    .replace(/&#0*38;/g, "&")
    .replace(/&quot;/gi, '"');
}

/**
 * KFintech mailback mails do not link to the archive directly: they wrap it in
 * `https://scdelivery.kfintech.com/c/?u=<destination>`, where every character
 * of the destination is shifted one code point forward — `iuuqt%3B00ett%2F...`
 * is `https://dss.kfintech.com/...`. Fetching the tracker itself only returns
 * an HTML landing page, which is what made every run end in "download returned
 * an HTML page, not a file". Decode the destination and fetch that instead.
 */
function decodeTrackerLink(link: string): string | null {
  let url: URL;
  try {
    url = new URL(link);
  } catch {
    return null;
  }

  const payload =
    url.searchParams.get("u") ??
    url.searchParams.get("url") ??
    url.searchParams.get("target");
  if (!payload || payload.length < 12) return null;

  const decoded = Array.from(payload)
    .map((char) => String.fromCharCode(char.charCodeAt(0) - 1))
    .join("");

  return /^https?:\/\/[^\s]+$/i.test(decoded) ? decoded : null;
}

function extractLinksFromText(text: string): string[] {
  const acc: string[] = [];
  for (const match of text.matchAll(/<a[^>]*href=["']([^"']+)["']/gi)) {
    acc.push(match[1]);
  }
  return acc;
}

function isDownloadLink(link: string): boolean {
  const lower = link.toLowerCase();
  if (lower.startsWith("mailto:") || lower.startsWith("tel:")) return false;
  if (/\.(png|jpg|jpeg|gif|bmp|svg|css|js)(\?|$)/.test(lower)) return false;
  if (/google-analytics|doubleclick|facebook\.com\/tr|analytics/i.test(lower)) {
    return false;
  }
  // Prefer links that look like file downloads or KFintech portals.
  if (lower.includes("download") || lower.includes(".zip") || lower.includes(".csv") || lower.includes(".txt")) {
    return true;
  }
  if (lower.includes("kfintech") || lower.includes("karvy")) return true;
  return false;
}

function extractLinks(
  part: any,
  acc: string[] = [],
): string[] {
  if (!part) return acc;

  // Only scan human-readable parts. Scanning attachments (which can be large
  // zips/CSVs encoded as base64) produced thousands of bogus URLs and made the
  // sync hang for minutes.
  const mimeType = String(part.mimeType ?? "").toLowerCase();
  const hasFilename = Boolean(part.filename);
  const isText = mimeType.startsWith("text/") || mimeType === "";
  const data = part.body?.data;
  if (data && isText && !hasFilename) {
    try {
      const text = Buffer.from(data, "base64url").toString("utf8");
      // Only anchor hrefs: KFintech puts the real download link in an <a>.
      for (const match of text.matchAll(/<a[^>]*href=["']([^"']+)["']/gi)) {
        acc.push(match[1]);
      }
    } catch {
      // ignore undecodable parts
    }
  }
  for (const child of part.parts ?? []) extractLinks(child, acc);
  return acc;
}

function isZipBytes(data: Buffer): boolean {
  return (
    data.length >= 4 &&
    data[0] === 0x50 &&
    data[1] === 0x4b &&
    (data[2] === 0x03 || data[2] === 0x05 || data[2] === 0x07) &&
    (data[3] === 0x04 || data[3] === 0x06 || data[3] === 0x08)
  );
}

/**
 * KFintech mailback reports are sometimes delivered through an HTML "reports
 * console" page rather than a direct file. When a download returns HTML, pull
 * the download links out of it so we can fetch the actual archive behind it.
 */
function extractDownloadLinksFromHtml(html: string): string[] {
  const acc: string[] = [];
  for (const match of html.matchAll(/<a[^>]*href=["']([^"']+)["']/gi)) {
    const href = decodeHtmlEntities(match[1]);
    acc.push(decodeTrackerLink(href) ?? href);
  }
  // A tracker/console page usually forwards with a meta refresh or a script
  // assignment instead of an anchor.
  for (const match of html.matchAll(
    /<meta[^>]+http-equiv=["']?refresh["']?[^>]*content=["'][^"']*?url=([^"'>\s]+)/gi,
  )) {
    acc.push(decodeHtmlEntities(match[1]));
  }
  for (const match of html.matchAll(
    /(?:window\.|document\.)?location(?:\.href)?\s*=\s*["']([^"']+)["']/gi,
  )) {
    acc.push(decodeHtmlEntities(match[1]));
  }
  for (const match of html.matchAll(
    /location\.replace\(\s*["']([^"']+)["'][^)]*\)/gi,
  )) {
    acc.push(decodeHtmlEntities(match[1]));
  }
  const resolved = acc.map((link) => decodeTrackerLink(link) ?? link);
  return [...new Set(resolved)].filter((link) => isDownloadLink(link));
}

async function processDownloaded(
  messageId: string,
  link: string,
  data: Buffer,
  errors: string[],
  files: StatementFile[],
  failuresRef: { value: number },
  visited: Set<string>,
  depth: number,
): Promise<void> {
  if (data.length === 0) {
    failuresRef.value += 1;
    errors.push(`Message ${messageId}/${link}: empty download`);
    return;
  }

  const head = data.slice(0, 256).toString("utf8").toLowerCase();
  const isHtml =
    head.includes("<!doctype html") ||
    head.includes("<html") ||
    head.includes("<head");

  if (isHtml) {
    // One level of indirection: the page may carry the real download link.
    if (depth < 1) {
      const html = data.toString("utf8");
      const nestedLinks = extractDownloadLinksFromHtml(html);
      for (const nested of nestedLinks.slice(0, 5)) {
        if (visited.has(nested)) continue;
        visited.add(nested);
        try {
          const nestedData = await downloadUrl(nested);
          await processDownloaded(
            messageId,
            nested,
            nestedData,
            errors,
            files,
            failuresRef,
            visited,
            depth + 1,
          );
        } catch (error) {
          failuresRef.value += 1;
          errors.push(
            `Message ${messageId}/${nested}: ${describeError(error)}`,
          );
        }
      }
      if (nestedLinks.length === 0) {
        failuresRef.value += 1;
        errors.push(
          `Message ${messageId}/${link}: download returned an HTML page, not a file`,
        );
      }
    } else {
      failuresRef.value += 1;
      errors.push(
        `Message ${messageId}/${link}: download returned an HTML page, not a file`,
      );
    }
    return;
  }

  const isZip = isZipBytes(data);
  const url = link.toLowerCase();

  if (isZip || url.endsWith(".zip")) {
    try {
      const extracted = await extractStatementFiles(
        data,
        config.kfintechZipPassword,
        "kfintech.zip",
      );
      files.push(...extracted);
    } catch (error) {
      failuresRef.value += 1;
      errors.push(
        `Message ${messageId}/${link}: ${describeError(error)}`,
      );
    }
    return;
  }

  if (url.endsWith(".csv") || url.endsWith(".txt")) {
    const text = decodeCsv(data);
    if (text.trim().length === 0) {
      failuresRef.value += 1;
      errors.push(`Message ${messageId}/${link}: empty statement`);
      return;
    }
    files.push({ filename: link.split("/").pop() || "statement.csv", text });
    return;
  }

  // Unknown content type: try zip first, then treat as CSV text.
  try {
    const extracted = await extractStatementFiles(
      data,
      config.kfintechZipPassword,
      "kfintech.zip",
    );
    files.push(...extracted);
  } catch {
    const text = decodeCsv(data);
    if (text.trim().length > 0 && text.includes(",")) {
      files.push({ filename: "statement.csv", text });
    } else {
      failuresRef.value += 1;
      errors.push(`Message ${messageId}/${link}: not a CSV or zip`);
    }
  }
}

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

  const rawLinks = [
    ...new Set([
      ...extractLinks(detail.data.payload),
      ...extractLinksFromText(detail.data.snippet ?? ""),
    ]),
  ];
  // Tracker links resolve to the archive itself; prefer those and keep the
  // original as a fallback.
  const decoded = rawLinks
    .map((link) => decodeTrackerLink(link))
    .filter((link): link is string => Boolean(link));
  const links = [...new Set([...decoded, ...rawLinks])];
  // Drop obvious non-download links (images, tracking pixels, mailto) so we do
  // not waste minutes fetching them.
  const candidates = links.filter((link) => isDownloadLink(link));
  const toFetch = (candidates.length > 0 ? candidates : links).slice(0, 10);
  if (toFetch.length === 0) {
    errors.push(`Message ${messageId}: no download link found`);
    return { messageId, files: [], failures: 1 };
  }

  const files: StatementFile[] = [];
  const failuresRef = { value: 0 };
  const visited = new Set<string>(toFetch);

  for (const link of toFetch) {
    try {
      const data = await downloadUrl(link);
      await processDownloaded(
        messageId,
        link,
        data,
        errors,
        files,
        failuresRef,
        visited,
        0,
      );
    } catch (error) {
      failuresRef.value += 1;
      errors.push(`Message ${messageId}/${link}: ${describeError(error)}`);
      logger.error("KFintech download failed", { messageId, link, error });
    }
  }

  return { messageId, files, failures: failuresRef.value };
}

async function backfillFolioMaster(
  gmail: ReturnType<typeof createGmailClient>,
  directory: FolioDirectory,
): Promise<number> {
  const list = await gmail.users.messages.list({
    userId: "me",
    q: kfintechGmailQuery,
    maxResults: 5,
  });

  let rows = 0;
  for (const message of list.data.messages ?? []) {
    const messageId = message.id;
    if (!messageId) continue;

    try {
      const bundle = await readMessage(gmail, messageId, []);
      for (const file of bundle.files) {
        if (!isFolioMasterCsv(file.text)) continue;
        rows += parseFolioMaster(file.text, directory);
      }
    } catch (error) {
      logger.warn("Could not read the KFintech investor master", {
        messageId,
        error,
      });
    }
  }

  return rows;
}

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

export async function runKfintechSync(
  trigger: SyncTrigger,
  actor = "",
): Promise<SyncSummary> {
  if (inProgress) {
    throw HttpError.conflict(
      "A KFintech sync is already running. Try again in a minute.",
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
    const labelId = await ensureProcessedLabel(
      gmail,
      config.kfintechProcessedLabel,
    );

    const list = await gmail.users.messages.list({
      userId: "me",
      q: kfintechGmailQuery,
      maxResults: config.maxMessages,
    });
    const messages = list.data.messages ?? [];
    messagesScanned = messages.length;

    const bundles: { messageId: string; files: StatementFile[]; failures: number }[] =
      [];
    for (const message of messages) {
      const messageId = message.id;
      if (!messageId) continue;

      try {
        const bundle = await readMessage(gmail, messageId, errors);
        bundles.push(bundle);
      } catch (error) {
        errors.push(`Message ${messageId}: ${describeError(error)}`);
        logger.error("KFintech message download failed", { messageId, error });
      }
    }

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
    if (masterRows === 0) {
      masterRows += await backfillFolioMaster(gmail, directory);
    }

    if (masterRows > 0) await storeFolioDirectory(directory);
    foliosMapped = directory.size;

    const resolveUid = createUidResolver();

    for (const bundle of bundles) {
      attachmentsParsed += bundle.files.length;

      for (const file of bundle.files) {
        const rows = extractRows(file.text);
        if (rows.length === 0) continue;
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
            `Message ${bundle.messageId}/${file.filename}: no investor master known yet`,
          );
        } else if (fileRows === 0) {
          const columns = headerTokens(file.text).slice(0, 24).join(", ");
          errors.push(
            `Message ${bundle.messageId}/${file.filename}: no rows could be mapped (columns: ${columns || "none detected"})`,
          );
        }
      }

      // Consume a message once it has yielded at least one statement, even if
      // a secondary link failed. Keeping it unread re-downloaded the same 25
      // emails on every run and took minutes each time.
      if (bundle.failures > 0 && bundle.files.length === 0) continue;

      await markProcessed(gmail, bundle.messageId, labelId);
      logger.info("Processed KFintech email", {
        messageId: bundle.messageId,
        files: bundle.files.length,
      });
    }

    if (unmappedRows > 0) {
      logger.info("Skipped KFintech rows without a client master folio", {
        unmappedRows,
      });
    }
  } catch (error) {
    fatalError = describeError(error);
    errors.push(fatalError);
    logger.error("KFintech sync aborted", error);
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

  logger.info("KFintech sync finished", summary);
  return summary;
}
