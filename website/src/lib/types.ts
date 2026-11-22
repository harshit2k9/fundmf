/** Mirrors the Flutter app domain models so both clients agree. */

export type AccountStatus = 'unclaimed' | 'pendingApproval' | 'active';

export interface UserProfile {
  /** Lower-cased email; also the Firestore document id. */
  email: string;
  fullName: string;
  pan: string;
  phone: string;
  uid: string;
  isApproved: boolean;
  clientId: string;
  createdAt?: Date | null;
  linkedAt?: Date | null;
  lastLoginAt?: Date | null;
}

export interface NavQuote {
  schemeCode: number;
  schemeName: string;
  fundHouse: string;
  nav: number;
  date: Date;
}

export type TransactionKind =
  | 'Purchase'
  | 'SIP'
  | 'Redemption'
  | 'Switch-In'
  | 'Switch-Out'
  | 'Other';

export interface FundTransaction {
  id: string;
  transactionId: string;
  pan: string;
  uid: string;
  folioNumber: string;
  schemeName: string;
  schemeCode: number;
  transactionDate: Date;
  kind: TransactionKind;
  rawType: string;
  amount: number;
  units: number;
  purchaseNav: number;
  sourceMessageId: string;
  processedAt?: Date | null;
}

export interface SchemeHolding {
  schemeCode: number;
  schemeName: string;
  folios: string[];
  units: number;
  investedAmount: number;
  averageNav: number;
  currentNav: number;
  currentValue: number;
  pnl: number;
  pnlPercent: number;
  allocationPercent: number;
  cagrPercent: number;
  navAvailable: boolean;
  navDate?: Date | null;
}

export interface PortfolioSummary {
  totalInvested: number;
  currentValue: number;
  absolutePnl: number;
  returnPercent: number;
  cagrPercent: number;
  totalUnits: number;
  holdings: SchemeHolding[];
  closedSchemes: number;
  hasLiveNav: boolean;
  asOf: Date;
}

export interface SyncResult {
  status: string;
  messagesScanned: number;
  attachmentsParsed: number;
  transactionsCreated: number;
  duplicatesSkipped: number;
  errors: string[];
  durationMs: number;
  trigger: string;
  foliosMapped: number;
  unmappedRows: number;
}

export interface SyncLogEntry {
  id: string;
  status: string;
  trigger: string;
  startedAt?: Date | null;
  finishedAt?: Date | null;
  messagesScanned: number;
  transactionsCreated: number;
  duplicatesSkipped: number;
  errors: string[];
  actor: string;
  errorMessage: string;
  durationMs: number;
  foliosMapped: number;
  unmappedRows: number;
}

export type SessionStatus =
  | 'loading'
  | 'signedOut'
  | 'unprovisioned'
  | 'pendingApproval'
  | 'active'
  | 'admin';
