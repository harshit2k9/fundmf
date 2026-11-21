import { logger } from "../logger";
import type { SyncSummary, SyncTrigger } from "../types";
import { runCamsSync } from "./cams-sync";
import { runKfintechSync } from "./kfintech-sync";

export async function runFullSync(
  trigger: SyncTrigger,
  actor = "",
): Promise<SyncSummary> {
  const startedAt = new Date();
  const cams = await runCamsSync(trigger, actor);
  const kfintech = await runKfintechSync(trigger, actor);

  const errors = [...cams.errors, ...kfintech.errors];
  const fatalError = cams.status === "failed" || kfintech.status === "failed";
  const status: SyncSummary["status"] = fatalError
    ? "failed"
    : errors.length > 0
      ? "partial"
      : "success";

  const finishedAt = new Date();
  const summary: SyncSummary = {
    status,
    trigger,
    messagesScanned: cams.messagesScanned + kfintech.messagesScanned,
    attachmentsParsed: cams.attachmentsParsed + kfintech.attachmentsParsed,
    foliosMapped: Math.max(cams.foliosMapped, kfintech.foliosMapped),
    unmappedRows: cams.unmappedRows + kfintech.unmappedRows,
    transactionsCreated:
      cams.transactionsCreated + kfintech.transactionsCreated,
    transactionsUpdated:
      cams.transactionsUpdated + kfintech.transactionsUpdated,
    duplicatesSkipped: cams.duplicatesSkipped + kfintech.duplicatesSkipped,
    errors: errors.slice(0, 50),
    durationMs: finishedAt.getTime() - startedAt.getTime(),
    startedAt: startedAt.toISOString(),
    finishedAt: finishedAt.toISOString(),
  };

  logger.info("Full sync finished", summary);
  return summary;
}
