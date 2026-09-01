"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import type {
  OperationsPlanningProjection,
  OperationsTenant,
  PlanRoundResult,
  UnplannedDeliverySummary,
} from "@rounds/contracts";

const roundsApiUrl = process.env.NEXT_PUBLIC_ROUNDS_API_URL ?? "http://127.0.0.1:8080";

type Props = {
  accessToken: string;
  tenant: OperationsTenant;
};

type ApiError = { error?: { message?: string } };

function responseMessage(body: unknown, fallback: string): string {
  if (body && typeof body === "object" && "error" in body) {
    const message = (body as ApiError).error?.message;
    if (message) return message;
  }
  return fallback;
}

function nextRoundReference(deliveries: UnplannedDeliverySummary[]): string {
  const date = deliveries[0]?.serviceDate ?? new Date().toISOString().slice(0, 10);
  return `ROUND-${date.replaceAll("-", "")}-01`;
}

function timeLabel(value: string): string {
  return new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Bangkok",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}

export function DispatchPanel({ accessToken, tenant }: Props) {
  const [projection, setProjection] = useState<OperationsPlanningProjection | null>(null);
  const [selectedStops, setSelectedStops] = useState<string[]>([]);
  const [driverId, setDriverId] = useState("");
  const [reference, setReference] = useState("");
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState<Extract<PlanRoundResult, { status: "committed" }> | null>(null);
  const [idempotencyKey, setIdempotencyKey] = useState(() => crypto.randomUUID());

  const loadPlanning = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const response = await fetch(`${roundsApiUrl}/v1/operations/planning`, {
        headers: {
          authorization: `Bearer ${accessToken}`,
          "x-rounds-tenant-id": tenant.id,
          "x-trace-id": crypto.randomUUID(),
        },
      });
      const body = await response.json() as OperationsPlanningProjection | ApiError;
      if (!response.ok) throw new Error(responseMessage(body, `Planning HTTP ${response.status}`));
      const data = body as OperationsPlanningProjection;
      setProjection(data);
      setDriverId((current) => current || data.drivers[0]?.id || "");
      setReference((current) => current || nextRoundReference(data.unplannedDeliveries));
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Planning could not be loaded");
    } finally {
      setLoading(false);
    }
  }, [accessToken, tenant.id]);

  useEffect(() => { void loadPlanning(); }, [loadPlanning]);

  const chosenDeliveries = useMemo(() => projection?.unplannedDeliveries.filter((delivery) => selectedStops.includes(delivery.stopId)) ?? [], [projection, selectedStops]);
  const anchor = chosenDeliveries[0];

  function toggle(delivery: UnplannedDeliverySummary) {
    setSelectedStops((current) => current.includes(delivery.stopId)
      ? current.filter((stopId) => stopId !== delivery.stopId)
      : [...current, delivery.stopId]);
  }

  function incompatible(delivery: UnplannedDeliverySummary): boolean {
    return Boolean(anchor && !selectedStops.includes(delivery.stopId) && (
      anchor.serviceDate !== delivery.serviceDate || anchor.pickupLocationId !== delivery.pickupLocationId
    ));
  }

  async function approveRound() {
    if (!projection || !driverId || !selectedStops.length) return;
    setSubmitting(true);
    setError("");
    try {
      const response = await fetch(`${roundsApiUrl}/v1/rounds`, {
        method: "POST",
        headers: {
          authorization: `Bearer ${accessToken}`,
          "content-type": "application/json",
          "idempotency-key": `operations:${idempotencyKey}`,
          "x-rounds-tenant-id": tenant.id,
          "x-trace-id": crypto.randomUUID(),
        },
        body: JSON.stringify({
          reference: reference.trim(),
          serviceDate: chosenDeliveries[0]!.serviceDate,
          driverId,
          stopIds: selectedStops,
        }),
      });
      const body = await response.json() as PlanRoundResult | ApiError;
      if (!response.ok || !("status" in body) || body.status !== "committed") {
        throw new Error(responseMessage(body, `Round command HTTP ${response.status}`));
      }
      setSuccess(body);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Round could not be approved");
    } finally {
      setSubmitting(false);
    }
  }

  if (loading) return <section className="dispatch-loading"><span /><p>Loading unplanned deliveries…</p></section>;
  if (success) return <section className="success-panel dispatch-success"><div className="success-icon">✓</div><p className="eyebrow">ROUND APPROVED</p><h2>{success.state.reference} is assigned.</h2><p>{success.state.stopIds.length} Stop{success.state.stopIds.length === 1 ? "" : "s"} can now be retrieved by the Team driver.</p><dl><div><dt>Round ID</dt><dd>{success.state.roundId}</dd></div><div><dt>State</dt><dd>{success.state.roundState}</dd></div></dl><button className="primary-action" onClick={() => { setSuccess(null); setSelectedStops([]); setReference(""); setIdempotencyKey(crypto.randomUUID()); void loadPlanning(); }}>Plan another Round</button></section>;

  return <div className="dispatch-workspace">
    <section className="page-heading"><div><p className="eyebrow">OWN TEAM · MANUAL PLAN</p><h1>Build a Round</h1><p>Select a small ordered set of deliveries and approve it for one Team driver.</p></div><div className="secure-badge">Server-approved assignment</div></section>
    {error && <div className="alert error" role="alert"><div><strong>Couldn&apos;t continue</strong><span>{error}</span></div></div>}
    <div className="dispatch-grid">
      <section className="form-card stop-pool">
        <div className="dispatch-card-heading"><div><p className="eyebrow">UNPLANNED</p><h2>Delivery pool</h2></div><span>{projection?.unplannedDeliveries.length ?? 0} available</span></div>
        {!projection?.unplannedDeliveries.length ? <div className="pool-empty"><strong>No unplanned deliveries</strong><p>Add a delivery first, then return to Dispatch.</p></div> : <div className="delivery-pool-list">
          {projection.unplannedDeliveries.map((delivery) => {
            const disabled = incompatible(delivery);
            const selected = selectedStops.includes(delivery.stopId);
            return <button type="button" key={delivery.stopId} disabled={disabled} className={`pool-delivery ${selected ? "selected" : ""}`} onClick={() => toggle(delivery)}>
              <span className="pool-check">{selected ? selectedStops.indexOf(delivery.stopId) + 1 : ""}</span>
              <span className="pool-copy"><strong>{delivery.reference} · {delivery.recipientName}</strong><small>{delivery.rawAddress}</small><em>{delivery.manifestSummary}</em></span>
              <span className="pool-window">{timeLabel(delivery.windowStart)}–{timeLabel(delivery.windowEnd)}</span>
            </button>;
          })}
        </div>}
      </section>
      <aside className="form-card round-builder">
        <p className="eyebrow">APPROVAL</p><h2>Round details</h2><label className="field"><span>Round reference</span><input required value={reference} onChange={(event) => setReference(event.target.value)} /></label>
        <label className="field"><span>Team driver</span><select value={driverId} onChange={(event) => setDriverId(event.target.value)}><option value="">Choose driver</option>{projection?.drivers.map((driver) => <option key={driver.id} value={driver.id}>{driver.displayName}{driver.vehiclePlate ? ` · ${driver.vehiclePlate}` : ""}</option>)}</select></label>
        <div className="sequence-preview"><span>STOP ORDER</span>{chosenDeliveries.length ? chosenDeliveries.map((delivery, index) => <div key={delivery.stopId}><b>{index + 1}</b><p><strong>{delivery.recipientName}</strong><small>{delivery.reference}</small></p></div>) : <p className="sequence-empty">Select deliveries in the order the driver should visit them.</p>}</div>
        <div className="round-summary"><span>{chosenDeliveries.length} Stops</span><span>{anchor?.serviceDate ?? "No service date"}</span></div>
        <button className="primary-action" type="button" disabled={submitting || tenant.role === "viewer" || !reference.trim() || !driverId || !selectedStops.length} onClick={() => void approveRound()}>{submitting ? "Approving…" : tenant.role === "viewer" ? "Viewer cannot approve" : "Approve & assign Round"}</button>
      </aside>
    </div>
  </div>;
}
