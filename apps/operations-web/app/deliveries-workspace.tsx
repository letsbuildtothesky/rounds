"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import type { OperationsDeliveriesProjection, OperationsDeliveryItem, OperationsTenant } from "@rounds/contracts";

const roundsApiUrl = process.env.NEXT_PUBLIC_ROUNDS_API_URL ?? "http://127.0.0.1:8080";
type ApiError = { error?: { message?: string } };
type DeliveryFilter = "all" | "unplanned" | "active" | "action" | "delivered";

const activeStates = new Set(["planned", "assigned", "pickup_pending", "in_custody", "en_route", "arrived", "delivered_pending_evidence"]);
const stateLabels: Record<string, string> = {
  unplanned: "Unplanned", planned: "Planned", assigned: "Assigned", pickup_pending: "Pickup pending",
  in_custody: "In custody", en_route: "En route", arrived: "Arrived", delivered_pending_evidence: "Verifying proof",
  delivered: "Delivered", exception: "Needs action", returned: "Returned", cancelled: "Cancelled", draft: "Draft",
};

function responseMessage(body: unknown, fallback: string): string {
  if (body && typeof body === "object" && "error" in body) return (body as ApiError).error?.message ?? fallback;
  return fallback;
}

function time(value: string, timezone: string): string {
  return new Intl.DateTimeFormat("en-GB", { hour: "2-digit", minute: "2-digit", timeZone: timezone }).format(new Date(value));
}

function dateTime(value: string, timezone: string): string {
  return new Intl.DateTimeFormat("en-GB", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit", timeZone: timezone }).format(new Date(value));
}

function matchesFilter(item: OperationsDeliveryItem, filter: DeliveryFilter): boolean {
  if (filter === "all") return true;
  if (filter === "unplanned") return item.state === "unplanned";
  if (filter === "active") return activeStates.has(item.state);
  if (filter === "action") return item.state === "exception" || item.state === "returned";
  return item.state === "delivered";
}

export function DeliveriesWorkspace({ accessToken, tenant, refreshKey, onAddDelivery, onBackToDispatch, onOpenPlanning, onCommunications }: {
  accessToken: string;
  tenant: OperationsTenant;
  refreshKey: number;
  onAddDelivery: () => void;
  onBackToDispatch: () => void;
  onOpenPlanning: (item: OperationsDeliveryItem) => void;
  onCommunications: () => void;
}) {
  const [projection, setProjection] = useState<OperationsDeliveriesProjection | null>(null);
  const [selectedId, setSelectedId] = useState("");
  const [mobileListOpen, setMobileListOpen] = useState(false);
  const [filter, setFilter] = useState<DeliveryFilter>("all");
  const [query, setQuery] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/deliveries`, { headers: { authorization: `Bearer ${accessToken}`, "x-rounds-tenant-id": tenant.id, "x-trace-id": crypto.randomUUID() } });
      const body = await response.json() as OperationsDeliveriesProjection | ApiError;
      if (!response.ok) throw new Error(responseMessage(body, `Deliveries HTTP ${response.status}`));
      const data = body as OperationsDeliveriesProjection;
      setProjection(data);
      setSelectedId((current) => data.deliveries.some((item) => item.deliveryId === current) ? current : data.deliveries[0]?.deliveryId ?? "");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Deliveries could not be loaded");
    } finally {
      setLoading(false);
    }
  }, [accessToken, tenant.id]);

  useEffect(() => { void load(); }, [load, refreshKey]);

  const counts = useMemo(() => ({
    all: projection?.deliveries.length ?? 0,
    unplanned: projection?.deliveries.filter((item) => item.state === "unplanned").length ?? 0,
    active: projection?.deliveries.filter((item) => activeStates.has(item.state)).length ?? 0,
    action: projection?.deliveries.filter((item) => item.state === "exception" || item.state === "returned").length ?? 0,
    delivered: projection?.deliveries.filter((item) => item.state === "delivered").length ?? 0,
  }), [projection]);
  const visible = useMemo(() => projection?.deliveries.filter((item) => matchesFilter(item, filter) && (!query.trim() || `${item.reference} ${item.recipientName} ${item.rawAddress} ${item.recipientPhone}`.toLowerCase().includes(query.trim().toLowerCase()))) ?? [], [filter, projection, query]);
  const selected = projection?.deliveries.find((item) => item.deliveryId === selectedId);

  useEffect(() => {
    if (visible.some((item) => item.deliveryId === selectedId)) return;
    setSelectedId(visible[0]?.deliveryId ?? "");
  }, [selectedId, visible]);

  return <section className="v45-deliveries" aria-label="Deliveries workspace">
    <header className="v45-deliveries-head"><div><button type="button" className="v45-deliveries-back" onClick={onBackToDispatch}><BackIcon />Dispatch</button><p>OPERATIONS TRUTH</p><h1>Deliveries</h1><span>Every canonical delivery, from intake through committed proof.</span></div><div><small>{projection ? `Observed ${time(projection.observedAt, tenant.timezone)}` : "Connecting"}</small><button type="button" onClick={() => void load()}>Refresh</button><button type="button" className="primary" onClick={onAddDelivery}>+ Add delivery</button></div></header>
    <div className="v45-deliveries-body">
      <aside className={`v45-deliveries-list ${selected ? "has-selection" : ""} ${mobileListOpen ? "mobile-list-open" : ""}`}>
        <label className="v45-deliveries-search"><SearchIcon /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search reference, recipient or address" /></label>
        <div className="v45-deliveries-filters">{(["all", "unplanned", "active", "action", "delivered"] as DeliveryFilter[]).map((item) => <button key={item} type="button" className={filter === item ? "on" : ""} onClick={() => setFilter(item)}><span>{item === "all" ? "All" : item[0]!.toUpperCase() + item.slice(1)}</span><b>{counts[item]}</b></button>)}</div>
        <div className="v45-deliveries-scroll">{loading ? <div className="v45-delivery-empty">Loading canonical delivery truth…</div> : error ? <div className="v45-delivery-empty error"><b>Couldn&apos;t load Deliveries</b><span>{error}</span><button type="button" onClick={() => void load()}>Retry</button></div> : visible.length === 0 ? <div className="v45-delivery-empty"><b>No matching deliveries</b><span>Change the filter or add a new delivery.</span></div> : visible.map((item) => <button key={item.deliveryId} type="button" className={`v45-delivery-row state-${item.state} ${selectedId === item.deliveryId ? "selected" : ""}`} onClick={() => { setSelectedId(item.deliveryId); setMobileListOpen(false); }}><span className="v45-delivery-row-top"><span><b>{item.recipientName}</b><small>{item.rawAddress}</small></span><em>#{item.reference}</em></span><span className="v45-delivery-row-foot"><span>{item.serviceDate} · {time(item.promise.windowStart, tenant.timezone)}–{time(item.promise.windowEnd, tenant.timezone)}</span><b>{stateLabels[item.state] ?? item.state}</b></span></button>)}</div>
      </aside>
      <main className={`v45-delivery-detail ${selected && !mobileListOpen ? "open" : ""}`}>{selected ? <DeliveryDetail item={selected} timezone={tenant.timezone} onBack={() => setMobileListOpen(true)} onOpenPlanning={onOpenPlanning} onCommunications={onCommunications} /> : <div className="v45-delivery-detail-empty"><PackageIcon /><h2>Select a delivery</h2><p>Inspect its promise, destination, manifest and execution truth.</p></div>}</main>
    </div>
  </section>;
}

function DeliveryDetail({ item, timezone, onBack, onOpenPlanning, onCommunications }: { item: OperationsDeliveryItem; timezone: string; onBack: () => void; onOpenPlanning: (item: OperationsDeliveryItem) => void; onCommunications: () => void }) {
  return <div className="v45-delivery-detail-scroll">
    <header><button type="button" className="v45-delivery-mobile-back" onClick={onBack}><BackIcon />All deliveries</button><div><p>DELIVERY · #{item.reference}</p><h2>{item.recipientName}</h2><span>{item.rawAddress}</span></div><b className={`v45-delivery-state state-${item.state}`}>{stateLabels[item.state] ?? item.state}</b></header>
    <section className="v45-delivery-decision"><div><small>SERVICE DATE</small><b>{item.serviceDate}</b></div><div><small>PROMISE</small><b>{time(item.promise.windowStart, timezone)}–{time(item.promise.windowEnd, timezone)}</b></div><div><small>STOP STATE</small><b>{stateLabels[item.stop.state] ?? item.stop.state}</b></div><div><small>VERSION</small><b>{item.version}</b></div></section>
    <div className="v45-delivery-detail-grid">
      <section><h3>People & destination <span>canonical</span></h3><dl><div><dt>Recipient</dt><dd>{item.recipientName}<small>{item.recipientPhone}</small></dd></div>{!item.buyerSameAsRecipient && <div><dt>Buyer</dt><dd>{item.buyerName}<small>{item.buyerPhone}</small></dd></div>}<div><dt>Address</dt><dd>{item.rawAddress}{item.accessNote && <small>{item.accessNote}</small>}</dd></div><div><dt>Destination pin</dt><dd>{item.coordinate ? `${item.coordinate.latitude.toFixed(5)}, ${item.coordinate.longitude.toFixed(5)}` : "Unavailable"}</dd></div><div><dt>Pickup</dt><dd>{item.pickupLocationName}</dd></div></dl></section>
      <section><h3>Execution <span>live state</span></h3><dl><div><dt>Round</dt><dd>{item.round?.reference ?? "Not planned"}{item.round && <small>{item.round.driverName} · Stop {item.round.sequence}</small>}</dd></div><div><dt>Delivery state</dt><dd>{stateLabels[item.state] ?? item.state}</dd></div><div><dt>Stop state</dt><dd>{stateLabels[item.stop.state] ?? item.stop.state}<small>Version {item.stop.version}</small></dd></div><div><dt>Updated</dt><dd>{dateTime(item.updatedAt, timezone)}</dd></div><div><dt>Source</dt><dd>{item.sourceSystem}</dd></div></dl></section>
    </div>
    <section className="v45-delivery-manifest"><h3>Physical manifest <span>Version {item.manifest.version} · {item.manifest.state}</span></h3><div>{item.manifest.items.map((manifestItem) => <article key={manifestItem.lineNumber}><b>{String(manifestItem.lineNumber).padStart(2, "0")}</b><span><strong>{manifestItem.description}</strong>{manifestItem.handlingNote && <small>{manifestItem.handlingNote}</small>}</span><em>×{manifestItem.quantity}</em></article>)}</div>{item.deliveryNote && <p><b>Delivery instruction</b>{item.deliveryNote}</p>}{item.isSurprise && <p className="gift"><b>Gift privacy</b>Buyer details are protected from recipient-facing communication.</p>}</section>
    <div className="v45-delivery-actions">{item.state === "unplanned" && <button type="button" className="primary" onClick={() => onOpenPlanning(item)}>Open in Dispatch planning</button>}{item.round && <button type="button" onClick={onCommunications}>Open communications</button>}<button type="button" onClick={() => navigator.clipboard.writeText(item.deliveryId)}>Copy delivery ID</button></div>
  </div>;
}

function SearchIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="m16 16 5 5"/></svg>; }
function BackIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m15 18-6-6 6-6"/></svg>; }
function PackageIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m4 7 8-4 8 4-8 4-8-4Z"/><path d="M4 7v10l8 4 8-4V7M12 11v10"/></svg>; }
