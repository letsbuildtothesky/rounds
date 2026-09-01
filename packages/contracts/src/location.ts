export const locationSources = ["google_nav", "rounds_os"] as const;
export type LocationSource = (typeof locationSources)[number];

export type PositionSample = {
  sequence: number;
  capturedAt: string;
  latitude: number;
  longitude: number;
  accuracyMeters: number;
  source: LocationSource;
  headingDegrees?: number;
  speedMetersPerSecond?: number;
};

export type LocationBatch = {
  schemaVersion: 1;
  traceId: string;
  tenantId: string;
  driverId: string;
  deviceId: string;
  sessionId: string;
  roundId?: string;
  stopId?: string;
  firstSequence: number;
  lastSequence: number;
  samples: PositionSample[];
};

export type Freshness = "live" | "aging" | "stale" | "unknown";

export type FleetPosition = {
  driverId: string;
  latitude: number;
  longitude: number;
  sourceAt: string;
  accuracyMeters: number;
  source: LocationSource;
  freshness: Freshness;
};

export type FleetPositionsEvent = {
  event: "fleet.positions";
  version: 1;
  tenantId: string;
  asOf: string;
  drivers: FleetPosition[];
};

