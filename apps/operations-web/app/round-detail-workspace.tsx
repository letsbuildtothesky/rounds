"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import type { OperationsRoundDetail, OperationsRoundStopDetail, OperationsTenant } from "@rounds/contracts";

const roundsApiUrl = process.env.NEXT_PUBLIC_ROUNDS_API_URL ?? "http://127.0.0.1:8080";
type ApiError = { error?: { message?: string } };

function time(value: string, timezone: string): string {
  return new Intl.DateTimeFormat("en-GB", { hour: "2-digit", minute: "2-digit", timeZone: timezone }).format(new Date(value));
}

function dateTime(value: string, timezone: string): string {
  return new Intl.DateTimeFormat("en-GB", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit", timeZone: timezone }).format(new Date(value));
}

function label(value: string): string {
  return value.replaceAll("_", " ").replace(/^./, (character) => character.toUpperCase());
}

export function RoundDetailWorkspace({ accessToken, tenant, roundId, onClose, onCommunications }: {
  accessToken: string;
  tenant: OperationsTenant;
  roundId: string;
  onClose: () => void;
  onCommunications: (threadId?: string) => void;
}) {
  const [detail, setDetail] = useState<OperationsRoundDetail | null>(null);
  const [selectedStopId, setSelectedStopId] = useState("");
  const [mobileListOpen, setMobileListOpen] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/rounds/${roundId}`, {
        headers: { authorization: `Bearer ${accessToken}`, "x-rounds-tenant-id": tenant.id, "x-trace-id": crypto.randomUUID() },
      });
      const body = await response.json() as OperationsRoundDetail | ApiError;
      if (!response.ok) throw new Error((body as ApiError).error?.message ?? `Round HTTP ${response.status}`);
      const next = body as OperationsRoundDetail;
      setDetail(next);
      setSelectedStopId((current) => next.stops.some((stop) => stop.stopId === current) ? current : next.stops[0]?.stopId ?? "");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Round details could not be loaded");
    } finally {
      setLoading(false);
    }
  }, [accessToken, roundId, tenant.id]);

  useEffect(() => { void load(); }, [load]);

  const selected = useMemo(() => detail?.stops.find((stop) => stop.stopId === selectedStopId), [detail, selectedStopId]);

  return <section className="v45-round-workspace" aria-label="Round details workspace">
    <header className="v45-round-head">
      <div><button type="button" onClick={onClose}><BackIcon />Dispatch</button><p>ROUND EXECUTION TRUTH</p><h1>{detail?.reference ?? "Round details"}</h1><span>{detail ? `${detail.driver.displayName} · ${detail.serviceDate}` : "Loading assignment"}</span></div>
      <div>{detail && <b className={`state-${detail.state}`}>{label(detail.state)}</b>}<small>{detail ? `Observed ${time(detail.observedAt, tenant.timezone)}` : "Connecting"}</small><button type="button" onClick={() => void load()}>Refresh</button></div>
    </header>
    {loading && !detail ? <div className="v45-round-message">Loading server-authoritative Round truth…</div> : error && !detail ? <div className="v45-round-message error"><b>Couldn&apos;t load this Round</b><span>{error}</span><button type="button" onClick={() => void load()}>Retry</button></div> : detail && <>
      <section className="v45-round-kpis"><div><small>ORDERED STOPS</small><b>{detail.stops.length}</b></div><div><small>IN CUSTODY</small><b>{detail.custodyStopCount}</b></div><div><small>NEEDS ACTION</small><b>{detail.openExceptionCount}</b></div><div><small>DRIVER POSITION</small><b>{detail.currentPosition ? time(detail.currentPosition.capturedAt, tenant.timezone) : "Not reported"}</b></div></section>
      {error && <div className="v45-round-stale" role="status">Refresh delayed · showing the last confirmed Round state.</div>}
      <div className="v45-round-body">
        <aside className={`v45-round-stop-list ${selected ? "has-selection" : ""} ${mobileListOpen ? "mobile-list-open" : ""}`}>
          <div className="v45-round-assignment"><small>ASSIGNMENT</small><b>{detail.driver.displayName}</b><span>{[detail.driver.vehicleLabel, detail.driver.vehiclePlate].filter(Boolean).join(" · ") || "Team driver"}</span><em>Pickup · {detail.pickup.displayName}</em></div>
          <div className="v45-round-stop-scroll">{detail.stops.length === 0 ? <div className="v45-round-message"><b>No Stops in this Round</b><span>The approved sequence is empty.</span></div> : detail.stops.map((stop) => <StopRow key={stop.stopId} stop={stop} timezone={tenant.timezone} selected={stop.stopId === selectedStopId} onSelect={() => { setSelectedStopId(stop.stopId); setMobileListOpen(false); }} />)}</div>
        </aside>
        <main className={`v45-round-stop-detail ${selected && !mobileListOpen ? "open" : ""}`}>{selected ? <StopDetail stop={selected} timezone={tenant.timezone} onBack={() => setMobileListOpen(true)} onCommunications={onCommunications} /> : <div className="v45-round-message"><RouteIcon /><b>Select a Stop</b><span>Inspect the exact visit, custody and manifest state.</span></div>}</main>
      </div>
    </>}
  </section>;
}

function StopRow({ stop, timezone, selected, onSelect }: { stop: OperationsRoundStopDetail; timezone: string; selected: boolean; onSelect: () => void }) {
  return <button type="button" className={`v45-round-stop-row ${selected ? "selected" : ""} ${stop.openExceptionCount ? "action" : ""}`} onClick={onSelect}>
    <b className="sequence">{String(stop.sequence).padStart(2, "0")}</b><span><strong>{stop.recipientName}</strong><small>{stop.rawAddress}</small><em>{time(stop.windowStart, timezone)}–{time(stop.windowEnd, timezone)} · #{stop.deliveryReference}</em></span><span className="truth"><b>{label(stop.stopState)}</b><small>{stop.openExceptionCount ? `${stop.openExceptionCount} action` : stop.pickupConfirmed ? "In custody" : "Awaiting pickup"}</small></span>
  </button>;
}

function StopDetail({ stop, timezone, onBack, onCommunications }: { stop: OperationsRoundStopDetail; timezone: string; onBack: () => void; onCommunications: (threadId?: string) => void }) {
  return <div className="v45-round-stop-detail-scroll">
    <header><button type="button" onClick={onBack}><BackIcon />All Stops</button><div><p>STOP {stop.sequence} · #{stop.deliveryReference}</p><h2>{stop.recipientName}</h2><span>{stop.rawAddress}</span></div><b className={stop.openExceptionCount ? "action" : ""}>{stop.openExceptionCount ? "Needs action" : label(stop.stopState)}</b></header>
    <section className="v45-round-stop-kpis"><div><small>PROMISE</small><b>{time(stop.windowStart, timezone)}–{time(stop.windowEnd, timezone)}</b></div><div><small>CUSTODY</small><b>{stop.pickupConfirmed ? "Confirmed" : "Not transferred"}</b></div><div><small>STOP VERSION</small><b>{stop.stopVersion}</b></div><div><small>EXCEPTIONS</small><b>{stop.openExceptionCount}</b></div></section>
    <div className="v45-round-stop-grid">
      <section><h3>Visit truth <span>canonical</span></h3><dl><div><dt>Recipient</dt><dd>{stop.recipientName}<small>{stop.recipientPhone}</small></dd></div><div><dt>Destination</dt><dd>{stop.rawAddress}</dd></div><div><dt>Destination pin</dt><dd>{stop.coordinate ? `${stop.coordinate.latitude.toFixed(5)}, ${stop.coordinate.longitude.toFixed(5)}` : "Unavailable"}</dd></div><div><dt>Delivery state</dt><dd>{label(stop.deliveryState)}</dd></div></dl></section>
      <section><h3>Execution evidence <span>live state</span></h3><dl><div><dt>Pickup</dt><dd>{stop.pickupConfirmed ? "Manifest confirmed" : "Awaiting confirmation"}</dd></div><div><dt>Arrived</dt><dd>{stop.arrivedAt ? dateTime(stop.arrivedAt, timezone) : "Not recorded"}</dd></div><div><dt>Completed</dt><dd>{stop.completedAt ? dateTime(stop.completedAt, timezone) : "Not recorded"}</dd></div><div><dt>Operations thread</dt><dd>{stop.operationsThreadId ? "Available" : "Not opened"}</dd></div></dl></section>
    </div>
    <section className="v45-round-manifest"><h3>Physical manifest <span>Version {stop.manifest.version} · {label(stop.manifest.state)}</span></h3>{stop.manifest.items.map((item) => <article key={item.lineNumber}><b>{String(item.lineNumber).padStart(2, "0")}</b><span><strong>{item.description}</strong>{item.handlingNote && <small>{item.handlingNote}</small>}</span><em>×{item.quantity}</em></article>)}</section>
    <div className="v45-round-actions">{stop.operationsThreadId ? <button type="button" className="primary" onClick={() => onCommunications(stop.operationsThreadId)}>Open Stop communications</button> : <button type="button" disabled>No Stop thread yet</button>}<button type="button" onClick={() => navigator.clipboard.writeText(stop.deliveryId)}>Copy delivery ID</button><button type="button" onClick={() => navigator.clipboard.writeText(stop.stopId)}>Copy Stop ID</button></div>
  </div>;
}

function BackIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m15 18-6-6 6-6"/></svg>; }
function RouteIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="6" cy="18" r="2"/><circle cx="18" cy="6" r="2"/><path d="M8 18h3a3 3 0 0 0 3-3V9a3 3 0 0 1 3-3"/></svg>; }
