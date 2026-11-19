export type TransactionType =
  | "Purchase"
  | "SIP"
  | "Redemption"
  | "Switch-In"
  | "Switch-Out"
  | "Other";

export interface ParsedTransaction {
  transactionId: string;
  pan: string;
  folioNumber: string;
  schemeName: string;
  schemeCode: number;
  transactionDate: Date;
  transactionType: TransactionType;
  rawType: string;
  amount: number;
  units: number;
  purchaseNav: number;
}

export type SyncTrigger = "scheduled" | "manual";

export interface SyncSummary {
  status: "success" | "partial" | "failed";
  trigger: SyncTrigger;
  messagesScanned: number;
  attachmentsParsed: number;
  transactionsCreated: number;
  duplicatesSkipped: number;
  errors: string[];
  durationMs: number;
  startedAt: string;
  finishedAt: string;
}
