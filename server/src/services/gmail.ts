import { gmail_v1, google } from "googleapis";

import { config } from "../config";
import { HttpError } from "../http-error";

/** Builds a Gmail client for fundmfservices@gmail.com from an OAuth2 refresh token. */
export function createGmailClient(): gmail_v1.Gmail {
  const { clientId, clientSecret, refreshToken } = config.gmail;

  if (!clientId || !clientSecret || !refreshToken) {
    throw HttpError.unavailable(
      "Gmail credentials are not configured on the server. Set GMAIL_CLIENT_ID, " +
        "GMAIL_CLIENT_SECRET and GMAIL_REFRESH_TOKEN in the Render environment.",
    );
  }

  const auth = new google.auth.OAuth2(clientId, clientSecret);
  auth.setCredentials({ refresh_token: refreshToken });
  return google.gmail({ version: "v1", auth });
}

/**
 * Collects every statement attachment part (zip or csv), including nested
 * multipart bodies.
 */
export function collectStatementParts(
  part: gmail_v1.Schema$MessagePart | null | undefined,
  acc: gmail_v1.Schema$MessagePart[] = [],
): gmail_v1.Schema$MessagePart[] {
  if (!part) return acc;
  const filename = (part.filename ?? "").toLowerCase();
  const isStatement =
    filename.endsWith(".zip") || filename.endsWith(".csv");
  if (isStatement && part.body) acc.push(part);
  for (const child of part.parts ?? []) collectStatementParts(child, acc);
  return acc;
}

/** Downloads an attachment as raw bytes (a zip cannot be read as text). */
export async function downloadUrl(url: string): Promise<Buffer> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30000);
  try {
    const response = await fetch(url, {
      redirect: "follow",
      signal: controller.signal,
    });
    if (!response.ok) {
      throw new Error(`Download failed: HTTP ${response.status} for ${url}`);
    }
    return Buffer.from(await response.arrayBuffer());
  } finally {
    clearTimeout(timeout);
  }
}

export async function downloadAttachmentBuffer(
  gmail: gmail_v1.Gmail,
  messageId: string,
  part: gmail_v1.Schema$MessagePart,
): Promise<Buffer> {
  let encoded = part.body?.data ?? undefined;
  const attachmentId = part.body?.attachmentId ?? undefined;

  if (!encoded && attachmentId) {
    const attachment = await gmail.users.messages.attachments.get({
      userId: "me",
      messageId,
      id: attachmentId,
    });
    encoded = attachment.data.data ?? undefined;
  }

  if (!encoded) return Buffer.alloc(0);
  return Buffer.from(encoded, "base64url");
}

export async function ensureProcessedLabel(
  gmail: gmail_v1.Gmail,
  labelName: string = config.processedLabel,
): Promise<string> {
  const response = await gmail.users.labels.list({ userId: "me" });
  const existing = (response.data.labels ?? []).find(
    (label) => label.name === labelName,
  );
  if (existing?.id) return existing.id;

  const created = await gmail.users.labels.create({
    userId: "me",
    requestBody: {
      name: labelName,
      labelListVisibility: "labelShow",
      messageListVisibility: "show",
    },
  });
  return created.data.id ?? "";
}

/** Marks the statement read and labelled so it is never scanned twice. */
export async function markProcessed(
  gmail: gmail_v1.Gmail,
  messageId: string,
  labelId: string,
): Promise<void> {
  await gmail.users.messages.modify({
    userId: "me",
    id: messageId,
    requestBody: {
      removeLabelIds: ["UNREAD"],
      addLabelIds: labelId ? [labelId] : [],
    },
  });
}
