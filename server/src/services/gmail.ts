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

/** Collects every CSV attachment part, including nested multipart bodies. */
export function collectCsvParts(
  part: gmail_v1.Schema$MessagePart | null | undefined,
  acc: gmail_v1.Schema$MessagePart[] = [],
): gmail_v1.Schema$MessagePart[] {
  if (!part) return acc;
  const filename = (part.filename ?? "").toLowerCase();
  if (filename.endsWith(".csv") && part.body) acc.push(part);
  for (const child of part.parts ?? []) collectCsvParts(child, acc);
  return acc;
}

export async function downloadAttachment(
  gmail: gmail_v1.Gmail,
  messageId: string,
  part: gmail_v1.Schema$MessagePart,
): Promise<string> {
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

  if (!encoded) return "";
  return Buffer.from(encoded, "base64url").toString("utf8");
}

export async function ensureProcessedLabel(
  gmail: gmail_v1.Gmail,
): Promise<string> {
  const response = await gmail.users.labels.list({ userId: "me" });
  const existing = (response.data.labels ?? []).find(
    (label) => label.name === config.processedLabel,
  );
  if (existing?.id) return existing.id;

  const created = await gmail.users.labels.create({
    userId: "me",
    requestBody: {
      name: config.processedLabel,
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
