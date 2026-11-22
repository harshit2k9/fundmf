import { useState } from 'react';
import { Link } from 'react-router-dom';

import { AuthLayout } from '../components/AuthLayout';
import { Field } from '../components/ui';
import { authErrorMessage, useAuth } from '../lib/auth';
import { validateEmail, validatePassword } from '../lib/validators';

export default function LoginPage() {
  const { signIn, resetPassword } = useAuth();
  const [mode, setMode] = useState<'signin' | 'reset'>('signin');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [emailError, setEmailError] = useState<string | null>(null);
  const [passwordError, setPasswordError] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setError(null);
    setNotice(null);

    const nextEmailError = validateEmail(email);
    setEmailError(nextEmailError);
    if (mode === 'signin') {
      const nextPasswordError = validatePassword(password);
      setPasswordError(nextPasswordError);
      if (nextEmailError || nextPasswordError) return;
    } else if (nextEmailError) {
      return;
    }

    setBusy(true);
    try {
      if (mode === 'signin') {
        await signIn(email, password);
      } else {
        await resetPassword(email);
        setNotice('Password reset link sent. Check your inbox.');
      }
    } catch (caught) {
      setError(authErrorMessage(caught));
    } finally {
      setBusy(false);
    }
  }

  return (
    <AuthLayout>
      <h2 style={{ fontSize: 22, marginBottom: 6 }}>
        {mode === 'signin' ? 'Welcome back' : 'Reset your password'}
      </h2>
      <p className="small muted" style={{ marginBottom: 20, lineHeight: 1.55 }}>
        {mode === 'signin'
          ? 'Sign in with the email your advisor provisioned for you.'
          : 'Enter your email and we will send you a secure reset link.'}
      </p>

      <form onSubmit={handleSubmit} className="stack" noValidate>
        <Field label="Email address" error={emailError}>
          <input
            className="input"
            type="email"
            autoComplete="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            placeholder="you@example.com"
          />
        </Field>

        {mode === 'signin' ? (
          <Field label="Password" error={passwordError}>
            <input
              className="input"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              placeholder="••••••••"
            />
          </Field>
        ) : null}

        {error ? <div className="alert alert-error">{error}</div> : null}
        {notice ? <div className="alert alert-success">{notice}</div> : null}

        <button className="btn btn-primary btn-block" type="submit" disabled={busy}>
          {busy ? <span className="spinner on-dark" /> : null}
          {mode === 'signin' ? 'Sign in' : 'Send reset link'}
        </button>
      </form>

      <div className="row-between" style={{ marginTop: 14 }}>
        <button
          type="button"
          className="btn btn-ghost btn-sm"
          onClick={() => {
            setMode(mode === 'signin' ? 'reset' : 'signin');
            setError(null);
            setNotice(null);
          }}
        >
          {mode === 'signin' ? 'Forgot password?' : 'Back to sign in'}
        </button>
        <Link className="small" to="/signup">
          Create account
        </Link>
      </div>

      <div className="alert alert-info" style={{ marginTop: 18 }}>
        Accounts are created by the Fundmf admin. If you have just signed up,
        your advisor still needs to approve and provision your PAN.
      </div>
    </AuthLayout>
  );
}
