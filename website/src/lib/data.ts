import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit as limitTo,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  type DocumentData,
  type Unsubscribe,
} from 'firebase/firestore';

import { API_BASE_URL, SYNC_PATH, db } from './firebase';
import { normalizeEmail, normalizePan } from './validators';
import type {
  FundTransaction,
  SyncLogEntry,
  SyncResult,
  TransactionKind,
  UserProfile,
} from './types';

/**
 * Firestore access, mirroring the Flutter repositories exactly:
 *   users/{email}              profile, email doubles as the document id
 *   transactions/{txId}        CAMS rows, keyed by Transaction_ID
 *   sync_logs/{autoId}         one entry per sync run
 */

const USERS = 'users';
const TRANSACTIONS = 'transactions';
const SYNC_LOGS = 'sync_logs';

const toDate = (value: unknown): Date | null => {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value === 'object' && value !== null && 'toDate' in value) {
    const candidate = value as { toDate: () => Date };
    if (typeof candidate.toDate === 'function') return candidate.toDate();
  }
  if (typeof value === 'number') return new Date(value);
  if (typeof value === 'string') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
};

const str = (value: unknown): string =>
  typeof value === 'string' ? value : value == null ? '' : String(value);

const num = (value: unknown): number => {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string') {
    const parsed = Number(value.replace(/,/g, ''));
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
};

const toKind = (raw: string): TransactionKind => {
  const value = raw.toLowerCase().replace(/[^a-z]/g, '');
  if (value.includes('switch')) {
    if (value.includes('out')) return 'Switch-Out';
    if (value.includes('in')) return 'Switch-In';
  }
  if (value.includes('redemption') || value.includes('redeem')) return 'Redemption';
  if (
    value.includes('systematic') ||
    value.includes('sip') ||
    value.includes('sipinstallment')
  ) {
    return 'SIP';
  }
  if (
    value.includes('purchase') ||
    value.includes('investment') ||
    value.includes('subscription') ||
    value.includes('allotment')
  ) {
    return 'Purchase';
  }
  return 'Other';
};

const mapProfile = (data: DocumentData, documentId?: string): UserProfile => {
  const rawEmail = str(data.email);
  return {
    email: normalizeEmail(rawEmail || documentId || ''),
    fullName: str(data.fullName),
    pan: normalizePan(str(data.pan)),
    phone: str(data.phone),
    uid: str(data.uid),
    isApproved: data.isApproved === true,
    clientId: str(data.clientId),
    createdAt: toDate(data.createdAt),
    linkedAt: toDate(data.linkedAt),
    lastLoginAt: toDate(data.lastLoginAt),
  };
};

const mapTransaction = (data: DocumentData, documentId: string): FundTransaction => {
  const storedId = str(data.transactionId);
  const rawType = str(data.transactionType);
  return {
    id: documentId || storedId,
    transactionId: storedId || documentId,
    pan: str(data.pan).toUpperCase(),
    uid: str(data.uid),
    folioNumber: str(data.folioNumber),
    schemeName: str(data.schemeName),
    schemeCode: num(data.schemeCode),
    transactionDate: toDate(data.transactionDate) ?? new Date(0),
    kind: toKind(rawType),
    rawType,
    amount: num(data.amount),
    units: num(data.units),
    purchaseNav: num(data.purchaseNav),
    sourceMessageId: str(data.sourceMessageId),
    processedAt: toDate(data.processedAt),
  };
};

// ------------------------------------------------------------------ users ---

export async function fetchProfile(email: string): Promise<UserProfile | null> {
  const snapshot = await getDoc(doc(db, USERS, normalizeEmail(email)));
  if (!snapshot.exists()) return null;
  return mapProfile(snapshot.data(), snapshot.id);
}

export function watchProfile(
  email: string,
  next: (profile: UserProfile | null) => void,
  onError?: (error: Error) => void,
): Unsubscribe {
  return onSnapshot(
    doc(db, USERS, normalizeEmail(email)),
    (snapshot) => {
      next(snapshot.exists() ? mapProfile(snapshot.data(), snapshot.id) : null);
    },
    (error) => onError?.(error),
  );
}

/** First login for an admin-provisioned email: bind the Firebase Auth uid. */
export const linkAuthUser = (email: string, uid: string): Promise<void> =>
  updateDoc(doc(db, USERS, normalizeEmail(email)), {
    uid,
    linkedAt: serverTimestamp(),
    lastLoginAt: serverTimestamp(),
  });

export const touchLastLogin = (email: string): Promise<void> =>
  updateDoc(doc(db, USERS, normalizeEmail(email)), {
    lastLoginAt: serverTimestamp(),
  });

// ----------------------------------------------------------- transactions ---

export function watchTransactionsForPan(
  pan: string,
  next: (transactions: FundTransaction[]) => void,
  onError?: (error: Error) => void,
  max = 500,
): Unsubscribe {
  const normalized = normalizePan(pan);
  if (!normalized) {
    next([]);
    return () => undefined;
  }
  const q = query(
    collection(db, TRANSACTIONS),
    where('pan', '==', normalized),
    orderBy('transactionDate', 'desc'),
    limitTo(max),
  );
  return onSnapshot(
    q,
    (snapshot) => {
      next(
        snapshot.docs.map((entry) => mapTransaction(entry.data(), entry.id)),
      );
    },
    (error) => onError?.(error),
  );
}

export async function fetchTransactionsForPan(
  pan: string,
  max = 500,
): Promise<FundTransaction[]> {
  const normalized = normalizePan(pan);
  if (!normalized) return [];
  const snapshot = await getDocs(
    query(
      collection(db, TRANSACTIONS),
      where('pan', '==', normalized),
      orderBy('transactionDate', 'desc'),
      limitTo(max),
    ),
  );
  return snapshot.docs.map((entry) => mapTransaction(entry.data(), entry.id));
}

// ------------------------------------------------------------ admin: users ---

export const generateClientId = (): string => {
  const now = new Date();
  const code = now.getTime().toString(36).toUpperCase();
  const suffix = code.length >= 5 ? code.slice(-5) : code;
  return `FMF-${now.getFullYear()}-${suffix}`;
};

export function watchAllProfiles(
  next: (profiles: UserProfile[]) => void,
  onError?: (error: Error) => void,
): Unsubscribe {
  return onSnapshot(
    query(collection(db, USERS), orderBy('fullName')),
    (snapshot) => {
      next(snapshot.docs.map((entry) => mapProfile(entry.data(), entry.id)));
    },
    (error) => onError?.(error),
  );
}

export async function createProfile(profile: UserProfile): Promise<void> {
  const email = normalizeEmail(profile.email);
  const reference = doc(db, USERS, email);
  if ((await getDoc(reference)).exists()) {
    throw new Error('A client with this email already exists.');
  }
  await setDoc(reference, {
    email,
    fullName: profile.fullName.trim(),
    pan: normalizePan(profile.pan),
    phone: profile.phone.trim(),
    uid: profile.uid.trim(),
    isApproved: profile.isApproved,
    clientId: profile.clientId.trim() || generateClientId(),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
}

export async function updateProfile(profile: UserProfile): Promise<void> {
  await updateDoc(doc(db, USERS, normalizeEmail(profile.email)), {
    fullName: profile.fullName.trim(),
    pan: normalizePan(profile.pan),
    phone: profile.phone.trim(),
    uid: profile.uid.trim(),
    isApproved: profile.isApproved,
    clientId: profile.clientId.trim(),
    updatedAt: serverTimestamp(),
  });
}

export const deleteProfile = (email: string): Promise<void> =>
  deleteDoc(doc(db, USERS, normalizeEmail(email)));

// -------------------------------------------------------------- sync logs ---

export function watchSyncLogs(
  next: (entries: SyncLogEntry[]) => void,
  onError?: (error: Error) => void,
  max = 25,
): Unsubscribe {
  const q = query(
    collection(db, SYNC_LOGS),
    orderBy('startedAt', 'desc'),
    limitTo(max),
  );
  return onSnapshot(
    q,
    (snapshot) => {
      next(
        snapshot.docs.map((entry) => {
          const data = entry.data();
          return {
            id: entry.id,
            status: str(data.status),
            trigger: str(data.trigger),
            startedAt: toDate(data.startedAt),
            finishedAt: toDate(data.finishedAt),
            messagesScanned: num(data.messagesScanned),
            transactionsCreated: num(data.transactionsCreated),
            duplicatesSkipped: num(data.duplicatesSkipped),
            errors: Array.isArray(data.errors)
              ? (data.errors as unknown[]).map((item) => String(item))
              : [],
            actor: str(data.actor),
            errorMessage: str(data.errorMessage),
            durationMs: num(data.durationMs),
            foliosMapped: num(data.foliosMapped),
            unmappedRows: num(data.unmappedRows),
          } satisfies SyncLogEntry;
        }),
      );
    },
    (error) => onError?.(error),
  );
}

// ----------------------------------------------------------- admin: sync ---

const SYNC_TIMEOUT_MS = 120_000;

/** POST /api/cams/sync with the admin's Firebase ID token. */
export async function triggerManualSync(idToken: string): Promise<SyncResult> {
  const controller = new AbortController();
  const timer = window.setTimeout(() => controller.abort(), SYNC_TIMEOUT_MS);

  let response: Response;
  try {
    response = await fetch(`${API_BASE_URL}${SYNC_PATH}`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${idToken}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({ trigger: 'manual' }),
      signal: controller.signal,
    });
  } catch (error) {
    if ((error as Error).name === 'AbortError') {
      throw new Error(
        'The sync is taking longer than expected. It may still finish — check the sync log in a minute.',
      );
    }
    throw new Error(
      'Could not reach the Fundmf API. Check your connection, or that the Render service is running.',
    );
  } finally {
    window.clearTimeout(timer);
  }

  const text = await response.text();
  let parsed: unknown = null;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch {
    parsed = null;
  }

  const serverMessage =
    parsed && typeof parsed === 'object' && 'message' in parsed
      ? String((parsed as { message?: unknown }).message ?? '')
      : '';

  if (!response.ok) {
    switch (response.status) {
      case 401:
        throw new Error('Your session expired. Sign in again to run the sync.');
      case 403:
        throw new Error('Only the Fundmf admin account can run the CAMS sync.');
      case 404:
        throw new Error(
          serverMessage ||
            'The sync endpoint was not found. Check VITE_API_BASE_URL.',
        );
      case 409:
        throw new Error(serverMessage || 'A sync is already running. Try again in a minute.');
      case 429:
        throw new Error(serverMessage || 'Too many sync requests. Wait a minute and try again.');
      case 503:
        throw new Error(
          serverMessage ||
            'The server is missing its Gmail credentials or is starting up.',
        );
      default:
        throw new Error(
          serverMessage || `The sync failed (HTTP ${response.status}).`,
        );
    }
  }

  if (!parsed || typeof parsed !== 'object') {
    throw new Error('The sync API returned an unexpected response.');
  }

  const map = parsed as Record<string, unknown>;
  const errors = Array.isArray(map.errors)
    ? (map.errors as unknown[]).map((item) => String(item))
    : [];

  return {
    status: str(map.status) || 'unknown',
    messagesScanned: num(map.messagesScanned),
    attachmentsParsed: num(map.attachmentsParsed),
    transactionsCreated: num(map.transactionsCreated),
    duplicatesSkipped: num(map.duplicatesSkipped),
    errors,
    durationMs: num(map.durationMs),
    trigger: str(map.trigger) || 'manual',
    foliosMapped: num(map.foliosMapped),
    unmappedRows: num(map.unmappedRows),
  };
}
