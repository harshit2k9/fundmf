import { AuthLayout } from '../components/AuthLayout';
import { DownloadApkButton } from '../components/DownloadApk';
import { useAuth } from '../lib/auth';
import { SUPPORT_EMAIL } from '../lib/firebase';

/** Shown while an admin has not approved (or provisioned) the account. */
export default function PendingPage() {
  const { status, profile, user, signOut } = useAuth();
  const unprovisioned = status === 'unprovisioned';

  return (
    <AuthLayout>
      <h2 style={{ fontSize: 21, marginBottom: 8 }}>
        {unprovisioned ? 'Waiting for provisioning' : 'Approval pending'}
      </h2>
      <p className="small muted" style={{ lineHeight: 1.6, marginBottom: 16 }}>
        {unprovisioned
          ? 'Your login works, but no client profile is linked to this email yet. Once the Fundmf admin adds your PAN and folio details you will see your portfolio here.'
          : 'Your profile has been linked to this login and is waiting for the admin to approve it. You will get access to the dashboard as soon as it is approved.'}
      </p>

      <div className="card" style={{ padding: 14, marginBottom: 16 }}>
        <div className="modal-row">
          <span>Signed in as</span>
          <strong>{user?.email ?? '—'}</strong>
        </div>
        <div className="modal-row">
          <span>Status</span>
          <strong>{unprovisioned ? 'Unclaimed' : 'Pending approval'}</strong>
        </div>
        {profile ? (
          <div className="modal-row">
            <span>Client ID</span>
            <strong>{profile.clientId || '—'}</strong>
          </div>
        ) : null}
      </div>

      <div className="alert alert-info" style={{ marginBottom: 16 }}>
        Need help? Write to{' '}
        <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a> from this email
        address and the admin will provision your account.
      </div>

      <div className="stack">
        <button type="button" className="btn btn-ghost btn-block" onClick={() => void signOut()}>
          Sign out
        </button>
        <DownloadApkButton className="btn btn-accent btn-block" label="Download Android APK" />
      </div>
    </AuthLayout>
  );
}
