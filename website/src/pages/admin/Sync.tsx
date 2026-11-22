import { useEffect, useState } from 'react';

import { Shell, adminNav } from '../../components/Shell';
import { EmptyState, StatusBadge } from '../../components/ui';
import { useAuth } from '../../lib/auth';
import { triggerManualSync, watchSyncLogs } from '../../lib/data';
import { fmtDateTime, fmtDuration } from '../../lib/format';
import type { SyncLogEntry, SyncResult } from '../../lib/types';

export default function AdminSyncPage() {
  const { user } = useAuth();
  const [logs, setLogs] = useState<SyncLogEntry[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<SyncResult | null>(null);
  const [running, setRunning] = useState(false);

  useEffect(() => {
    const unsubscribe = watchSyncLogs(
      setLogs,
      (caught) => setError(caught.message || 'Could not load the sync log.'),
    );
    return unsubscribe;
  }, []);

  async function runSync() {
    if (!user) return;
    setRunning(true);
    setError(null);
    setResult(null);
    try {
      const token = await user.getIdToken();
      setResult(await triggerManualSync(token));
    } catch (caught) {
      setError((caught as Error).message || 'The sync failed.');
    } finally {
      setRunning(false);
    }
  }

  return (
    <Shell
      items={adminNav}
      title="CAMS sync"
      subtitle="Gmail → CAMS/KFintech statements → Firestore"
    >
      <div className="stack" style={{ gap: 16 }}>
        <section className="card">
          <p className="small muted" style={{ lineHeight: 1.6, marginBottom: 14 }}>
            Scans unread statement emails, extracts the folio master and
            transaction rows, and writes them to Firestore. Runs are rate-limited
            to ten per minute.
          </p>
          <button
            type="button"
            className="btn btn-primary"
            onClick={() => void runSync()}
            disabled={running}
          >
            {running ? <span className="spinner on-dark" /> : '⟳'}
            {running ? 'Scanning inbox…' : 'Run sync now'}
          </button>
        </section>

        {error ? <div className="alert alert-error">{error}</div> : null}

        {result ? (
          <section className="card">
            <div className="row-between" style={{ marginBottom: 12 }}>
              <div className="section-title">Latest run</div>
              <StatusBadge status={result.status} />
            </div>
            <div className="stats">
              <div className="stat">
                <span>Emails</span>
                <strong>{result.messagesScanned}</strong>
              </div>
              <div className="stat">
                <span>Folios mapped</span>
                <strong>{result.foliosMapped}</strong>
              </div>
              <div className="stat">
                <span>New rows</span>
                <strong>{result.transactionsCreated}</strong>
              </div>
              <div className="stat">
                <span>Duplicates</span>
                <strong>{result.duplicatesSkipped}</strong>
              </div>
              <div className="stat">
                <span>Duration</span>
                <strong>{fmtDuration(result.durationMs)}</strong>
              </div>
            </div>
            {result.errors.length > 0 ? (
              <div className="alert alert-error" style={{ marginTop: 14 }}>
                {result.errors.map((entry) => (
                  <div key={entry} style={{ marginBottom: 4 }}>
                    {entry}
                  </div>
                ))}
              </div>
            ) : null}
          </section>
        ) : null}

        <section>
          <div className="row-between" style={{ marginBottom: 10 }}>
            <div className="page-title" style={{ fontSize: 16 }}>
              Sync log
            </div>
            <span className="small muted">Most recent 25 runs, newest first</span>
          </div>

          {logs.length === 0 ? (
            <div className="card">
              <EmptyState title="No runs recorded yet">
                Trigger a sync to create the first audit entry.
              </EmptyState>
            </div>
          ) : (
            <div className="stack" style={{ gap: 10 }}>
              {logs.map((log) => (
                <article className="card" key={log.id} style={{ padding: 15 }}>
                  <div className="row-between" style={{ marginBottom: 8 }}>
                    <div className="row" style={{ gap: 8 }}>
                      <StatusBadge status={log.status} />
                      <span className="small muted">{log.trigger}</span>
                    </div>
                    <span className="tiny muted">{fmtDateTime(log.startedAt ?? null)}</span>
                  </div>
                  <div className="small">
                    {log.messagesScanned} emails · {log.foliosMapped} folios ·{' '}
                    {log.transactionsCreated} new · {log.duplicatesSkipped} duplicates ·{' '}
                    {fmtDuration(log.durationMs)}
                  </div>
                  {log.actor ? (
                    <div className="tiny muted" style={{ marginTop: 4 }}>
                      Triggered by {log.actor}
                    </div>
                  ) : null}
                  {log.errorMessage ? (
                    <div className="tiny" style={{ color: 'var(--coral-deep)', marginTop: 6 }}>
                      {log.errorMessage}
                    </div>
                  ) : null}
                  {log.errors.slice(0, 3).map((entry) => (
                    <div
                      key={entry}
                      className="tiny"
                      style={{ color: 'var(--coral-deep)', marginTop: 6, wordBreak: 'break-word' }}
                    >
                      {entry}
                    </div>
                  ))}
                </article>
              ))}
            </div>
          )}
        </section>
      </div>
    </Shell>
  );
}
