import type { MessageMediaAttachment, MessageLocationAttachment } from "@rounds/contracts";

export const messageMediaLimitBytes = 15 * 1024 * 1024;
export const messageAttachmentLimit = 8;

export type StagedOperationsAttachment = {
  localId: string;
  tenantId: string;
  threadId: string;
  kind: "image" | "file" | "voice";
  fileName: string;
  contentType: string;
  byteSize: number;
  blob: Blob;
  durationMilliseconds?: number;
  createdAt: string;
} | {
  localId: string;
  tenantId: string;
  threadId: string;
  kind: "location";
  attachment: MessageLocationAttachment;
  createdAt: string;
};

export type PreparedMessageMedia = {
  status: "prepared";
  mediaAssetId: string;
  bucket: string;
  path: string;
  assetState: "staged" | "uploaded_uncommitted";
  tusEndpoint: string;
};

export function classifyMessageFile(file: Pick<File, "type">): "image" | "file" {
  return ["image/jpeg", "image/png", "image/webp"].includes(file.type) ? "image" : "file";
}

export function validateMessageFile(file: Pick<File, "size">): string | null {
  if (file.size < 1) return "The selected file is empty.";
  if (file.size > messageMediaLimitBytes) return "Each attachment must be 15 MB or smaller.";
  return null;
}

export function formatAttachmentSize(bytes: number): string {
  return bytes >= 1048576 ? `${(bytes / 1048576).toFixed(1)} MB` : `${Math.max(1, Math.ceil(bytes / 1024))} KB`;
}

export async function sha256Hex(blob: Blob): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", await blob.arrayBuffer());
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function metadataValue(value: string): string {
  const bytes = new TextEncoder().encode(value);
  let binary = "";
  bytes.forEach((byte) => { binary += String.fromCharCode(byte); });
  return btoa(binary);
}

async function responseJson(response: Response, fallback: string): Promise<Record<string, unknown>> {
  const body = await response.json().catch(() => ({})) as { error?: { message?: string } };
  if (!response.ok) throw new Error(body.error?.message ?? fallback);
  return body;
}

export async function uploadOperationsMessageMedia(input: {
  roundsApiUrl: string;
  accessToken: string;
  tenantId: string;
  threadId: string;
  attachment: Extract<StagedOperationsAttachment, { kind: "image" | "file" | "voice" }>;
}): Promise<MessageMediaAttachment> {
  const { attachment } = input;
  const preparedResponse = await fetch(`${input.roundsApiUrl}/v1/operations/communications/${input.threadId}/message-media`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${input.accessToken}`,
      "content-type": "application/json",
      "x-rounds-tenant-id": input.tenantId,
      "x-trace-id": attachment.localId,
    },
    body: JSON.stringify({
      kind: attachment.kind,
      fileName: attachment.fileName,
      contentType: attachment.contentType,
      byteSize: attachment.byteSize,
      sha256: await sha256Hex(attachment.blob),
      ...(attachment.durationMilliseconds == null ? {} : { durationMilliseconds: attachment.durationMilliseconds }),
    }),
  });
  const prepared = await responseJson(preparedResponse, "Attachment could not be prepared") as PreparedMessageMedia;

  if (prepared.assetState !== "uploaded_uncommitted") {
    const metadata = [
      ["bucketName", prepared.bucket],
      ["objectName", prepared.path],
      ["contentType", attachment.contentType],
      ["cacheControl", "3600"],
    ].map(([key, value]) => `${key} ${metadataValue(value!)}`).join(",");
    const start = await fetch(prepared.tusEndpoint, {
      method: "POST",
      headers: {
        authorization: `Bearer ${input.accessToken}`,
        "tus-resumable": "1.0.0",
        "upload-length": String(attachment.byteSize),
        "upload-metadata": metadata,
      },
    });
    const location = start.headers.get("location");
    if (start.status !== 201 || !location) throw new Error(`Attachment upload could not start (HTTP ${start.status})`);
    const uploadUrl = new URL(location, prepared.tusEndpoint).toString();
    const upload = await fetch(uploadUrl, {
      method: "PATCH",
      headers: {
        authorization: `Bearer ${input.accessToken}`,
        "tus-resumable": "1.0.0",
        "upload-offset": "0",
        "content-type": "application/offset+octet-stream",
      },
      body: attachment.blob,
    });
    if (upload.status !== 204) throw new Error(`Attachment upload paused (HTTP ${upload.status})`);
  }

  const verify = await fetch(`${input.roundsApiUrl}/v1/operations/message-media/${prepared.mediaAssetId}/verify`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${input.accessToken}`,
      "x-rounds-tenant-id": input.tenantId,
      "x-trace-id": attachment.localId,
    },
  });
  await responseJson(verify, "Attachment upload could not be verified");
  return {
    kind: attachment.kind,
    mediaAssetId: prepared.mediaAssetId,
    fileName: attachment.fileName,
    contentType: attachment.contentType,
    byteSize: attachment.byteSize,
    ...(attachment.durationMilliseconds == null ? {} : { durationMilliseconds: attachment.durationMilliseconds }),
  };
}

const databaseName = "rounds-operations-drafts";
const storeName = "message-attachments";

function openDraftDatabase(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(databaseName, 1);
    request.onupgradeneeded = () => {
      const database = request.result;
      if (!database.objectStoreNames.contains(storeName)) {
        const store = database.createObjectStore(storeName, { keyPath: "localId" });
        store.createIndex("thread", ["tenantId", "threadId"]);
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error ?? new Error("Draft storage could not open"));
  });
}

export async function listStagedAttachments(tenantId: string, threadId: string): Promise<StagedOperationsAttachment[]> {
  const database = await openDraftDatabase();
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(storeName, "readonly");
    const request = transaction.objectStore(storeName).index("thread").getAll([tenantId, threadId]);
    request.onsuccess = () => resolve((request.result as StagedOperationsAttachment[]).sort((a, b) => a.createdAt.localeCompare(b.createdAt)));
    request.onerror = () => reject(request.error ?? new Error("Draft attachments could not be read"));
    transaction.oncomplete = () => database.close();
  });
}

export async function saveStagedAttachment(attachment: StagedOperationsAttachment): Promise<void> {
  const database = await openDraftDatabase();
  await new Promise<void>((resolve, reject) => {
    const transaction = database.transaction(storeName, "readwrite");
    transaction.objectStore(storeName).put(attachment);
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error ?? new Error("Draft attachment could not be saved"));
  });
  database.close();
}

export async function removeStagedAttachment(localId: string): Promise<void> {
  const database = await openDraftDatabase();
  await new Promise<void>((resolve, reject) => {
    const transaction = database.transaction(storeName, "readwrite");
    transaction.objectStore(storeName).delete(localId);
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error ?? new Error("Draft attachment could not be removed"));
  });
  database.close();
}

export async function clearStagedAttachments(attachments: StagedOperationsAttachment[]): Promise<void> {
  await Promise.all(attachments.map((attachment) => removeStagedAttachment(attachment.localId)));
}
