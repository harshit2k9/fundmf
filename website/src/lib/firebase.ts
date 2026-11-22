import { initializeApp, type FirebaseApp } from 'firebase/app';
import { getAuth, type Auth } from 'firebase/auth';
import { getFirestore, type Firestore } from 'firebase/firestore';

/**
 * Firebase web configuration for the `fundmf-mf` project. These identifiers are
 * public (they ship in every web bundle); the Gmail refresh token used by the
 * backend lives only in the Render environment.
 *
 * The client SDK is shared with the Flutter app, so the website reads and
 * writes the same Firestore collections and the same Firebase Auth users.
 */
export const firebaseConfig = {
  apiKey: 'AIzaSyD5sPxWoDCm0NBPq-lRTKrnVa37NEnAyZQ',
  appId: '1:961928659142:web:cd92bc6d9002c81d0817c7',
  messagingSenderId: '961928659142',
  projectId: 'fundmf-mf',
  authDomain: 'fundmf-mf.firebaseapp.com',
  storageBucket: 'fundmf-mf.firebasestorage.app',
  measurementId: 'G-K8BGDMV3Y0',
};

export const firebaseApp: FirebaseApp = initializeApp(firebaseConfig);
export const auth: Auth = getAuth(firebaseApp);
export const db: Firestore = getFirestore(firebaseApp);

/** Express backend on Render — the same one the Android app calls. */
export const API_BASE_URL = (
  import.meta.env.VITE_API_BASE_URL ?? 'https://fundmf.onrender.com'
).replace(/\/+$/, '');

export const SYNC_PATH = '/api/cams/sync';

/** Applied from .env — lets you host the APK anywhere. */
export const APK_URL: string =
  import.meta.env.VITE_APK_URL ?? '/fundmf-release.apk';

export const APK_SIZE_LABEL = '57 MB';

/** The only account allowed to provision clients and trigger syncs. */
export const ADMIN_EMAIL = 'fundmfservices@gmail.com';

export const SUPPORT_EMAIL = 'fundmfservices@gmail.com';

export const API_BASE_PUBLIC_URL = 'https://api.mfapi.in/mf';

export const APP_NAME = 'FUNDMF';
