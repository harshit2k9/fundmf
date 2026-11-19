import "dotenv/config";

/** Splits a comma separated env var into a trimmed, non-empty list. */
function list(value: string | undefined, fallback: string[]): string[] {
  const items = (value ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
  return items.length > 0 ? items : fallback;
}

function integer(value: string | undefined, fallback: number): number {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

/**
 * Every environment-specific value lives here. Nothing is validated at import
 * time so the health check still answers when a secret is missing; the Gmail
 * secrets are validated when a sync actually starts.
 */
export const config = {
  port: integer(process.env.PORT, 8080),

  /** Comma separated origins, or ["*"] to reflect any origin (bearer tokens). */
  allowedOrigins: list(process.env.ALLOWED_ORIGINS, ["*"]),

  firebase: {
    projectId: (process.env.FIREBASE_PROJECT_ID ?? "").trim(),
    serviceAccountJson: (process.env.FIREBASE_SERVICE_ACCOUNT ?? "").trim(),
  },

  adminEmail: (process.env.ADMIN_EMAIL ?? "fundmfservices@gmail.com")
    .trim()
    .toLowerCase(),

  gmail: {
    clientId: (process.env.GMAIL_CLIENT_ID ?? "").trim(),
    clientSecret: (process.env.GMAIL_CLIENT_SECRET ?? "").trim(),
    refreshToken: (process.env.GMAIL_REFRESH_TOKEN ?? "").trim(),
  },

  camsSender: "donotreply@camsonline.com",
  processedLabel: "CAMS_PROCESSED",
  maxMessages: integer(process.env.CAMS_MAX_MESSAGES, 25),
} as const;

export const gmailQuery = `from:${config.camsSender} has:attachment filename:csv is:unread`;
