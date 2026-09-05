"use client";

import { useEffect, useMemo, useRef, useState, type ClipboardEvent, type DragEvent, type KeyboardEvent } from "react";
import type {
  DriverThreadMessage,
  MessageLocationAttachment,
  MessageMediaAttachment,
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
import type { OperationsCommunicationsStore } from "./use-operations-communications";

const roundsApiUrl = process.env.NEXT_PUBLIC_ROUNDS_API_URL ?? "http://127.0.0.1:8080";
type Props = {
  accessToken: string;
  tenant: OperationsTenant;
  communications: OperationsCommunicationsStore;
  request?: { threadId: string; nonce: number; startVoice?: boolean };
  drawerOpen?: boolean;
  onContactHistory: (threadId: string) => void;
  onOpenRound: (roundId: string) => void;
};
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

function attachmentSizeLabel(bytes: number): string {
  return bytes >= 1048576
    ? `${(bytes / 1048576).toFixed(1)} MB`
    : `${Math.max(1, Math.ceil(bytes / 1024))} KB`;
}

function attachmentDurationLabel(milliseconds: number): string {
  const seconds = Math.max(0, Math.ceil(milliseconds / 1000));
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
}

function VoiceMessageAttachment({ attachment }: { attachment: MessageMediaAttachment }) {
  const latestUrl = useRef(attachment.downloadUrl);
  const audio = useRef<HTMLAudioElement | null>(null);
  const [playing, setPlaying] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    latestUrl.current = attachment.downloadUrl;
  }, [attachment.downloadUrl]);

  useEffect(() => () => {
    if (!audio.current) return;
    audio.current.pause();
    audio.current.removeAttribute("src");
    audio.current.load();
  }, []);

  async function togglePlayback() {
    if (!latestUrl.current) {
      setError("Voice note unavailable");
      return;
    }
    const player = audio.current ?? new Audio(latestUrl.current);
    if (!audio.current) {
      player.preload = "metadata";
      player.onplay = () => setPlaying(true);
      player.onpause = () => setPlaying(false);
      player.onended = () => setPlaying(false);
      player.onerror = () => {
        setPlaying(false);
        setError("Voice note could not be played");
      };
      audio.current = player;
    }
    setError("");
    try {
      if (player.paused) {
        if (player.ended) player.currentTime = 0;
        await player.play();
      } else {
        player.pause();
      }
    } catch {
      setPlaying(false);
      setError("Voice note could not be played");
    }
  }

  return <div className="v45-comms-voice-card">
    <button type="button" className="v45-comms-voice-play" onClick={() => void togglePlayback()} disabled={!attachment.downloadUrl} aria-label={playing ? "Pause voice note" : "Play voice note"}>{playing ? "Ⅱ" : "▶"}</button>
    <span className="v45-comms-voice-wave" aria-hidden="true">{Array.from({ length: 12 }, (_, index) => <i key={index} />)}</span>
    <time>{attachmentDurationLabel(attachment.durationMilliseconds ?? 0)}</time>
    {error && <small role="status">{error}</small>}
  </div>;
}

function PhotoMessageAttachment({ attachment }: { attachment: MessageMediaAttachment }) {
  const [source, setSource] = useState(attachment.downloadUrl ?? "");
  useEffect(() => {
    setSource((current) => current || attachment.downloadUrl || "");
  }, [attachment.downloadUrl]);
  return <div className="v45-comms-media-card">
    <div className="v45-comms-media-photo">
      {source
        ? <img src={source} alt={attachment.fileName} onError={() => setSource(attachment.downloadUrl !== source ? attachment.downloadUrl ?? "" : "")} />
        : <span>Photo unavailable</span>}
    </div>
    <div className="v45-comms-media-copy"><small>PHOTO</small><strong>{attachment.fileName}</strong><span>{attachmentSizeLabel(attachment.byteSize)}</span></div>
  </div>;
}

function FileMessageAttachment({ attachment }: { attachment: MessageMediaAttachment }) {
  const latestUrl = useRef(attachment.downloadUrl);
  const [opening, setOpening] = useState(false);
  const [error, setError] = useState("");
  useEffect(() => {
    latestUrl.current = attachment.downloadUrl;
  }, [attachment.downloadUrl]);

  async function openFile() {
    const url = latestUrl.current;
    if (!url || opening) return;
    const viewer = window.open("about:blank", "_blank");
    if (!viewer) {
      setError("File could not be opened");
      return;
    }
    viewer.opener = null;
    setOpening(true);
    setError("");
    try {
      const response = await fetch(url);
      if (!response.ok) throw new Error(`File HTTP ${response.status}`);
      const objectUrl = URL.createObjectURL(await response.blob());
      viewer.location.replace(objectUrl);
      window.setTimeout(() => URL.revokeObjectURL(objectUrl), 60_000);
    } catch {
      viewer.close();
      setError("File could not be opened");
    } finally {
      setOpening(false);
    }
  }

  return <div className="v45-comms-media-card">
    <div className="v45-comms-media-file" aria-hidden="true">↗</div>
    <div className="v45-comms-media-copy"><small>FILE</small><strong>{attachment.fileName}</strong><span>{error || attachmentSizeLabel(attachment.byteSize)}</span></div>
    <button type="button" className="v45-comms-media-action" onClick={() => void openFile()} disabled={!attachment.downloadUrl || opening}>{opening ? "Opening…" : "Open file"}</button>
  </div>;
}

function MessageAttachments({ message }: { message: DriverThreadMessage }) {
  return <>{message.attachments?.map((attachment, index) => {
    if (attachment.kind === "location") {
      const coordinates = `${attachment.latitude},${attachment.longitude}`;
      const href = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(coordinates)}`;
      return <a className="v45-comms-attachment" href={href} target="_blank" rel="noreferrer" key={`${attachment.kind}:${attachment.capturedAt}:${index}`}>
        <span aria-hidden="true">⌖</span>
        <span><strong>{attachment.label}</strong><small>{attachment.latitude.toFixed(4)}, {attachment.longitude.toFixed(4)}</small></span>
        <i aria-hidden="true">›</i>
      </a>;
    }
    const key = `${attachment.kind}:${attachment.mediaAssetId}:${index}`;
    if (attachment.kind === "voice") return <VoiceMessageAttachment attachment={attachment} key={key} />;
    if (attachment.kind === "image") return <PhotoMessageAttachment attachment={attachment} key={key} />;
    return <FileMessageAttachment attachment={attachment} key={key} />;
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
  return <div className="v45-comms-staged-row">
    <span className="v45-comms-staged-mark" aria-hidden="true">
      {attachment.kind === "image" && previewUrl ? <img src={previewUrl} alt="" /> : attachment.kind === "location" ? "⌖" : attachment.kind === "voice" ? "●" : "DOC"}
    </span>
    <span className="v45-comms-staged-copy"><strong>{label}</strong><small>{detail}</small>{attachment.kind === "voice" && previewUrl && <audio src={previewUrl} controls preload="metadata" />}</span>
    <button type="button" onClick={onRemove} aria-label={`Remove ${label}`}>×</button>
  </div>;
}

export function CommunicationsPanel({ accessToken, tenant, communications, request, drawerOpen = false, onContactHistory, onOpenRound }: Props) {
  const { projection, loading, error: loadError, refresh, markRead } = communications;
  const [selectedThreadId, setSelectedThreadId] = useState("");
  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");
  const [staged, setStaged] = useState<StagedOperationsAttachment[]>([]);
  const [attachmentMenuOpen, setAttachmentMenuOpen] = useState(false);
  const [dragActive, setDragActive] = useState(false);
  const [recording, setRecording] = useState(false);
  const [recordingSeconds, setRecordingSeconds] = useState(0);
  const [expanded, setExpanded] = useState(false);
  const [activeThreadIds, setActiveThreadIds] = useState<string[]>([]);
  const photoInput = useRef<HTMLInputElement>(null);
  const fileInput = useRef<HTMLInputElement>(null);
  const mediaRecorder = useRef<MediaRecorder | null>(null);
  const recordingChunks = useRef<Blob[]>([]);
  const recordingStartedAt = useRef(0);
  const handledRequest = useRef(0);
  const handledVoiceRequest = useRef(0);

  useEffect(() => {
    if (!projection) return;
    setSelectedThreadId((current) => projection.threads.some((thread) => thread.id === current)
      ? current
      : projection.threads[0]?.id ?? "");
    const unreadThreadIds = projection.threads.filter((thread) => thread.unreadCount > 0).map((thread) => thread.id);
    setActiveThreadIds((current) => [...current, ...unreadThreadIds.filter((threadId) => !current.includes(threadId))]);
  }, [projection]);

  const selected = useMemo(
    () => projection?.threads.find((thread) => thread.id === selectedThreadId) ?? null,
    [projection, selectedThreadId],
  );

  useEffect(() => {
    if (expanded && selected?.unreadCount) void markRead(selected.id);
  }, [expanded, markRead, selected]);

  useEffect(() => {
    if (!projection || !request?.nonce || request.nonce <= handledRequest.current) return;
    handledRequest.current = request.nonce;
    setExpanded(true);
    if (!projection.threads.length) {
      setSelectedThreadId("");
      return;
    }
    const threadId = projection.threads.some((thread) => thread.id === request.threadId)
      ? request.threadId
      : projection.threads.some((thread) => thread.id === selectedThreadId)
        ? selectedThreadId
        : projection.threads[0]!.id;
    setSelectedThreadId(threadId);
    setActiveThreadIds((current) => current.includes(threadId) ? current : [...current, threadId]);
  }, [projection, request?.nonce, request?.threadId, selectedThreadId]);

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

  useEffect(() => {
    if (!request?.startVoice || request.nonce <= handledVoiceRequest.current || !expanded || !selectedThreadId || recording) return;
    if (request.threadId && request.threadId !== selectedThreadId) return;
    handledVoiceRequest.current = request.nonce;
    const timer = window.setTimeout(() => void startVoiceRecording(), 0);
    return () => window.clearTimeout(timer);
  }, [expanded, recording, request?.nonce, request?.startVoice, request?.threadId, selectedThreadId]);

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
      await refresh(true);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Reply could not be sent");
      await refresh(true);
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

  const activeThreads = activeThreadIds
    .map((threadId) => projection?.threads.find((thread) => thread.id === threadId))
    .filter((thread): thread is NonNullable<typeof thread> => Boolean(thread));

  function activateThread(threadId: string) {
    setSelectedThreadId(threadId);
    setActiveThreadIds((current) => current.includes(threadId) ? current : [...current, threadId]);
    setExpanded(true);
  }

  function closeSelectedThread() {
    if (!selectedThreadId) {
      setExpanded(false);
      return;
    }
    const remaining = activeThreadIds.filter((threadId) => threadId !== selectedThreadId);
    setActiveThreadIds(remaining);
    if (remaining.length) setSelectedThreadId(remaining.at(-1)!);
    else setExpanded(false);
  }

  return <>
    {expanded && <aside className={`v45-comms-widget${drawerOpen ? " beside-drawer" : ""}${dragActive ? " drop-active" : ""}`} aria-label="Driver communication" onDragEnter={(event) => { event.preventDefault(); setDragActive(true); }} onDragOver={(event) => event.preventDefault()} onDragLeave={(event) => { if (!event.currentTarget.contains(event.relatedTarget as Node | null)) setDragActive(false); }} onDrop={onDrop}>
      {dragActive && selected && <div className="v45-comms-drop-overlay"><strong>Drop to send to {selected.driverName}</strong><span>Photos and files are staged first for review.</span></div>}
      <header className="v45-comms-head">
        <span className={`v45-comms-avatar${selected?.priority === "emergency" ? " emergency" : ""}`}>{selected?.driverName.slice(0, 2).toUpperCase() || "DR"}</span>
        <span className="v45-comms-title"><strong>{selected?.driverName ?? (loading ? "Loading conversations…" : "Driver communications")}</strong><small>{selected ? `Own driver · ${selected.roundReference}` : "No active driver thread"}</small></span>
        {selected && <span className={`v45-comms-presence${selected.priority === "emergency" ? " emergency" : ""}`}><i />{selected.priority === "emergency" ? "Emergency" : "Active Round"}</span>}
        <span className="v45-comms-head-actions">
          <button type="button" className="call" disabled title="In-app calling is not connected yet" aria-label="Call driver"><CallIcon /></button>
          <button type="button" onClick={() => setExpanded(false)} title="Minimize" aria-label="Minimize">−</button>
          <button type="button" onClick={closeSelectedThread} title="Close" aria-label="Close">×</button>
        </span>
      </header>

      {selected && <div className="v45-comms-context">
        <span><strong>{selected.roundReference}</strong><small>#{selected.deliveryReference} · {selected.recipientName}</small></span>
        <span><button type="button" onClick={() => onContactHistory(selected.id)}>Contact history</button><button type="button" onClick={() => onOpenRound(selected.roundId)}>Open Round</button></span>
      </div>}

      {(error || loadError) && <div className="v45-comms-error" role="alert"><strong>Couldn&apos;t continue</strong><span>{error || loadError}</span><button type="button" onClick={() => { setError(""); void refresh(); }}>Retry</button></div>}

      <div className="v45-comms-thread" aria-live="polite">
        {loading ? <div className="v45-comms-empty">Loading driver conversations…</div> : !projection?.threads.length ? <div className="v45-comms-empty"><strong>No driver conversations yet</strong><span>A thread appears when a Team driver opens Contact Operations during an active Round.</span></div> : selected && !selected.messages.length ? <div className="v45-comms-empty">No messages in this thread yet.</div> : selected?.messages.map((message) => message.sender === "system" ? <div className="v45-comms-event" key={message.id}><span>{message.body} · {timeLabel(message.sentAt, tenant.timezone)}</span></div> : <div className={`v45-comms-message ${message.sender}`} key={message.id}>
          <div className="v45-comms-bubble">{message.body && <p>{message.body}</p>}<MessageAttachments message={message} /></div><div className="v45-comms-message-meta">{timeLabel(message.sentAt, tenant.timezone)}</div>
        </div>)}
      </div>

      {selected && <footer className="v45-comms-compose">
        <input ref={photoInput} className="v45-comms-file-input" type="file" accept="image/jpeg,image/png,image/webp" multiple onChange={(event) => { void stageFiles(Array.from(event.target.files ?? [])); event.target.value = ""; }} />
        <input ref={fileInput} className="v45-comms-file-input" type="file" multiple onChange={(event) => { void stageFiles(Array.from(event.target.files ?? [])); event.target.value = ""; }} />
        {attachmentMenuOpen && <div className="v45-comms-attach-menu" role="menu"><button type="button" onClick={() => photoInput.current?.click()}>Photo</button><button type="button" onClick={() => fileInput.current?.click()}>File</button><button type="button" onClick={() => stageCurrentLocation("Dispatcher location")}>Location</button><button type="button" onClick={stageMapContext}>Map context</button></div>}
        {!!staged.length && <div className="v45-comms-staged"><header><strong>{staged.length} attachment{staged.length === 1 ? "" : "s"} ready</strong><span>Add a message or Send</span></header>{staged.map((attachment) => <StagedAttachmentPreview key={attachment.localId} attachment={attachment} onRemove={() => void removeAttachment(attachment)} />)}</div>}
        {recording && <div className="v45-comms-recording" role="status"><span /><strong>Recording voice note</strong><i className="v45-comms-wave" aria-hidden="true">||||||||</i><time>{Math.floor(recordingSeconds / 60)}:{String(recordingSeconds % 60).padStart(2, "0")}</time><button type="button" onClick={stopVoiceRecording}>Stop</button></div>}
        <div className="v45-comms-compose-row">
          <button className="attach" type="button" aria-label="Add attachment" aria-expanded={attachmentMenuOpen} onClick={() => setAttachmentMenuOpen((open) => !open)} disabled={tenant.role === "viewer"}>+</button>
          <textarea aria-label="Message driver" rows={1} maxLength={2000} value={draft} onChange={(event) => updateDraft(event.target.value)} onKeyDown={onComposerKeyDown} onPaste={onComposerPaste} disabled={tenant.role === "viewer" || recording} placeholder={tenant.role === "viewer" ? "Viewer access is read-only" : "Message driver…"} />
          <button className={`mic${recording ? " recording" : ""}`} type="button" aria-label={recording ? "Stop voice recording" : "Record voice note"} onClick={() => recording ? stopVoiceRecording() : void startVoiceRecording()} disabled={tenant.role === "viewer"}><MicIcon /></button>
          <button className="send" type="button" onClick={() => void send()} disabled={(!draft.trim() && !staged.length) || sending || tenant.role === "viewer"} aria-label="Send message"><SendIcon /></button>
        </div>
        <div className="v45-comms-compose-hint"><span>Drop files or links here · paste images or links · Enter to send</span><span>#{selected.deliveryReference}</span></div>
      </footer>}
    </aside>}

    {!!activeThreads.length && <div className="v45-comms-tray" aria-label="Active driver conversations">
      {activeThreads.slice(-4).map((thread) => <button type="button" key={thread.id} className={`${thread.id === selectedThreadId && expanded ? "active" : ""}${thread.unreadCount ? " unread" : ""}`} onClick={() => activateThread(thread.id)}><span className="v45-comms-tray-avatar">{thread.driverName.slice(0, 2).toUpperCase()}</span><span><strong>{thread.driverName}</strong><small>{messageSummary(thread.messages.at(-1))}</small></span>{thread.priority === "emergency" ? <i className="emergency">!</i> : thread.unreadCount ? <i className={thread.hasUnreadVoice ? "voice" : ""} title={thread.hasUnreadVoice ? "Unread voice message" : `${thread.unreadCount} unread`}>{thread.hasUnreadVoice ? "●" : thread.unreadCount}</i> : null}</button>)}
      {activeThreads.length > 4 && <span className="v45-comms-tray-overflow">+{activeThreads.length - 4}</span>}
    </div>}
  </>;
}

function CallIcon() {
  return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 4h3l1.2 4-2 1.2a15 15 0 0 0 5.6 5.6l1.2-2L20 14v3c0 1.1-.9 2-2 2C10.8 19 5 13.2 5 6c0-1.1.9-2 2-2Z" /></svg>;
}

function MicIcon() {
  return <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="9" y="3" width="6" height="11" rx="3" /><path d="M5.5 10.5a6.5 6.5 0 0 0 13 0M12 17v4M8.5 21h7" /></svg>;
}

function SendIcon() {
  return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m5 12 14-7-4 14-3-6-7-1Z" /><path d="m12 13 7-8" /></svg>;
}
