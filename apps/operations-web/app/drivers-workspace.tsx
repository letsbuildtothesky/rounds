"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import type {
  OperationsDriverCapacityItem,
  OperationsDriversProjection,
  OperationsTenant,
  SetDriverRecurringScheduleResult,
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

export function DriversWorkspace({ accessToken, tenant, onBackToDispatch, onOpenRound, onCommunications }: Props) {
  const [serviceDate, setServiceDate] = useState(() => localDate(tenant.timezone));
  const [projection, setProjection] = useState<OperationsDriversProjection | null>(null);
  const [tab, setTab] = useState<Tab>("team");
  const [query, setQuery] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [editing, setEditing] = useState<OperationsDriverCapacityItem | null>(null);

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

  return <section className="v45-drivers" aria-label="Drivers workspace">
    <header className="v45-drivers-head">
      <div><button className="v45-drivers-back" type="button" onClick={onBackToDispatch}><BackIcon /> Dispatch</button><p>OWN-FLEET CAPACITY</p><h1>Drivers</h1><span>Shifts, vehicles and current work</span></div>
      <div><small>Observed {observedLabel}</small><button type="button" onClick={() => void load()}>Refresh</button></div>
    </header>

    <nav className="v45-drivers-tabs" aria-label="Drivers sections">
      <button className={tab === "team" ? "on" : ""} type="button" onClick={() => setTab("team")}>Own team <b>{projection?.summary.ownDrivers ?? 0}</b></button>
      <button className={tab === "network" ? "on" : ""} type="button" onClick={() => setTab("network")}>Network <small>Later slice</small></button>
      <button className={tab === "schedule" ? "on" : ""} type="button" onClick={() => setTab("schedule")}>Schedule <b>{projection?.summary.scheduled ?? 0}</b></button>
    </nav>

    {tab === "network" ? <div className="v45-drivers-deferred"><span>NETWORK CAPACITY</span><h2>Network drivers are not connected yet.</h2><p>This checkpoint is deliberately limited to your own team. No partner availability or price is being simulated.</p><button type="button" onClick={() => setTab("team")}>Return to Own team</button></div> : <>
      <section className="v45-driver-kpis" aria-label="Own team capacity summary">
        <div><small>OWN DRIVERS</small><b>{projection?.summary.ownDrivers ?? "—"}</b><span>Active team relationships</span></div>
        <div><small>AVAILABLE NOW</small><b>{projection?.summary.availableNow ?? "—"}</b><span>Schedule projection</span></div>
        <div><small>ACTIVE ROUNDS</small><b>{projection?.summary.activeRounds ?? "—"}</b><span>Loading or on the road</span></div>
        <div><small>SCHEDULE REQUIRED</small><b>{projection?.summary.scheduleRequired ?? "—"}</b><span>Needs dispatcher setup</span></div>
      </section>

      <div className="v45-drivers-tools">
        <label><SearchIcon /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search driver, vehicle or Round" /></label>
        <label className="v45-drivers-date"><span>Service date</span><input type="date" value={serviceDate} onChange={(event) => setServiceDate(event.target.value)} /></label>
      </div>

      <div className="v45-drivers-content">
        <header><div><small>{tab === "schedule" ? "RECURRING SHIFTS" : "OWN TEAM"}</small><h2>{tab === "schedule" ? "Schedule" : "Current capacity"}</h2></div><p>{visibleDrivers.length} driver{visibleDrivers.length === 1 ? "" : "s"} · {serviceDate}</p></header>
        {loading ? <div className="v45-drivers-message">Checking own-team capacity…</div> : error ? <div className="v45-drivers-message error"><b>Couldn&apos;t load Drivers</b><span>{error}</span><button type="button" onClick={() => void load()}>Retry</button></div> : visibleDrivers.length === 0 ? <div className="v45-drivers-message"><b>No own drivers found.</b><span>Drivers appear after an active own-team relationship is configured.</span></div> : <div className="v45-driver-list">
          {visibleDrivers.map((driver) => tab === "schedule"
            ? <ScheduleRow key={driver.driverId} driver={driver} tenant={tenant} onEdit={() => setEditing(driver)} />
            : <DriverRow key={driver.driverId} driver={driver} tenant={tenant} onSchedule={() => { setTab("schedule"); setEditing(driver); }} onOpenRound={onOpenRound} onCommunications={onCommunications} />)}
        </div>}
      </div>
    </>}

    {editing && projection && <ScheduleDrawer driver={editing} projection={projection} accessToken={accessToken} tenant={tenant} onClose={() => setEditing(null)} onSaved={async () => { setEditing(null); await load(); }} />}
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

function ScheduleRow({ driver, tenant, onEdit }: { driver: OperationsDriverCapacityItem; tenant: OperationsTenant; onEdit: () => void }) {
  return <article className="v45-schedule-row">
    <div className="v45-driver-avatar">{driver.initials}</div>
    <div><h3>{driver.displayName}</h3><p>{scheduleLabel(driver)}</p></div>
    <div><small>{driver.effectiveShift ? "TODAY" : "SERVICE DATE"}</small><b>{driver.effectiveShift ? `${timeLabel(driver.effectiveShift.startAt, tenant.timezone)}–${timeLabel(driver.effectiveShift.endAt, tenant.timezone)}` : "Off shift"}</b></div>
    <div><small>VEHICLE PROFILE</small><b>{driver.vehicleProfile?.displayName ?? "Not assigned"}</b>{driver.vehicleProfile?.requiresReview && <span>Conservative default · review required</span>}</div>
    <button type="button" onClick={onEdit}>{driver.schedule ? "Edit schedule" : "Set schedule"}</button>
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

function BackIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m15 18-6-6 6-6" /></svg>; }
function SearchIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="7" /><path d="m16 16 4 4" /></svg>; }
function CloseIcon() { return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18" /></svg>; }
