"use client";

import { useCallback, useEffect, useMemo, useRef, useState, type ClipboardEvent, type DragEvent, type KeyboardEvent } from "react";
import type {
  DriverThreadMessage,
  MessageLocationAttachment,
  OperationsCommunicationsProjection,
  OperationsTenant,
  SendOperationsMessageResult,
} from "@rounds/contracts";
import {
  clearStagedAttachments,
  classifyMessageFile,
  formatAttachmentSize,
  listStagedAttachments,
  messageAttachmentLimit,
  removeStagedAttachment,
  saveStagedAttachment,
  uploadOperationsMessageMedia,
  validateMessageFile,
  type StagedOperationsAttachment,
} from "../src/operations-message-media";

const roundsApiUrl = process.env.NEXT_PUBLIC_ROUNDS_API_URL ?? "http://127.0.0.1:8080";
type Props = { accessToken: string; tenant: OperationsTenant; initialThreadId?: string };
type ApiError = { error?: { message?: string }; status?: string };

function timeLabel(value: string, timezone: string): string {
  return new Intl.DateTimeFormat("en-GB", {
    hour: "2-digit",
    minute: "2-digit",
    timeZone: timezone,
  }).format(new Date(value));
}

function messageFrom(body: ApiError, fallback: string): string {
  return body.error?.message ?? fallback;
}

function messageSummary(message: DriverThreadMessage | undefined): string {
  if (!message) return "No messages yet";
  if (message.body.trim()) return message.body;
  const attachment = message.attachments?.[0];
  if (!attachment) return "Attachment";
  if (attachment.kind === "location") return "Location shared";
  if (attachment.kind === "voice") return "Voice note";
  return attachment.fileName;
}

function MessageAttachments({ message }: { message: DriverThreadMessage }) {
  return <>{message.attachments?.map((attachment, index) => {
    if (attachment.kind === "location") {
      const coordinates = `${attachment.latitude},${attachment.longitude}`;
      const href = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(coordinates)}`;
      return <a className="message-location" href={href} target="_blank" rel="noreferrer" key={`${attachment.kind}:${attachment.capturedAt}:${index}`}>
        <span aria-hidden="true">⌖</span>
        <span><strong>{attachment.label}</strong><small>{attachment.latitude.toFixed(4)}, {attachment.longitude.toFixed(4)}</small></span>
        <i aria-hidden="true">›</i>
      </a>;
    }
    const size = attachment.byteSize >= 1048576
      ? `${(attachment.byteSize / 1048576).toFixed(1)} MB`
      : `${Math.ceil(attachment.byteSize / 1024)} KB`;
    const duration = attachment.durationMilliseconds == null ? "" : `${Math.floor(attachment.durationMilliseconds / 60000)}:${String(Math.ceil(attachment.durationMilliseconds / 1000) % 60).padStart(2, "0")}`;
    return <a
      className="message-location message-media"
      href={attachment.downloadUrl}
      target="_blank"
      rel="noreferrer"
      key={`${attachment.kind}:${attachment.mediaAssetId}:${index}`}
      aria-disabled={!attachment.downloadUrl}
    >
      <span aria-hidden="true">{attachment.kind === "voice" ? "▶" : attachment.kind === "image" ? "▧" : "▤"}</span>
      <span><strong>{attachment.kind === "voice" ? "Voice note" : attachment.fileName}</strong><small>{attachment.kind === "voice" ? duration : size}</small></span>
      <i aria-hidden="true">›</i>
    </a>;
  })}</>;
}

function draftKey(tenantId: string, threadId: string): string {
  return `rounds:operations:message-draft:${tenantId}:${threadId}`;
}

function StagedAttachmentPreview({ attachment, onRemove }: { attachment: StagedOperationsAttachment; onRemove: () => void }) {
  const [previewUrl, setPreviewUrl] = useState("");
  useEffect(() => {
    if (attachment.kind !== "image" && attachment.kind !== "voice") return;
    const url = URL.createObjectURL(attachment.blob);
    setPreviewUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [attachment]);
  const label = attachment.kind === "location" ? attachment.attachment.label : attachment.kind === "voice" ? "Voice note" : attachment.fileName;
  const detail = attachment.kind === "location"
    ? `${attachment.attachment.latitude.toFixed(4)}, ${attachment.attachment.longitude.toFixed(4)}`
    : attachment.kind === "voice"
      ? `${Math.max(1, Math.round((attachment.durationMilliseconds ?? 0) / 1000))} sec · ${formatAttachmentSize(attachment.byteSize)}`
      : formatAttachmentSize(attachment.byteSize);
  return <div className="staged-attachment">
    <span className="staged-attachment-mark" aria-hidden="true">
      {attachment.kind === "image" && previewUrl ? <img src={previewUrl} alt="" /> : attachment.kind === "location" ? "⌖" : attachment.kind === "voice" ? "●" : "DOC"}
    </span>
    <span className="staged-attachment-copy"><strong>{label}</strong><small>{detail}</small>{attachment.kind === "voice" && previewUrl && <audio src={previewUrl} controls preload="metadata" />}</span>
    <button type="button" onClick={onRemove} aria-label={`Remove ${label}`}>×</button>
  </div>;
}

export function CommunicationsPanel({ accessToken, tenant, initialThreadId = "" }: Props) {
  const [projection, setProjection] = useState<OperationsCommunicationsProjection | null>(null);
  const [selectedThreadId, setSelectedThreadId] = useState("");
  const [draft, setDraft] = useState("");
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");
  const [staged, setStaged] = useState<StagedOperationsAttachment[]>([]);
  const [attachmentMenuOpen, setAttachmentMenuOpen] = useState(false);
  const [dragActive, setDragActive] = useState(false);
  const [recording, setRecording] = useState(false);
  const [recordingSeconds, setRecordingSeconds] = useState(0);
  const photoInput = useRef<HTMLInputElement>(null);
  const fileInput = useRef<HTMLInputElement>(null);
  const mediaRecorder = useRef<MediaRecorder | null>(null);
  const recordingChunks = useRef<Blob[]>([]);
  const recordingStartedAt = useRef(0);

  const load = useCallback(async (quiet = false) => {
    if (!quiet) setLoading(true);
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/communications`, {
        headers: {
          authorization: `Bearer ${accessToken}`,
          "x-rounds-tenant-id": tenant.id,
          "x-trace-id": crypto.randomUUID(),
        },
      });
      const body = await response.json() as OperationsCommunicationsProjection | ApiError;
      if (!response.ok) throw new Error(messageFrom(body as ApiError, `Communications HTTP ${response.status}`));
      const next = body as OperationsCommunicationsProjection;
      setProjection(next);
      setSelectedThreadId((current) => next.threads.some((thread) => thread.id === initialThreadId)
        ? initialThreadId
        : next.threads.some((thread) => thread.id === current) ? current : next.threads[0]?.id ?? "");
      setError("");
    } catch (caught) {
      if (!quiet) setError(caught instanceof Error ? caught.message : "Communications could not be loaded");
    } finally {
      if (!quiet) setLoading(false);
    }
  }, [accessToken, initialThreadId, tenant.id]);

  useEffect(() => {
    void load();
    const timer = window.setInterval(() => void load(true), 5000);
    return () => window.clearInterval(timer);
  }, [load]);

  const selected = useMemo(
    () => projection?.threads.find((thread) => thread.id === selectedThreadId) ?? null,
    [projection, selectedThreadId],
  );

  useEffect(() => {
    let active = true;
    if (!selectedThreadId) {
      setDraft("");
      setStaged([]);
      return;
    }
    setDraft(window.localStorage.getItem(draftKey(tenant.id, selectedThreadId)) ?? "");
    void listStagedAttachments(tenant.id, selectedThreadId).then((attachments) => {
      if (active) setStaged(attachments);
    }).catch(() => {
      if (active) setError("Saved attachment drafts could not be restored on this browser.");
    });
    return () => { active = false; };
  }, [selectedThreadId, tenant.id]);

  useEffect(() => {
    if (!recording) return;
    const timer = window.setInterval(() => setRecordingSeconds(Math.floor((Date.now() - recordingStartedAt.current) / 1000)), 250);
    return () => window.clearInterval(timer);
  }, [recording]);

  async function addStaged(attachment: StagedOperationsAttachment) {
    if (staged.length >= messageAttachmentLimit) {
      setError(`A message can contain up to ${messageAttachmentLimit} attachments.`);
      return;
    }
    await saveStagedAttachment(attachment);
    setStaged((current) => [...current, attachment]);
    setAttachmentMenuOpen(false);
    setError("");
  }

  async function stageFiles(files: File[]) {
    for (const file of files.slice(0, Math.max(0, messageAttachmentLimit - staged.length))) {
      const issue = validateMessageFile(file);
      if (issue) {
        setError(`${file.name}: ${issue}`);
        continue;
      }
      await addStaged({
        localId: crypto.randomUUID(),
        tenantId: tenant.id,
        threadId: selectedThreadId,
        kind: classifyMessageFile(file),
        fileName: file.name.slice(0, 240),
        contentType: file.type || "application/octet-stream",
        byteSize: file.size,
        blob: file,
        createdAt: new Date().toISOString(),
      });
    }
  }

  async function removeAttachment(attachment: StagedOperationsAttachment) {
    await removeStagedAttachment(attachment.localId);
    setStaged((current) => current.filter((item) => item.localId !== attachment.localId));
  }

  function updateDraft(value: string) {
    setDraft(value);
    if (selectedThreadId) window.localStorage.setItem(draftKey(tenant.id, selectedThreadId), value);
  }

  function stageCurrentLocation(label: string) {
    if (!navigator.geolocation) {
      setError("Location is not available in this browser.");
      return;
    }
    navigator.geolocation.getCurrentPosition((position) => {
      void addStaged({
        localId: crypto.randomUUID(),
        tenantId: tenant.id,
        threadId: selectedThreadId,
        kind: "location",
        attachment: {
          kind: "location",
          label,
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
          accuracyMeters: position.coords.accuracy,
          capturedAt: new Date(position.timestamp).toISOString(),
        },
        createdAt: new Date().toISOString(),
      });
    }, (failure) => setError(failure.message || "Current location could not be read"), { enableHighAccuracy: true, timeout: 10000 });
  }

  function stageMapContext() {
    if (!selected?.destinationPosition) {
      setError("This Stop does not yet have an authoritative map pin.");
      return;
    }
    const attachment: MessageLocationAttachment = {
      kind: "location",
      label: `Map context · ${selected.deliveryReference}`,
      latitude: selected.destinationPosition.latitude,
      longitude: selected.destinationPosition.longitude,
      capturedAt: new Date().toISOString(),
    };
    void addStaged({
      localId: crypto.randomUUID(), tenantId: tenant.id, threadId: selected.id,
      kind: "location", attachment, createdAt: new Date().toISOString(),
    });
  }

  async function startVoiceRecording() {
    if (!navigator.mediaDevices?.getUserMedia || typeof MediaRecorder === "undefined") {
      setError("Voice recording is not available in this browser.");
      return;
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const preferred = MediaRecorder.isTypeSupported("audio/webm;codecs=opus") ? "audio/webm;codecs=opus" : "";
      const recorder = new MediaRecorder(stream, preferred ? { mimeType: preferred } : undefined);
      recordingChunks.current = [];
      recorder.ondataavailable = (event) => { if (event.data.size) recordingChunks.current.push(event.data); };
      recorder.onstop = () => {
        const duration = Date.now() - recordingStartedAt.current;
        const contentType = recorder.mimeType.split(";")[0] || "audio/webm";
        const blob = new Blob(recordingChunks.current, { type: contentType });
        stream.getTracks().forEach((track) => track.stop());
        setRecording(false);
        setRecordingSeconds(0);
        if (duration < 250 || !blob.size) {
          setError("Voice note was too short. Record for at least one second.");
          return;
        }
        void addStaged({
          localId: crypto.randomUUID(), tenantId: tenant.id, threadId: selectedThreadId,
          kind: "voice", fileName: `dispatch-voice-${Date.now()}.${contentType === "audio/mp4" ? "m4a" : contentType === "audio/ogg" ? "ogg" : "webm"}`, contentType,
          byteSize: blob.size, blob, durationMilliseconds: duration, createdAt: new Date().toISOString(),
        });
      };
      mediaRecorder.current = recorder;
      recordingStartedAt.current = Date.now();
      recorder.start(250);
      setRecording(true);
      setError("");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Microphone permission was not granted");
    }
  }

  function stopVoiceRecording() {
    if (mediaRecorder.current?.state === "recording") mediaRecorder.current.stop();
  }

  async function send() {
    const body = draft.trim();
    if (!selected || (!body && !staged.length) || sending || tenant.role === "viewer") return;
    if (!navigator.onLine) {
      setError("You are offline. The message and attachments are saved here and have not been sent.");
      return;
    }
    setSending(true);
    setError("");
    try {
      const attachments = await Promise.all(staged.map((attachment) => attachment.kind === "location"
        ? Promise.resolve(attachment.attachment)
        : uploadOperationsMessageMedia({ roundsApiUrl, accessToken, tenantId: tenant.id, threadId: selected.id, attachment })));
      const response = await fetch(`${roundsApiUrl}/v1/operations/communications/${selected.id}/messages`, {
        method: "POST",
        headers: {
          authorization: `Bearer ${accessToken}`,
          "content-type": "application/json",
          "idempotency-key": `operations:${selected.id}:${crypto.randomUUID()}`,
          "x-rounds-tenant-id": tenant.id,
          "x-trace-id": crypto.randomUUID(),
        },
        body: JSON.stringify({ body, attachments }),
      });
      const result = await response.json() as SendOperationsMessageResult | ApiError;
      if (!response.ok || !("status" in result) || result.status !== "committed") {
        throw new Error(messageFrom(result as ApiError, `Reply HTTP ${response.status}`));
      }
      setDraft("");
      window.localStorage.removeItem(draftKey(tenant.id, selected.id));
      await clearStagedAttachments(staged);
      setStaged([]);
      await load(true);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Reply could not be sent");
      await load(true);
    } finally {
      setSending(false);
    }
  }

  function onComposerKeyDown(event: KeyboardEvent<HTMLTextAreaElement>) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      void send();
    }
  }

  function onComposerPaste(event: ClipboardEvent<HTMLTextAreaElement>) {
    const images = Array.from(event.clipboardData.items)
      .filter((item) => item.kind === "file" && item.type.startsWith("image/"))
      .flatMap((item) => item.getAsFile() ? [item.getAsFile()!] : []);
    if (images.length) {
      event.preventDefault();
      void stageFiles(images);
    }
  }

  function onDrop(event: DragEvent<HTMLElement>) {
    event.preventDefault();
    setDragActive(false);
    const files = Array.from(event.dataTransfer.files);
    if (files.length) {
      void stageFiles(files);
      return;
    }
    const url = event.dataTransfer.getData("text/uri-list").trim();
    if (url) updateDraft(draft ? `${draft}\n${url}` : url);
  }

  return <div className="communications-workspace">
    <section className="page-heading communications-heading">
      <div><p className="eyebrow">DRIVER SUPPORT</p><h1>Communications</h1><p>Durable messages attached to the active Round and Stop.</p></div>
      <button type="button" className="history-refresh" onClick={() => void load()}>Refresh</button>
    </section>
    {error && <div className="alert error" role="alert"><div><strong>Couldn&apos;t continue</strong><span>{error}</span></div></div>}
    {loading ? <section className="dispatch-loading"><span /><p>Loading driver conversations…</p></section> : !projection?.threads.length ? <section className="history-empty"><div>↔</div><h2>No driver conversations yet</h2><p>A conversation appears when a Team driver opens Contact Operations during an active Round.</p></section> : <section className="communications-frame">
      <aside className="thread-list" aria-label="Driver conversations">
        <div className="thread-list-title"><strong>Active threads</strong><span>{projection.threads.length}</span></div>
        {projection.threads.map((thread) => {
          const last = thread.messages.at(-1);
          return <button type="button" key={thread.id} className={`${thread.id === selectedThreadId ? "thread-row selected" : "thread-row"}${thread.priority === "emergency" ? " emergency" : ""}`} onClick={() => setSelectedThreadId(thread.id)}>
            <span className="driver-avatar">{thread.driverName.slice(0, 1).toUpperCase()}</span>
            <span className="thread-copy"><strong>{thread.priority === "emergency" ? "EMERGENCY · " : ""}{thread.driverName}</strong><small>{thread.roundReference} · Stop {thread.stopSequence}</small><em>{messageSummary(last)}</em></span>
            <time>{last ? timeLabel(last.sentAt, tenant.timezone) : ""}</time>
          </button>;
        })}
      </aside>
      {selected && <article className={`conversation-card${dragActive ? " drop-active" : ""}`} onDragEnter={(event) => { event.preventDefault(); setDragActive(true); }} onDragOver={(event) => event.preventDefault()} onDragLeave={(event) => { if (!event.currentTarget.contains(event.relatedTarget as Node | null)) setDragActive(false); }} onDrop={onDrop}>
        {dragActive && <div className="communications-drop-target"><strong>Drop to stage for {selected.driverName}</strong><span>Photos and files wait for review before Send.</span></div>}
        <header className="conversation-header">
          <span className="driver-avatar large">{selected.driverName.slice(0, 1).toUpperCase()}</span>
          <div><p className="eyebrow">{selected.priority === "emergency" ? "DRIVER EMERGENCY · PRIORITY" : "TEAM DRIVER · ACTIVE ROUND"}</p><h2>{selected.driverName}</h2><span>{selected.roundReference} · Stop {selected.stopSequence} · {selected.deliveryReference}</span></div>
          <span className={`live-pill ${selected.priority === "emergency" ? "emergency" : ""}`}><i /> {selected.priority === "emergency" ? "Emergency" : "Active"}</span>
        </header>
        <div className="conversation-context"><div><small>Recipient</small><strong>{selected.recipientName}</strong></div><div><small>Destination</small><strong>{selected.rawAddress}</strong></div></div>
        <div className="message-stream" aria-live="polite">
          {!selected.messages.length && <div className="message-empty">No messages in this thread yet.</div>}
          {selected.messages.map((message) => message.sender === "system" ? <div className="system-message" key={message.id}>{message.body}</div> : <div className={`message-row ${message.sender}`} key={message.id}>
            <div className="message-bubble">{message.body && <p>{message.body}</p>}<MessageAttachments message={message} /><time>{timeLabel(message.sentAt, tenant.timezone)}</time></div>
          </div>)}
        </div>
        <footer className="composer rich-composer">
          <input ref={photoInput} className="composer-file-input" type="file" accept="image/jpeg,image/png,image/webp" multiple onChange={(event) => { void stageFiles(Array.from(event.target.files ?? [])); event.target.value = ""; }} />
          <input ref={fileInput} className="composer-file-input" type="file" multiple onChange={(event) => { void stageFiles(Array.from(event.target.files ?? [])); event.target.value = ""; }} />
          {attachmentMenuOpen && <div className="composer-attachment-menu" role="menu">
            <button type="button" onClick={() => photoInput.current?.click()}>Photo</button>
            <button type="button" onClick={() => fileInput.current?.click()}>File</button>
            <button type="button" onClick={() => stageCurrentLocation("Dispatcher location")}>Location</button>
            <button type="button" onClick={stageMapContext}>Map context</button>
          </div>}
          {!!staged.length && <div className="staged-attachments"><header><strong>{staged.length} staged</strong><span>Review before Send</span></header>{staged.map((attachment) => <StagedAttachmentPreview key={attachment.localId} attachment={attachment} onRemove={() => void removeAttachment(attachment)} />)}</div>}
          {recording && <div className="voice-recording" role="status"><span /><strong>Recording voice note</strong><time>{Math.floor(recordingSeconds / 60)}:{String(recordingSeconds % 60).padStart(2, "0")}</time><button type="button" onClick={stopVoiceRecording}>Stop</button></div>}
          <div className="composer-row">
            <button className="composer-add" type="button" aria-label="Add attachment" aria-expanded={attachmentMenuOpen} onClick={() => setAttachmentMenuOpen((open) => !open)} disabled={tenant.role === "viewer"}>+</button>
            <textarea aria-label="Reply to driver" rows={2} maxLength={2000} value={draft} onChange={(event) => updateDraft(event.target.value)} onKeyDown={onComposerKeyDown} onPaste={onComposerPaste} disabled={tenant.role === "viewer" || recording} placeholder={tenant.role === "viewer" ? "Viewer access is read-only" : "Message the driver…"} />
            <button className={`composer-mic${recording ? " recording" : ""}`} type="button" aria-label={recording ? "Stop voice recording" : "Record voice note"} onClick={() => recording ? stopVoiceRecording() : void startVoiceRecording()} disabled={tenant.role === "viewer"}>◉</button>
            <button className="composer-send" type="button" onClick={() => void send()} disabled={(!draft.trim() && !staged.length) || sending || tenant.role === "viewer"}>{sending ? "Uploading…" : "Send"}</button>
          </div>
          <small>Drop files here · paste images or links · Enter to send · drafts stay on this browser</small>
        </footer>
      </article>}
    </section>}
  </div>;
}
