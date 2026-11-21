import {
  Uint8ArrayReader,
  Uint8ArrayWriter,
  ZipReader,
} from "@zip.js/zip.js";

/** A statement file recovered from a CAMS email attachment. */
export interface StatementFile {
  filename: string;
  text: string;
}

/** Guard rails so a malformed or hostile archive cannot exhaust memory. */
const MAX_ENTRIES = 200;
const MAX_ENTRY_BYTES = 32 * 1024 * 1024;
const MAX_DEPTH = 2;

/** Document attachments that ride along in the same mailbox (KYC forms). */
const BINARY_EXTENSIONS = [
  ".pdf",
  ".png",
  ".jpg",
  ".jpeg",
  ".gif",
  ".bmp",
  ".tif",
  ".tiff",
  ".xls",
  ".xlsx",
  ".doc",
  ".docx",
  ".ppt",
  ".pptx",
  ".msg",
  ".eml",
];

function isBinaryName(name: string): boolean {
  const lower = name.toLowerCase();
  return BINARY_EXTENSIONS.some((extension) => lower.endsWith(extension));
}

/** Decodes UTF-8/UTF-16 text, rejecting binary payloads (stray NUL bytes). */
function decodeText(bytes: Uint8Array): string {
  // Some CAMS CRMS exports are UTF-16 with a byte order mark.
  if (bytes.length > 1) {
    if (bytes[0] === 0xff && bytes[1] === 0xfe) {
      return new TextDecoder("utf-16le").decode(bytes).replace(/^\uFEFF/, "");
    }
    if (bytes[0] === 0xfe && bytes[1] === 0xff) {
      return new TextDecoder("utf-16be").decode(bytes).replace(/^\uFEFF/, "");
    }
  }
  if (bytes.includes(0)) return "";
  return new TextDecoder("utf-8").decode(bytes).replace(/^\uFEFF/, "");
}

/**
 * CAMS mailback archives do not always keep the `.csv` extension on the report
 * inside them, so the content decides: a statement always has comma separated
 * rows.
 */
function looksLikeCsv(text: string): boolean {
  const lines = text.split(/\r?\n/).filter((line) => line.trim().length > 0);
  return lines
    .slice(0, 60)
    .some((line) => (line.match(/,/g) ?? []).length >= 2);
}

function translateError(error: unknown, archiveName: string): Error {
  const message = error instanceof Error ? error.message : String(error);
  if (message.startsWith("Could not read") || message.startsWith(`${archiveName} `)) {
    return error instanceof Error ? error : new Error(message);
  }
  if (/invalid password|password|encrypted/i.test(message)) {
    return new Error(
      `Could not open ${archiveName}: zip password is missing or incorrect. ` +
        "Check CAMS_ZIP_PASSWORD on the server.",
    );
  }
  return new Error(`Could not read ${archiveName}: ${message}`);
}

/**
 * Extracts every statement text file from a CAMS zip attachment, including
 * zips nested inside it. The investor master ("CSV with Headers") and the
 * transaction feed are both returned; files that are not comma separated
 * reports (PDFs, KYC forms) are ignored.
 */
export async function extractStatementFiles(
  archive: Buffer,
  password: string,
  archiveName = "statement.zip",
  depth = 0,
): Promise<StatementFile[]> {
  const reader = new ZipReader(
    new Uint8ArrayReader(new Uint8Array(archive)),
    password ? { password } : {},
  );

  const files: StatementFile[] = [];
  let csvEntriesSeen = 0;

  try {
    const entries = await reader.getEntries();
    if (entries.length > MAX_ENTRIES) {
      throw new Error(
        `${archiveName} contains ${entries.length} entries; expected only CSV statements.`,
      );
    }

    for (const entry of entries) {
      if (entry.directory) continue;
      const name = entry.filename ?? "";
      const lower = name.toLowerCase();
      if (entry.uncompressedSize > MAX_ENTRY_BYTES) {
        throw new Error(
          `${name} is too large to import (${entry.uncompressedSize} bytes).`,
        );
      }

      // CAMS sometimes ships <report>.zip containing <report>.zip.
      if (lower.endsWith(".zip")) {
        if (depth >= MAX_DEPTH) continue;
        const nested = (await entry.getData(
          new Uint8ArrayWriter(),
        )) as Uint8Array;
        if (nested.length === 0) continue;
        files.push(
          ...(await extractStatementFiles(
            Buffer.from(nested),
            password,
            name,
            depth + 1,
          )),
        );
        continue;
      }

      if (isBinaryName(name)) continue;

      const bytes = (await entry.getData(
        new Uint8ArrayWriter(),
      )) as Uint8Array;
      const text = decodeText(bytes);
      if (lower.endsWith(".csv") || lower.endsWith(".txt")) {
        csvEntriesSeen += 1;
      }
      if (text.trim().length === 0) continue;
      if (!looksLikeCsv(text)) continue;

      files.push({ filename: name || `${archiveName}.csv`, text });
    }

    if (files.length === 0 && csvEntriesSeen > 0) {
      throw new Error(
        `${archiveName} contains CSV entries that could not be decoded; ` +
          "the zip password is probably wrong.",
      );
    }

    return files;
  } catch (error) {
    throw translateError(error, archiveName);
  } finally {
    await reader.close();
  }
}
