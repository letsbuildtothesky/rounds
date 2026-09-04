"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import type {
  OperationsDriverCapacityItem,
  OperationsDriversProjection,
  OperationsTenant,
  SetDriverRecurringScheduleResult,
  SetDriverShiftExceptionResult,
} from "@rounds/contracts";

const roundsApiUrl = process.env.NEXT_PUBLIC_ROUNDS_API_URL ?? "http://127.0.0.1:8080";
const weekdays = [
  { value: 1, short: "Mon" }, { value: 2, short: "Tue" }, { value: 3, short: "Wed" },
  { value: 4, short: "Thu" }, { value: 5, short: "Fri" }, { value: 6, short: "Sat" },
  { value: 7, short: "Sun" },
];

type ApiError = { error?: { message?: string } };
type Tab = "team" | "schedule" | "network";

type Props = {
  accessToken: string;
  tenant: OperationsTenant;
  onBackToDispatch: () => void;
  onHistory: () => void;
  onOpenRound: (roundId: string) => void;
  onCommunications: () => void;
};

function localDate(timezone: string): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: timezone, year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
}

function timeLabel(value: string | undefined, timezone: string): string {
  if (!value) return "—";
  return new Intl.DateTimeFormat("en-GB", { timeZone: timezone, hour: "2-digit", minute: "2-digit" }).format(new Date(value));
}

function titleCase(value: string): string {
  return value.replaceAll("_", " ").replace(/\b\w/g, (character) => character.toUpperCase());
}

function scheduleLabel(driver: OperationsDriverCapacityItem): string {
  if (!driver.schedule) return "Schedule required";
  const dayLabels = driver.schedule.weekdays.map((day) => weekdays.find((item) => item.value === day)?.short).filter(Boolean);
  const days = dayLabels.length === 7 ? "Every day" : dayLabels.join(", ");
  return `${days} · ${driver.schedule.startLocal.slice(0, 5)}–${driver.schedule.endLocal.slice(0, 5)}`;
}

export function DriversWorkspace({ accessToken, tenant, onBackToDispatch, onHistory, onOpenRound, onCommunications }: Props) {
  const [serviceDate, setServiceDate] = useState(() => localDate(tenant.timezone));
  const [projection, setProjection] = useState<OperationsDriversProjection | null>(null);
  const [tab, setTab] = useState<Tab>("team");
  const [query, setQuery] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [editing, setEditing] = useState<OperationsDriverCapacityItem | null>(null);
  const [editingException, setEditingException] = useState<OperationsDriverCapacityItem | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/drivers?serviceDate=${encodeURIComponent(serviceDate)}`, {
        headers: {
          authorization: `Bearer ${accessToken}`,
          "x-rounds-tenant-id": tenant.id,
          "x-trace-id": crypto.randomUUID(),
        },
      });
      const body = await response.json() as OperationsDriversProjection | ApiError;
      if (!response.ok) throw new Error((body as ApiError).error?.message ?? `Drivers HTTP ${response.status}`);
      setProjection(body as OperationsDriversProjection);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Drivers could not be loaded");
    } finally {
      setLoading(false);
    }
  }, [accessToken, serviceDate, tenant.id]);

  useEffect(() => { void load(); }, [load]);

  const visibleDrivers = useMemo(() => {
    const needle = query.trim().toLowerCase();
    return (projection?.drivers ?? []).filter((driver) => !needle || `${driver.displayName} ${driver.vehiclePlate ?? ""} ${driver.currentRound?.reference ?? ""}`.toLowerCase().includes(needle));
  }, [projection, query]);

  const observedLabel = projection ? new Intl.DateTimeFormat("en-GB", { timeZone: tenant.timezone, hour: "2-digit", minute: "2-digit" }).format(new Date(projection.observedAt)) : "—";
  const nextCapacity = useMemo(() => {
    if ((projection?.summary.availableNow ?? 0) > 0) return "Now";
    const next = (projection?.drivers ?? [])
      .flatMap((driver) => driver.availability.nextAvailableAt ? [driver.availability.nextAvailableAt] : [])
      .sort()[0];
    return next ? timeLabel(next, tenant.timezone) : "—";
  }, [projection, tenant.timezone]);
  const motorbikes = projection?.summary.vehicleGroups.motorbike ?? 0;
  const cars = projection?.summary.vehicleGroups.car ?? 0;

  return <section className="v45-drivers" aria-label="Drivers workspace">
    <header className="v45-drivers-head">
      <div><button className="v45-drivers-back" type="button" onClick={onBackToDispatch}><BackIcon /> Dispatch</button><h1>Drivers</h1><p>{tab === "team" ? "See who is working, what they are carrying, and when capacity becomes available." : tab === "network" ? "See live Network availability without confusing availability with performance." : "Shape own-fleet capacity with recurring schedules and date-specific exceptions."}</p></div>
      <div><small>Observed {observedLabel}</small><button type="button" onClick={() => void load()}>Refresh</button>{tab !== "schedule" && <button type="button" onClick={onHistory}>Driver history</button>}</div>
    </header>

    <nav className="v45-drivers-tabs" aria-label="Drivers sections">
      <button className={tab === "team" ? "on" : ""} type="button" onClick={() => setTab("team")}>Own team</button>
      <button className={tab === "network" ? "on" : ""} type="button" onClick={() => setTab("network")}>Network</button>
      <button className={tab === "schedule" ? "on" : ""} type="button" onClick={() => setTab("schedule")}>Schedule</button>
    </nav>

    {tab === "network" ? <div className="v45-drivers-deferred"><span>ROUNDS NETWORK · LATER SLICE</span><h2>Network drivers are not connected yet.</h2><p>This checkpoint is deliberately limited to your own team. No partner availability, exact location, performance or price is being simulated.</p><button type="button" onClick={() => setTab("team")}>Return to Own team</button></div> : <div className="v45-drivers-body">
      <section className="v45-drivers-hero">
        <div className="v45-drivers-section-head"><div><small>{tab === "schedule" ? "OWN FLEET · CAPACITY" : "OWN FLEET · LIVE"}</small><h2>{tab === "schedule" ? "Schedule shapes what Dispatch can promise." : "Your team right now."}</h2><p>{tab === "schedule" ? "Recurring work patterns set the baseline. Date exceptions override a single day without rewriting the normal week." : "Availability is calculated from shift state and current Rounds. Reliability evidence stays in History."}</p></div><div className="v45-drivers-command-live"><b><i />{tab === "schedule" ? `${projection?.summary.scheduled ?? 0} scheduled` : `${projection?.summary.ownDrivers ?? 0} active`}</b><span>{tab === "schedule" ? serviceDate : <>Next capacity <strong>{nextCapacity}</strong></>}</span></div></div>
        <div className="v45-driver-kpis" aria-label="Own team capacity summary">
          <div><span>Scheduled today</span><b>{projection?.summary.scheduled ?? "—"}</b><small>own drivers</small></div>
          <div><span>Active Rounds</span><b>{projection?.summary.activeRounds ?? "—"}</b><small>in progress</small></div>
          <div><span>{tab === "schedule" ? "Available now" : "Next available"}</span><b>{tab === "schedule" ? projection?.summary.availableNow ?? "—" : nextCapacity}</b><small>projected</small></div>
          <div><span>Motorbikes / cars</span><b>{motorbikes} / {cars}</b><small>today</small></div>
        </div>
      </section>

      <section className="v45-drivers-content">
        <header><div><small>{tab === "schedule" ? "RECURRING SHIFTS" : "OWN TEAM"}</small><h2>{tab === "schedule" ? "Schedule" : "Live work and capacity"}</h2></div><p>{visibleDrivers.length} driver{visibleDrivers.length === 1 ? "" : "s"}</p></header>
        <div className={`v45-drivers-tools ${tab === "team" ? "team" : ""}`}>
          <label><SearchIcon /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search driver, vehicle or Round" /></label>
          <label className="v45-drivers-date"><span>Service date</span><input type="date" value={serviceDate} onChange={(event) => setServiceDate(event.target.value)} /></label>
        </div>
        {loading ? <div className="v45-drivers-message">Checking own-team capacity…</div> : error ? <div className="v45-drivers-message error"><b>Couldn&apos;t load Drivers</b><span>{error}</span><button type="button" onClick={() => void load()}>Retry</button></div> : visibleDrivers.length === 0 ? <div className="v45-drivers-message"><b>No own drivers found.</b><span>Drivers appear after an active own-team relationship is configured.</span></div> : <div className="v45-driver-list">
          {visibleDrivers.map((driver) => tab === "schedule"
            ? <ScheduleRow key={driver.driverId} driver={driver} tenant={tenant} onEdit={() => setEditing(driver)} onException={() => setEditingException(driver)} />
            : <DriverRow key={driver.driverId} driver={driver} tenant={tenant} onSchedule={() => { setTab("schedule"); setEditing(driver); }} onOpenRound={onOpenRound} onCommunications={onCommunications} />)}
        </div>}
        {tab === "team" && <p className="v45-drivers-context"><strong>Operational context first.</strong> Current work and next availability help Dispatch act now. Cause-attributed reliability, attendance and custody evidence stay in History.</p>}
      </section>
    </div>}

    {editing && projection && <ScheduleDrawer driver={editing} projection={projection} accessToken={accessToken} tenant={tenant} onClose={() => setEditing(null)} onSaved={async () => { setEditing(null); await load(); }} />}
    {editingException && projection && <ShiftExceptionDrawer driver={editingException} projection={projection} serviceDate={serviceDate} accessToken={accessToken} tenant={tenant} onClose={() => setEditingException(null)} onSaved={async () => { setEditingException(null); await load(); }} />}
  </section>;
}

function DriverRow({ driver, tenant, onSchedule, onOpenRound, onCommunications }: { driver: OperationsDriverCapacityItem; tenant: OperationsTenant; onSchedule: () => void; onOpenRound: (roundId: string) => void; onCommunications: () => void }) {
  return <article className="v45-driver-row">
    <div className={`v45-driver-avatar presence-${driver.presence.state}`}>{driver.initials}<i /></div>
    <div className="v45-driver-identity"><h3>{driver.displayName}</h3><p>{driver.presence.state === "live" ? `Live · ${timeLabel(driver.presence.capturedAt, tenant.timezone)}` : driver.presence.state === "stale" ? `Last seen ${timeLabel(driver.presence.capturedAt, tenant.timezone)}` : "Location not reported"}</p></div>
    <div className="v45-driver-cell"><small>AVAILABILITY</small><b className={`availability-${driver.availability.state}`}>{driver.availability.label}</b><span>{driver.availability.projectionBasis}</span></div>
    <div className="v45-driver-cell"><small>VEHICLE + SHIFT</small><b>{driver.vehicleProfile?.displayName ?? "Vehicle setup required"}</b><span>{driver.vehiclePlate ?? "No plate"} · {driver.effectiveShift ? `${timeLabel(driver.effectiveShift.startAt, tenant.timezone)}–${timeLabel(driver.effectiveShift.endAt, tenant.timezone)}` : "Off shift"}</span></div>
    <div className="v45-driver-cell"><small>CURRENT WORK</small><b>{driver.currentRound?.reference ?? "No active Round"}</b><span>{driver.currentRound ? `${driver.currentRound.stopCount} Stops · ${titleCase(driver.currentRound.state)}` : `${driver.completedDeliveriesToday} completed today`}</span></div>
    <div className="v45-driver-actions">{driver.currentRound && <button type="button" onClick={() => onOpenRound(driver.currentRound!.id)}>Open Round</button>}<button type="button" onClick={onCommunications}>Message</button><button type="button" onClick={onSchedule}>Schedule</button></div>
  </article>;
}

function ScheduleRow({ driver, tenant, onEdit, onException }: { driver: OperationsDriverCapacityItem; tenant: OperationsTenant; onEdit: () => void; onException: () => void }) {
  return <article className="v45-schedule-row">
    <div className="v45-driver-avatar">{driver.initials}</div>
    <div><h3>{driver.displayName}</h3><p>{scheduleLabel(driver)}</p></div>
    <div><small>{driver.effectiveShift ? "TODAY" : "SERVICE DATE"}</small><b>{driver.effectiveShift ? `${timeLabel(driver.effectiveShift.startAt, tenant.timezone)}–${timeLabel(driver.effectiveShift.endAt, tenant.timezone)}` : "Off shift"}</b></div>
    <div><small>VEHICLE PROFILE</small><b>{driver.vehicleProfile?.displayName ?? "Not assigned"}</b>{driver.vehicleProfile?.requiresReview && <span>Conservative default · review required</span>}</div>
    <div className="v45-schedule-actions"><button type="button" onClick={onEdit}>{driver.schedule ? "Edit schedule" : "Set schedule"}</button><button type="button" onClick={onException}>{driver.dateException ? "Edit date" : "Date exception"}</button></div>
  </article>;
}

function ScheduleDrawer({ driver, projection, accessToken, tenant, onClose, onSaved }: { driver: OperationsDriverCapacityItem; projection: OperationsDriversProjection; accessToken: string; tenant: OperationsTenant; onClose: () => void; onSaved: () => Promise<void> }) {
  const fallbackProfile = driver.vehicleProfile?.id ?? projection.vehicleProfiles[0]?.id ?? "";
  const [selectedDays, setSelectedDays] = useState(driver.schedule?.weekdays ?? [1, 2, 3, 4, 5]);
  const [startLocal, setStartLocal] = useState(driver.schedule?.startLocal.slice(0, 5) ?? "08:00");
  const [endLocal, setEndLocal] = useState(driver.schedule?.endLocal.slice(0, 5) ?? "18:00");
  const [vehicleProfileId, setVehicleProfileId] = useState(driver.schedule ? driver.vehicleProfile?.id ?? fallbackProfile : fallbackProfile);
  const [note, setNote] = useState(driver.schedule?.note ?? "");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  function toggleDay(day: number) {
    setSelectedDays((current) => current.includes(day) ? current.filter((item) => item !== day) : [...current, day].sort((a, b) => a - b));
  }

  async function save() {
    setSubmitting(true); setError("");
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/drivers/${driver.driverId}/recurring-schedule`, {
        method: "POST",
        headers: {
          authorization: `Bearer ${accessToken}`,
          "content-type": "application/json",
          "idempotency-key": `operations:${crypto.randomUUID()}`,
          "if-match-version": String(driver.schedule?.version ?? 0),
          "x-rounds-tenant-id": tenant.id,
          "x-trace-id": crypto.randomUUID(),
        },
        body: JSON.stringify({ weekdays: selectedDays, startLocal, endLocal, vehicleProfileId, ...(note.trim() ? { note: note.trim() } : {}) }),
      });
      const body = await response.json() as SetDriverRecurringScheduleResult | ApiError;
      if (!response.ok || !("status" in body) || body.status !== "committed") throw new Error((body as ApiError).error?.message ?? `Schedule HTTP ${response.status}`);
      await onSaved();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Schedule could not be saved");
    } finally { setSubmitting(false); }
  }

  const profile = projection.vehicleProfiles.find((item) => item.id === vehicleProfileId);
  return <div className="v45-driver-scrim" onClick={onClose}><aside className="v45-schedule-drawer" role="dialog" aria-modal="true" aria-labelledby="schedule-drawer-title" onClick={(event) => event.stopPropagation()}>
    <header><div><small>OWN TEAM · RECURRING</small><h2 id="schedule-drawer-title">{driver.displayName}</h2><p>Set the normal weekly shift and vehicle used for capacity planning.</p></div><button type="button" onClick={onClose} aria-label="Close schedule"><CloseIcon /></button></header>
    <div className="v45-schedule-form">
      <fieldset><legend>Working days</legend><div className="v45-weekdays">{weekdays.map((day) => <button className={selectedDays.includes(day.value) ? "on" : ""} type="button" key={day.value} onClick={() => toggleDay(day.value)}>{day.short}</button>)}</div></fieldset>
      <div className="v45-time-grid"><label>Shift starts<input type="time" value={startLocal} onChange={(event) => setStartLocal(event.target.value)} /></label><label>Shift ends<input type="time" value={endLocal} onChange={(event) => setEndLocal(event.target.value)} /></label></div>
      <label>Vehicle profile<select value={vehicleProfileId} onChange={(event) => setVehicleProfileId(event.target.value)}><option value="">Choose vehicle profile</option>{projection.vehicleProfiles.map((item) => <option key={item.id} value={item.id}>{item.displayName}</option>)}</select></label>
      {profile && <div className="v45-profile-summary"><small>PLANNING RULE</small><b>{titleCase(profile.vehicleGroup)} · {profile.maxStopsPerDeparture} Stop{profile.maxStopsPerDeparture === 1 ? "" : "s"} per departure</b><span>{titleCase(profile.departurePattern)} · {profile.planningDeliveriesPerBlock} deliveries per planning block</span>{profile.requiresReview && <em>Conservative default. Confirm this profile before production planning.</em>}</div>}
      <label>Schedule note <span>Optional</span><textarea value={note} maxLength={500} onChange={(event) => setNote(event.target.value)} placeholder="Operational note for this recurring shift" /></label>
      {error && <div className="v45-schedule-error" role="alert">{error}</div>}
    </div>
    <footer><button type="button" onClick={onClose}>Cancel</button><button className="primary" type="button" disabled={submitting || tenant.role === "viewer" || selectedDays.length === 0 || !startLocal || !endLocal || !vehicleProfileId} onClick={() => void save()}>{submitting ? "Saving…" : tenant.role === "viewer" ? "Viewer cannot save" : "Save recurring schedule"}</button></footer>
  </aside></div>;
}

function ShiftExceptionDrawer({ driver, projection, serviceDate, accessToken, tenant, onClose, onSaved }: { driver: OperationsDriverCapacityItem; projection: OperationsDriversProjection; serviceDate: string; accessToken: string; tenant: OperationsTenant; onClose: () => void; onSaved: () => Promise<void> }) {
  const existing = driver.dateException?.serviceDate === serviceDate ? driver.dateException : undefined;
  const fallbackProfile = existing?.vehicleProfileId ?? driver.vehicleProfile?.id ?? projection.vehicleProfiles[0]?.id ?? "";
  const [kind, setKind] = useState<"shift" | "off">(existing?.kind ?? "shift");
  const [startLocal, setStartLocal] = useState(existing?.startLocal?.slice(0, 5) ?? driver.schedule?.startLocal.slice(0, 5) ?? "08:00");
  const [endLocal, setEndLocal] = useState(existing?.endLocal?.slice(0, 5) ?? driver.schedule?.endLocal.slice(0, 5) ?? "18:00");
  const [vehicleProfileId, setVehicleProfileId] = useState(fallbackProfile);
  const [note, setNote] = useState(existing?.note ?? "");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  async function save() {
    setSubmitting(true); setError("");
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/drivers/${driver.driverId}/shift-exception`, {
        method: "POST",
        headers: {
          authorization: `Bearer ${accessToken}`,
          "content-type": "application/json",
          "idempotency-key": `operations:${crypto.randomUUID()}`,
          "if-match-version": String(existing?.version ?? 0),
          "x-rounds-tenant-id": tenant.id,
          "x-trace-id": crypto.randomUUID(),
        },
        body: JSON.stringify({ serviceDate, kind, ...(kind === "shift" ? { startLocal, endLocal, vehicleProfileId } : {}), ...(note.trim() ? { note: note.trim() } : {}) }),
      });
      const body = await response.json() as SetDriverShiftExceptionResult | ApiError;
      if (!response.ok || !("status" in body) || body.status !== "committed") throw new Error((body as ApiError).error?.message ?? `Date exception HTTP ${response.status}`);
      await onSaved();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Date exception could not be saved");
    } finally { setSubmitting(false); }
  }

  async function clearException() {
    if (!existing) return;
    setSubmitting(true); setError("");
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/drivers/${driver.driverId}/shift-exception`, {
        method: "DELETE",
        headers: { authorization: `Bearer ${accessToken}`, "content-type": "application/json", "idempotency-key": `operations:${crypto.randomUUID()}`, "if-match-version": String(existing.version), "x-rounds-tenant-id": tenant.id, "x-trace-id": crypto.randomUUID() },
        body: JSON.stringify({ serviceDate }),
      });
      const body = await response.json() as { status?: string; error?: { message?: string } };
      if (!response.ok || body.status !== "committed") throw new Error(body.error?.message ?? `Clear exception HTTP ${response.status}`);
      await onSaved();
    } catch (caught) { setError(caught instanceof Error ? caught.message : "Date exception could not be cleared"); }
    finally { setSubmitting(false); }
  }

  const profile = projection.vehicleProfiles.find((item) => item.id === vehicleProfileId);
  return <div className="v45-driver-scrim" onClick={onClose}><aside className="v45-schedule-drawer" role="dialog" aria-modal="true" aria-labelledby="exception-drawer-title" onClick={(event) => event.stopPropagation()}>
    <header><div><small>OWN TEAM · DATE EXCEPTION</small><h2 id="exception-drawer-title">{driver.displayName}</h2><p>Override the recurring schedule for {serviceDate}. This date wins in planning.</p></div><button type="button" onClick={onClose} aria-label="Close date exception"><CloseIcon /></button></header>
    <div className="v45-schedule-form">
      <div className="v45-exception-date"><small>SERVICE DATE</small><b>{serviceDate}</b><span>{existing ? `Existing override · version ${existing.version}` : "No date override yet"}</span></div>
      <fieldset><legend>Working state</legend><div className="v45-exception-kind"><button className={kind === "shift" ? "on" : ""} type="button" onClick={() => setKind("shift")}><b>Custom shift</b><span>Replace normal hours and vehicle</span></button><button className={kind === "off" ? "on" : ""} type="button" onClick={() => setKind("off")}><b>Day off</b><span>No own-team capacity that date</span></button></div></fieldset>
      {kind === "shift" && <><div className="v45-time-grid"><label>Shift starts<input type="time" value={startLocal} onChange={(event) => setStartLocal(event.target.value)} /></label><label>Shift ends<input type="time" value={endLocal} onChange={(event) => setEndLocal(event.target.value)} /></label></div><label>Vehicle profile<select value={vehicleProfileId} onChange={(event) => setVehicleProfileId(event.target.value)}><option value="">Choose vehicle profile</option>{projection.vehicleProfiles.map((item) => <option key={item.id} value={item.id}>{item.displayName}</option>)}</select></label>{profile && <div className="v45-profile-summary"><small>DATE-SPECIFIC PLANNING RULE</small><b>{titleCase(profile.vehicleGroup)} · {profile.maxStopsPerDeparture} Stop{profile.maxStopsPerDeparture === 1 ? "" : "s"} per departure</b><span>{titleCase(profile.departurePattern)} · {profile.planningDeliveriesPerBlock} deliveries per planning block</span></div>}</>}
      <label>Reason <span>Optional</span><textarea value={note} maxLength={500} onChange={(event) => setNote(event.target.value)} placeholder={kind === "off" ? "Why this driver is unavailable" : "Why this date differs from the recurring schedule"} /></label>
      {error && <div className="v45-schedule-error" role="alert">{error}</div>}
    </div>
    <footer>{existing && <button className="v45-clear-exception" type="button" disabled={submitting || tenant.role === "viewer"} onClick={() => void clearException()}>Use recurring schedule</button>}<button type="button" onClick={onClose}>Cancel</button><button className="primary" type="button" disabled={submitting || tenant.role === "viewer" || (kind === "shift" && (!startLocal || !endLocal || !vehicleProfileId))} onClick={() => void save()}>{submitting ? "Saving…" : tenant.role === "viewer" ? "Viewer cannot save" : "Save date exception"}</button></footer>
  </aside></div>;
}

function BackIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m15 18-6-6 6-6" /></svg>; }
function SearchIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="7" /><path d="m16 16 4 4" /></svg>; }
function CloseIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18" /></svg>; }
