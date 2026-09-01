import type { Freshness } from "@rounds/contracts";

const demoDrivers: Array<{
  id: string;
  stop: string;
  freshness: Freshness;
  age: string;
  source: string;
  accuracy: string;
}> = [
  {
    id: "DRIVER-P0-001",
    stop: "STOP-001 · Interchange 21",
    freshness: "live",
    age: "8 sec",
    source: "google_nav",
    accuracy: "±8 m",
  },
];

const label: Record<Freshness, string> = {
  live: "LIVE",
  aging: "AGING",
  stale: "LAST KNOWN",
  unknown: "UNKNOWN",
};

export default function TelemetryViewer() {
  return (
    <main>
      <header>
        <div>
          <p className="eyebrow">ROUNDS · PHASE 0</p>
          <h1>Operations telemetry</h1>
        </div>
        <div className="connection"><span /> Broadcast connected</div>
      </header>

      <section className="metrics" aria-label="Telemetry metrics">
        <Metric title="Riders" value="1" detail="1 viewer" />
        <Metric title="End-to-end latency" value="1.2 s" detail="field value pending" />
        <Metric title="Ingest" value="0.1 req/s" detail="2 samples/request" />
        <Metric title="Broadcast" value="0.2 msg/s" detail="tenant aggregated" />
      </section>

      <section className="workspace">
        <div className="map" aria-label="Map placeholder awaiting Mapbox token">
          <div className="bangkok-grid" />
          <div className="marker"><span>1</span></div>
          <div className="map-label">BANGKOK FIELD CORPUS</div>
        </div>
        <aside>
          <h2>Current positions</h2>
          {demoDrivers.map((driver) => (
            <article key={driver.id}>
              <div className="driver-title">
                <strong>{driver.id}</strong>
                <span className={`status ${driver.freshness}`}>{label[driver.freshness]}</span>
              </div>
              <p>{driver.stop}</p>
              <dl>
                <div><dt>Source age</dt><dd>{driver.age}</dd></div>
                <div><dt>Source</dt><dd>{driver.source}</dd></div>
                <div><dt>Accuracy</dt><dd>{driver.accuracy}</dd></div>
              </dl>
            </article>
          ))}
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
