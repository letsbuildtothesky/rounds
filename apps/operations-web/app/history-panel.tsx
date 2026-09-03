"use client";

import { useCallback, useEffect, useState } from "react";
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

  return <div className="history-workspace">
    <section className="page-heading"><div><p className="eyebrow">OPERATING MEMORY</p><h1>Delivery History</h1><p>Terminal outcomes backed by locked manifests, custody decisions and verified evidence.</p></div><button type="button" className="history-refresh" onClick={() => void load()}>Refresh</button></section>
    {error && <div className="alert error" role="alert"><div><strong>Couldn&apos;t load History</strong><span>{error}</span></div></div>}
    {loading ? <section className="dispatch-loading"><span /><p>Loading committed evidence…</p></section> : !history?.deliveries.length ? <section className="history-empty"><div>✓</div><h2>No terminal delivery outcomes yet</h2><p>A delivery appears here after its required evidence and final custody outcome are durably committed.</p></section> : <section className="history-list">
      {history.deliveries.map((item) => <article className={`history-card ${item.outcome}`} key={item.recordId}>
        <div className="history-primary"><div className={`history-check ${item.outcome}`}>{item.outcome === "returned" ? "↩" : "✓"}</div><div><p className="eyebrow">{item.roundReference} · {item.outcome === "returned" ? "RETURNED" : "DELIVERED"}</p><h2>{item.deliveryReference} · {item.recipientName}</h2><p>{item.rawAddress}</p></div></div>
        {item.outcome === "delivered" ? <dl className="history-evidence">
          <div><dt>Delivered</dt><dd>{formatDate(item.deliveredAt)}</dd></div>
          <div><dt>Driver</dt><dd>{item.driverName}</dd></div>
          <div><dt>Handoff</dt><dd>{handoffLabel(item.handoffType)} · {item.receiverLabel}</dd></div>
          <div><dt>Evidence</dt><dd><span className="evidence-verified">Verified</span> {item.verifiedPhotoCount} photo · manifest v{item.manifestVersion}</dd></div>
        </dl> : <>
          <dl className="history-evidence">
            <div><dt>Returned</dt><dd>{formatDate(item.returnedAt)}</dd></div>
            <div><dt>Driver</dt><dd>{item.driverName}</dd></div>
            <div><dt>Resolution</dt><dd>Merchant received returned package</dd></div>
            <div><dt>Evidence</dt><dd><span className="evidence-verified">Verified</span> {item.verifiedPhotoCount} damage photo · manifest v{item.manifestVersion}</dd></div>
          </dl>
          {(item.exceptionNote || item.resolutionNote) && <div className="history-return-notes">
            {item.exceptionNote && <p><strong>Driver report</strong><span>{item.exceptionNote}</span></p>}
            {item.resolutionNote && <p><strong>Operations resolution</strong><span>{item.resolutionNote}</span></p>}
          </div>}
        </>}
      </article>)}
    </section>}
  </div>;
}
