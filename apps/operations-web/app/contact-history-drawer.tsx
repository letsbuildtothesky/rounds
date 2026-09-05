"use client";

import { useMemo, useState } from "react";
import type { OperationsCommunicationThread } from "@rounds/contracts";
import {
  composeOperationsContactHistory,
  filterOperationsContactHistory,
  type OperationsContactHistoryEvent,
  type OperationsContactHistoryFilter,
} from "../src/operations-contact-history";

type Props = {
  thread: OperationsCommunicationThread;
  timezone: string;
  onClose: () => void;
  onMessage: (threadId: string) => void;
  onOpenRound: (roundId: string) => void;
};

const filterLabels: Record<OperationsContactHistoryFilter, string> = {
  all: "All",
  messages: "Messages",
  calls: "Calls",
  media: "Files & media",
};

function timeLabel(value: string, timezone: string): string {
  return new Intl.DateTimeFormat("en-GB", {
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
    timeZone: timezone,
  }).format(new Date(value));
}

function actorInitials(event: OperationsContactHistoryEvent): string {
  if (event.actorRole === "system") return "•";
  if (event.actorRole === "operations") return "D";
  return event.actor.split(/\s+/).map((part) => part[0]).join("").slice(0, 2).toUpperCase() || "DR";
}

export function ContactHistoryDrawer({ thread, timezone, onClose, onMessage, onOpenRound }: Props) {
  const [filter, setFilter] = useState<OperationsContactHistoryFilter>("all");
  const history = useMemo(() => composeOperationsContactHistory(thread), [thread]);
  const events = filterOperationsContactHistory(history.events, filter);

  return <aside className="v45-drawer v45-contact-history open" role="dialog" aria-modal="false" aria-labelledby="v45-contact-history-title">
    <header>
      <div><small>{thread.recipientName}</small><h2 id="v45-contact-history-title">Contact history</h2><p>#{thread.deliveryReference} · communication audit</p></div>
      <button type="button" onClick={onClose} aria-label="Close contact history"><CloseIcon /></button>
    </header>
    <div className="v45-drawer-body">
      <div className="v45-contact-presence"><span>{thread.driverName.slice(0, 2).toUpperCase()}</span><div><b>{thread.driverName}</b><small>{thread.roundReference} · Stop {thread.stopSequence}</small></div><em><i />Active Round</em></div>
      <div className="v45-contact-summary">
        <div><span>Messages</span><b>{history.counts.messages}</b></div>
        <div><span>Calls</span><b>{history.counts.calls}</b></div>
        <div><span>Files & media</span><b>{history.counts.media}</b></div>
      </div>
      <nav className="v45-contact-tabs" aria-label="Contact history filters">
        {(Object.keys(filterLabels) as OperationsContactHistoryFilter[]).map((item) => <button type="button" key={item} className={filter === item ? "on" : ""} aria-pressed={filter === item} onClick={() => setFilter(item)}>{filterLabels[item]}</button>)}
      </nav>
      <section className="v45-contact-ledger">
        <header><b>Communication ledger</b><span>{events.length} event{events.length === 1 ? "" : "s"}</span></header>
        {events.length ? events.map((event) => <article className="v45-contact-row" key={event.id}>
          <time dateTime={event.occurredAt}>{timeLabel(event.occurredAt, timezone)}</time>
          <span className={`v45-contact-avatar ${event.actorRole}`}>{actorInitials(event)}</span>
          <div><header><b>{event.type}</b><span>{event.status}</span></header><strong>{event.title}</strong><p>{event.detail}</p></div>
        </article>) : <div className="v45-contact-empty">No communication events in this view.</div>}
      </section>
      <div className="v45-contact-actions"><button className="primary" type="button" onClick={() => onMessage(thread.id)}>Message driver</button><button type="button" disabled title="In-app calling is not connected yet">Call driver</button><button type="button" onClick={() => onOpenRound(thread.roundId)}>Back to Round</button></div>
    </div>
  </aside>;
}

function CloseIcon() {
  return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18" /></svg>;
}
