import type { RequestHandler } from "express";
import { getAuth } from "firebase-admin/auth";

import { config } from "../config";
import { HttpError } from "../http-error";
import { logger } from "../logger";

const BEARER = /^Bearer\s+(.+)$/i;

/**
 * Verifies the Firebase ID token sent by the Flutter client and restricts the
 * request to the Fundmf admin. Authentication itself still lives in Firebase.
 */
export const requireAdmin: RequestHandler = async (req, res, next) => {
  const match = BEARER.exec((req.header("authorization") ?? "").trim());
  if (!match) {
    res.status(401).json({
      error: "unauthenticated",
      message: "Missing Firebase ID token.",
    });
    return;
  }

  try {
    // checkRevoked: a disabled or signed-out admin loses access immediately.
    const decoded = await getAuth().verifyIdToken(match[1].trim(), true);
    const email = (decoded.email ?? "").toLowerCase();

    if (email !== config.adminEmail && decoded.role !== "admin") {
      logger.warn("Rejected sync request: not the admin", {
        uid: decoded.uid,
        email,
      });
      res.status(403).json({
        error: "permission-denied",
        message: "Only the Fundmf admin account can run the CAMS sync.",
      });
      return;
    }

    res.locals.actor = email || decoded.uid;
    next();
  } catch (error) {
    const code =
      typeof (error as { code?: unknown }).code === "string"
        ? (error as { code: string }).code
        : "";

    // A bad/expired/revoked token is the caller's problem; anything else means
    // this service cannot verify tokens (missing credentials, project id).
    if (code.startsWith("auth/")) {
      logger.warn("Rejected sync request: invalid token", error);
      res.status(401).json({
        error: "unauthenticated",
        message: "Your session expired. Sign in again to run the sync.",
      });
      return;
    }

    logger.error("Could not verify Firebase ID token", error);
    next(
      new HttpError(
        500,
        "internal",
        "The sync service could not verify your session. Check its Firebase admin credentials.",
      ),
    );
  }
};
