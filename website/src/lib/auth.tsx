import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import {
  EmailAuthProvider,
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  reauthenticateWithCredential,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signOut as firebaseSignOut,
  updatePassword,
  type User,
} from 'firebase/auth';

import { ADMIN_EMAIL, auth } from './firebase';
import { fetchProfile, linkAuthUser, touchLastLogin } from './data';
import { normalizeEmail } from './validators';
import type { SessionStatus, UserProfile } from './types';

/**
 * Resolves the onboarding gate exactly like the Flutter session provider:
 *
 *   signed out                -> login
 *   admin email               -> admin panel
 *   no provisioned profile    -> unprovisioned (contact admin)
 *   profile not yet linked    -> link uid, then continue
 *   linked but not approved   -> pending approval
 *   linked + approved         -> dashboard
 */
interface AuthContextValue {
  status: SessionStatus;
  user: User | null;
  profile: UserProfile | null;
  error: string | null;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (email: string, password: string) => Promise<void>;
  resetPassword: (email: string) => Promise<void>;
  changePassword: (currentPassword: string, newPassword: string) => Promise<void>;
  signOut: () => Promise<void>;
  refresh: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<SessionStatus>('loading');
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [tick, setTick] = useState(0);
  /** Prevents re-linking on every auth event for the same uid. */
  const linkingRef = useRef<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    const unsubscribe = onAuthStateChanged(auth, async (nextUser) => {
      if (cancelled) return;

      if (!nextUser || !nextUser.email) {
        setUser(null);
        setProfile(null);
        setStatus('signedOut');
        return;
      }

      setUser(nextUser);
      const email = normalizeEmail(nextUser.email);

      if (email === ADMIN_EMAIL) {
        setProfile(null);
        setStatus('admin');
        return;
      }

      let resolved: UserProfile | null = null;
      try {
        resolved = await fetchProfile(email);
      } catch {
        resolved = null;
      }
      if (cancelled) return;

      if (!resolved) {
        setProfile(null);
        setStatus('unprovisioned');
        return;
      }

      let claimed = resolved;

      if (!claimed.uid) {
        if (linkingRef.current !== nextUser.uid) {
          linkingRef.current = nextUser.uid;
          try {
            await linkAuthUser(email, nextUser.uid);
            claimed = { ...claimed, uid: nextUser.uid, linkedAt: new Date() };
          } catch {
            // The next auth event or a manual refresh retries the link.
          }
        }
      } else if (claimed.uid !== nextUser.uid) {
        setProfile(null);
        setStatus('unprovisioned');
        return;
      }

      if (claimed.isApproved) {
        try {
          await touchLastLogin(email);
        } catch {
          // A failed timestamp write must not block the dashboard.
        }
      }

      setProfile(claimed);
      setStatus(claimed.isApproved ? 'active' : 'pendingApproval');
    });

    return () => {
      cancelled = true;
      unsubscribe();
    };
  }, [tick]);

  const signIn = useCallback(async (email: string, password: string) => {
    setError(null);
    await signInWithEmailAndPassword(auth, normalizeEmail(email), password);
  }, []);

  const signUp = useCallback(async (email: string, password: string) => {
    setError(null);
    await createUserWithEmailAndPassword(auth, normalizeEmail(email), password);
  }, []);

  const resetPassword = useCallback(async (email: string) => {
    await sendPasswordResetEmail(auth, normalizeEmail(email));
  }, []);

  const changePassword = useCallback(
    async (currentPassword: string, newPassword: string) => {
      const current = auth.currentUser;
      if (!current || !current.email) {
        throw new Error('No signed-in user.');
      }
      const credential = EmailAuthProvider.credential(
        current.email,
        currentPassword,
      );
      await reauthenticateWithCredential(current, credential);
      await updatePassword(current, newPassword);
    },
    [],
  );

  const signOut = useCallback(async () => {
    await firebaseSignOut(auth);
  }, []);

  const refresh = useCallback(() => setTick((value) => value + 1), []);

  const value = useMemo<AuthContextValue>(
    () => ({
      status,
      user,
      profile,
      error,
      signIn,
      signUp,
      resetPassword,
      changePassword,
      signOut,
      refresh,
    }),
    [status, user, profile, error, signIn, signUp, resetPassword, changePassword, signOut, refresh],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used inside <AuthProvider>');
  return context;
}

/** Firebase error codes turned into the copy the app shows. */
export function authErrorMessage(error: unknown): string {
  const code = (error as { code?: string })?.code ?? '';
  switch (code) {
    case 'auth/invalid-email':
      return 'That email address is not valid.';
    case 'auth/missing-password':
      return 'Enter your password.';
    case 'auth/user-disabled':
      return 'This account has been disabled. Contact support.';
    case 'auth/user-not-found':
    case 'auth/wrong-password':
    case 'auth/invalid-credential':
      return 'Incorrect email or password.';
    case 'auth/email-already-in-use':
      return 'An account with this email already exists. Sign in instead.';
    case 'auth/weak-password':
      return 'Use a stronger password (at least 8 characters).';
    case 'auth/too-many-requests':
      return 'Too many attempts. Wait a few minutes and try again.';
    case 'auth/network-request-failed':
      return 'Network error. Check your connection and try again.';
    case 'auth/requires-recent-login':
      return 'Please sign in again before changing your password.';
    default:
      return (error as Error)?.message || 'Something went wrong. Please try again.';
  }
}
