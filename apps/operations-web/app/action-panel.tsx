"use client";

import { useCallback, useEffect, useState } from "react";
import type {
  OperationsActionException,
  OperationsActionProjection,
  OperationsTenant,
} from "@rounds/contracts";

const roundsApiUrl = process.env.NEXT_PUBLIC_ROUNDS_API_URL ?? "http://127.0.0.1:8080";
type Props = { accessToken: string; tenant: OperationsTenant; onOpenThread: (threadId: string) => void };
type ApiError = { error?: { message?: string } };

const categoryLabels: Record<OperationsActionException["category"], string> = {
  missing_item: "Missing item",
  wrong_item: "Wrong item",
  damaged_item: "Damaged item",
  wrong_pin: "Wrong pin",
  wrong_entrance: "Wrong entrance / access",
  wrong_address: "Wrong address",
  cannot_find_location: "Cannot find location",
};

function timeLabel(value: string, timezone: string): string {
  return new Intl.DateTimeFormat("en-GB", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: timezone,
  }).format(new Date(value));
}

export function ActionPanel({ accessToken, tenant, onOpenThread }: Props) {
  const [projection, setProjection] = useState<OperationsActionProjection | null>(null);
  const [loading, setLoading] = useState(true);
  const [stale, setStale] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async (quiet = false) => {
    if (!quiet) setLoading(true);
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/action`, {
        headers: {
          authorization: `Bearer ${accessToken}`,
          "x-rounds-tenant-id": tenant.id,
          "x-trace-id": crypto.randomUUID(),
        },
      });
      const body = await response.json() as OperationsActionProjection | ApiError;
      if (!response.ok) throw new Error((body as ApiError).error?.message ?? `Action HTTP ${response.status}`);
      setProjection(body as OperationsActionProjection);
      setStale(false);
      setError("");
    } catch (caught) {
      if (quiet) setStale(true);
      else setError(caught instanceof Error ? caught.message : "Action could not be loaded");
    } finally {
      if (!quiet) setLoading(false);
    }
  }, [accessToken, tenant.id]);

  useEffect(() => {
    void load();
    const timer = window.setInterval(() => void load(true), 5000);
    return () => window.clearInterval(timer);
  }, [load]);

  if (loading) return <section className="dispatch-loading"><span /><p>Checking live Operations truth…</p></section>;

  return <div className="action-workspace">
    <section className="page-heading action-heading">
      <div><p className="eyebrow">LIVE OPERATIONS</p><h1>Action</h1><p>Only work that needs an Operations decision appears here.</p></div>
      <button type="button" className="history-refresh" onClick={() => void load()}>Refresh</button>
    </section>
    {error && <div className="alert error" role="alert"><div><strong>Couldn&apos;t load current truth</strong><span>{error}</span></div></div>}
    {stale && projection && <div className="freshness-strip stale" role="status"><strong>Last-known view</strong><span>Live refresh is paused. Actions are withheld until current truth returns.</span></div>}
    {projection && <>
      <section className="action-metrics" aria-label="Live Operations summary">
        <article><span>Needs attention</span><strong>{projection.exceptions.length}</strong><small>open exception{projection.exceptions.length === 1 ? "" : "s"}</small></article>
        <article><span>Rounds moving</span><strong>{projection.rounds.filter((round) => round.state === "active").length}</strong><small>{projection.rounds.length} assigned now</small></article>
        <article><span>Custody</span><strong>{projection.rounds.reduce((sum, round) => sum + round.custodyStopCount, 0)}</strong><small>confirmed Stop{projection.rounds.reduce((sum, round) => sum + round.custodyStopCount, 0) === 1 ? "" : "s"}</small></article>
        <article className="freshness-card"><span>Observed</span><strong>{timeLabel(projection.observedAt, tenant.timezone).split(", ").at(-1)}</strong><small>{stale ? "last known" : "refreshes every 5 sec"}</small></article>
      </section>

      {!projection.exceptions.length ? <section className="action-clear">
        <div>✓</div><h2>Nothing needs attention.</h2><p>There are no unresolved operational exceptions for {tenant.displayName}.</p>
      </section> : <section className="exception-section">
        <div className="dispatch-card-heading"><div><p className="eyebrow">UNRESOLVED</p><h2>Exception queue</h2></div><span>{projection.exceptions.length} open</span></div>
        <div className="exception-list">{projection.exceptions.map((exception) => <article className="exception-card" key={exception.id}>
          <div className="exception-accent" />
          <header><div><p className="eyebrow">{exception.stage.toUpperCase()} · STOP {exception.stopSequence || "—"}</p><h3>{categoryLabels[exception.category]}</h3></div><span className="exception-status">OPEN</span></header>
          <p className="exception-note">{exception.note || "The driver did not add a note."}</p>
          <dl className="exception-context">
            <div><dt>Delivery</dt><dd>{exception.deliveryReference} · {exception.recipientName}</dd></div>
            <div><dt>Round</dt><dd>{exception.roundReference} · {exception.driverName}</dd></div>
            <div><dt>Location</dt><dd>{exception.rawAddress}</dd></div>
            {exception.observedCoordinate && <div><dt>Driver observation</dt><dd>{exception.observedCoordinate.latitude.toFixed(6)}, {exception.observedCoordinate.longitude.toFixed(6)}{exception.observedAccuracyMeters != null ? ` · ±${Math.round(exception.observedAccuracyMeters)} m` : ""}</dd></div>}
            <div><dt>Reported</dt><dd>{timeLabel(exception.reportedAt, tenant.timezone)}</dd></div>
          </dl>
          <footer><span>Manifest v{exception.manifestVersion} · {exception.stopState}</span>{exception.operationsThreadId ? <button type="button" disabled={stale} onClick={() => onOpenThread(exception.operationsThreadId!)}>Open driver conversation →</button> : <em>Driver conversation has not started</em>}</footer>
        </article>)}</div>
      </section>}

      <section className="round-health-section">
        <div className="dispatch-card-heading"><div><p className="eyebrow">ROUND HEALTH</p><h2>Live execution</h2></div><span>{projection.rounds.length} assigned</span></div>
        {!projection.rounds.length ? <div className="pool-empty"><strong>No work moving now</strong><p>Assigned and active Rounds will appear here.</p></div> : <div className="round-health-grid">{projection.rounds.map((round) => <article className={`round-health-card ${round.openExceptionCount ? "has-exception" : ""}`} key={round.id}>
          <header><span>{round.state}</span><strong>{round.reference}</strong></header>
          <p>{round.driverName}</p>
          <div><span><b>{round.custodyStopCount}</b> in custody</span><span><b>{round.stopCount}</b> Stops</span><span className={round.openExceptionCount ? "danger" : ""}><b>{round.openExceptionCount}</b> open</span></div>
        </article>)}</div>}
      </section>
    </>}
  </div>;
}
