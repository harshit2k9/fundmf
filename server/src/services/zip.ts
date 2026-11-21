import { TextWriter, Uint8ArrayReader, ZipReader } from "@zip.js/zip.js";

/** A statement file recovered from a CAMS email attachment. */
export interface StatementFile {
  filename: string;
  text: string;
}

/** Guard rails so a malformed or hostile archive cannot exhaust memory. */
const MAX_ENTRIES = 40;
const MAX_ENTRY_BYTES = 64 * 1024 * 1024;

/**
 * Extracts every CSV from a CAMS zip attachment.
 *
 * The statements arrive as a password protected archive (both the classic
 * ZipCrypto flavour and WinZip AES are handled by @zip.js/zip.js), with the
 * investor master ("CSV with Headers") and the transaction feed inside it.
 */
export async function extractCsvFiles(
  archive: Buffer,
  password: string,
  archiveName = "statement.zip",
): Promise<StatementFile[]> {
  const reader = new ZipReader(
    new Uint8ArrayReader(new Uint8Array(archive)),
    password ? { password } : {},
  );

  try {
    const entries = await reader.getEntries();
    if (entries.length > MAX_ENTRIES) {
      throw new Error(
        `${archiveName} contains ${entries.length} entries; expected only CSV statements.`,
      );
    }

    const files: StatementFile[] = [];
    for (const entry of entries) {
      if (entry.directory) continue;
      const name = entry.filename ?? "";
      if (!name.toLowerCase().endsWith(".csv")) continue;
      if (entry.uncompressedSize > MAX_ENTRY_BYTES) {
        throw new Error(`${name} is too large to import (${entry.uncompressedSize} bytes).`);
      }

      const text = await entry.getData(new TextWriter("utf-8"));
      if (typeof text !== "string" || text.trim().length === 0) continue;
      files.push({ filename: name, text });
    }

    if (files.length === 0) {
      throw new Error(`${archiveName} does not contain a CSV statement.`);
    }
    return files;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (/invalid password|password/i.test(message)) {
      throw new Error(
        `Could not open ${archiveName}: zip password is missing or incorrect. ` +
          "Check CAMS_ZIP_PASSWORD on the server.",
      );
    }
    throw new Error(`Could not read ${archiveName}: ${message}`);
  } finally {
    await reader.close();
  }
}
