import { useState } from 'react';
import { useNavigate } from 'react-router-dom';

import { DownloadApkButton } from '../components/DownloadApk';
import { Shell, investorNav } from '../components/Shell';
import { Field } from '../components/ui';
import { authErrorMessage, useAuth } from '../lib/auth';
import { SUPPORT_EMAIL } from '../lib/firebase';
import { fmtDate, fmtDateTime, initials, maskPan } from '../lib/format';
import { validateConfirmPassword, validatePassword } from '../lib/validators';

export default function ProfilePage() {
  const { profile, user, changePassword, signOut } = useAuth();
  const navigate = useNavigate();

  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [errors, setErrors] = useState<Record<string, string | null>>({});
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function handlePasswordChange(event: React.FormEvent) {
    event.preventDefault();
    setError(null);
    setNotice(null);

    const nextErrors = {
      current: currentPassword ? null : 'Enter your current password',
      next: validatePassword(newPassword),
      confirm: validateConfirmPassword(confirmPassword, newPassword),
    };
    setErrors(nextErrors);
    if (Object.values(nextErrors).some(Boolean)) return;

    setBusy(true);
    try {
      await changePassword(currentPassword, newPassword);
      setNotice('Password updated.');
      setCurrentPassword('');
      setNewPassword('');
      setConfirmPassword('');
    } catch (caught) {
      setError(authErrorMessage(caught));
    } finally {
      setBusy(false);
    }
  }

  const status = !profile?.uid ? 'Unclaimed' : profile?.isApproved ? 'Active' : 'Pending approval';

  return (
    <Shell items={investorNav} title="Profile" subtitle={user?.email ?? ''}>
      <div className="stack" style={{ gap: 16 }}>
        <section className="card">
          <div className="row" style={{ gap: 14 }}>
            <div
              style={{
                width: 52,
                height: 52,
                borderRadius: 16,
                background: 'var(--navy)',
                color: '#fff',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontWeight: 750,
                fontSize: 18,
                flex: '0 0 52px',
              }}
            >
              {initials(profile?.fullName ?? '')}
            </div>
            <div className="grow">
              <div style={{ fontSize: 17, fontWeight: 750 }}>
                {profile?.fullName || 'Investor'}
              </div>
              <div className="small muted">{user?.email ?? '—'}</div>
            </div>
            <span className={`badge ${profile?.isApproved ? 'success' : 'partial'}`}>
              {status}
            </span>
          </div>

          <div style={{ marginTop: 16 }}>
            <div className="modal-row">
              <span>Client ID</span>
              <strong>{profile?.clientId || '—'}</strong>
            </div>
            <div className="modal-row">
              <span>PAN</span>
              <strong>{profile?.pan ? maskPan(profile.pan) : '—'}</strong>
            </div>
            <div className="modal-row">
              <span>Phone</span>
              <strong>{profile?.phone || '—'}</strong>
            </div>
            <div className="modal-row">
              <span>Member since</span>
              <strong>{fmtDate(profile?.createdAt ?? null)}</strong>
            </div>
            <div className="modal-row">
              <span>Last login</span>
              <strong>{fmtDateTime(profile?.lastLoginAt ?? null)}</strong>
            </div>
          </div>
        </section>

        <section className="card">
          <div className="section-title" style={{ marginBottom: 12 }}>
            Security
          </div>
          <form className="stack" onSubmit={handlePasswordChange} noValidate>
            <Field label="Current password" error={errors.current}>
              <input
                className="input"
                type="password"
                autoComplete="current-password"
                value={currentPassword}
                onChange={(event) => setCurrentPassword(event.target.value)}
              />
            </Field>
            <Field label="New password" error={errors.next}>
              <input
                className="input"
                type="password"
                autoComplete="new-password"
                value={newPassword}
                onChange={(event) => setNewPassword(event.target.value)}
              />
            </Field>
            <Field label="Confirm new password" error={errors.confirm}>
              <input
                className="input"
                type="password"
                autoComplete="new-password"
                value={confirmPassword}
                onChange={(event) => setConfirmPassword(event.target.value)}
              />
            </Field>

            {error ? <div className="alert alert-error">{error}</div> : null}
            {notice ? <div className="alert alert-success">{notice}</div> : null}

            <button className="btn btn-primary" type="submit" disabled={busy}>
              {busy ? <span className="spinner on-dark" /> : null}
              Update password
            </button>
          </form>
        </section>

        <section className="card">
          <div className="section-title" style={{ marginBottom: 10 }}>
            Android app
          </div>
          <p className="small muted" style={{ marginBottom: 12, lineHeight: 1.55 }}>
            Prefer the native app? The same portfolio, transactions and admin
            tools are available offline-first on Android.
          </p>
          <DownloadApkButton className="btn btn-accent btn-block" label="Download APK" />
        </section>

        <section className="card">
          <div className="section-title" style={{ marginBottom: 10 }}>
            Support
          </div>
          <p className="small muted" style={{ marginBottom: 12 }}>
            Questions about your folios or statements? Write to{' '}
            <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>.
          </p>
          <button
            type="button"
            className="btn btn-ghost btn-block"
            onClick={() => {
              void signOut().then(() => navigate('/login'));
            }}
          >
            Sign out
          </button>
        </section>
      </div>
    </Shell>
  );
}
