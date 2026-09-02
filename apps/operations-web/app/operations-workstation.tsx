"use client";

import { useCallback, useEffect, useMemo, useState, type ReactNode } from "react";
import type {
  OperationsActionException,
  OperationsActionProjection,
  OperationsPlanningProjection,
  OperationsDeliveryItem,
  OperationsRoundSummary,
  OperationsTenant,
  PlanRoundResult,
  UnplannedDeliverySummary,
} from "@rounds/contracts";
import { OperationsMap, type OperationsMapCamera, type OperationsMapMode } from "./operations-map";
import { OperationsMenuIcon, OperationsSectionSheet, type OperationsSectionKey } from "./operations-section-sheet";
import { DeliveriesWorkspace } from "./deliveries-workspace";
import { RoundDetailWorkspace } from "./round-detail-workspace";

const roundsApiUrl = process.env.NEXT_PUBLIC_ROUNDS_API_URL ?? "http://127.0.0.1:8080";

type QueueTab = "action" | "ready" | "live" | "done";
type Selection = { kind: "exception"; item: OperationsActionException } | { kind: "round"; item: OperationsRoundSummary } | { kind: "delivery"; item: UnplannedDeliverySummary } | null;
type ApiError = { error?: { message?: string } };

type Props = {
  accessToken?: string;
  tenant: OperationsTenant;
  userName: string;
  demoMode?: boolean;
  deliveryIntake?: ReactNode;
  deliveryIntakeOpen?: boolean;
  deliveriesOpen?: boolean;
  deliveryRefreshKey?: number;
  onCloseDeliveryIntake?: () => void;
  onDeliveries?: () => void;
  onCloseDeliveries?: () => void;
  onAddDelivery: () => void;
  onHistory: () => void;
  onCommunications: (threadId?: string) => void;
  onSignOut: () => void;
};

function demoProjection(tenantId: string): OperationsActionProjection {
  const reportedAt = new Date().toISOString();
  return {
    tenantId,
    observedAt: reportedAt,
    rounds: [
      { id: "demo-round-18", reference: "Round 18", serviceDate: "2026-09-02", state: "active", driverId: "demo-somchai", driverName: "Somchai K.", stopCount: 3, custodyStopCount: 2, openExceptionCount: 1, currentPosition: { latitude: 13.7298, longitude: 100.5487, capturedAt: reportedAt } },
      { id: "demo-round-19", reference: "Round 19", serviceDate: "2026-09-02", state: "active", driverId: "demo-nattawut", driverName: "Nattawut P.", stopCount: 2, custodyStopCount: 1, openExceptionCount: 0, currentPosition: { latitude: 13.7338, longitude: 100.5766, capturedAt: reportedAt } },
      { id: "demo-round-20", reference: "Round 20", serviceDate: "2026-09-02", state: "approved", driverId: "demo-pim", driverName: "Pim T.", stopCount: 3, custodyStopCount: 0, openExceptionCount: 0 },
    ],
    exceptions: [
      { id: "demo-exception-1", deliveryId: "demo-delivery-10432", deliveryReference: "10432", recipientName: "K. Nattaporn", rawAddress: "The Emporio Place · Sukhumvit 24", coordinate: { latitude: 13.7274, longitude: 100.5663 }, stopId: "demo-stop-1", stopSequence: 1, stopState: "exception", stopVersion: 3, roundId: "demo-round-18", roundReference: "Round 18", roundState: "loading", driverId: "demo-somchai", driverName: "Somchai K.", stage: "pickup", category: "missing_item", note: "One manifest item is not physically present at pickup.", status: "open", manifestVersion: 1, reportedAt, operationsThreadId: "demo-thread-1" },
      { id: "demo-exception-2", deliveryId: "demo-delivery-10439", deliveryReference: "10439", recipientName: "Pullman Bangkok Hotel G", rawAddress: "Silom Road · Bang Rak", coordinate: { latitude: 13.7215, longitude: 100.5298 }, stopId: "demo-stop-2", stopSequence: 2, stopState: "arrived", stopVersion: 6, roundId: "demo-round-18", roundReference: "Round 18", roundState: "active", driverId: "demo-somchai", driverName: "Somchai K.", stage: "delivery", category: "damaged_item", note: "Packaging damage requires an Operations decision before handoff.", status: "open", manifestVersion: 2, reportedAt, operationsThreadId: "demo-thread-2" },
      { id: "demo-exception-3", deliveryId: "demo-delivery-10444", deliveryReference: "10444", recipientName: "Anantara Siam", rawAddress: "Ratchadamri Road · Pathum Wan", coordinate: { latitude: 13.7402, longitude: 100.5417 }, stopId: "demo-stop-3", stopSequence: 1, stopState: "exception", stopVersion: 2, roundId: "demo-round-19", roundReference: "Round 19", roundState: "loading", driverId: "demo-nattawut", driverName: "Nattawut P.", stage: "pickup", category: "wrong_item", note: "The physical package does not match the current manifest.", status: "open", manifestVersion: 1, reportedAt, operationsThreadId: "demo-thread-3" },
    ],
  };
}

function demoPlanningProjection(tenantId: string): OperationsPlanningProjection {
  return {
    tenantId,
    drivers: [
      { id: "demo-somchai", displayName: "Somchai K.", vehicleLabel: "Motorbike + box", vehiclePlate: "1GX 1042" },
      { id: "demo-pim", displayName: "Pim T.", vehicleLabel: "Car", vehiclePlate: "8KT 3318" },
    ],
    unplannedDeliveries: [
      { deliveryId: "demo-ready-10435", stopId: "demo-ready-stop-1", reference: "10435", serviceDate: "2026-09-02", pickupLocationId: "urbanflowers", recipientName: "James T.", rawAddress: "Sathorn Square · Sathorn", coordinate: { latitude: 13.7215, longitude: 100.5298 }, windowStart: "2026-09-02T06:00:00.000Z", windowEnd: "2026-09-02T08:30:00.000Z", manifestSummary: "1× Signature hamper" },
      { deliveryId: "demo-ready-10441", stopId: "demo-ready-stop-2", reference: "10441", serviceDate: "2026-09-02", pickupLocationId: "urbanflowers", recipientName: "Marriott Sukhumvit", rawAddress: "Thonglor · Sukhumvit", coordinate: { latitude: 13.7308, longitude: 100.5828 }, windowStart: "2026-09-02T07:00:00.000Z", windowEnd: "2026-09-02T09:00:00.000Z", manifestSummary: "2× Lobby arrangement" },
      { deliveryId: "demo-ready-10446", stopId: "demo-ready-stop-3", reference: "10446", serviceDate: "2026-09-02", pickupLocationId: "urbanflowers", recipientName: "Bangkok Hospital", rawAddress: "Phetchaburi Road", coordinate: { latitude: 13.7487, longitude: 100.5846 }, windowStart: "2026-09-02T08:00:00.000Z", windowEnd: "2026-09-02T11:00:00.000Z", manifestSummary: "1× Get well bouquet" },
    ],
    activeRounds: demoProjection(tenantId).rounds,
  };
}

const exceptionLabels: Record<OperationsActionException["category"], string> = {
  missing_item: "Missing item",
  wrong_item: "Wrong item",
  damaged_item: "Damaged item",
};

const mapModeCopy: Record<OperationsMapMode, { label: string; description: string; hint: string }> = {
  operations: { label: "Operations", description: "Live driver and destination positions only", hint: "server-backed positions only" },
  satellite: { label: "Satellite", description: "Real-world aerial imagery for access and site checks", hint: "inspect real-world access" },
};

function shortTime(value: string, timezone: string): string {
  return new Intl.DateTimeFormat("en-GB", { hour: "2-digit", minute: "2-digit", timeZone: timezone }).format(new Date(value));
}

function nextRoundReference(deliveries: UnplannedDeliverySummary[]): string {
  const serviceDate = deliveries[0]?.serviceDate ?? new Date().toISOString().slice(0, 10);
  const time = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Bangkok",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  }).format(new Date()).replaceAll(":", "");
  return `ROUND-${serviceDate.replaceAll("-", "")}-${time}`;
}

export function OperationsWorkstation({ accessToken, tenant, userName, demoMode = false, deliveryIntake, deliveryIntakeOpen = false, deliveriesOpen = false, deliveryRefreshKey = 0, onCloseDeliveryIntake, onDeliveries, onCloseDeliveries, onAddDelivery, onHistory, onCommunications, onSignOut }: Props) {
  const [projection, setProjection] = useState<OperationsActionProjection | null>(null);
  const [planning, setPlanning] = useState<OperationsPlanningProjection | null>(null);
  const [planningDate, setPlanningDate] = useState(() => new Intl.DateTimeFormat("en-CA", { timeZone: tenant.timezone }).format(new Date()));
  const [selectedStops, setSelectedStops] = useState<string[]>([]);
  const [planningDriverId, setPlanningDriverId] = useState("");
  const [roundReference, setRoundReference] = useState("");
  const [roundSubmitting, setRoundSubmitting] = useState(false);
  const [roundError, setRoundError] = useState("");
  const [roundSuccess, setRoundSuccess] = useState<Extract<PlanRoundResult, { status: "committed" }> | null>(null);
  const [roundIdempotencyKey, setRoundIdempotencyKey] = useState(() => crypto.randomUUID());
  const [dispatchMode, setDispatchMode] = useState<"live" | "plan">("live");
  const [tab, setTab] = useState<QueueTab>("action");
  const [query, setQuery] = useState("");
  const [selection, setSelection] = useState<Selection>(null);
  const [loading, setLoading] = useState(true);
  const [stale, setStale] = useState(false);
  const [error, setError] = useState("");
  const [profileOpen, setProfileOpen] = useState(false);
  const [sectionMenuOpen, setSectionMenuOpen] = useState(false);
  const [mapMode, setMapMode] = useState<OperationsMapMode>("operations");
  const [mapMenuOpen, setMapMenuOpen] = useState(false);
  const [mapCamera, setMapCamera] = useState<OperationsMapCamera>({ bearing: 0, pitch: 0 });
  const [mapHint, setMapHint] = useState("");
  const [roundDetailId, setRoundDetailId] = useState("");

  const load = useCallback(async (quiet = false) => {
    if (!quiet) setLoading(true);
    if (demoMode) {
      setProjection(demoProjection(tenant.id));
      setError("");
      setStale(false);
      setLoading(false);
      return;
    }
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
      setError("");
      setStale(false);
    } catch (caught) {
      if (quiet) setStale(true);
      else setError(caught instanceof Error ? caught.message : "Dispatch could not be loaded");
    } finally {
      if (!quiet) setLoading(false);
    }
  }, [accessToken, demoMode, tenant.id]);

  const loadPlanning = useCallback(async () => {
    if (demoMode) {
      const data = demoPlanningProjection(tenant.id);
      setPlanning(data);
      setPlanningDate((current) => data.unplannedDeliveries.some((delivery) => delivery.serviceDate === current) ? current : data.unplannedDeliveries[0]?.serviceDate ?? current);
      setPlanningDriverId((current) => current || data.drivers[0]?.id || "");
      setRoundReference((current) => current || nextRoundReference(data.unplannedDeliveries));
      return;
    }
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/planning`, {
        headers: {
          authorization: `Bearer ${accessToken}`,
          "x-rounds-tenant-id": tenant.id,
          "x-trace-id": crypto.randomUUID(),
        },
      });
      const body = await response.json() as OperationsPlanningProjection | ApiError;
      if (!response.ok) throw new Error((body as ApiError).error?.message ?? `Planning HTTP ${response.status}`);
      const data = body as OperationsPlanningProjection;
      setPlanning(data);
      setPlanningDate((current) => data.unplannedDeliveries.some((delivery) => delivery.serviceDate === current) ? current : data.unplannedDeliveries[0]?.serviceDate ?? current);
      setPlanningDriverId((current) => current || data.drivers[0]?.id || "");
      setRoundReference((current) => current || nextRoundReference(data.unplannedDeliveries));
      setError("");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Planning could not be loaded");
    }
  }, [accessToken, demoMode, tenant.id]);

  useEffect(() => {
    void load();
    const timer = window.setInterval(() => void load(true), 5000);
    return () => window.clearInterval(timer);
  }, [load]);

  useEffect(() => {
    if (dispatchMode === "plan") void loadPlanning();
  }, [dispatchMode, loadPlanning]);

  useEffect(() => {
    setMapHint(`${mapModeCopy[mapMode].label} · ${mapModeCopy[mapMode].hint}`);
    const timer = window.setTimeout(() => setMapHint(""), 1800);
    return () => window.clearTimeout(timer);
  }, [mapMode]);

  const buckets = useMemo(() => {
    const rounds = projection?.rounds ?? [];
    return {
      action: projection?.exceptions ?? [],
      ready: rounds.filter((round) => round.state === "approved" || round.state === "loading"),
      live: rounds.filter((round) => round.state === "active"),
      done: rounds.filter((round) => round.state === "complete"),
    };
  }, [projection]);

  const visible = useMemo(() => {
    const needle = query.trim().toLowerCase();
    if (tab === "action") return buckets.action.filter((item) => !needle || `${item.deliveryReference} ${item.recipientName} ${item.rawAddress}`.toLowerCase().includes(needle));
    return buckets[tab].filter((item) => !needle || `${item.reference} ${item.driverName} ${item.state}`.toLowerCase().includes(needle));
  }, [buckets, query, tab]);

  const activeRounds = buckets.live.length;
  const chosenDeliveries = useMemo(() => planning?.unplannedDeliveries.filter((delivery) => selectedStops.includes(delivery.stopId)) ?? [], [planning, selectedStops]);
  const planningAnchor = chosenDeliveries[0];

  function togglePlanningDelivery(delivery: UnplannedDeliverySummary) {
    if (planningAnchor && !selectedStops.includes(delivery.stopId) && (planningAnchor.serviceDate !== delivery.serviceDate || planningAnchor.pickupLocationId !== delivery.pickupLocationId)) return;
    setRoundError("");
    setRoundSuccess(null);
    setSelectedStops((current) => current.includes(delivery.stopId) ? current.filter((stopId) => stopId !== delivery.stopId) : [...current, delivery.stopId]);
  }

  async function approveRound() {
    if (!planning || !planningDriverId || !roundReference.trim() || !chosenDeliveries.length) return;
    setRoundSubmitting(true);
    setRoundError("");
    setRoundSuccess(null);
    try {
      const response = await fetch(`${roundsApiUrl}/v1/rounds`, {
        method: "POST",
        headers: {
          authorization: `Bearer ${accessToken}`,
          "content-type": "application/json",
          "idempotency-key": `operations:${roundIdempotencyKey}`,
          "x-rounds-tenant-id": tenant.id,
          "x-trace-id": crypto.randomUUID(),
        },
        body: JSON.stringify({
          reference: roundReference.trim(),
          serviceDate: chosenDeliveries[0]!.serviceDate,
          driverId: planningDriverId,
          stopIds: selectedStops,
        }),
      });
      const body = await response.json() as PlanRoundResult | ApiError;
      if (!response.ok || !("status" in body) || body.status !== "committed") throw new Error((body as ApiError).error?.message ?? `Round command HTTP ${response.status}`);
      setRoundSuccess(body);
      setSelectedStops([]);
      setRoundReference("");
      setRoundIdempotencyKey(crypto.randomUUID());
      await Promise.all([loadPlanning(), load(true)]);
    } catch (caught) {
      setRoundError(caught instanceof Error ? caught.message : "Round could not be approved");
    } finally {
      setRoundSubmitting(false);
    }
  }

  return <main className="v45-app">
    <header className="v45-topbar">
      <div className="v45-wordmark">Rounds<i /></div>
      <div className="v45-workspace"><b>{tenant.displayName}</b><span>Bangkok · Automatic dispatch</span></div>
      <nav className="v45-nav" aria-label="Operations sections">
        <button className={!deliveriesOpen ? "on" : ""} type="button" onClick={onCloseDeliveries}>Dispatch</button>
        <button className={deliveriesOpen ? "on" : ""} type="button" onClick={onDeliveries}>Deliveries</button>
        <button type="button" disabled title="Drivers workspace is not connected yet">Drivers</button>
        <button type="button" onClick={onHistory}>History</button>
        <button type="button" disabled title="Settings workspace is not connected yet">Settings</button>
      </nav>
      <button className="v45-section-trigger" type="button" aria-haspopup="dialog" aria-expanded={sectionMenuOpen} onClick={() => setSectionMenuOpen(true)}><span>{deliveriesOpen || deliveryIntakeOpen ? "Deliveries" : "Dispatch"}</span><OperationsMenuIcon /></button>
      <div className="v45-spacer" />
      <button className="v45-network" type="button" disabled title="Network dispatch is outside the connected Own-Team slice"><i /><span>Own Team</span><ChevronIcon /></button>
      <button className="v45-util" type="button" title="Driver communications" onClick={() => onCommunications()}><MessageIcon />{buckets.action.length > 0 && <b>{buckets.action.length}</b>}</button>
      <button className="v45-util" type="button" title="Operational alerts" onClick={() => setTab("action")}><BellIcon /></button>
      <div className="v45-profile-wrap"><button className="v45-util" type="button" title="Business settings" onClick={() => setProfileOpen((open) => !open)}><UserIcon /></button>{profileOpen && <div className="v45-profile-menu"><strong>{userName}</strong><span>{tenant.displayName}</span><button type="button" onClick={onSignOut}>Sign out</button></div>}</div>
    </header>

    {stale && <div className="v45-system-strip"><i /><b>Last-known operational view</b><span>Live refresh is paused. Decisions are withheld until current truth returns.</span><button onClick={() => void load()}>Retry</button></div>}

    <OperationsSectionSheet
      open={sectionMenuOpen}
      current={deliveriesOpen || deliveryIntakeOpen ? "deliveries" : "action"}
      onClose={() => setSectionMenuOpen(false)}
      onSelect={(section: OperationsSectionKey) => {
        if (section === "action") { onCloseDeliveryIntake?.(); onCloseDeliveries?.(); }
        else if (section === "deliveries") { onCloseDeliveryIntake?.(); onDeliveries?.(); }
        else if (section === "communications") onCommunications();
        else if (section === "history") onHistory();
      }}
      onSignOut={onSignOut}
    />

    <div className="v45-board">
      <aside className="v45-rail">
        <div className="v45-rail-head">
          <div className="v45-rail-title"><div><h1>Dispatch</h1><p>What needs attention now.</p></div><button type="button" className="v45-add" onClick={onAddDelivery}>+ Deliveries</button></div>
          <div className="v45-mode"><button className={dispatchMode === "live" ? "on" : ""} type="button" onClick={() => { setDispatchMode("live"); setSelection(null); }}>Live</button><button className={dispatchMode === "plan" ? "on" : ""} type="button" onClick={() => { setDispatchMode("plan"); setSelection(null); }}>Plan <span>{planning?.unplannedDeliveries.length ?? buckets.ready.length}</span></button></div>
          {dispatchMode === "plan" ? <div className="v45-plan-controls"><label>Planning date<input type="date" value={planningDate} onChange={(event) => { setPlanningDate(event.target.value); setSelectedStops([]); setRoundError(""); setRoundSuccess(null); }} /></label><p><span>Unplanned deliveries waiting</span><b>{planning?.unplannedDeliveries.filter((delivery) => delivery.serviceDate === planningDate).length ?? "—"}</b></p><button type="button" onClick={() => void loadPlanning()}>Refresh delivery pool</button><small>Select Stops in visit order. Nothing is assigned until explicit approval.</small></div> : <div className="v45-scope"><label>Delivery view<select defaultValue="all"><option value="all">All deliveries</option><option value="today">Today</option></select></label><p><b>{buckets.action.length} action</b><span>·</span><b>{activeRounds} live</b><span>·</span><span>{buckets.done.length} completed today</span></p></div>}
          {dispatchMode === "live" && <div className="v45-tabs" role="tablist">
            {(["action", "ready", "live", "done"] as QueueTab[]).map((item) => <button key={item} type="button" role="tab" aria-selected={tab === item} className={tab === item ? "on" : ""} onClick={() => { setTab(item); setSelection(null); }}><b>{buckets[item].length}</b>{item[0]!.toUpperCase() + item.slice(1)}</button>)}
          </div>}
          <label className="v45-search"><SearchIcon /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search order, customer or area" /></label>
          {dispatchMode === "plan" && <section className="v45-plan-approval" aria-label="Round approval">
            <div><span>PROPOSED ROUND</span><b>{selectedStops.length} Stop{selectedStops.length === 1 ? "" : "s"} selected</b>{selectedStops.length > 0 && <button type="button" onClick={() => setSelectedStops([])}>Clear</button>}</div>
            <label>Round reference<input value={roundReference} onChange={(event) => setRoundReference(event.target.value)} placeholder="ROUND-YYYYMMDD-01" /></label>
            <label>Team driver<select value={planningDriverId} onChange={(event) => setPlanningDriverId(event.target.value)}><option value="">Choose driver</option>{planning?.drivers.map((driver) => <option key={driver.id} value={driver.id}>{driver.displayName}{driver.vehiclePlate ? ` · ${driver.vehiclePlate}` : ""}</option>)}</select></label>
            {roundError && <p role="alert">{roundError}</p>}
            {roundSuccess && <p className="success" role="status">{roundSuccess.state.reference} assigned · {roundSuccess.state.stopIds.length} Stop{roundSuccess.state.stopIds.length === 1 ? "" : "s"}</p>}
            <button className="primary" type="button" disabled={roundSubmitting || tenant.role === "viewer" || !selectedStops.length || !planningDriverId || !roundReference.trim()} onClick={() => void approveRound()}>{roundSubmitting ? "Approving…" : tenant.role === "viewer" ? "Viewer cannot approve" : "Approve & assign Round"}</button>
          </section>}
        </div>
        <div className="v45-queue">
          {dispatchMode === "plan" ? <PlanningQueue planning={planning} planningDate={planningDate} query={query} selection={selection} selectedStops={selectedStops} anchor={planningAnchor} setSelection={setSelection} onToggle={togglePlanningDelivery} timezone={tenant.timezone} /> : <><div className={`v45-group ${tab === "action" ? "action" : ""}`}><b>{tab === "action" ? "Needs action" : tab === "ready" ? "Ready" : tab === "live" ? "Live deliveries" : "Recently completed"}</b><span>{visible.length}</span></div>
          {loading ? <div className="v45-empty">Checking live Operations truth…</div> : error ? <div className="v45-empty error"><b>Couldn&apos;t load Dispatch</b><span>{error}</span><button onClick={() => void load()}>Retry</button></div> : visible.length === 0 ? <div className="v45-empty"><b>{tab === "action" ? "Nothing needs attention." : `No ${tab} work right now.`}</b><span>{tab === "action" ? "The exception queue is clear." : "Live work appears here automatically."}</span></div> : tab === "action" ? (visible as OperationsActionException[]).map((item) => <ExceptionRow key={item.id} item={item} selected={selection?.kind === "exception" && selection.item.id === item.id} onSelect={() => setSelection({ kind: "exception", item })} timezone={tenant.timezone} />) : (visible as OperationsRoundSummary[]).map((item) => <RoundRow key={item.id} item={item} selected={selection?.kind === "round" && selection.item.id === item.id} onSelect={() => setSelection({ kind: "round", item })} />)}</>}
        </div>
      </aside>

      <section className="v45-map-wrap">
        <div className="v45-map-header"><strong>Bangkok · {dispatchMode === "live" ? "Live" : "Plan"}</strong><span>{dispatchMode === "plan" ? `${planning?.unplannedDeliveries.filter((delivery) => delivery.serviceDate === planningDate).length ?? 0} unplanned` : tab === "action" ? "All deliveries" : `${visible.length} ${tab}`}</span><button type="button" disabled title="Round overview is not connected yet">Rounds</button><button type="button" disabled title="Automatic planning is not connected yet"><i />Manual</button><div className="v45-spacer" /><em><i />{stale ? "Connection delayed" : dispatchMode === "plan" ? "Draft only" : "On time"}</em><span>{dispatchMode === "plan" ? `${selectedStops.length} selected · not approved` : <>Live rounds <b>{activeRounds}</b></>}</span></div>
        <div className="v45-map-body" onClick={() => setMapMenuOpen(false)}>
          <OperationsMap
            mode={dispatchMode}
            mapMode={mapMode}
            rounds={projection?.rounds ?? []}
            exceptions={projection?.exceptions ?? []}
            planningDeliveries={planning?.unplannedDeliveries.filter((delivery) => delivery.serviceDate === planningDate) ?? []}
            onCameraChange={setMapCamera}
            onSelectRound={(round) => { setDispatchMode("live"); setTab(round.state === "complete" ? "done" : round.state === "active" ? "live" : "ready"); setSelection({ kind: "round", item: round }); }}
            onSelectException={(item) => { setDispatchMode("live"); setTab("action"); setSelection({ kind: "exception", item }); }}
            onSelectDelivery={(item) => { setDispatchMode("plan"); setSelection({ kind: "delivery", item }); }}
          />
          <div className="v45-map-mode" onClick={(event) => event.stopPropagation()}>
            <button type="button" aria-haspopup="menu" aria-expanded={mapMenuOpen} onClick={() => setMapMenuOpen((open) => !open)}>{mapModeCopy[mapMode].label}<span>▾</span></button>
            <div className={`v45-map-mode-menu ${mapMenuOpen ? "open" : ""}`} role="menu">
              {(["operations", "satellite"] as OperationsMapMode[]).map((item) => <button key={item} type="button" role="menuitemradio" aria-checked={mapMode === item} className={mapMode === item ? "on" : ""} onClick={() => { setMapMode(item); setMapMenuOpen(false); }}><b>{mapModeCopy[item].label}</b><span>{mapModeCopy[item].description}</span></button>)}
            </div>
          </div>
          {demoMode && <div className="v45-preview-badge"><b>PREVIEW DATA</b><span>Positions shown here are UX samples, not live drivers.</span></div>}
          {!demoMode && !loading && <div className="v45-map-truth"><b>Live map truth</b><span>Only server-reported driver positions and saved destination pins are shown. Routes appear after server routing is connected.</span></div>}
          {mapHint && <div className="v45-map-hint"><strong>{mapHint.split(" · ")[0]}</strong> · {mapHint.split(" · ").slice(1).join(" · ")}</div>}
          <div className="v45-legend"><span><i className="own" />Driver position</span><span><i className="destination" />Destination</span></div>
          <button className="v45-focus" type="button" onClick={() => window.dispatchEvent(new CustomEvent("rounds-map-control", { detail: "focus" }))}><FocusIcon />Focus map</button>
          <div className="v45-camera">
            <button type="button" title="Zoom in" onClick={() => window.dispatchEvent(new CustomEvent("rounds-map-control", { detail: "zoom-in" }))}>+</button>
            <button type="button" title="Zoom out" onClick={() => window.dispatchEvent(new CustomEvent("rounds-map-control", { detail: "zoom-out" }))}>−</button>
            <button type="button" title="Rotate left" onClick={() => window.dispatchEvent(new CustomEvent("rounds-map-control", { detail: "rotate-left" }))}>↶</button>
            <button type="button" className="compass" title="Return North" onClick={() => window.dispatchEvent(new CustomEvent("rounds-map-control", { detail: "north" }))}><span style={{ transform: `rotate(${-mapCamera.bearing}deg)` }}>↑</span><small>{Math.round((mapCamera.bearing % 360 + 360) % 360)}°</small></button>
            <button type="button" title="Rotate right" onClick={() => window.dispatchEvent(new CustomEvent("rounds-map-control", { detail: "rotate-right" }))}>↷</button>
            <button type="button" className={mapCamera.pitch >= 20 ? "on" : ""} title="Toggle 2D / 3D" onClick={() => window.dispatchEvent(new CustomEvent("rounds-map-control", { detail: "toggle-pitch" }))}>{mapCamera.pitch >= 20 ? "2D" : "3D"}</button>
          </div>
        </div>

        <aside className={`v45-drawer ${selection ? "open" : ""}`} aria-hidden={!selection}>
          <header><div><small>{selection?.kind === "exception" ? "ORDER DECISION" : selection?.kind === "delivery" ? "PLANNING DELIVERY" : "LIVE ROUND"}</small><h2>{selection?.kind === "exception" ? selection.item.recipientName : selection?.kind === "round" ? selection.item.reference : selection?.kind === "delivery" ? selection.item.recipientName : ""}</h2><p>{selection?.kind === "exception" ? `#${selection.item.deliveryReference} · ${selection.item.rawAddress}` : selection?.kind === "round" ? `${selection.item.driverName} · ${selection.item.stopCount} Stops` : selection?.kind === "delivery" ? `#${selection.item.reference} · ${selection.item.rawAddress}` : ""}</p></div><button type="button" onClick={() => setSelection(null)} aria-label="Close drawer"><CloseIcon /></button></header>
          <div className="v45-drawer-body">{selection?.kind === "exception" ? <ExceptionDrawer item={selection.item} accessToken={accessToken} tenant={tenant} onCommunications={onCommunications} onResolved={() => { setSelection(null); void load(); }} /> : selection?.kind === "round" ? <RoundDrawer item={selection.item} onCommunications={onCommunications} onOpen={() => setRoundDetailId(selection.item.id)} /> : selection?.kind === "delivery" ? <PlanningDrawer item={selection.item} timezone={tenant.timezone} /> : null}</div>
        </aside>
      </section>

      {roundDetailId && accessToken && <RoundDetailWorkspace accessToken={accessToken} tenant={tenant} roundId={roundDetailId} onClose={() => setRoundDetailId("")} onCommunications={(threadId) => { setRoundDetailId(""); onCommunications(threadId); }} />}

      {deliveriesOpen && accessToken && <DeliveriesWorkspace
        accessToken={accessToken}
        tenant={tenant}
        refreshKey={deliveryRefreshKey}
        onAddDelivery={onAddDelivery}
        onBackToDispatch={() => onCloseDeliveries?.()}
        onOpenPlanning={(item: OperationsDeliveryItem) => {
          onCloseDeliveries?.();
          setDispatchMode("plan");
          setPlanningDate(item.serviceDate);
          setQuery(item.reference);
          setSelection(null);
        }}
        onCommunications={() => onCommunications()}
      />}

      {deliveryIntakeOpen && <>
        <button className="v45-intake-scrim" type="button" aria-label="Close delivery intake" onClick={onCloseDeliveryIntake} />
        <aside className="v45-intake-drawer" role="dialog" aria-modal="true" aria-labelledby="v45-intake-title">
          <header><div><small>+ DELIVERIES</small><h2 id="v45-intake-title">Add delivery</h2><p>Create one canonical delivery for the unplanned pool.</p></div><button type="button" onClick={onCloseDeliveryIntake} aria-label="Close delivery intake"><CloseIcon /></button></header>
          <div className="v45-intake-body">{deliveryIntake}</div>
        </aside>
      </>}
    </div>
  </main>;
}

function ExceptionRow({ item, selected, onSelect, timezone }: { item: OperationsActionException; selected: boolean; onSelect: () => void; timezone: string }) {
  return <button type="button" className={`v45-order ${selected ? "selected" : ""}`} onClick={onSelect}><span className="v45-order-line"><span><b>{item.recipientName}</b><small>{item.rawAddress}</small></span><em>#{item.deliveryReference}</em></span><span className="v45-order-foot"><span>{shortTime(item.reportedAt, timezone)}</span><span>{item.stage}</span><b>{exceptionLabels[item.category]}</b></span></button>;
}

function RoundRow({ item, selected, onSelect }: { item: OperationsRoundSummary; selected: boolean; onSelect: () => void }) {
  return <button type="button" className={`v45-order round ${selected ? "selected" : ""}`} onClick={onSelect}><span className="v45-order-line"><span><b>{item.reference}</b><small>{item.driverName}</small></span><em>{item.stopCount} Stops</em></span><span className="v45-order-foot"><span>{item.custodyStopCount} custody</span><span>{item.openExceptionCount} action</span><b>{item.state}</b></span></button>;
}

function PlanningQueue({ planning, planningDate, query, selection, selectedStops, anchor, setSelection, onToggle, timezone }: { planning: OperationsPlanningProjection | null; planningDate: string; query: string; selection: Selection; selectedStops: string[]; anchor?: UnplannedDeliverySummary; setSelection: (selection: Selection) => void; onToggle: (item: UnplannedDeliverySummary) => void; timezone: string }) {
  const deliveries = planning?.unplannedDeliveries.filter((item) => item.serviceDate === planningDate && (!query.trim() || `${item.reference} ${item.recipientName} ${item.rawAddress}`.toLowerCase().includes(query.trim().toLowerCase()))) ?? [];
  return <><div className="v45-group"><b>Unplanned deliveries</b><span>{deliveries.length}</span></div>{!planning ? <div className="v45-empty">Loading the delivery pool…</div> : deliveries.length === 0 ? <div className="v45-empty"><b>No unplanned deliveries for this date.</b><span>Add a delivery or choose another planning date.</span></div> : deliveries.map((item) => <PlanningRow key={item.stopId} item={item} inspected={selection?.kind === "delivery" && selection.item.stopId === item.stopId} selectedOrder={selectedStops.includes(item.stopId) ? selectedStops.indexOf(item.stopId) + 1 : 0} disabled={Boolean(anchor && !selectedStops.includes(item.stopId) && (anchor.serviceDate !== item.serviceDate || anchor.pickupLocationId !== item.pickupLocationId))} onInspect={() => setSelection({ kind: "delivery", item })} onToggle={() => onToggle(item)} timezone={timezone} />)}</>;
}

function PlanningRow({ item, inspected, selectedOrder, disabled, onInspect, onToggle, timezone }: { item: UnplannedDeliverySummary; inspected: boolean; selectedOrder: number; disabled: boolean; onInspect: () => void; onToggle: () => void; timezone: string }) {
  return <article className={`v45-order round planning ${inspected ? "selected" : ""} ${selectedOrder ? "proposed" : ""} ${disabled ? "disabled" : ""}`}><button type="button" className="v45-order-inspect" onClick={onInspect}><span className="v45-order-line"><span><b>{item.recipientName}</b><small>{item.rawAddress}</small></span><em>#{item.reference}</em></span><span className="v45-order-foot"><span>{shortTime(item.windowStart, timezone)}–{shortTime(item.windowEnd, timezone)}</span><span>{item.manifestSummary}</span><b>Ready</b></span></button><button className="v45-plan-toggle" type="button" disabled={disabled} aria-label={selectedOrder ? `Remove ${item.reference} from proposed Round` : `Add ${item.reference} to proposed Round`} onClick={onToggle}>{selectedOrder || "+"}</button></article>;
}

function ExceptionDrawer({ item, accessToken, tenant, onCommunications, onResolved }: { item: OperationsActionException; accessToken?: string; tenant: OperationsTenant; onCommunications: (threadId?: string) => void; onResolved: () => void }) {
  const [resolving, setResolving] = useState(false);
  const [note, setNote] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [resolutionError, setResolutionError] = useState("");
  const [idempotencyKey] = useState(() => crypto.randomUUID());
  const isPickupCorrection = item.stage === "pickup";
  const canResolve = Boolean(accessToken && tenant.role !== "viewer" && item.stopState === "exception" && (
    isPickupCorrection
      ? item.roundState === "approved" || item.roundState === "loading"
      : item.category === "damaged_item" && item.roundState === "active"
  ));

  async function resolveException() {
    if (!accessToken || !canResolve || !note.trim()) return;
    setSubmitting(true); setResolutionError("");
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/exceptions/${item.id}/${isPickupCorrection ? "resolve" : "confirm-return"}`, {
        method: "POST",
        headers: { authorization: `Bearer ${accessToken}`, "content-type": "application/json", "idempotency-key": `operations-exception:${idempotencyKey}`, "x-rounds-tenant-id": tenant.id, "x-trace-id": crypto.randomUUID() },
        body: JSON.stringify({ stopId: item.stopId, expectedStopVersion: item.stopVersion, ...(isPickupCorrection ? { resolution: "pickup_corrected" } : {}), note: note.trim() }),
      });
      const body = await response.json() as { status?: string; error?: { message?: string } };
      if (!response.ok || body.status !== "committed") throw new Error(body.error?.message ?? `Resolution HTTP ${response.status}`);
      onResolved();
    } catch (caught) { setResolutionError(caught instanceof Error ? caught.message : "Exception could not be resolved"); }
    finally { setSubmitting(false); }
  }

  return <><section className="v45-decision"><small>NEXT DECISION</small><h3>Review {exceptionLabels[item.category].toLowerCase()} report.</h3><p>{item.note || "The driver reported an item problem without an additional note."}</p><div><span><small>Stage</small><b>{item.stage}</b></span><span><small>Reported</small><b>{shortTime(item.reportedAt, tenant.timezone)}</b></span><span><small>State</small><b>Action</b></span></div></section><section className="v45-detail"><h4>Delivery truth <span>realtime</span></h4><dl><div><dt>Round</dt><dd>{item.roundReference}</dd></div><div><dt>Driver</dt><dd>{item.driverName}</dd></div><div><dt>Stop</dt><dd>{item.stopSequence} · {item.stopState} · v{item.stopVersion}</dd></div><div><dt>Manifest</dt><dd>Version {item.manifestVersion}</dd></div></dl></section>{resolving && <section className="v45-resolution"><small>AUDITED RESOLUTION</small><h4>{isPickupCorrection ? "Confirm the pickup issue is corrected" : "Confirm the damaged item was returned"}</h4><p>{isPickupCorrection ? <>This releases the Stop back to <b>Assigned</b>. The driver must physically re-check the manifest before custody transfers.</> : <>Use this only after UrbanFlowers physically receives the item. The original delivery becomes <b>Returned</b> and its delivery Stop closes without POD.</>}</p><label>Operations evidence note<textarea autoFocus value={note} maxLength={500} onChange={(event) => setNote(event.target.value)} placeholder={isPickupCorrection ? "What was corrected, checked, and by whom?" : "Who returned the item, who received it, and where?"} /></label>{resolutionError && <div role="alert">{resolutionError}</div>}<div><button type="button" onClick={() => { setResolving(false); setResolutionError(""); }}>Cancel</button><button type="button" className="primary" disabled={submitting || !note.trim()} onClick={() => void resolveException()}>{submitting ? "Committing…" : isPickupCorrection ? "Confirm corrected & resume pickup" : "Confirm physical return"}</button></div></section>}<div className="v45-drawer-actions">{!resolving && canResolve && <button className="primary" type="button" onClick={() => setResolving(true)}>{isPickupCorrection ? "Resolve corrected pickup" : "Confirm returned item"}</button>}<button disabled={!item.operationsThreadId} onClick={() => onCommunications(item.operationsThreadId)}>Message driver</button>{!canResolve && <small>{tenant.role === "viewer" ? "Viewer access is read-only." : item.stage === "delivery" && item.category !== "damaged_item" ? "This delivery exception needs a different explicit outcome." : "Refresh before resolving this Stop."}</small>}</div></>;
}

function RoundDrawer({ item, onCommunications, onOpen }: { item: OperationsRoundSummary; onCommunications: (threadId?: string) => void; onOpen: () => void }) {
  return <><section className="v45-decision"><small>ROUND STATUS</small><h3>{item.state === "active" ? "Round is moving." : item.state === "complete" ? "Round completed." : "Round is ready for execution."}</h3><p>Dispatch sees the same server-authoritative operational state produced by the driver app.</p><div><span><small>Stops</small><b>{item.stopCount}</b></span><span><small>Custody</small><b>{item.custodyStopCount}</b></span><span><small>Action</small><b>{item.openExceptionCount}</b></span></div></section><section className="v45-detail"><h4>Assignment <span>live</span></h4><dl><div><dt>Driver</dt><dd>{item.driverName}</dd></div><div><dt>Service date</dt><dd>{item.serviceDate}</dd></div><div><dt>State</dt><dd>{item.state}</dd></div></dl></section><div className="v45-drawer-actions"><button className="primary" onClick={onOpen}>Open Round details</button><button onClick={() => onCommunications()}>Open communications</button></div></>;
}

function PlanningDrawer({ item, timezone }: { item: UnplannedDeliverySummary; timezone: string }) {
  return <><section className="v45-decision"><small>PLAN INPUT</small><h3>Ready to place into a physical Round.</h3><p>Rounds will compare the delivery window, pickup, driver shift, vehicle and cargo limits before approval.</p><div><span><small>Window</small><b>{shortTime(item.windowStart, timezone)}</b></span><span><small>Service</small><b>{item.serviceDate}</b></span><span><small>State</small><b>Ready</b></span></div></section><section className="v45-detail"><h4>Delivery <span>unplanned</span></h4><dl><div><dt>Reference</dt><dd>#{item.reference}</dd></div><div><dt>Destination</dt><dd>{item.rawAddress}</dd></div><div><dt>Manifest</dt><dd>{item.manifestSummary}</dd></div></dl></section><div className="v45-drawer-actions"><button className="primary">Add to proposed Round</button><button>Inspect destination on map</button></div></>;
}

function SearchIcon() { return <svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>; }
function MessageIcon() { return <svg viewBox="0 0 24 24"><path d="M4 5h16v11H8l-4 4z"/><path d="M8 9h8M8 12h5"/></svg>; }
function BellIcon() { return <svg viewBox="0 0 24 24"><path d="M15 17h5l-1.4-1.4A2 2 0 0 1 18 14.2V11a6 6 0 1 0-12 0v3.2a2 2 0 0 1-.6 1.4L4 17h5"/><path d="M10 17a2 2 0 0 0 4 0"/></svg>; }
function UserIcon() { return <svg viewBox="0 0 24 24"><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/></svg>; }
function ChevronIcon() { return <svg viewBox="0 0 24 24"><path d="m9 18 6-6-6-6"/></svg>; }
function CloseIcon() { return <svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6 6 18"/></svg>; }
function FocusIcon() { return <svg viewBox="0 0 24 24"><path d="M8 3H3v5M16 3h5v5M21 16v5h-5M3 16v5h5"/></svg>; }
