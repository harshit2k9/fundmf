import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';

import { AllocationDonut } from '../../components/Donut';
import { Shell, adminNav } from '../../components/Shell';
import { AccountBadge, EmptyState, Loading } from '../../components/ui';
import { fetchProfile, fetchTransactionsForPan } from '../../lib/data';
import {
  changeClass,
  fmtCurrency,
  fmtDate,
  fmtPercent,
  fmtSignedCurrency,
  fmtSignedPercent,
  fmtUnits,
  maskPan,
} from '../../lib/format';
import { summaryForTransactions } from '../../lib/portfolio';
import type { PortfolioSummary, UserProfile } from '../../lib/types';

/** Admin view of one client: profile plus a live-valued portfolio by PAN. */
export default function AdminClientDetailPage() {
  const { email = '' } = useParams();
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [summary, setSummary] = useState<PortfolioSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);

    void (async () => {
      try {
        const next = await fetchProfile(decodeURIComponent(email));
        if (cancelled) return;
        setProfile(next);

        if (!next || !next.pan) {
          setSummary(null);
          setLoading(false);
          return;
        }

        const transactions = await fetchTransactionsForPan(next.pan);
        const computed = await summaryForTransactions(transactions);
        if (cancelled) return;
        setSummary(computed);
      } catch (caught) {
        if (cancelled) return;
        setError((caught as Error).message || 'Could not load this client.');
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [email]);

  return (
    <Shell
      items={adminNav}
      title={profile?.fullName || 'Client'}
      subtitle={profile?.email ?? decodeURIComponent(email)}
      actions={
        <Link className="btn btn-ghost btn-sm" to="/admin/clients">
          ← All clients
        </Link>
      }
    >
      <div className="stack" style={{ gap: 16 }}>
        {loading ? <Loading label="Valuing portfolio…" /> : null}
        {error ? <div className="alert alert-error">{error}</div> : null}

        {!loading && !profile ? (
          <div className="card">
            <EmptyState title="Client not found">
              This profile may have been deleted.
            </EmptyState>
          </div>
        ) : null}

        {profile ? (
          <>
            <section className="card">
              <div className="row-between">
                <div>
                  <div style={{ fontWeight: 750, fontSize: 16 }}>
                    {profile.fullName || '—'}
                  </div>
                  <div className="small muted">{profile.email}</div>
                </div>
                <AccountBadge approved={profile.isApproved} linked={!!profile.uid} />
              </div>
              <div style={{ marginTop: 14 }}>
                <div className="modal-row">
                  <span>Client ID</span>
                  <strong>{profile.clientId || '—'}</strong>
                </div>
                <div className="modal-row">
                  <span>PAN</span>
                  <strong>{maskPan(profile.pan)}</strong>
                </div>
                <div className="modal-row">
                  <span>Phone</span>
                  <strong>{profile.phone || '—'}</strong>
                </div>
                <div className="modal-row">
                  <span>Provisioned</span>
                  <strong>{fmtDate(profile.createdAt ?? null)}</strong>
                </div>
                <div className="modal-row">
                  <span>Claimed</span>
                  <strong>{profile.uid ? fmtDate(profile.linkedAt ?? null) : 'Not yet'}</strong>
                </div>
              </div>
            </section>

            {summary ? (
              <>
                <div className="stats">
                  <div className="stat">
                    <span>Invested</span>
                    <strong>{fmtCurrency(summary.totalInvested)}</strong>
                  </div>
                  <div className="stat">
                    <span>Current value</span>
                    <strong>{fmtCurrency(summary.currentValue)}</strong>
                  </div>
                  <div className="stat">
                    <span>Absolute P&amp;L</span>
                    <strong className={changeClass(summary.absolutePnl)}>
                      {fmtSignedCurrency(summary.absolutePnl)}
                    </strong>
                  </div>
                  <div className="stat">
                    <span>Return / CAGR</span>
                    <strong>
                      {fmtSignedPercent(summary.returnPercent)} ·{' '}
                      {fmtPercent(summary.cagrPercent)}
                    </strong>
                  </div>
                </div>

                {summary.holdings.length === 0 ? (
                  <div className="card">
                    <EmptyState title="No holdings">
                      No transactions are mapped to this PAN yet.
                    </EmptyState>
                  </div>
                ) : (
                  <div className="split">
                    <div className="card">
                      <div className="section-title" style={{ marginBottom: 14 }}>
                        Allocation
                      </div>
                      <AllocationDonut holdings={summary.holdings} />
                    </div>
                    <div className="stack" style={{ gap: 10 }}>
                      {summary.holdings.map((holding) => (
                        <div
                          className="card"
                          key={`${holding.schemeCode}-${holding.schemeName}`}
                          style={{ padding: 14 }}
                        >
                          <div className="row-between" style={{ alignItems: 'flex-start' }}>
                            <div style={{ minWidth: 0 }}>
                              <div style={{ fontWeight: 700, fontSize: 13.5 }}>
                                {holding.schemeName}
                              </div>
                              <div className="tiny muted">
                                {fmtUnits(holding.units)} u · avg {holding.averageNav.toFixed(4)} · nav{' '}
                                {holding.currentNav.toFixed(4)}
                              </div>
                            </div>
                            <div style={{ textAlign: 'right', whiteSpace: 'nowrap' }}>
                              <div style={{ fontWeight: 700 }}>
                                {fmtCurrency(holding.currentValue)}
                              </div>
                              <div className={`tiny ${changeClass(holding.pnl)}`}>
                                {fmtSignedCurrency(holding.pnl)}
                              </div>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </>
            ) : null}
          </>
        ) : null}
      </div>
    </Shell>
  );
}
