import { API_BASE_PUBLIC_URL } from './firebase';
import type { NavQuote } from './types';

/** Latest NAV lookup against api.mfapi.in, ported from NavRepository. */

const CACHE_TTL_MS = 30 * 60 * 1000;

const STOP_WORDS = new Set([
  'fund',
  'plan',
  'scheme',
  'option',
  'mutual',
  'regular',
  'direct',
  'growth',
  'idcw',
  'dividend',
  'payout',
  'reinvestment',
  'the',
  'and',
  'of',
  'to',
  'formerly',
  'known',
  'as',
]);

interface Cached {
  quote: NavQuote | null;
  fetchedAt: number;
}

const codeCache = new Map<number, Cached>();
const nameCache = new Map<string, Cached>();
const nameMisses = new Map<string, number>();
const inFlight = new Map<number, Promise<NavQuote | null>>();
const codeLookups = new Map<string, Promise<number | null>>();

const tokens = (name: string): string[] => {
  let cleaned = name.toLowerCase();
  const formerly = cleaned.indexOf('(formerly');
  if (formerly > 0) cleaned = cleaned.slice(0, formerly);

  const seen = new Set<string>();
  const out: string[] = [];
  for (const word of cleaned.split(/[^a-z0-9]+/)) {
    if (word.length < 2 || STOP_WORDS.has(word)) continue;
    if (seen.has(word)) continue;
    seen.add(word);
    out.push(word);
  }
  return out;
};

const parseMfApiDate = (value: string): Date | null => {
  // dd-MM-yyyy
  const match = /^(\d{2})-(\d{2})-(\d{4})$/.exec((value ?? '').trim());
  if (!match) return null;
  const date = new Date(Number(match[3]), Number(match[2]) - 1, Number(match[1]));
  return Number.isNaN(date.getTime()) ? null : date;
};

async function fetchCode(schemeCode: number): Promise<NavQuote | null> {
  try {
    const response = await fetch(
      `${API_BASE_PUBLIC_URL}/${schemeCode}`,
    );
    if (!response.ok) return null;

    const body = (await response.json()) as {
      meta?: { scheme_name?: string; fund_house?: string };
      data?: Array<{ nav?: string; date?: string }>;
    };
    const latest = body.data?.[0];
    if (!latest) return null;

    const nav = Number(String(latest.nav ?? '').replace(/,/g, '').trim());
    const date = parseMfApiDate(String(latest.date ?? ''));
    if (!Number.isFinite(nav) || nav <= 0 || !date) return null;

    return {
      schemeCode,
      schemeName: String(body.meta?.scheme_name ?? ''),
      fundHouse: String(body.meta?.fund_house ?? ''),
      nav,
      date,
    };
  } catch {
    // Offline or malformed payload: keep the portfolio usable without a NAV.
    return null;
  }
}

export async function latestNav(schemeCode: number): Promise<NavQuote | null> {
  if (!schemeCode || schemeCode <= 0) return null;

  const cached = codeCache.get(schemeCode);
  if (cached && Date.now() - cached.fetchedAt < CACHE_TTL_MS) {
    return cached.quote;
  }

  const pending = inFlight.get(schemeCode);
  if (pending) return pending;

  const future = fetchCode(schemeCode).then((quote) => {
    codeCache.set(schemeCode, { quote, fetchedAt: Date.now() });
    return quote;
  });
  inFlight.set(schemeCode, future);
  try {
    return await future;
  } finally {
    inFlight.delete(schemeCode);
  }
}

/** Fetches many schemes in small parallel chunks. */
export async function latestNavBatch(
  schemeCodes: Iterable<number>,
  chunkSize = 6,
): Promise<Map<number, NavQuote>> {
  const unique = [...new Set([...schemeCodes].filter((code) => code > 0))].sort(
    (a, b) => a - b,
  );
  const result = new Map<number, NavQuote>();

  for (let start = 0; start < unique.length; start += chunkSize) {
    const chunk = unique.slice(start, start + chunkSize);
    const quotes = await Promise.all(chunk.map((code) => latestNav(code)));
    quotes.forEach((quote, index) => {
      if (quote) result.set(chunk[index], quote);
    });
  }

  return result;
}

function bestMatch(schemeName: string, body: unknown): number | null {
  if (!Array.isArray(body)) return null;

  const target = new Set(tokens(schemeName));
  if (target.size === 0) return null;

  const lower = schemeName.toLowerCase();
  const wantRegular = lower.includes('regular') || !lower.includes('direct');
  const wantGrowth = lower.includes('growth') || !lower.includes('idcw');

  let bestCode: number | null = null;
  let bestScore = 0;
  let bestOverlap = 0;

  for (const item of body) {
    if (typeof item !== 'object' || item === null) continue;
    const candidate = item as { schemeCode?: unknown; schemeName?: unknown };
    if (typeof candidate.schemeCode !== 'number') continue;
    if (typeof candidate.schemeName !== 'string') continue;

    const candidateTokens = new Set(tokens(candidate.schemeName));
    let overlap = 0;
    for (const token of target) if (candidateTokens.has(token)) overlap += 1;
    if (overlap === 0) continue;

    const name = candidate.schemeName.toLowerCase();
    let score = overlap * 10;
    if (wantRegular && name.includes('regular')) score += 6;
    if (!wantRegular && name.includes('direct')) score += 6;
    if (wantRegular && name.includes('direct')) score -= 8;
    if (wantGrowth && name.includes('growth')) score += 6;
    score -= Math.min(Math.max(candidateTokens.size - overlap, 0), 5) * 2;
    if (!wantGrowth && (name.includes('idcw') || name.includes('dividend'))) {
      score += 4;
    }

    if (score > bestScore || (score === bestScore && overlap > bestOverlap)) {
      bestScore = score;
      bestOverlap = overlap;
      bestCode = candidate.schemeCode;
    }
  }

  return bestOverlap >= 2 ? bestCode : null;
}

async function searchSchemeCode(schemeName: string): Promise<number | null> {
  const words = tokens(schemeName);
  if (words.length === 0) return null;

  const queries = [...new Set([words.slice(0, 8).join(' '), words.slice(0, 5).join(' ')])]
    .filter(Boolean);

  for (const query of queries) {
    const url = new URL(`${API_BASE_PUBLIC_URL}/search`);
    url.searchParams.set('q', query);
    try {
      const response = await fetch(url.toString());
      if (!response.ok) continue;
      const code = bestMatch(schemeName, await response.json());
      if (code != null) return code;
    } catch {
      return null;
    }
  }
  return null;
}

/** Latest NAV for a scheme the statement only identified by name. */
export async function latestNavForName(
  schemeName: string,
): Promise<NavQuote | null> {
  const key = schemeName.trim().toLowerCase();
  if (!key) return null;

  const cached = nameCache.get(key);
  if (cached && Date.now() - cached.fetchedAt < CACHE_TTL_MS) return cached.quote;

  const missedAt = nameMisses.get(key);
  if (missedAt && Date.now() - missedAt < CACHE_TTL_MS) return null;

  let pending = codeLookups.get(key);
  if (!pending) {
    pending = searchSchemeCode(schemeName);
    codeLookups.set(key, pending);
  }

  const code = await pending;
  if (code == null) {
    codeLookups.delete(key);
    nameMisses.set(key, Date.now());
    return null;
  }

  const quote = await latestNav(code);
  if (quote) nameCache.set(key, { quote, fetchedAt: Date.now() });
  return quote;
}
