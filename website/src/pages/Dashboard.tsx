import { useCallback, useEffect, useState } from 'react';

import { AllocationDonut } from '../components/Donut';
import { Shell, investorNav } from '../components/Shell';
import { EmptyState, Loading } from '../components/ui';
import { useAuth } from '../lib/auth';
import { watchTransactionsForPan } from '../lib/data';
import {
  changeClass,
  fmtCurrency,
  fmtDate,
  fmtNav,
  fmtPercent,
  fmtSignedCurrency,
  fmtSignedPercent,
  fmtUnits,
  greeting,
  firstName as firstNameOf,
} from '../lib/format';
import { summaryForTransactions } from '../lib/portfolio';
import type { PortfolioSummary } from '../lib/types';

export default function DashboardPage() {
  const { profile } = useAuth();
  const pan = profile?.pan ?? '';
  const [summary, setSummary] = useState<PortfolioSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);

  useEffect(() => {
    if (!pan) {
      setSummary(null);
      setLoading(false);
      return;
    }

    let cancelled = false;
    let recompute = 0;
    setLoading(true);
    setError(null);

    const unsubscribe = watchTransactionsForPan(
      pan,
      (transactions) => {
        const run = ++recompute;
        void summaryForTransactions(transactions)
          .then((next) => {
            if (cancelled || run !== recompute) return;
            setSummary(next);
            setLoading(false);
          })
          .catch((caught: Error) => {
            if (cancelled) return;
            setError(caught.message);
            setLoading(false);
          });
      },
      (caught) => {
        if (cancelled) return;
        setError(
          caught.message ||
            'Could not load transactions. Check your connection and try again.',
        );
        setLoading(false);
      },
    );

    return () => {
      cancelled = true;
      unsubscribe();
    };
  }, [pan, reloadKey]);

  const refresh = useCallback(() => setReloadKey((value) => value + 1), []);

  const firstName = firstNameOf(profile?.fullName ?? '');
  const today = new Date();

  return (
    <Shell
      items={investorNav}
      title={greeting(today)}
      subtitle={profile?.fullName ? `${firstName} · ${fmtDate(today)}` : fmtDate(today)}
      actions={
        <button type="button" className="btn btn-ghost btn-sm" onClick={refresh}>
          ⟳ Refresh
        </button>
      }
    >
      <div className="stack" style={{ gap: 18 }}>
        {loading ? <Loading label="Valuing your portfolio…" /> : null}

        {error ? (
          <div className="alert alert-error">
            {error}{' '}
            <button type="button" className="btn btn-ghost btn-sm" onClick={refresh}>
              Retry
            </button>
          </div>
        ) : null}

        {!loading && !error && summary ? (
          <>
            <SummaryCard summary={summary} />

            <div className="stats">
              <div className="stat">
                <span>Total invested</span>
                <strong>{fmtCurrency(summary.totalInvested)}</strong>
              </div>
              <div className="stat">
                <span>Current value</span>
                <strong>{fmtCurrency(summary.currentValue)}</strong>
              </div>
              <div className="stat">
                <span>Total units</span>
                <strong>{fmtUnits(summary.totalUnits)}</strong>
              </div>
              <div className="stat">
                <span>Schemes</span>
                <strong>{summary.holdings.length}</strong>
              </div>
            </div>

            {summary.holdings.length === 0 ? (
              <div className="card">
                <EmptyState title="No holdings yet">
                  Your portfolio appears once a CAMS or KFintech statement has
                  been synced for PAN {profile?.pan || '—'}. Ask the admin to run
                  a sync if you expect data here.
                </EmptyState>
              </div>
            ) : (
              <div className="split">
                <div className="card">
                  <div className="section-title" style={{ marginBottom: 14 }}>
                    Allocation
                  </div>
                  <AllocationDonut holdings={summary.holdings} />
                  <div className="tiny muted" style={{ marginTop: 12 }}>
                    {summary.hasLiveNav
                      ? 'Valuation uses live AMFI NAVs from api.mfapi.in.'
                      : 'Live NAVs unavailable — showing average cost.'}
                    {summary.closedSchemes > 0
                      ? ` ${summary.closedSchemes} fully redeemed scheme(s) hidden.`
                      : ''}
                  </div>
                </div>

                <div className="stack" style={{ gap: 12 }}>
                  {summary.holdings.map((holding) => (
                    <article
                      className="holding"
                      key={`${holding.schemeCode}-${holding.schemeName}`}
                    >
                      <div className="holding-head">
                        <div>
                          <div className="holding-name">{holding.schemeName}</div>
                          <div className="holding-meta">
                            {holding.schemeCode > 0
                              ? `AMFI ${holding.schemeCode} · `
                              : ''}
                            Folio {holding.folios.join(', ') || '—'}
                          </div>
                        </div>
                        <div style={{ textAlign: 'right' }}>
                          <div style={{ fontWeight: 750 }}>
                            {fmtCurrency(holding.currentValue)}
                          </div>
                          <div
                            className={`small ${changeClass(holding.pnl)}`}
                            style={{ fontWeight: 650 }}
                          >
                            {fmtSignedCurrency(holding.pnl)} (
                            {fmtSignedPercent(holding.pnlPercent)})
                          </div>
                        </div>
                      </div>
                      <div className="holding-grid">
                        <div>
                          <span>Units</span>
                          <strong>{fmtUnits(holding.units)}</strong>
                        </div>
                        <div>
                          <span>Avg NAV</span>
                          <strong>{fmtNav(holding.averageNav)}</strong>
                        </div>
                        <div>
                          <span>Current NAV</span>
                          <strong>{fmtNav(holding.currentNav)}</strong>
                        </div>
                        <div>
                          <span>Invested</span>
                          <strong>{fmtCurrency(holding.investedAmount)}</strong>
                        </div>
                        <div>
                          <span>Allocation</span>
                          <strong>{holding.allocationPercent.toFixed(1)}%</strong>
                        </div>
                        <div>
                          <span>CAGR</span>
                          <strong>{fmtPercent(holding.cagrPercent)}</strong>
                        </div>
                      </div>
                      {!holding.navAvailable ? (
                        <div className="tiny muted">
                          No live NAV found — valued at average cost.
                        </div>
                      ) : null}
                    </article>
                  ))}
                </div>
              </div>
            )}
          </>
        ) : null}
      </div>
    </Shell>
  );
}

function SummaryCard({ summary }: { summary: PortfolioSummary }) {
  const positive = summary.absolutePnl >= 0;
  return (
    <section className="summary">
      <div className="row-between">
        <div>
          <div
            className="tiny"
            style={{ letterSpacing: '0.07em', textTransform: 'uppercase', opacity: 0.7 }}
          >
            Portfolio value
          </div>
          <div className="summary-value">{fmtCurrency(summary.currentValue)}</div>
          <div className="small" style={{ opacity: 0.75 }}>
            Invested {fmtCurrency(summary.totalInvested)} · as of {fmtDate(summary.asOf)}
          </div>
        </div>
        <span className={`pill${positive ? '' : ' neg'}`}>
          {fmtSignedPercent(summary.returnPercent)}
        </span>
      </div>

      <div className="summary-grid">
        <div className="summary-cell">
          <span>Absolute P&amp;L</span>
          <strong>{fmtSignedCurrency(summary.absolutePnl)}</strong>
        </div>
        <div className="summary-cell">
          <span>Absolute return</span>
          <strong>{fmtSignedPercent(summary.returnPercent)}</strong>
        </div>
        <div className="summary-cell">
          <span>CAGR</span>
          <strong>{fmtPercent(summary.cagrPercent)}</strong>
        </div>
        <div className="summary-cell">
          <span>Units</span>
          <strong>{fmtUnits(summary.totalUnits)}</strong>
        </div>
      </div>
    </section>
  );
}

