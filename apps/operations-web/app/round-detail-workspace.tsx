"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import type { MoveRoundStopPreview, MoveRoundStopRequest, OperationsPlanningProjection, OperationsRoundDetail, OperationsRoundStopDetail, OperationsRoundSummary, OperationsTenant } from "@rounds/contracts";

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
  const [moveOpen, setMoveOpen] = useState(false);
  const [moveTargets, setMoveTargets] = useState<OperationsRoundSummary[]>([]);
  const [moveRequest, setMoveRequest] = useState<MoveRoundStopRequest | null>(null);
  const [movePreview, setMovePreview] = useState<MoveRoundStopPreview | null>(null);
  const [moveBusy, setMoveBusy] = useState(false);
  const [moveError, setMoveError] = useState("");

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

  const openMove = useCallback(async () => {
    if (!detail || !selected) return;
    setMoveOpen(true); setMoveBusy(true); setMoveError(""); setMovePreview(null); setMoveRequest(null);
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/planning`, { headers: { authorization: `Bearer ${accessToken}`, "x-rounds-tenant-id": tenant.id, "x-trace-id": crypto.randomUUID() } });
      const body = await response.json() as OperationsPlanningProjection | ApiError;
      if (!response.ok) throw new Error((body as ApiError).error?.message ?? `Planning HTTP ${response.status}`);
      setMoveTargets((body as OperationsPlanningProjection).activeRounds.filter((round) => round.id !== detail.id && round.state === "approved" && round.serviceDate === detail.serviceDate && round.custodyStopCount === 0));
    } catch (caught) { setMoveError(caught instanceof Error ? caught.message : "Destination Rounds could not be loaded"); }
    finally { setMoveBusy(false); }
  }, [accessToken, detail, selected, tenant.id]);

  const previewMove = useCallback(async (target: OperationsRoundSummary) => {
    if (!detail || !selected) return;
    setMoveBusy(true); setMoveError(""); setMovePreview(null);
    try {
      const detailResponse = await fetch(`${roundsApiUrl}/v1/operations/rounds/${target.id}`, { headers: { authorization: `Bearer ${accessToken}`, "x-rounds-tenant-id": tenant.id, "x-trace-id": crypto.randomUUID() } });
      const targetDetail = await detailResponse.json() as OperationsRoundDetail | ApiError;
      if (!detailResponse.ok) throw new Error((targetDetail as ApiError).error?.message ?? `Round HTTP ${detailResponse.status}`);
      const requestBody: MoveRoundStopRequest = { sourceRoundId: detail.id, targetRoundId: target.id, stopId: selected.stopId, sourceExpectedVersion: detail.version, targetExpectedVersion: (targetDetail as OperationsRoundDetail).version };
      const response = await fetch(`${roundsApiUrl}/v1/operations/rounds/move-preview`, {
        method: "POST", headers: { authorization: `Bearer ${accessToken}`, "content-type": "application/json", "x-rounds-tenant-id": tenant.id, "x-trace-id": crypto.randomUUID() }, body: JSON.stringify(requestBody),
      });
      const preview = await response.json() as MoveRoundStopPreview | ApiError;
      if (!response.ok) throw new Error((preview as ApiError).error?.message ?? `Preview HTTP ${response.status}`);
      setMoveRequest(requestBody); setMovePreview(preview as MoveRoundStopPreview);
    } catch (caught) { setMoveError(caught instanceof Error ? caught.message : "Move preview could not be calculated"); }
    finally { setMoveBusy(false); }
  }, [accessToken, detail, selected, tenant.id]);

  const confirmMove = useCallback(async () => {
    if (!moveRequest || !movePreview?.movable) return;
    setMoveBusy(true); setMoveError("");
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/rounds/move`, {
        method: "POST", headers: { authorization: `Bearer ${accessToken}`, "content-type": "application/json", "idempotency-key": crypto.randomUUID(), "x-rounds-tenant-id": tenant.id, "x-trace-id": crypto.randomUUID() }, body: JSON.stringify(moveRequest),
      });
      const result = await response.json() as { status?: string; state?: { sourceRoundRemoved?: boolean }; error?: { message?: string } };
      if (!response.ok || result.status !== "committed") throw new Error(result.error?.message ?? `Move HTTP ${response.status}`);
      setMoveOpen(false); setMovePreview(null); setMoveRequest(null);
      if (result.state?.sourceRoundRemoved) onClose(); else await load();
    } catch (caught) { setMoveError(caught instanceof Error ? caught.message : "Move could not be committed"); }
    finally { setMoveBusy(false); }
  }, [accessToken, load, movePreview, moveRequest, onClose, tenant.id]);

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
        <main className={`v45-round-stop-detail ${selected && !mobileListOpen ? "open" : ""}`}>{selected ? <StopDetail stop={selected} roundState={detail.state} timezone={tenant.timezone} onBack={() => setMobileListOpen(true)} onCommunications={onCommunications} onMove={() => void openMove()} /> : <div className="v45-round-message"><RouteIcon /><b>Select a Stop</b><span>Inspect the exact visit, custody and manifest state.</span></div>}</main>
      </div>
      {moveOpen && <MoveRoundSheet stop={selected!} targets={moveTargets} preview={movePreview} busy={moveBusy} error={moveError} timezone={tenant.timezone} onClose={() => setMoveOpen(false)} onChoose={(target) => void previewMove(target)} onBack={() => { setMovePreview(null); setMoveRequest(null); setMoveError(""); }} onConfirm={() => void confirmMove()} />}
    </>}
  </section>;
}

function StopRow({ stop, timezone, selected, onSelect }: { stop: OperationsRoundStopDetail; timezone: string; selected: boolean; onSelect: () => void }) {
  return <button type="button" className={`v45-round-stop-row ${selected ? "selected" : ""} ${stop.openExceptionCount ? "action" : ""}`} onClick={onSelect}>
    <b className="sequence">{String(stop.sequence).padStart(2, "0")}</b><span><strong>{stop.recipientName}</strong><small>{stop.rawAddress}</small><em>{time(stop.windowStart, timezone)}–{time(stop.windowEnd, timezone)} · #{stop.deliveryReference}</em></span><span className="truth"><b>{label(stop.stopState)}</b><small>{stop.openExceptionCount ? `${stop.openExceptionCount} action` : stop.pickupConfirmed ? "In custody" : "Awaiting pickup"}</small></span>
  </button>;
}

function StopDetail({ stop, roundState, timezone, onBack, onCommunications, onMove }: { stop: OperationsRoundStopDetail; roundState: string; timezone: string; onBack: () => void; onCommunications: (threadId?: string) => void; onMove: () => void }) {
  const movable = roundState === "approved" && stop.stopState === "assigned" && !stop.pickupConfirmed && !stop.arrivedAt && !stop.completedAt && stop.openExceptionCount === 0;
  return <div className="v45-round-stop-detail-scroll">
    <header><button type="button" onClick={onBack}><BackIcon />All Stops</button><div><p>STOP {stop.sequence} · #{stop.deliveryReference}</p><h2>{stop.recipientName}</h2><span>{stop.rawAddress}</span></div><b className={stop.openExceptionCount ? "action" : ""}>{stop.openExceptionCount ? "Needs action" : label(stop.stopState)}</b></header>
    <section className="v45-round-stop-kpis"><div><small>PROMISE</small><b>{time(stop.windowStart, timezone)}–{time(stop.windowEnd, timezone)}</b></div><div><small>CUSTODY</small><b>{stop.pickupConfirmed ? "Confirmed" : "Not transferred"}</b></div><div><small>STOP VERSION</small><b>{stop.stopVersion}</b></div><div><small>EXCEPTIONS</small><b>{stop.openExceptionCount}</b></div></section>
    <div className="v45-round-stop-grid">
      <section><h3>Visit truth <span>canonical</span></h3><dl><div><dt>Recipient</dt><dd>{stop.recipientName}<small>{stop.recipientPhone}</small></dd></div><div><dt>Destination</dt><dd>{stop.rawAddress}</dd></div><div><dt>Destination pin</dt><dd>{stop.coordinate ? `${stop.coordinate.latitude.toFixed(5)}, ${stop.coordinate.longitude.toFixed(5)}` : "Unavailable"}</dd></div><div><dt>Delivery state</dt><dd>{label(stop.deliveryState)}</dd></div></dl></section>
      <section><h3>Execution evidence <span>live state</span></h3><dl><div><dt>Pickup</dt><dd>{stop.pickupConfirmed ? "Manifest confirmed" : "Awaiting confirmation"}</dd></div><div><dt>Arrived</dt><dd>{stop.arrivedAt ? dateTime(stop.arrivedAt, timezone) : "Not recorded"}</dd></div><div><dt>Completed</dt><dd>{stop.completedAt ? dateTime(stop.completedAt, timezone) : "Not recorded"}</dd></div><div><dt>Operations thread</dt><dd>{stop.operationsThreadId ? "Available" : "Not opened"}</dd></div></dl></section>
    </div>
    <section className="v45-round-manifest"><h3>Physical manifest <span>Version {stop.manifest.version} · {label(stop.manifest.state)}</span></h3>{stop.manifest.items.map((item) => <article key={item.lineNumber}><b>{String(item.lineNumber).padStart(2, "0")}</b><span><strong>{item.description}</strong>{item.handlingNote && <small>{item.handlingNote}</small>}</span><em>×{item.quantity}</em></article>)}</section>
    <div className="v45-round-actions">{movable && <button type="button" className="primary" onClick={onMove}>Move to another Round</button>}{stop.operationsThreadId ? <button type="button" onClick={() => onCommunications(stop.operationsThreadId)}>Open Stop communications</button> : <button type="button" disabled>No Stop thread yet</button>}<button type="button" onClick={() => navigator.clipboard.writeText(stop.deliveryId)}>Copy delivery ID</button><button type="button" onClick={() => navigator.clipboard.writeText(stop.stopId)}>Copy Stop ID</button></div>
  </div>;
}

function deltaMinutes(before?: number, after?: number): string {
  if (before === undefined || after === undefined) return "—";
  const value = Math.round((after - before) / 60);
  return `${value >= 0 ? "+" : ""}${value} min`;
}

function deltaDistance(before?: number, after?: number): string {
  if (before === undefined || after === undefined) return "—";
  const value = (after - before) / 1000;
  return `${value >= 0 ? "+" : ""}${value.toFixed(1)} km`;
}

function MoveRoundSheet({ stop, targets, preview, busy, error, timezone, onClose, onChoose, onBack, onConfirm }: {
  stop: OperationsRoundStopDetail; targets: OperationsRoundSummary[]; preview: MoveRoundStopPreview | null; busy: boolean; error: string; timezone: string;
  onClose: () => void; onChoose: (target: OperationsRoundSummary) => void; onBack: () => void; onConfirm: () => void;
}) {
  return <div className="v45-move-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}><aside className="v45-move-sheet" role="dialog" aria-modal="true" aria-label="Move Stop to another Round">
    <header><div><small>{preview ? "CHANGE PREVIEW" : "MOVE STOP"}</small><h2>{preview ? `Move #${stop.deliveryReference}` : stop.recipientName}</h2><p>{preview ? `${preview.source.reference} → ${preview.target.reference}` : `#${stop.deliveryReference} · choose destination Round`}</p></div><button type="button" onClick={onClose} aria-label="Close">×</button></header>
    <div className="v45-move-content">
      {!preview ? <><div className="v45-move-note">Moving a Stop recalculates both Rounds before confirmation. Only future own-fleet Stops before custody are eligible.</div><section><h3>Choose destination Round <span>own fleet only</span></h3>{busy ? <p className="v45-move-empty">Loading Rounds…</p> : targets.length ? <div className="v45-move-candidates">{targets.map((target) => <button type="button" key={target.id} onClick={() => onChoose(target)}><span><b>{target.reference} · {target.driverName}</b><small>{target.stopCount} Stops · {target.openExceptionCount ? `${target.openExceptionCount} needs action` : "Ready for recalculation"}</small></span><strong>Preview →</strong></button>)}</div> : <p className="v45-move-empty">No other approved own-team Round is available on this service date.</p>}</section></> : <><section className="v45-move-hero"><small>BEFORE YOU APPLY</small><h3>Move {stop.recipientName} to {preview.target.reference}.</h3><p>Both ordered routes were recalculated together against the current driver shifts, promise windows, and physical cargo rules.</p></section><div className="v45-move-impact"><div><span>Target load</span><b>{preview.target.stopsBefore} → {preview.target.stopsAfter} Stops</b></div><div><span>Added route time</span><b>{deltaMinutes(preview.target.routeBefore?.durationSeconds, preview.target.routeAfter?.durationSeconds)}</b></div><div><span>Added route distance</span><b>{deltaDistance(preview.target.routeBefore?.distanceMeters, preview.target.routeAfter?.distanceMeters)}</b></div><div><span>Target finish</span><b>{preview.target.routeBefore && preview.target.routeAfter ? `${time(preview.target.routeBefore.finishAt, timezone)} → ${time(preview.target.routeAfter.finishAt, timezone)}` : "—"}</b></div><div><span>Window check</span><b>{preview.movable ? "Fits" : "Blocked"}</b></div><div><span>Vehicle</span><b>{preview.target.vehicleLabel ?? preview.target.driverName}</b></div><div><span>Physical constraint</span><b>{preview.target.routeAfter?.capacity.constrainingDimension?.code ?? "Capacity fit"}</b></div><div><span>Source Round</span><b>{preview.source.removed ? "Removed when empty" : `${preview.source.stopsAfter} Stops`}</b></div></div>{preview.blockingReasons.length > 0 && <div className="v45-move-blocked">{preview.blockingReasons.map((reason) => <p key={reason}>{reason}</p>)}</div>}</>}
      {error && <div className="v45-move-blocked"><p>{error}</p></div>}
    </div>
    <footer>{preview ? <><button type="button" className="primary" disabled={busy || !preview.movable} onClick={onConfirm}>{busy ? "Rechecking…" : "Confirm move"}</button><button type="button" disabled={busy} onClick={onBack}>Choose another Round</button></> : <button type="button" onClick={onClose}>Back to Round</button>}</footer>
  </aside></div>;
}

function BackIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m15 18-6-6 6-6"/></svg>; }
function RouteIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="6" cy="18" r="2"/><circle cx="18" cy="6" r="2"/><path d="M8 18h3a3 3 0 0 0 3-3V9a3 3 0 0 1 3-3"/></svg>; }
