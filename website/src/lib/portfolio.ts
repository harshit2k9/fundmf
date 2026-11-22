import { latestNavBatch, latestNavForName } from './nav';
import type {
  FundTransaction,
  NavQuote,
  PortfolioSummary,
  SchemeHolding,
} from './types';

/**
 * Deterministic portfolio maths, ported line for line from the Flutter
 * PortfolioCalculator so the website and the app report identical numbers.
 *
 * Accounting method: average cost. Units and cost basis accumulate in
 * chronological order; a redemption removes `units × average NAV at that
 * moment` of principal.
 */

const UNIT_EPSILON = 0.0001;

const isInflow = (kind: FundTransaction['kind']): boolean =>
  kind === 'Purchase' || kind === 'SIP' || kind === 'Switch-In';

const isOutflow = (kind: FundTransaction['kind']): boolean =>
  kind === 'Redemption' || kind === 'Switch-Out';

const schemeKeyForCode = (schemeCode: number): string => `code:${schemeCode}`;

const schemeKeyForName = (schemeName: string): string =>
  `name:${schemeName.trim().toUpperCase()}`;

export const schemeKeyOf = (transaction: FundTransaction): string =>
  transaction.schemeCode > 0
    ? schemeKeyForCode(transaction.schemeCode)
    : schemeKeyForName(transaction.schemeName);

interface Bucket {
  key: string;
  schemeCode: number;
  schemeName: string;
  folios: string[];
  units: number;
  costBasis: number;
  firstInflowDate?: Date;
}

function cagr(
  invested: number,
  value: number,
  firstDate: Date | undefined,
  now: Date,
): number {
  if (invested <= 0 || value <= 0 || !firstDate) return 0;
  const days = Math.floor((now.getTime() - firstDate.getTime()) / 86_400_000);
  if (days < 30) return ((value / invested) - 1) * 100;
  const years = days / 365.25;
  if (years <= 0) return 0;
  return (Math.pow(value / invested, 1 / years) - 1) * 100;
}

export const emptySummary = (): PortfolioSummary => ({
  totalInvested: 0,
  currentValue: 0,
  absolutePnl: 0,
  returnPercent: 0,
  cagrPercent: 0,
  totalUnits: 0,
  holdings: [],
  closedSchemes: 0,
  hasLiveNav: false,
  asOf: new Date(),
});

export function calculate(
  transactions: FundTransaction[],
  navByKey: Map<string, NavQuote> = new Map(),
): PortfolioSummary {
  if (transactions.length === 0) return emptySummary();

  const ordered = [...transactions].sort((a, b) => {
    const byDate = a.transactionDate.getTime() - b.transactionDate.getTime();
    return byDate !== 0
      ? byDate
      : a.transactionId.localeCompare(b.transactionId);
  });

  const buckets = new Map<string, Bucket>();
  let firstInflowDate: Date | undefined;

  for (const transaction of ordered) {
    const key = schemeKeyOf(transaction);
    let bucket = buckets.get(key);
    if (!bucket) {
      bucket = {
        key,
        schemeCode: transaction.schemeCode,
        schemeName: transaction.schemeName,
        folios: [],
        units: 0,
        costBasis: 0,
      };
      buckets.set(key, bucket);
    }

    if (!bucket.schemeName && transaction.schemeName) {
      bucket.schemeName = transaction.schemeName;
    }
    if (
      transaction.folioNumber &&
      !bucket.folios.includes(transaction.folioNumber)
    ) {
      bucket.folios.push(transaction.folioNumber);
    }

    if (isInflow(transaction.kind)) {
      if (!firstInflowDate || transaction.transactionDate < firstInflowDate) {
        firstInflowDate = transaction.transactionDate;
      }
      const units = Math.abs(transaction.units);
      let amount = Math.abs(transaction.amount);
      // Some statement variants only carry units + NAV.
      if (amount === 0 && units > 0 && transaction.purchaseNav > 0) {
        amount = units * transaction.purchaseNav;
      }
      bucket.units += units;
      bucket.costBasis += amount;
      if (!bucket.firstInflowDate || transaction.transactionDate < bucket.firstInflowDate) {
        bucket.firstInflowDate = transaction.transactionDate;
      }
    } else if (isOutflow(transaction.kind)) {
      const units = Math.abs(transaction.units);
      if (units > 0 && bucket.units > UNIT_EPSILON) {
        const averageNav = bucket.costBasis / bucket.units;
        const principal = Math.min(units * averageNav, bucket.costBasis);
        bucket.costBasis = Math.max(0, bucket.costBasis - principal);
        bucket.units = Math.max(0, bucket.units - units);
      }
    }
    // `Other` rows (STT, dividends, segregation) never change units or cost.
  }

  const now = new Date();
  const holdings: SchemeHolding[] = [];

  for (const bucket of buckets.values()) {
    if (bucket.units <= UNIT_EPSILON) continue;

    const quote = navByKey.get(bucket.key);
    const averageNav = bucket.units > 0 ? bucket.costBasis / bucket.units : 0;
    const currentNav = quote?.nav ?? averageNav;
    const currentValue = bucket.units * currentNav;
    const pnl = currentValue - bucket.costBasis;

    holdings.push({
      schemeCode: bucket.schemeCode,
      schemeName: bucket.schemeName,
      folios: [...bucket.folios],
      units: bucket.units,
      investedAmount: bucket.costBasis,
      averageNav,
      currentNav,
      currentValue,
      pnl,
      pnlPercent: bucket.costBasis > 0 ? (pnl / bucket.costBasis) * 100 : 0,
      allocationPercent: 0,
      cagrPercent: cagr(bucket.costBasis, currentValue, bucket.firstInflowDate, now),
      navAvailable: quote != null,
      navDate: quote?.date ?? null,
    });
  }

  holdings.sort((a, b) => b.currentValue - a.currentValue);

  const totalValue = holdings.reduce((sum, h) => sum + h.currentValue, 0);
  const totalInvested = holdings.reduce((sum, h) => sum + h.investedAmount, 0);
  const totalUnits = holdings.reduce((sum, h) => sum + h.units, 0);
  const absolutePnl = totalValue - totalInvested;

  return {
    totalInvested,
    currentValue: totalValue,
    absolutePnl,
    returnPercent: totalInvested > 0 ? (absolutePnl / totalInvested) * 100 : 0,
    cagrPercent: cagr(totalInvested, totalValue, firstInflowDate, now),
    totalUnits,
    holdings: holdings.map((holding) => ({
      ...holding,
      allocationPercent:
        totalValue > 0 ? (holding.currentValue / totalValue) * 100 : 0,
    })),
    closedSchemes: buckets.size - holdings.length,
    hasLiveNav: holdings.some((holding) => holding.navAvailable),
    asOf: now,
  };
}

/** Live NAVs for every scheme in the portfolio, then the summary. */
export async function summaryForTransactions(
  transactions: FundTransaction[],
): Promise<PortfolioSummary> {
  if (transactions.length === 0) return emptySummary();

  const codes = new Set<number>();
  for (const transaction of transactions) {
    if (transaction.schemeCode > 0) codes.add(transaction.schemeCode);
  }
  const quotes = await latestNavBatch(codes);

  const navByKey = new Map<string, NavQuote>();
  for (const quote of quotes.values()) {
    navByKey.set(schemeKeyForCode(quote.schemeCode), quote);
  }

  // The CAMS R9/R10 feed carries only the RTA scheme code, so those rows have no
  // AMFI code. Resolve it from the scheme name to keep valuation working.
  const uncodedNames = new Set<string>();
  for (const transaction of transactions) {
    if (transaction.schemeCode <= 0 && transaction.schemeName.trim()) {
      uncodedNames.add(transaction.schemeName);
    }
  }

  const resolved = await Promise.all(
    [...uncodedNames].map(async (name) => [name, await latestNavForName(name)] as const),
  );
  for (const [name, quote] of resolved) {
    if (quote) navByKey.set(schemeKeyForName(name), quote);
  }

  return calculate(transactions, navByKey);
}
