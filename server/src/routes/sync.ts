import { Router } from "express";

import { asyncHandler } from "../middleware/async-handler";
import { requireAdmin } from "../middleware/auth";
import { runCamsSync } from "../services/cams-sync";

export const syncRouter = Router();

/**
 * POST /api/cams/sync
 * Admin-only manual ingestion. Returns the same summary the cron job logs.
 */
syncRouter.post(
  "/cams/sync",
  requireAdmin,
  asyncHandler(async (_req, res) => {
    const actor = String(res.locals.actor ?? "");
    const summary = await runCamsSync("manual", actor);
    // A partial or failed run is still a successful request: the admin panel
    // renders the per-message errors from the body.
    res.status(200).json(summary);
  }),
);
