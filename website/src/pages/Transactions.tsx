import { useEffect, useMemo, useState } from 'react';

import { Shell, investorNav } from '../components/Shell';
import { EmptyState, Loading } from '../components/ui';
import { useIsMobile } from '../hooks/useMediaQuery';
import { useAuth } from '../lib/auth';
import { watchTransactionsForPan } from '../lib/data';
import {
  changeClass,
  fmtCurrency,
  fmtDate,
  fmtNav,
  fmtUnits,
} from '../lib/format';
import type { FundTransaction, TransactionKind } from '../lib/types';

const KINDS: Array<TransactionKind | 'All'> = [
  'All',
  'Purchase',
  'SIP',
  'Redemption',
  'Switch-In',
  'Switch-Out',
  'Other',
];

const isInflow = (kind: TransactionKind): boolean =>
  kind === 'Purchase' || kind === 'SIP' || kind === 'Switch-In';

const csvCell = (value: string | number): string => {
  const text = String(value);
  return /[",\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
};

export default function TransactionsPage() {
  const { profile } = useAuth();
  const pan = profile?.pan ?? '';
  const isMobile = useIsMobile();

  const [transactions, setTransactions] = useState<FundTransaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [kind, setKind] = useState<TransactionKind | 'All'>('All');
  const [selected, setSelected] = useState<FundTransaction | null>(null);

  useEffect(() => {
    if (!pan) {
      setTransactions([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    const unsubscribe = watchTransactionsForPan(
      pan,
      (rows) => {
        setTransactions(rows);
        setLoading(false);
      },
      (caught) => {
        setError(caught.message || 'Could not load transactions.');
        setLoading(false);
      },
    );
    return unsubscribe;
  }, [pan]);

  const filtered = useMemo(() => {
    const needle = search.trim().toLowerCase();
    return transactions.filter((transaction) => {
      if (kind !== 'All' && transaction.kind !== kind) return false;
      if (!needle) return true;
      return (
        transaction.schemeName.toLowerCase().includes(needle) ||
        transaction.folioNumber.toLowerCase().includes(needle) ||
        transaction.rawType.toLowerCase().includes(needle)
      );
    });
  }, [transactions, search, kind]);

  const totals = useMemo(() => {
    let invested = 0;
    let redeemed = 0;
    for (const transaction of filtered) {
      if (isInflow(transaction.kind)) invested += Math.abs(transaction.amount);
      else if (transaction.kind === 'Redemption' || transaction.kind === 'Switch-Out') {
        redeemed += Math.abs(transaction.amount);
      }
    }
    return { invested, redeemed };
  }, [filtered]);

  function exportCsv() {
    const header = [
      'Date',
      'Scheme',
      'Folio',
      'Type',
      'Amount',
      'Units',
      'NAV',
      'PAN',
      'Transaction ID',
    ];
    const rows = filtered.map((transaction) => [
      fmtDate(transaction.transactionDate),
      transaction.schemeName,
      transaction.folioNumber,
      transaction.rawType || transaction.kind,
      transaction.amount.toFixed(2),
      transaction.units.toFixed(3),
      transaction.purchaseNav.toFixed(4),
      transaction.pan,
      transaction.transactionId,
    ]);
    const csv = [header, ...rows].map((row) => row.map(csvCell).join(',')).join('\n');
    const blob = new Blob([`\uFEFF${csv}`], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `fundmf-transactions-${new Date().toISOString().slice(0, 10)}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  }

  return (
    <Shell
      items={investorNav}
      title="Transactions"
      subtitle={`${filtered.length} of ${transactions.length} CAMS rows`}
      actions={
        <button
          type="button"
          className="btn btn-ghost btn-sm"
          onClick={exportCsv}
          disabled={filtered.length === 0}
        >
          ⤓ Export CSV
        </button>
      }
    >
      <div className="stack" style={{ gap: 16 }}>
        <div className="stats">
          <div className="stat">
            <span>Money in</span>
            <strong className="gain">{fmtCurrency(totals.invested)}</strong>
          </div>
          <div className="stat">
            <span>Money out</span>
            <strong className="loss">{fmtCurrency(totals.redeemed)}</strong>
          </div>
          <div className="stat">
            <span>Rows</span>
            <strong>{filtered.length}</strong>
          </div>
        </div>

        <div className="card" style={{ padding: 12 }}>
          <div className="row wrap" style={{ gap: 10 }}>
            <input
              className="input grow"
              style={{ minWidth: 180 }}
              placeholder="Search scheme or folio…"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
            />
            <select
              className="select"
              style={{ maxWidth: 190 }}
              value={kind}
              onChange={(event) => setKind(event.target.value as TransactionKind | 'All')}
            >
              {KINDS.map((option) => (
                <option key={option} value={option}>
                  {option === 'All' ? 'All transaction types' : option}
                </option>
              ))}
            </select>
          </div>
        </div>

        {loading ? <Loading label="Loading statements…" /> : null}
        {error ? <div className="alert alert-error">{error}</div> : null}

        {!loading && filtered.length === 0 ? (
          <div className="card">
            <EmptyState title="Nothing here yet">
              No transactions match this filter. Statements appear after the
              admin runs a CAMS or KFintech sync.
            </EmptyState>
          </div>
        ) : null}

        {!loading && filtered.length > 0 && isMobile ? (
          <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
            {filtered.map((transaction) => (
              <button
                key={transaction.id}
                type="button"
                className="tx-row"
                onClick={() => setSelected(transaction)}
              >
                <span className={`tx-icon ${isInflow(transaction.kind) ? 'in' : 'out'}`}>
                  {isInflow(transaction.kind) ? '↓' : '↑'}
                </span>
                <span className="grow" style={{ minWidth: 0 }}>
                  <span
                    style={{
                      display: 'block',
                      fontSize: 13,
                      fontWeight: 650,
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                      whiteSpace: 'nowrap',
                    }}
                  >
                    {transaction.schemeName}
                  </span>
                  <span className="tiny muted">
                    {fmtDate(transaction.transactionDate)} · {transaction.kind} ·{' '}
                    {fmtUnits(transaction.units)} u
                  </span>
                </span>
                <span
                  className={`small ${isInflow(transaction.kind) ? 'gain' : 'loss'}`}
                  style={{ fontWeight: 700, whiteSpace: 'nowrap' }}
                >
                  {isInflow(transaction.kind) ? '+' : '−'}
                  {fmtCurrency(transaction.amount)}
                </span>
              </button>
            ))}
          </div>
        ) : null}

        {!loading && filtered.length > 0 && !isMobile ? (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Scheme</th>
                  <th>Folio</th>
                  <th>Type</th>
                  <th className="num">Amount</th>
                  <th className="num">Units</th>
                  <th className="num">NAV</th>
                  <th className="num" />
                </tr>
              </thead>
              <tbody>
                {filtered.map((transaction) => (
                  <tr key={transaction.id}>
                    <td style={{ whiteSpace: 'nowrap' }}>
                      {fmtDate(transaction.transactionDate)}
                    </td>
                    <td style={{ maxWidth: 320 }}>{transaction.schemeName}</td>
                    <td className="muted small">{transaction.folioNumber || '—'}</td>
                    <td>
                      <span className={`badge ${isInflow(transaction.kind) ? 'success' : 'neutral'}`}>
                        {transaction.kind}
                      </span>
                    </td>
                    <td className={`num ${isInflow(transaction.kind) ? 'gain' : 'loss'}`}>
                      {isInflow(transaction.kind) ? '+' : '−'}
                      {fmtCurrency(transaction.amount)}
                    </td>
                    <td className="num">{fmtUnits(transaction.units)}</td>
                    <td className="num">{fmtNav(transaction.purchaseNav)}</td>
                    <td className="num">
                      <button
                        type="button"
                        className="btn btn-ghost btn-sm"
                        onClick={() => setSelected(transaction)}
                      >
                        View
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : null}
      </div>

      {selected ? (
        <div
          className="modal-backdrop"
          role="presentation"
          onClick={() => setSelected(null)}
        >
          <div
            className="modal"
            role="dialog"
            aria-modal="true"
            aria-label="Transaction details"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="row-between" style={{ marginBottom: 14 }}>
              <h3 style={{ fontSize: 16 }}>Transaction detail</h3>
              <button
                type="button"
                className="btn btn-ghost btn-sm"
                onClick={() => setSelected(null)}
              >
                Close
              </button>
            </div>

            <div style={{ marginBottom: 12 }}>
              <div style={{ fontWeight: 700, lineHeight: 1.35 }}>
                {selected.schemeName}
              </div>
              <div className="tiny muted">
                {selected.schemeCode > 0 ? `AMFI ${selected.schemeCode}` : 'No AMFI code'}
              </div>
            </div>

            <div className="modal-row">
              <span>Type</span>
              <strong>{selected.rawType || selected.kind}</strong>
            </div>
            <div className="modal-row">
              <span>Date</span>
              <strong>{fmtDate(selected.transactionDate)}</strong>
            </div>
            <div className="modal-row">
              <span>Amount</span>
              <strong className={changeClass(isInflow(selected.kind) ? 1 : -1)}>
                {isInflow(selected.kind) ? '+' : '−'}
                {fmtCurrency(selected.amount)}
              </strong>
            </div>
            <div className="modal-row">
              <span>Units</span>
              <strong>{fmtUnits(selected.units)}</strong>
            </div>
            <div className="modal-row">
              <span>NAV</span>
              <strong>{fmtNav(selected.purchaseNav)}</strong>
            </div>
            <div className="modal-row">
              <span>Folio</span>
              <strong>{selected.folioNumber || '—'}</strong>
            </div>
            <div className="modal-row">
              <span>PAN</span>
              <strong>{selected.pan}</strong>
            </div>
            <div className="modal-row">
              <span>Transaction ID</span>
              <strong className="small">{selected.transactionId}</strong>
            </div>
            <div className="modal-row">
              <span>Net units change</span>
              <strong className={changeClass(isInflow(selected.kind) ? 1 : -1)}>
                {isInflow(selected.kind) ? '+' : '−'}
                {fmtUnits(selected.units)}
              </strong>
            </div>
          </div>
        </div>
      ) : null}
    </Shell>
  );
}
