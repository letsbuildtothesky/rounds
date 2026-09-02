"use client";

import { useCallback, useEffect, useMemo, useState, type KeyboardEvent } from "react";
import type {
  OperationsCommunicationsProjection,
  OperationsTenant,
  SendOperationsMessageResult,
} from "@rounds/contracts";

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

export function CommunicationsPanel({ accessToken, tenant, initialThreadId = "" }: Props) {
  const [projection, setProjection] = useState<OperationsCommunicationsProjection | null>(null);
  const [selectedThreadId, setSelectedThreadId] = useState("");
  const [draft, setDraft] = useState("");
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");

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

  async function send() {
    const body = draft.trim();
    if (!selected || !body || sending || tenant.role === "viewer") return;
    setSending(true);
    setError("");
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/communications/${selected.id}/messages`, {
        method: "POST",
        headers: {
          authorization: `Bearer ${accessToken}`,
          "content-type": "application/json",
          "idempotency-key": `operations:${selected.id}:${crypto.randomUUID()}`,
          "x-rounds-tenant-id": tenant.id,
          "x-trace-id": crypto.randomUUID(),
        },
        body: JSON.stringify({ body }),
      });
      const result = await response.json() as SendOperationsMessageResult | ApiError;
      if (!response.ok || !("status" in result) || result.status !== "committed") {
        throw new Error(messageFrom(result as ApiError, `Reply HTTP ${response.status}`));
      }
      setDraft("");
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
          return <button type="button" key={thread.id} className={thread.id === selectedThreadId ? "thread-row selected" : "thread-row"} onClick={() => setSelectedThreadId(thread.id)}>
            <span className="driver-avatar">{thread.driverName.slice(0, 1).toUpperCase()}</span>
            <span className="thread-copy"><strong>{thread.driverName}</strong><small>{thread.roundReference} · Stop {thread.stopSequence}</small><em>{last?.body ?? "No messages yet"}</em></span>
            <time>{last ? timeLabel(last.sentAt, tenant.timezone) : ""}</time>
          </button>;
        })}
      </aside>
      {selected && <article className="conversation-card">
        <header className="conversation-header">
          <span className="driver-avatar large">{selected.driverName.slice(0, 1).toUpperCase()}</span>
          <div><p className="eyebrow">TEAM DRIVER · ACTIVE ROUND</p><h2>{selected.driverName}</h2><span>{selected.roundReference} · Stop {selected.stopSequence} · {selected.deliveryReference}</span></div>
          <span className="live-pill"><i /> Active</span>
        </header>
        <div className="conversation-context"><div><small>Recipient</small><strong>{selected.recipientName}</strong></div><div><small>Destination</small><strong>{selected.rawAddress}</strong></div></div>
        <div className="message-stream" aria-live="polite">
          {!selected.messages.length && <div className="message-empty">No messages in this thread yet.</div>}
          {selected.messages.map((message) => message.sender === "system" ? <div className="system-message" key={message.id}>{message.body}</div> : <div className={`message-row ${message.sender}`} key={message.id}>
            <div className="message-bubble"><p>{message.body}</p><time>{timeLabel(message.sentAt, tenant.timezone)}</time></div>
          </div>)}
        </div>
        <footer className="composer">
          <textarea aria-label="Reply to driver" rows={2} maxLength={2000} value={draft} onChange={(event) => setDraft(event.target.value)} onKeyDown={onComposerKeyDown} disabled={tenant.role === "viewer"} placeholder={tenant.role === "viewer" ? "Viewer access is read-only" : "Message the driver…"} />
          <button type="button" onClick={() => void send()} disabled={!draft.trim() || sending || tenant.role === "viewer"}>{sending ? "Sending…" : "Send"}</button>
          <small>Enter to send · Shift+Enter for a new line</small>
        </footer>
      </article>}
    </section>}
  </div>;
}
