import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';

import { Shell, adminNav } from '../../components/Shell';
import { AccountBadge, EmptyState, Field, Loading } from '../../components/ui';
import { useIsMobile } from '../../hooks/useMediaQuery';
import {
  createProfile,
  deleteProfile,
  fetchTransactionsForPan,
  updateProfile,
  watchAllProfiles,
} from '../../lib/data';
import { changeClass, fmtCurrency, fmtDate, fmtSignedCurrency, initials, maskPan } from '../../lib/format';
import { normalizeEmail } from '../../lib/validators';
import {
  validateEmail,
  validatePan,
  validatePhone,
  validateRequired,
} from '../../lib/validators';
import type { UserProfile } from '../../lib/types';
import { summaryForTransactions } from '../../lib/portfolio';

interface Draft {
  email: string;
  fullName: string;
  pan: string;
  phone: string;
  clientId: string;
  isApproved: boolean;
}

const emptyDraft: Draft = {
  email: '',
  fullName: '',
  pan: '',
  phone: '',
  clientId: '',
  isApproved: true,
};

export default function AdminClientsPage() {
  const isMobile = useIsMobile();
  const [profiles, setProfiles] = useState<UserProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [aum, setAum] = useState({
    invested: 0,
    current: 0,
    pnl: 0,
  });
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [editing, setEditing] = useState<UserProfile | null>(null);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [formErrors, setFormErrors] = useState<Record<string, string | null>>({});
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const unsubscribe = watchAllProfiles(
      (next) => {
        setProfiles(next);
        setLoading(false);
      },
      (caught) => {
        setError(caught.message || 'Could not load clients.');
        setLoading(false);
      },
    );
    return unsubscribe;
  }, []);

  useEffect(() => {
    if (profiles.length === 0) {
      setAum({ invested: 0, current: 0, pnl: 0 });
      return;
    }
    let cancelled = false;
    void (async () => {
      let invested = 0;
      let current = 0;
      let pnl = 0;
      for (const profile of profiles) {
        try {
          const transactions = await fetchTransactionsForPan(profile.pan);
          const summary = await summaryForTransactions(transactions);
          invested += summary.totalInvested;
          current += summary.currentValue;
          pnl += summary.absolutePnl;
        } catch {
          // Skip clients whose portfolio cannot be valued.
        }
      }
      if (!cancelled) setAum({ invested, current, pnl });
    })();
    return () => {
      cancelled = true;
    };
  }, [profiles]);

  const filtered = useMemo(() => {
    const needle = search.trim().toLowerCase();
    if (!needle) return profiles;
    return profiles.filter(
      (profile) =>
        profile.fullName.toLowerCase().includes(needle) ||
        profile.email.toLowerCase().includes(needle) ||
        profile.pan.toLowerCase().includes(needle) ||
        profile.clientId.toLowerCase().includes(needle),
    );
  }, [profiles, search]);

  function openCreate() {
    setEditing(null);
    setDraft({ ...emptyDraft });
    setFormErrors({});
  }

  function openEdit(profile: UserProfile) {
    setEditing(profile);
    setDraft({
      email: profile.email,
      fullName: profile.fullName,
      pan: profile.pan,
      phone: profile.phone,
      clientId: profile.clientId,
      isApproved: profile.isApproved,
    });
    setFormErrors({});
  }

  async function save(event: React.FormEvent) {
    event.preventDefault();
    if (!draft) return;

    const nextErrors = {
      email: editing ? null : validateEmail(draft.email),
      fullName: validateRequired(draft.fullName, 'Full name'),
      pan: validatePan(draft.pan),
      phone: validatePhone(draft.phone),
    };
    setFormErrors(nextErrors);
    if (Object.values(nextErrors).some(Boolean)) return;

    setSaving(true);
    setError(null);
    try {
      if (editing) {
        await updateProfile({ ...editing, ...draft });
      } else {
        await createProfile({
          email: normalizeEmail(draft.email),
          fullName: draft.fullName,
          pan: draft.pan,
          phone: draft.phone,
          clientId: draft.clientId,
          isApproved: draft.isApproved,
          uid: '',
        });
      }
      setDraft(null);
      setEditing(null);
    } catch (caught) {
      setError((caught as Error).message || 'Could not save the client.');
    } finally {
      setSaving(false);
    }
  }

  async function toggleApproval(profile: UserProfile) {
    setError(null);
    try {
      await updateProfile({ ...profile, isApproved: !profile.isApproved });
    } catch (caught) {
      setError((caught as Error).message || 'Could not update approval.');
    }
  }

  async function remove(profile: UserProfile) {
    const confirmed = window.confirm(
      `Delete ${profile.fullName || profile.email}? Their transactions stay in Firestore, but the login loses access.`,
    );
    if (!confirmed) return;
    setError(null);
    try {
      await deleteProfile(profile.email);
    } catch (caught) {
      setError((caught as Error).message || 'Could not delete the client.');
    }
  }

  return (
    <Shell
      items={adminNav}
      title="Clients"
      subtitle={`${profiles.length} provisioned · admin directory`}
      actions={
        <button type="button" className="btn btn-primary btn-sm" onClick={openCreate}>
          + New client
        </button>
      }
    >
      <div className="stack" style={{ gap: 16 }}>
        <div className="stats">
          <div className="stat">
            <span>Clients</span>
            <strong>{profiles.length}</strong>
          </div>
          <div className="stat">
            <span>Total invested</span>
            <strong>{fmtCurrency(aum.invested)}</strong>
          </div>
          <div className="stat">
            <span>Total AUM</span>
            <strong>{fmtCurrency(aum.current)}</strong>
          </div>
          <div className="stat">
            <span>Total P&amp;L</span>
            <strong className={changeClass(aum.pnl)}>
              {fmtSignedCurrency(aum.pnl)}
            </strong>
          </div>
        </div>

        <div className="card" style={{ padding: 12 }}>
          <input
            className="input"
            placeholder="Search by name, email, PAN or client ID…"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
          />
        </div>

        {loading ? <Loading label="Loading clients…" /> : null}
        {error ? <div className="alert alert-error">{error}</div> : null}

        {!loading && filtered.length === 0 ? (
          <div className="card">
            <EmptyState title="No clients found">
              Provision a client with their email, PAN and phone so statements
              can be mapped to their portfolio.
            </EmptyState>
          </div>
        ) : null}

        {!loading && filtered.length > 0 && isMobile ? (
          <div className="stack" style={{ gap: 10 }}>
            {filtered.map((profile) => (
              <div className="card" key={profile.email} style={{ padding: 14 }}>
                <div className="row" style={{ gap: 11, alignItems: 'flex-start' }}>
                  <div
                    style={{
                      width: 38,
                      height: 38,
                      borderRadius: 12,
                      background: 'var(--navy)',
                      color: '#fff',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontWeight: 700,
                      fontSize: 13,
                      flex: '0 0 38px',
                    }}
                  >
                    {initials(profile.fullName)}
                  </div>
                  <div className="grow" style={{ minWidth: 0 }}>
                    <div style={{ fontWeight: 700, fontSize: 14 }}>
                      {profile.fullName || '—'}
                    </div>
                    <div className="tiny muted" style={{ wordBreak: 'break-word' }}>
                      {profile.email}
                    </div>
                    <div className="tiny muted">
                      {profile.clientId || '—'} · {maskPan(profile.pan)}
                    </div>
                  </div>
                  <AccountBadge approved={profile.isApproved} linked={!!profile.uid} />
                </div>
                <div className="row wrap" style={{ marginTop: 12, gap: 8 }}>
                  <Link className="btn btn-ghost btn-sm" to={`/admin/clients/${encodeURIComponent(profile.email)}`}>
                    Portfolio
                  </Link>
                  <button type="button" className="btn btn-ghost btn-sm" onClick={() => openEdit(profile)}>
                    Edit
                  </button>
                  <button type="button" className="btn btn-ghost btn-sm" onClick={() => void toggleApproval(profile)}>
                    {profile.isApproved ? 'Revoke' : 'Approve'}
                  </button>
                  <button type="button" className="btn btn-danger btn-sm" onClick={() => void remove(profile)}>
                    Delete
                  </button>
                </div>
              </div>
            ))}
          </div>
        ) : null}

        {!loading && filtered.length > 0 && !isMobile ? (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Client</th>
                  <th>Client ID</th>
                  <th>PAN</th>
                  <th>Phone</th>
                  <th>Status</th>
                  <th>Created</th>
                  <th className="num" />
                </tr>
              </thead>
              <tbody>
                {filtered.map((profile) => (
                  <tr key={profile.email}>
                    <td>
                      <div style={{ fontWeight: 650 }}>{profile.fullName || '—'}</div>
                      <div className="tiny muted">{profile.email}</div>
                    </td>
                    <td className="small">{profile.clientId || '—'}</td>
                    <td className="small mono">{maskPan(profile.pan)}</td>
                    <td className="small">{profile.phone || '—'}</td>
                    <td>
                      <AccountBadge approved={profile.isApproved} linked={!!profile.uid} />
                    </td>
                    <td className="small muted">{fmtDate(profile.createdAt ?? null)}</td>
                    <td className="num">
                      <div className="row" style={{ justifyContent: 'flex-end', gap: 6 }}>
                        <Link
                          className="btn btn-ghost btn-sm"
                          to={`/admin/clients/${encodeURIComponent(profile.email)}`}
                        >
                          Portfolio
                        </Link>
                        <button type="button" className="btn btn-ghost btn-sm" onClick={() => openEdit(profile)}>
                          Edit
                        </button>
                        <button type="button" className="btn btn-ghost btn-sm" onClick={() => void toggleApproval(profile)}>
                          {profile.isApproved ? 'Revoke' : 'Approve'}
                        </button>
                        <button type="button" className="btn btn-danger btn-sm" onClick={() => void remove(profile)}>
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : null}
      </div>

      {draft ? (
        <div className="modal-backdrop" role="presentation" onClick={() => setDraft(null)}>
          <div
            className="modal"
            role="dialog"
            aria-modal="true"
            aria-label={editing ? 'Edit client' : 'New client'}
            onClick={(event) => event.stopPropagation()}
          >
            <div className="row-between" style={{ marginBottom: 14 }}>
              <h3 style={{ fontSize: 16 }}>{editing ? 'Edit client' : 'New client'}</h3>
              <button type="button" className="btn btn-ghost btn-sm" onClick={() => setDraft(null)}>
                Close
              </button>
            </div>

            <form className="stack" onSubmit={save} noValidate>
              <Field label="Email" error={formErrors.email}>
                <input
                  className="input"
                  type="email"
                  value={draft.email}
                  disabled={!!editing}
                  onChange={(event) => setDraft({ ...draft, email: event.target.value })}
                />
              </Field>
              <Field label="Full name" error={formErrors.fullName}>
                <input
                  className="input"
                  value={draft.fullName}
                  onChange={(event) => setDraft({ ...draft, fullName: event.target.value })}
                />
              </Field>
              <Field label="PAN" error={formErrors.pan}>
                <input
                  className="input"
                  value={draft.pan}
                  placeholder="ABCDE1234F"
                  onChange={(event) => setDraft({ ...draft, pan: event.target.value.toUpperCase() })}
                />
              </Field>
              <Field label="Phone" error={formErrors.phone}>
                <input
                  className="input"
                  value={draft.phone}
                  placeholder="9876543210"
                  onChange={(event) => setDraft({ ...draft, phone: event.target.value })}
                />
              </Field>
              <Field label="Client ID (optional)">
                <input
                  className="input"
                  value={draft.clientId}
                  placeholder="Generated automatically"
                  onChange={(event) => setDraft({ ...draft, clientId: event.target.value })}
                />
              </Field>

              <label className="row small" style={{ gap: 8 }}>
                <input
                  type="checkbox"
                  checked={draft.isApproved}
                  onChange={(event) => setDraft({ ...draft, isApproved: event.target.checked })}
                />
                Approved to view the dashboard
              </label>

              <button className="btn btn-primary btn-block" type="submit" disabled={saving}>
                {saving ? <span className="spinner on-dark" /> : null}
                {editing ? 'Save changes' : 'Create client'}
              </button>
            </form>
          </div>
        </div>
      ) : null}
    </Shell>
  );
}
