import { useState } from 'react';
import { Link } from 'react-router-dom';

import { AuthLayout } from '../components/AuthLayout';
import { Field } from '../components/ui';
import { authErrorMessage, useAuth } from '../lib/auth';
import {
  validateConfirmPassword,
  validateEmail,
  validatePassword,
} from '../lib/validators';

export default function SignupPage() {
  const { signUp } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [errors, setErrors] = useState<Record<string, string | null>>({});
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setError(null);

    const nextErrors = {
      email: validateEmail(email),
      password: validatePassword(password),
      confirm: validateConfirmPassword(confirm, password),
    };
    setErrors(nextErrors);
    if (Object.values(nextErrors).some(Boolean)) return;

    setBusy(true);
    try {
      await signUp(email, password);
      // The auth listener immediately resolves the profile gate and routes to
      // the pending screen until an admin provisions and approves the account.
    } catch (caught) {
      setError(authErrorMessage(caught));
    } finally {
      setBusy(false);
    }
  }

  return (
    <AuthLayout>
      <h2 style={{ fontSize: 22, marginBottom: 6 }}>Create your account</h2>
      <p className="small muted" style={{ marginBottom: 20, lineHeight: 1.55 }}>
        Use the same email your advisor has on file. Once your account is
        approved, every CAMS and KFintech statement we receive appears here.
      </p>

      <form onSubmit={handleSubmit} className="stack" noValidate>
        <Field label="Email address" error={errors.email}>
          <input
            className="input"
            type="email"
            autoComplete="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            placeholder="you@example.com"
          />
        </Field>

        <Field label="Password" error={errors.password}>
          <input
            className="input"
            type="password"
            autoComplete="new-password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            placeholder="At least 8 characters"
          />
        </Field>

        <Field label="Confirm password" error={errors.confirm}>
          <input
            className="input"
            type="password"
            autoComplete="new-password"
            value={confirm}
            onChange={(event) => setConfirm(event.target.value)}
            placeholder="Repeat your password"
          />
        </Field>

        {error ? <div className="alert alert-error">{error}</div> : null}

        <button className="btn btn-primary btn-block" type="submit" disabled={busy}>
          {busy ? <span className="spinner on-dark" /> : null}
          Create account
        </button>
      </form>

      <p className="small muted center" style={{ marginTop: 16 }}>
        Already registered? <Link to="/login">Sign in</Link>
      </p>
    </AuthLayout>
  );
}
