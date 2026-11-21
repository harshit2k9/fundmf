import { parse } from "csv-parse/sync";

import { logger } from "../logger";
import type { ParsedTransaction, TransactionType } from "../types";

const normalizeToken = (value: string): string =>
  value.toLowerCase().replace(/[^a-z0-9]/g, "");

/**
 * CAMS statements exist in several layouts. Each logical field is matched
 * against a list of normalized header aliases instead of fixed positions.
 *
 * The R9/R10 feed used by fundmfservices carries the investor master
 * (FOLIOCHK / PAN_NO / PRODUCT / SCH_NAME) in one CSV and the transaction
 * tape (AMC_CODE / FOLIO_CHK / SCH_CODE / TRXNTYPE / TRADDATE ...) in another,
 * so both layouts are described here.
 */
const COLUMN_ALIASES = {
  transactionId: [
    "Transaction ID",
    "Transaction_ID",
    "Transaction No",
    "Txn ID",
    "Transaction Number",
    "Trxn ID",
    "TRXNNO",
    "Trxn No",
  ].map(normalizeToken),
  pan: ["PAN", "PAN Number", "Investor PAN", "Primary PAN", "PAN_NO"].map(
    normalizeToken,
  ),
  folio: [
    "Folio",
    "Folio No",
    "Folio Number",
    "Folio_Number",
    "Account Number",
    "FOLIOCHK",
    "FOLIO_CHK",
  ].map(normalizeToken),
  schemeName: [
    "Scheme",
    "Scheme Name",
    "Scheme_Name",
    "Fund",
    "Fund Name",
    "SCH_NAME",
  ].map(normalizeToken),
  schemeCode: ["Scheme Code", "AMFI Code", "AMFI Scheme Code", "Code"].map(
    normalizeToken,
  ),
  internalSchemeCode: ["SCH_CODE", "Product Code", "Scheme Internal Code"].map(
    normalizeToken,
  ),
  product: ["PRODUCT"].map(normalizeToken),
  amcCode: ["AMC_CODE", "AMC Code", "AMC"].map(normalizeToken),
  investorName: ["INV_NAME", "Investor Name", "Investor"].map(normalizeToken),
  date: [
    "Date",
    "Transaction Date",
    "Transaction_Date",
    "Posting Date",
    "TRADDATE",
    "Trade Date",
  ].map(normalizeToken),
  type: [
    "Type",
    "Transaction Type",
    "Transaction_Type",
    "Description",
    "Transaction Description",
    "TRXNTYPE",
    "Trxn Type",
  ].map(normalizeToken),
  amount: [
    "Amount",
    "Amount (INR)",
    "Transaction Amount",
    "Gross Amount",
  ].map(normalizeToken),
  units: ["Units", "Units Allotted", "Quantity", "Unit"].map(normalizeToken),
  nav: [
    "NAV",
    "Purchase NAV",
    "Purchase_NAV",
    "Price",
    "NAV Price",
    "Rate",
    "PURPRICE",
    "Purchase Price",
  ].map(normalizeToken),
  status: ["TRXNSTAT", "Transaction Status", "Status"].map(normalizeToken),
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

  const numeric = /^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})(?:[ T]\d{1,2}:\d{2}(?::\d{2})?\s*(?:AM|PM)?)?/i.exec(
    value,
  );
  if (numeric) {
    const first = Number(numeric[1]);
    const second = Number(numeric[2]);
    let year = Number(numeric[3]);
    // The R9/R10 transaction tape stamps dates as M/D/YYYY hh:mm:ss AM/PM.
    // Legacy layouts use dd/MM/yyyy, so only a timestamp forces month-first.
    const monthFirst = (numeric[0].match(/\d{1,2}:\d{2}/) ?? []).length > 0;
    let day = monthFirst ? second : first;
    let month = monthFirst ? first : second;
    if (month > 12 && day <= 12) {
      const swap = day;
      day = month;
      month = swap;
    }
    if (year < 100) year += 2000;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    const date = new Date(year, month - 1, day);
    if (
      Number.isNaN(date.getTime()) ||
      date.getMonth() !== month - 1 ||
      date.getDate() !== day
    ) {
      return null;
    }
    return date;
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

/**
 * Maps both descriptive type names and the short RTA codes found in the
 * transaction tape (P*, R*, S*, T*, D*).
 */
function mapTransactionType(rawType: string): TransactionType {
  const value = normalizeToken(rawType);
  if (!value) return "Other";

  if (value.includes("switch") || value.includes("switching")) {
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

  const code = rawType.trim().toUpperCase();
  if (code.includes("SIP")) return "SIP";
  const prefix = code.charAt(0);
  if (prefix === "P") return "Purchase";
  if (prefix === "R") return "Redemption";
  if (prefix === "S" || prefix === "T") {
    if (code.includes("OUT") || /^(SO|SOW|SWO|TO|TOW|TWO)/.test(code)) {
      return "Switch-Out";
    }
    if (code.includes("IN") || /^(SI|SIW|SWI|TI|TIW|TWI)/.test(code)) {
      return "Switch-In";
    }
  }
  return "Other";
}

/** Finds the real header row: CAMS files often start with a preamble block. */
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

function normalizePan(value: string): string {
  return value.toUpperCase().replace(/[^A-Z0-9]/g, "");
}

/** One folio in the investor master ("static detail") CSV. */
export interface FolioAccount {
  amcCode: string;
  folioNumber: string;
  pan: string;
  investorName: string;
  /** RTA scheme code (SCH_CODE / PRODUCT suffix) -> scheme name. */
  schemes: Map<string, string>;
}

function folioKey(amcCode: string, folioNumber: string): string {
  return `${amcCode.toUpperCase()}|${folioNumber.trim().toUpperCase()}`;
}

/**
 * The CAMS transaction tape identifies an investor by folio, not by PAN. This
 * directory is built from the investor master CSV so every transaction can be
 * tied to the client's PAN (and therefore to their Fundmf profile).
 */
export class FolioDirectory {
  private readonly accounts = new Map<string, FolioAccount>();
  private readonly byFolio = new Map<string, FolioAccount>();

  add(account: FolioAccount): void {
    const key = folioKey(account.amcCode, account.folioNumber);
    const existing = this.accounts.get(key);

    if (existing) {
      for (const [code, name] of account.schemes) {
        if (!existing.schemes.has(code)) existing.schemes.set(code, name);
      }
      return;
    }

    this.accounts.set(key, account);
    if (!this.byFolio.has(account.folioNumber.trim().toUpperCase())) {
      this.byFolio.set(account.folioNumber.trim().toUpperCase(), account);
    }
  }

  /** Resolves a folio, preferring the AMC-scoped key over a bare folio match. */
  find(amcCode: string, folioNumber: string): FolioAccount | undefined {
    const folio = folioNumber.trim().toUpperCase();
    if (!folio) return undefined;
    return this.accounts.get(folioKey(amcCode, folio)) ?? this.byFolio.get(folio);
  }

  schemeName(amcCode: string, folioNumber: string, internalCode: string): string {
    const account = this.find(amcCode, folioNumber);
    if (!account) return "";
    return account.schemes.get(internalCode.toUpperCase()) ?? "";
  }

  /** Distinct folios (the number of clients whose statements were mapped). */
  get size(): number {
    return this.accounts.size;
  }
}

/**
 * True for the investor/holding master: it carries a PAN, a folio and the
 * scheme catalogue, and no transaction columns.
 */
export function isFolioMasterCsv(csvText: string): boolean {
  const lines = csvText.replace(/^\uFEFF/, "").split(/\r?\n/);
  const headerIndex = findHeaderLineIndex(lines);
  if (headerIndex < 0) return false;

  const tokens = new Set(lines[headerIndex].split(",").map(normalizeToken));
  const hasAny = (aliases: readonly string[]): boolean =>
    aliases.some((alias) => tokens.has(alias));

  return (
    hasAny(COLUMN_ALIASES.folio) &&
    hasAny(COLUMN_ALIASES.pan) &&
    (hasAny(COLUMN_ALIASES.product) ||
      hasAny(COLUMN_ALIASES.internalSchemeCode))
  );
}

/**
 * Reads the investor master CSV into [directory]. Each row is one folio +
 * scheme pair, so folios repeat; the directory merges the scheme catalogue.
 * Returns the number of master rows consumed.
 */
export function parseFolioMaster(
  csvText: string,
  directory: FolioDirectory,
): number {
  const rows = extractRows(csvText);
  let consumed = 0;

  for (const row of rows) {
    const folioNumber = readField(row, "folio");
    const pan = normalizePan(readField(row, "pan"));
    if (!folioNumber || !pan) continue;

    const amcCode = readField(row, "amcCode").toUpperCase();
    const product = readField(row, "product").toUpperCase();
    let internalCode = readField(row, "internalSchemeCode").toUpperCase();
    if (!internalCode && amcCode && product.startsWith(amcCode)) {
      internalCode = product.slice(amcCode.length);
    }
    if (!internalCode) internalCode = product;

    const schemeName = readField(row, "schemeName");
    const account: FolioAccount = {
      amcCode,
      folioNumber,
      pan,
      investorName: readField(row, "investorName"),
      schemes: new Map<string, string>(),
    };
    if (internalCode && schemeName) account.schemes.set(internalCode, schemeName);

    directory.add(account);
    consumed += 1;
  }

  return consumed;
}

export interface MappedRow {
  transaction: ParsedTransaction | null;
  /** True when the row is a real transaction whose folio is not in the master. */
  unmapped: boolean;
}

/**
 * Maps one transaction-tape row. PAN and scheme name come from the folio
 * directory (the transaction CSV itself has neither); statements that still
 * carry a PAN column keep working as before.
 */
export function mapTransactionRow(
  row: Record<string, string>,
  directory: FolioDirectory,
): MappedRow {
  const amcCode = readField(row, "amcCode").toUpperCase();
  const folioNumber = readField(row, "folio");
  const internalCode = readField(row, "internalSchemeCode").toUpperCase();

  const amount = parseNumber(readField(row, "amount"));
  const units = parseNumber(readField(row, "units"));

  // Non-financial rows (address change, nominee, joint holder, ...) carry no
  // money and no units.
  if (amount === 0 && units === 0) return { transaction: null, unmapped: false };

  // Rejected / reversed rows never reach the ledger.
  const status = readField(row, "status").toUpperCase();
  if (status && status !== "Y") return { transaction: null, unmapped: false };

  const account = directory.find(amcCode, folioNumber);
  const pan = normalizePan(readField(row, "pan")) || account?.pan || "";
  if (!pan) return { transaction: null, unmapped: true };

  const date = parseDate(readField(row, "date"));
  if (!date) return { transaction: null, unmapped: false };

  const rawType = readField(row, "type");
  const kind = mapTransactionType(rawType);
  const fallbackName = internalCode ? `Scheme ${internalCode}` : "Unknown scheme";
  const schemeName =
    readField(row, "schemeName") ||
    directory.schemeName(amcCode, folioNumber, internalCode) ||
    fallbackName;

  const nav = parseNumber(readField(row, "nav"));

  const transactionNumber = sanitizeId(readField(row, "transactionId"));
  // The RTA transaction number is unique per AMC; namespace it so two AMCs
  // can never collide on a Firestore document id.
  const explicitId = transactionNumber
    ? sanitizeId(`${amcCode || "AMC"}-${transactionNumber}`)
    : "";
  // No transaction number: build a deterministic key so re-syncs of the same
  // statement are still idempotent.
  const derivedId = sanitizeId(
    `${amcCode || "AMC"}-${folioNumber}-${date.toISOString().slice(0, 10)}-` +
      `${internalCode || schemeName}-${units}-${amount}-${kind}`,
  );

  return {
    unmapped: false,
    transaction: {
      transactionId: explicitId || derivedId,
      pan,
      folioNumber,
      amcCode,
      schemeName,
      schemeCode: Number.parseInt(readField(row, "schemeCode"), 10) || 0,
      transactionDate: date,
      transactionType: kind,
      rawType: rawType || kind,
      amount,
      units,
      purchaseNav: nav,
    },
  };
}
