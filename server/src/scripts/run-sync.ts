/**
 * Render cron job entrypoint: runs the same ingestion pipeline as the API on a
 * schedule, without depending on the web service being awake.
 *
 * Schedule in render.yaml is every 6 hours, on the hour (UTC).
 */
import { initFirebase } from "../firebase";
import { logger } from "../logger";
import { runCamsSync } from "../services/cams-sync";

async function main(): Promise<void> {
  initFirebase();
  const summary = await runCamsSync("scheduled", "render-cron");
  logger.info("Scheduled CAMS sync result", summary);

  if (summary.status === "failed") {
    // Non-zero exit marks the cron run as failed in the Render dashboard.
    process.exitCode = 1;
  }
}

main().catch((error: unknown) => {
  logger.error("Scheduled CAMS sync crashed", error);
  process.exitCode = 1;
});
