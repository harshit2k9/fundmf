import { parse } from "csv-parse/sync";

import { logger } from "../logger";
import type { ParsedTransaction, TransactionType } from "../types";

const normalizeToken = (value: string): string =>
  value.toLowerCase().replace(/[^a-z0-9]/g, "");

/**
 * CAMS statements exist in several layouts. Each logical field is matched
 * against a list of normalized header aliases instead of fixed positions.
 */
const COLUMN_ALIASES = {
  transactionId: [
    "Transaction ID",
    "Transaction_ID",
    "Transaction No",
    "Txn ID",
    "Transaction Number",
    "Trxn ID",
  ].map(normalizeToken),
  pan: ["PAN", "PAN Number", "Investor PAN", "Primary PAN"].map(normalizeToken),
  folio: [
    "Folio",
    "Folio No",
    "Folio Number",
    "Folio_Number",
    "Account Number",
  ].map(normalizeToken),
  schemeName: [
    "Scheme",
    "Scheme Name",
    "Scheme_Name",
    "Fund",
    "Fund Name",
  ].map(normalizeToken),
  schemeCode: ["Scheme Code", "AMFI Code", "AMFI Scheme Code", "Code"].map(
    normalizeToken,
  ),
  date: ["Date", "Transaction Date", "Transaction_Date", "Posting Date"].map(
    normalizeToken,
  ),
  type: [
    "Type",
    "Transaction Type",
    "Transaction_Type",
    "Description",
    "Transaction Description",
  ].map(normalizeToken),
  amount: [
    "Amount",
    "Amount (INR)",
    "Transaction Amount",
    "Gross Amount",
  ].map(normalizeToken),
  units: ["Units", "Units Allotted", "Quantity", "Unit"].map(normalizeToken),
  nav: ["NAV", "Purchase NAV", "Purchase_NAV", "Price", "NAV Price", "Rate"].map(
    normalizeToken,
  ),
} as const;

type ColumnKey = keyof typeof COLUMN_ALIASES;

const KNOWN_HEADERS = new Set<string>(Object.values(COLUMN_ALIASES).flat());

const MONTHS: Record<string, number> = {
  jan: 1,
  feb: 2,
  mar: 3,
  apr: 4,
  may: 5,
  jun: 6,
  jul: 7,
  aug: 8,
  sep: 9,
  oct: 10,
  nov: 11,
  dec: 12,
};

function readField(row: Record<string, string>, key: ColumnKey): string {
  for (const alias of COLUMN_ALIASES[key]) {
    const value = row[alias];
    if (value && value.trim().length > 0) return value.trim();
  }
  return "";
}

function parseNumber(raw: string): number {
  if (!raw) return 0;
  const negative = raw.trim().startsWith("(") && raw.trim().endsWith(")");
  const cleaned = raw.replace(/[^0-9.\-]/g, "");
  const value = Number.parseFloat(cleaned);
  if (!Number.isFinite(value)) return 0;
  return Math.abs(negative ? -value : value);
}

/** Accepts dd-MMM-yyyy, dd/MM/yyyy, dd-MM-yyyy and yyyy-MM-dd. */
function parseDate(raw: string): Date | null {
  const value = raw.trim();
  if (!value) return null;

  const iso = /^(\d{4})-(\d{2})-(\d{2})/.exec(value);
  if (iso) {
    return new Date(Number(iso[1]), Number(iso[2]) - 1, Number(iso[3]));
  }

  const numeric = /^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})/.exec(value);
  if (numeric) {
    const day = Number(numeric[1]);
    const month = Number(numeric[2]);
    let year = Number(numeric[3]);
    if (year < 100) year += 2000;
    const date = new Date(year, month - 1, day);
    return Number.isNaN(date.getTime()) ? null : date;
  }

  const named = /^(\d{1,2})-([A-Za-z]{3,})-(\d{2,4})/.exec(value);
  if (named) {
    const month = MONTHS[named[2].slice(0, 3).toLowerCase()];
    if (!month) return null;
    const day = Number(named[1]);
    let year = Number(named[3]);
    if (year < 100) year += 2000;
    return new Date(year, month - 1, day);
  }

  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function mapTransactionType(rawType: string): TransactionType {
  const value = normalizeToken(rawType);
  if (!value) return "Other";

  if (value.includes("switch")) {
    if (value.includes("out")) return "Switch-Out";
    if (value.includes("in")) return "Switch-In";
  }
  if (value.includes("redemption") || value.includes("redeem")) {
    return "Redemption";
  }
  if (value.includes("systematic") || value.includes("sip")) {
    return "SIP";
  }
  if (
    value.includes("purchase") ||
    value.includes("investment") ||
    value.includes("subscription") ||
    value.includes("allotment")
  ) {
    return "Purchase";
  }
  return "Other";
}

/**
 * Finds the real header row: CAMS files often start with an investor/address
 * block before the transaction table.
 */
function findHeaderLineIndex(lines: string[]): number {
  for (let index = 0; index < Math.min(lines.length, 60); index += 1) {
    const line = lines[index];
    if (!line || line.trim().length === 0) continue;
    const tokens = line.split(",").map(normalizeToken);
    const matches = tokens.filter((token) => KNOWN_HEADERS.has(token)).length;
    if (matches >= 3) return index;
  }
  return -1;
}

export function extractRows(csvText: string): Array<Record<string, string>> {
  const lines = csvText.replace(/^\uFEFF/, "").split(/\r?\n/);
  const headerIndex = findHeaderLineIndex(lines);
  if (headerIndex < 0) return [];

  const payload = lines.slice(headerIndex).join("\n");
  let matrix: string[][];
  try {
    matrix = parse(payload, {
      bom: true,
      trim: true,
      skip_empty_lines: true,
      relax_column_count: true,
    }) as string[][];
  } catch (error) {
    logger.warn("Could not parse CSV payload", error);
    return [];
  }

  if (matrix.length < 2) return [];
  const headers = matrix[0].map(normalizeToken);

  return matrix.slice(1).map((cells) => {
    const row: Record<string, string> = {};
    headers.forEach((header, index) => {
      if (header) row[header] = (cells[index] ?? "").trim();
    });
    return row;
  });
}

/** Firestore ids cannot contain '/', and must be reasonably short. */
function sanitizeId(value: string): string {
  return value.replace(/[/\\#?[\]]/g, "_").trim().slice(0, 400);
}

export function mapRow(
  row: Record<string, string>,
): ParsedTransaction | null {
  const pan = readField(row, "pan").toUpperCase().replace(/[^A-Z0-9]/g, "");
  const schemeName = readField(row, "schemeName");
  const date = parseDate(readField(row, "date"));
  const rawType = readField(row, "type");

  if (!pan || !schemeName || !date) return null;

  const amount = parseNumber(readField(row, "amount"));
  const units = parseNumber(readField(row, "units"));
  const nav = parseNumber(readField(row, "nav"));
  const kind = mapTransactionType(rawType);

  // Skip footer/notes rows that carry no money or units.
  if (amount === 0 && units === 0) return null;

  const explicitId = sanitizeId(readField(row, "transactionId"));
  // No Transaction_ID in the file: build a deterministic key so re-syncs of the
  // same statement are still idempotent.
  const derivedId = sanitizeId(
    `${pan}-${date.toISOString().slice(0, 10)}-${schemeName}-${units}-${amount}-${kind}`,
  );

  return {
    transactionId: explicitId || derivedId,
    pan,
    folioNumber: readField(row, "folio"),
    schemeName,
    schemeCode: Number.parseInt(readField(row, "schemeCode"), 10) || 0,
    transactionDate: date,
    transactionType: kind,
    rawType: rawType || kind,
    amount: Math.abs(amount),
    units: Math.abs(units),
    purchaseNav: Math.abs(nav),
  };
}
