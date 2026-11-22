import { useState } from 'react';

import { Shell, adminNav } from '../../components/Shell';
import { StatusBadge } from '../../components/ui';
import { useAuth } from '../../lib/auth';
import { triggerManualSync } from '../../lib/data';
import { fmtDuration } from '../../lib/format';
import type { SyncResult } from '../../lib/types';

export default function AdminSyncPage() {
  const { user } = useAuth();
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<SyncResult | null>(null);
  const [running, setRunning] = useState(false);

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

      </div>
    </Shell>
  );
}
