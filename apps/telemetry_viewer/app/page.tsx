"use client";

import { createClient, type RealtimeChannel } from "@supabase/supabase-js";
import { useCallback, useEffect, useMemo, useState } from "react";
import type { FleetPosition, Freshness } from "@rounds/contracts";

const projectUrl =
  process.env.NEXT_PUBLIC_SUPABASE_URL ??
  "https://stpwwkeytrfojvciyfvf.supabase.co";
const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "";
const tenantId = "00000000-0000-4000-8000-000000000001";
const topic = `phase-zero-${tenantId}`;

type SnapshotPosition = FleetPosition & {
  receivedAt: string;
  ingestWatermark: number;
};

type Metrics = {
  requests: number;
  ingestRequestsPerSecond: number;
  averageSamplesPerRequest: number;
  broadcastsPerSecond: number;
};

type Snapshot = {
  asOf: string;
  positions: SnapshotPosition[];
  metrics: Metrics;
};

const labels: Record<Freshness, string> = {
  live: "LIVE",
  aging: "AGING",
  stale: "LAST KNOWN",
  unknown: "UNKNOWN",
};

const emptyMetrics: Metrics = {
  requests: 0,
  ingestRequestsPerSecond: 0,
  averageSamplesPerRequest: 0,
  broadcastsPerSecond: 0,
};

function ageLabel(sourceAt: string, now = Date.now()): string {
  const seconds = Math.max(0, Math.round((now - Date.parse(sourceAt)) / 1000));
  return seconds < 60 ? `${seconds} sec` : `${Math.floor(seconds / 60)} min`;
}

export default function TelemetryViewer() {
  const [position, setPosition] = useState<SnapshotPosition>();
  const [metrics, setMetrics] = useState<Metrics>(emptyMetrics);
  const [connection, setConnection] = useState("CONNECTING");
  const [broadcastCount, setBroadcastCount] = useState(0);
  const [error, setError] = useState<string>();
  const supabase = useMemo(
    () => (publishableKey ? createClient(projectUrl, publishableKey) : null),
    [],
  );

  const refresh = useCallback(async () => {
    if (!publishableKey) {
      setError("Set NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY to load live telemetry.");
      return;
    }
    const response = await fetch(`${projectUrl}/functions/v1/location-ingest`, {
      headers: { apikey: publishableKey },
      cache: "no-store",
    });
    if (!response.ok) throw new Error(`snapshot HTTP ${response.status}`);
    const snapshot = (await response.json()) as Snapshot;
    setPosition(snapshot.positions[0]);
    setMetrics(snapshot.metrics);
    setError(undefined);
  }, []);

  useEffect(() => {
    let channel: RealtimeChannel | undefined;
    void refresh().catch((caught) => setError(String(caught)));
    const poll = window.setInterval(
      () => void refresh().catch((caught) => setError(String(caught))),
      10_000,
    );

    if (supabase) {
      channel = supabase
        .channel(topic, { config: { private: false } })
        .on("broadcast", { event: "fleet.positions" }, ({ payload }) => {
          const incoming = payload as {
            drivers?: Array<
              FleetPosition & { receivedAt?: string; ingestWatermark?: number }
            >;
          };
          const driver = incoming.drivers?.[0];
          if (!driver) return;
          setPosition((previous) => ({
            ...driver,
            receivedAt: driver.receivedAt ?? new Date().toISOString(),
            ingestWatermark:
              driver.ingestWatermark ?? previous?.ingestWatermark ?? 0,
          }));
          setBroadcastCount((count) => count + 1);
        })
        .subscribe((status) => setConnection(status));
    }

    return () => {
      window.clearInterval(poll);
      if (channel && supabase) void supabase.removeChannel(channel);
    };
  }, [refresh, supabase]);

  const freshness = position?.freshness ?? "unknown";
  const sourceAge = position ? ageLabel(position.sourceAt) : "—";

  return (
    <main>
      <header>
        <div>
          <p className="eyebrow">ROUNDS · PHASE 0</p>
          <h1>Operations telemetry</h1>
        </div>
        <div className={`connection ${connection.toLowerCase()}`}>
          <span /> {connection === "SUBSCRIBED" ? "Broadcast connected" : connection}
        </div>
      </header>

      {error && <p className="error-banner">{error}</p>}

      <section className="metrics" aria-label="Telemetry metrics">
        <Metric title="Riders" value={position ? "1" : "0"} detail="1 local viewer" />
        <Metric title="Source age" value={sourceAge} detail={labels[freshness]} />
        <Metric
          title="Ingest"
          value={`${metrics.ingestRequestsPerSecond.toFixed(2)} req/s`}
          detail={`${metrics.averageSamplesPerRequest.toFixed(1)} samples/request`}
        />
        <Metric
          title="Broadcast"
          value={`${metrics.broadcastsPerSecond.toFixed(2)} msg/s`}
          detail={`${broadcastCount} delivered this view`}
        />
      </section>

      <section className="workspace">
        <div className="map" aria-label="Bangkok field position surface">
          <div className="bangkok-grid" />
          {position && <div className="marker"><span>1</span></div>}
          <div className="map-label">
            {position
              ? `${position.latitude.toFixed(5)}, ${position.longitude.toFixed(5)}`
              : "WAITING FOR PHONE TELEMETRY"}
          </div>
        </div>
        <aside>
          <h2>Current positions</h2>
          {position ? (
            <article>
              <div className="driver-title">
                <strong>DRIVER-P0-001</strong>
                <span className={`status ${freshness}`}>{labels[freshness]}</span>
              </div>
              <p>STOP-001 · Interchange 21</p>
              <dl>
                <div><dt>Source age</dt><dd>{sourceAge}</dd></div>
                <div><dt>Source</dt><dd>{position.source}</dd></div>
                <div><dt>Accuracy</dt><dd>±{position.accuracyMeters.toFixed(0)} m</dd></div>
                <div><dt>Watermark</dt><dd>{position.ingestWatermark}</dd></div>
              </dl>
            </article>
          ) : (
            <p className="notice">UNKNOWN · no accepted phone batch yet.</p>
          )}
          <p className="notice">Stale positions are never displayed as live.</p>
        </aside>
      </section>
    </main>
  );
}

function Metric({ title, value, detail }: { title: string; value: string; detail: string }) {
  return (
    <article>
      <p>{title}</p>
      <strong>{value}</strong>
      <small>{detail}</small>
    </article>
  );
}
