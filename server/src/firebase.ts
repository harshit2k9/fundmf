import {
  applicationDefault,
  cert,
  getApps,
  initializeApp,
} from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

import { config } from "./config";
import { logger } from "./logger";

/**
 * Initialises the Firebase Admin SDK once per process. Authentication and
 * Firestore are still Firebase; only the compute moved to Render.
 *
 * Credentials come from FIREBASE_SERVICE_ACCOUNT (full service account JSON),
 * or Application Default Credentials when running with GOOGLE_APPLICATION_CREDENTIALS.
 */
export function initFirebase(): void {
  if (getApps().length > 0) return;

  const raw = config.firebase.serviceAccountJson;
  if (raw) {
    let parsed: {
      project_id?: string;
      client_email?: string;
      private_key?: string;
    };
    try {
      parsed = JSON.parse(raw) as typeof parsed;
    } catch {
      throw new Error("FIREBASE_SERVICE_ACCOUNT is not valid JSON.");
    }

    if (!parsed.client_email || !parsed.private_key) {
      throw new Error(
        "FIREBASE_SERVICE_ACCOUNT must contain client_email and private_key.",
      );
    }

    initializeApp({
      projectId: config.firebase.projectId || parsed.project_id,
      credential: cert({
        projectId: parsed.project_id,
        clientEmail: parsed.client_email,
        // Render stores the key with literal "\n" escapes; restore real newlines.
        privateKey: parsed.private_key.replace(/\\n/g, "\n"),
      }),
    });
    logger.info("Firebase Admin initialised from service account env var");
    return;
  }

  logger.warn(
    "FIREBASE_SERVICE_ACCOUNT is not set; using application default credentials",
  );
  initializeApp({
    projectId: config.firebase.projectId || undefined,
    credential: applicationDefault(),
  });
}

export function firestore() {
  return getFirestore();
}
