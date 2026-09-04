"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import type { OperationsHistoryProjection, OperationsTenant } from "@rounds/contracts";

const roundsApiUrl = process.env.NEXT_PUBLIC_ROUNDS_API_URL ?? "http://127.0.0.1:8080";
type Props = { accessToken: string; tenant: OperationsTenant };
type ApiError = { error?: { message?: string } };

function handoffLabel(type: string): string {
  if (type === "someone_else") return "Someone else";
  if (type === "left_at_location") return "Left at approved location";
  return "Recipient";
}

export function HistoryPanel({ accessToken, tenant }: Props) {
  const [history, setHistory] = useState<OperationsHistoryProjection | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [query, setQuery] = useState("");
  const [outcome, setOutcome] = useState<"all" | "delivered" | "returned">("all");
  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/history`, { headers: {
        authorization: `Bearer ${accessToken}`,
        "x-rounds-tenant-id": tenant.id,
        "x-trace-id": crypto.randomUUID(),
      } });
      const body = await response.json() as OperationsHistoryProjection | ApiError;
      if (!response.ok) throw new Error((body as ApiError).error?.message ?? `History HTTP ${response.status}`);
      setHistory(body as OperationsHistoryProjection);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "History could not be loaded");
    } finally {
      setLoading(false);
    }
  }, [accessToken, tenant.id]);
  useEffect(() => { void load(); }, [load]);

  const formatDate = (value: string) => new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium", timeStyle: "short", timeZone: tenant.timezone,
  }).format(new Date(value));

  const records = useMemo(() => {
    const needle = query.trim().toLowerCase();
    return (history?.deliveries ?? []).filter((item) => {
      if (outcome !== "all" && item.outcome !== outcome) return false;
      return !needle || `${item.deliveryReference} ${item.roundReference} ${item.recipientName} ${item.driverName} ${item.rawAddress}`.toLowerCase().includes(needle);
    });
  }, [history, outcome, query]);
  const delivered = history?.deliveries.filter((item) => item.outcome === "delivered").length ?? 0;
  const returned = history?.deliveries.filter((item) => item.outcome === "returned").length ?? 0;
  const podComplete = history?.deliveries.length ? Math.round(history.deliveries.filter((item) => item.verifiedPhotoCount > 0).length / history.deliveries.length * 100) : 0;

  return <div className="v45-history">
    <header className="v45-history-head"><div><h1>History</h1><p>What happened, why it happened, and what needs attention across your delivery operation.</p></div><button type="button" onClick={() => void load()}>Refresh</button></header>
    <nav className="v45-history-tabs" aria-label="History views"><button type="button" disabled title="Management overview is not connected yet">Overview</button><button type="button" className="on">Deliveries</button><button type="button" disabled title="Driver evidence history is not connected yet">Drivers</button><button type="button" disabled title="Incident history is not connected yet">Incidents</button></nav>
    <main className="v45-history-body">
      <section className="v45-history-intro"><small>DELIVERY RECORDS</small><h2>Every delivery, with the evidence attached.</h2><p>Committed own-fleet outcomes stay in one operational record. Network and external-provider history will appear only after those sources are connected.</p></section>
      <section className="v45-history-kpis" aria-label="Delivery history summary"><div><span>Terminal records</span><b>{history?.deliveries.length ?? "—"}</b><small>committed outcomes</small></div><div><span>Delivered</span><b>{delivered}</b><small>custody completed</small></div><div><span>Returned</span><b className={returned ? "attention" : ""}>{returned}</b><small>merchant received</small></div><div><span>POD complete</span><b>{podComplete}%</b><small>verified photo evidence</small></div></section>
      <div className="v45-history-tools"><label><SearchIcon /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search order, recipient, driver or address" /></label><select value={outcome} onChange={(event) => setOutcome(event.target.value as typeof outcome)} aria-label="Outcome filter"><option value="all">All outcomes</option><option value="delivered">Delivered</option><option value="returned">Returned</option></select><span>{records.length} record{records.length === 1 ? "" : "s"} shown</span></div>
      {error && <div className="v45-history-message error" role="alert"><b>Couldn&apos;t load History</b><span>{error}</span><button type="button" onClick={() => void load()}>Retry</button></div>}
      {loading ? <div className="v45-history-message">Loading committed evidence…</div> : !history?.deliveries.length ? <div className="v45-history-message"><b>No terminal delivery outcomes yet</b><span>A delivery appears here after its required evidence and final custody outcome are durably committed.</span></div> : records.length === 0 ? <div className="v45-history-message"><b>No matching records</b><span>Change the search or outcome filter.</span></div> : <section className="v45-history-records">
        <div className="v45-history-row header"><span>Delivery</span><span>Outcome</span><span>Driver / handoff</span><span>Evidence</span></div>
        {records.map((item) => <article className={`v45-history-row ${item.outcome}`} key={item.recordId}>
          <div className="v45-history-delivery"><b>#{item.deliveryReference} · {item.recipientName}</b><span>{item.rawAddress}</span><small>{item.roundReference}</small></div>
          <div><b>{item.outcome === "returned" ? "Returned" : "Delivered"}</b><span>{formatDate(item.outcome === "delivered" ? item.deliveredAt : item.returnedAt)}</span>{item.outcome === "returned" && <small>Merchant received package</small>}</div>
          <div><b>{item.driverName}</b><span>{item.outcome === "delivered" ? `${handoffLabel(item.handoffType)} · ${item.receiverLabel}` : "Return custody completed"}</span></div>
          <div><b><em>Verified</em> {item.verifiedPhotoCount} {item.outcome === "returned" ? "damage " : ""}photo</b><span>Manifest v{item.manifestVersion}</span></div>
          {item.outcome === "returned" && (item.exceptionNote || item.resolutionNote) && <div className="v45-history-notes">{item.exceptionNote && <p><strong>Driver report</strong><span>{item.exceptionNote}</span></p>}{item.resolutionNote && <p><strong>Operations resolution</strong><span>{item.resolutionNote}</span></p>}</div>}
        </article>)}
      </section>}
    </main>
  </div>;
}

function SearchIcon() {
  return <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6.5" /><path d="m16 16 4 4" /></svg>;
}
