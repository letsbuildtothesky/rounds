"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import type {
  OperationsActionException,
  OperationsActionProjection,
  OperationsRoundSummary,
  OperationsTenant,
} from "@rounds/contracts";

const roundsApiUrl = process.env.NEXT_PUBLIC_ROUNDS_API_URL ?? "http://127.0.0.1:8080";

type QueueTab = "action" | "ready" | "live" | "done";
type Selection = { kind: "exception"; item: OperationsActionException } | { kind: "round"; item: OperationsRoundSummary } | null;
type ApiError = { error?: { message?: string } };

type Props = {
  accessToken: string;
  tenant: OperationsTenant;
  userName: string;
  onAddDelivery: () => void;
  onHistory: () => void;
  onCommunications: (threadId?: string) => void;
  onSignOut: () => void;
};

const exceptionLabels: Record<OperationsActionException["category"], string> = {
  missing_item: "Missing item",
  wrong_item: "Wrong item",
  damaged_item: "Damaged item",
};

const positions = [
  { left: "44%", top: "25%" },
  { left: "68%", top: "48%" },
  { left: "29%", top: "61%" },
  { left: "77%", top: "32%" },
];

function initials(name: string): string {
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "DR";
}

function shortTime(value: string, timezone: string): string {
  return new Intl.DateTimeFormat("en-GB", { hour: "2-digit", minute: "2-digit", timeZone: timezone }).format(new Date(value));
}

export function OperationsWorkstation({ accessToken, tenant, userName, onAddDelivery, onHistory, onCommunications, onSignOut }: Props) {
  const [projection, setProjection] = useState<OperationsActionProjection | null>(null);
  const [tab, setTab] = useState<QueueTab>("action");
  const [query, setQuery] = useState("");
  const [selection, setSelection] = useState<Selection>(null);
  const [loading, setLoading] = useState(true);
  const [stale, setStale] = useState(false);
  const [error, setError] = useState("");
  const [profileOpen, setProfileOpen] = useState(false);

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
      setError("");
      setStale(false);
    } catch (caught) {
      if (quiet) setStale(true);
      else setError(caught instanceof Error ? caught.message : "Dispatch could not be loaded");
    } finally {
      if (!quiet) setLoading(false);
    }
  }, [accessToken, tenant.id]);

  useEffect(() => {
    void load();
    const timer = window.setInterval(() => void load(true), 5000);
    return () => window.clearInterval(timer);
  }, [load]);

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

  return <main className="v45-app">
    <header className="v45-topbar">
      <div className="v45-wordmark">Rounds<i /></div>
      <div className="v45-workspace"><b>{tenant.displayName}</b><span>Bangkok · Automatic dispatch</span></div>
      <nav className="v45-nav" aria-label="Operations sections">
        <button className="on">Dispatch</button>
        <button type="button">Drivers</button>
        <button type="button" onClick={onHistory}>History</button>
        <button type="button">Settings</button>
      </nav>
      <div className="v45-spacer" />
      <button className="v45-network" type="button"><i /><span>Network enabled</span><ChevronIcon /></button>
      <button className="v45-util" type="button" title="Driver communications" onClick={() => onCommunications()}><MessageIcon />{buckets.action.length > 0 && <b>{buckets.action.length}</b>}</button>
      <button className="v45-util" type="button" title="Operational alerts" onClick={() => setTab("action")}><BellIcon /></button>
      <div className="v45-profile-wrap"><button className="v45-util" type="button" title="Business settings" onClick={() => setProfileOpen((open) => !open)}><UserIcon /></button>{profileOpen && <div className="v45-profile-menu"><strong>{userName}</strong><span>{tenant.displayName}</span><button type="button" onClick={onSignOut}>Sign out</button></div>}</div>
    </header>

    {stale && <div className="v45-system-strip"><i /><b>Last-known operational view</b><span>Live refresh is paused. Decisions are withheld until current truth returns.</span><button onClick={() => void load()}>Retry</button></div>}

    <div className="v45-board">
      <aside className="v45-rail">
        <div className="v45-rail-head">
          <div className="v45-rail-title"><div><h1>Dispatch</h1><p>What needs attention now.</p></div><button type="button" className="v45-add" onClick={onAddDelivery}>+ Deliveries</button></div>
          <div className="v45-mode"><button className="on" type="button">Live</button><button type="button">Plan <span>{buckets.ready.length}</span></button></div>
          <div className="v45-scope"><label>Delivery view<select defaultValue="all"><option value="all">All deliveries</option><option value="today">Today</option></select></label><p><b>{buckets.action.length} action</b><span>·</span><b>{activeRounds} live</b><span>·</span><span>{buckets.done.length} completed today</span></p></div>
          <div className="v45-tabs" role="tablist">
            {(["action", "ready", "live", "done"] as QueueTab[]).map((item) => <button key={item} type="button" role="tab" aria-selected={tab === item} className={tab === item ? "on" : ""} onClick={() => { setTab(item); setSelection(null); }}><b>{buckets[item].length}</b>{item[0]!.toUpperCase() + item.slice(1)}</button>)}
          </div>
          <label className="v45-search"><SearchIcon /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search order, customer or area" /></label>
        </div>
        <div className="v45-queue">
          <div className={`v45-group ${tab === "action" ? "action" : ""}`}><b>{tab === "action" ? "Needs action" : tab === "ready" ? "Ready" : tab === "live" ? "Live deliveries" : "Recently completed"}</b><span>{visible.length}</span></div>
          {loading ? <div className="v45-empty">Checking live Operations truth…</div> : error ? <div className="v45-empty error"><b>Couldn&apos;t load Dispatch</b><span>{error}</span><button onClick={() => void load()}>Retry</button></div> : visible.length === 0 ? <div className="v45-empty"><b>{tab === "action" ? "Nothing needs attention." : `No ${tab} work right now.`}</b><span>{tab === "action" ? "The exception queue is clear." : "Live work appears here automatically."}</span></div> : tab === "action" ? (visible as OperationsActionException[]).map((item) => <ExceptionRow key={item.id} item={item} selected={selection?.kind === "exception" && selection.item.id === item.id} onSelect={() => setSelection({ kind: "exception", item })} timezone={tenant.timezone} />) : (visible as OperationsRoundSummary[]).map((item) => <RoundRow key={item.id} item={item} selected={selection?.kind === "round" && selection.item.id === item.id} onSelect={() => setSelection({ kind: "round", item })} />)}
        </div>
      </aside>

      <section className="v45-map-wrap">
        <div className="v45-map-header"><strong>Bangkok · Live</strong><span>{tab === "action" ? "All deliveries" : `${visible.length} ${tab}`}</span><button>Rounds</button><button><i />Automatic</button><div className="v45-spacer" /><em><i />{stale ? "Connection delayed" : "On time"}</em><span>Live rounds <b>{activeRounds}</b></span></div>
        <div className="v45-map-body">
          <div className="v45-map-grid" />
          <div className="v45-water" />
          <div className="v45-park one" /><div className="v45-park two" />
          <div className="v45-road h1" /><div className="v45-road h2" /><div className="v45-road h3" /><div className="v45-road v1" /><div className="v45-road v2" /><div className="v45-road v3" />
          <svg className="v45-routes" viewBox="0 0 1000 700" preserveAspectRatio="none" aria-hidden="true"><path className="shadow" d="M115,430 L220,405 L300,315 L420,320 L500,190 L610,215 L680,350 L825,385"/><path d="M115,430 L220,405 L300,315 L420,320 L500,190 L610,215 L680,350 L825,385"/><path className="shadow" d="M330,585 L440,520 L545,555 L650,475 L820,460"/><path className="green" d="M330,585 L440,520 L545,555 L650,475 L820,460"/></svg>
          <span className="v45-place asoke">ASOKE</span><span className="v45-place sukhumvit">SUKHUMVIT</span><span className="v45-place thonglor">THONGLOR</span><span className="v45-place sathorn">SATHORN</span>
          {(projection?.rounds ?? []).slice(0, 4).map((round, index) => <button key={round.id} className={`v45-driver ${selection?.kind === "round" && selection.item.id === round.id ? "selected" : ""}`} style={positions[index]} onClick={() => { setTab(round.state === "complete" ? "done" : round.state === "active" ? "live" : "ready"); setSelection({ kind: "round", item: round }); }} title={round.driverName}>{initials(round.driverName)}</button>)}
          {(projection?.exceptions ?? []).slice(0, 3).map((item, index) => <button key={item.id} className="v45-stop" style={{ left: `${70 + index * 7}%`, top: `${31 + index * 12}%` }} onClick={() => { setTab("action"); setSelection({ kind: "exception", item }); }}>{index + 1}</button>)}
          <div className="v45-map-mode"><button>Operations <span>▾</span></button></div>
          <div className="v45-legend"><span><i className="own" />Own</span><span><i className="network" />Network</span><span><i className="traffic" />Traffic impact</span></div>
          <button className="v45-focus"><FocusIcon />Focus map</button><div className="v45-zoom"><button>+</button><button>−</button></div>
        </div>

        <aside className={`v45-drawer ${selection ? "open" : ""}`} aria-hidden={!selection}>
          <header><div><small>{selection?.kind === "exception" ? "ORDER DECISION" : "LIVE ROUND"}</small><h2>{selection?.kind === "exception" ? selection.item.recipientName : selection?.kind === "round" ? selection.item.reference : ""}</h2><p>{selection?.kind === "exception" ? `#${selection.item.deliveryReference} · ${selection.item.rawAddress}` : selection?.kind === "round" ? `${selection.item.driverName} · ${selection.item.stopCount} Stops` : ""}</p></div><button type="button" onClick={() => setSelection(null)} aria-label="Close drawer"><CloseIcon /></button></header>
          <div className="v45-drawer-body">{selection?.kind === "exception" ? <ExceptionDrawer item={selection.item} timezone={tenant.timezone} onCommunications={onCommunications} /> : selection?.kind === "round" ? <RoundDrawer item={selection.item} onCommunications={onCommunications} /> : null}</div>
        </aside>
      </section>
    </div>
  </main>;
}

function ExceptionRow({ item, selected, onSelect, timezone }: { item: OperationsActionException; selected: boolean; onSelect: () => void; timezone: string }) {
  return <button type="button" className={`v45-order ${selected ? "selected" : ""}`} onClick={onSelect}><span className="v45-order-line"><span><b>{item.recipientName}</b><small>{item.rawAddress}</small></span><em>#{item.deliveryReference}</em></span><span className="v45-order-foot"><span>{shortTime(item.reportedAt, timezone)}</span><span>{item.stage}</span><b>{exceptionLabels[item.category]}</b></span></button>;
}

function RoundRow({ item, selected, onSelect }: { item: OperationsRoundSummary; selected: boolean; onSelect: () => void }) {
  return <button type="button" className={`v45-order round ${selected ? "selected" : ""}`} onClick={onSelect}><span className="v45-order-line"><span><b>{item.reference}</b><small>{item.driverName}</small></span><em>{item.stopCount} Stops</em></span><span className="v45-order-foot"><span>{item.custodyStopCount} custody</span><span>{item.openExceptionCount} action</span><b>{item.state}</b></span></button>;
}

function ExceptionDrawer({ item, timezone, onCommunications }: { item: OperationsActionException; timezone: string; onCommunications: (threadId?: string) => void }) {
  return <><section className="v45-decision"><small>NEXT DECISION</small><h3>Review {exceptionLabels[item.category].toLowerCase()} report.</h3><p>{item.note || "The driver reported an item problem without an additional note."}</p><div><span><small>Stage</small><b>{item.stage}</b></span><span><small>Reported</small><b>{shortTime(item.reportedAt, timezone)}</b></span><span><small>State</small><b>Action</b></span></div></section><section className="v45-detail"><h4>Delivery truth <span>realtime</span></h4><dl><div><dt>Round</dt><dd>{item.roundReference}</dd></div><div><dt>Driver</dt><dd>{item.driverName}</dd></div><div><dt>Stop</dt><dd>{item.stopSequence} · {item.stopState}</dd></div><div><dt>Manifest</dt><dd>Version {item.manifestVersion}</dd></div></dl></section><div className="v45-drawer-actions"><button className="primary" disabled={!item.operationsThreadId} onClick={() => onCommunications(item.operationsThreadId)}>Message driver</button><button>Inspect destination on map</button></div></>;
}

function RoundDrawer({ item, onCommunications }: { item: OperationsRoundSummary; onCommunications: (threadId?: string) => void }) {
  return <><section className="v45-decision"><small>ROUND STATUS</small><h3>{item.state === "active" ? "Round is moving." : item.state === "complete" ? "Round completed." : "Round is ready for execution."}</h3><p>Dispatch sees the same server-authoritative operational state produced by the driver app.</p><div><span><small>Stops</small><b>{item.stopCount}</b></span><span><small>Custody</small><b>{item.custodyStopCount}</b></span><span><small>Action</small><b>{item.openExceptionCount}</b></span></div></section><section className="v45-detail"><h4>Assignment <span>live</span></h4><dl><div><dt>Driver</dt><dd>{item.driverName}</dd></div><div><dt>Service date</dt><dd>{item.serviceDate}</dd></div><div><dt>State</dt><dd>{item.state}</dd></div></dl></section><div className="v45-drawer-actions"><button className="primary" onClick={() => onCommunications()}>Message driver</button><button>Open Round details</button></div></>;
}

function SearchIcon() { return <svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>; }
function MessageIcon() { return <svg viewBox="0 0 24 24"><path d="M4 5h16v11H8l-4 4z"/><path d="M8 9h8M8 12h5"/></svg>; }
function BellIcon() { return <svg viewBox="0 0 24 24"><path d="M15 17h5l-1.4-1.4A2 2 0 0 1 18 14.2V11a6 6 0 1 0-12 0v3.2a2 2 0 0 1-.6 1.4L4 17h5"/><path d="M10 17a2 2 0 0 0 4 0"/></svg>; }
function UserIcon() { return <svg viewBox="0 0 24 24"><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/></svg>; }
function ChevronIcon() { return <svg viewBox="0 0 24 24"><path d="m9 18 6-6-6-6"/></svg>; }
function CloseIcon() { return <svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6 6 18"/></svg>; }
function FocusIcon() { return <svg viewBox="0 0 24 24"><path d="M8 3H3v5M16 3h5v5M21 16v5h-5M3 16v5h5"/></svg>; }
