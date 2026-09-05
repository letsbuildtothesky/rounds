import assert from "node:assert/strict";
import test from "node:test";
import type {
  DriverSession,
  OperationsMapTrail,
  OperationsRoundDetail,
  OperationsSession,
  PlanningRoutePreview,
} from "@rounds/contracts";
import { operationsLiveMapHandler } from "../src/operations-live-map-handler.js";
import type {
  ActorContext,
  AuthenticatedIdentity,
  IdentityGateway,
  OperationsMapTrailGateway,
  OperationsRoundDetailGateway,
} from "../src/types.js";

const tenantId = "10000000-0000-4000-8000-000000000001";
const roundId = "10000000-0000-4000-8000-000000000010";
const driverId = "10000000-0000-4000-8000-000000000011";
const stopId = "10000000-0000-4000-8000-000000000012";
const now = new Date("2026-09-05T06:00:00.000Z");
const actor: ActorContext = { authUserId: "auth", personId: "10000000-0000-4000-8000-000000000002", tenantId, role: "viewer" };

function detail(capturedAt = "2026-09-05T05:59:45.000Z"): OperationsRoundDetail {
  return {
    tenantId,
    observedAt: now.toISOString(),
    id: roundId,
    reference: "ROUND-LIVE",
    serviceDate: "2026-09-05",
    state: "active",
    version: 4,
    driver: { id: driverId, displayName: "Johannes" },
    pickup: { id: "10000000-0000-4000-8000-000000000020", displayName: "UrbanFlowers" },
    stops: [{
      stopId,
      sequence: 1,
      stopState: "active",
      stopVersion: 3,
      destinationVersion: 2,
      deliveryId: "10000000-0000-4000-8000-000000000021",
      deliveryReference: "UF-001",
      deliveryState: "en_route",
      recipientName: "Siriporn",
      recipientPhone: "+66000000000",
      rawAddress: "Bangkok",
      coordinate: { latitude: 13.74, longitude: 100.57 },
      windowStart: "2026-09-05T06:00:00.000Z",
      windowEnd: "2026-09-05T08:00:00.000Z",
      manifest: { id: "10000000-0000-4000-8000-000000000022", state: "picked_up_locked", version: 2, items: [{ lineNumber: 1, description: "Bouquet", quantity: 1 }] },
      pickupConfirmed: true,
      openExceptionCount: 0,
    }],
    custodyStopCount: 1,
    openExceptionCount: 0,
    currentPosition: { latitude: 13.73, longitude: 100.56, capturedAt },
  };
}

const trail: OperationsMapTrail = {
  roundId,
  driverId,
  sessionIds: ["10000000-0000-4000-8000-000000000030"],
  source: "rounds_telemetry",
  locationSources: ["google_nav"],
  sampleCount: 2,
  truncated: false,
  firstCapturedAt: "2026-09-05T05:59:30.000Z",
  lastCapturedAt: "2026-09-05T05:59:45.000Z",
  geometry: { type: "LineString", coordinates: [[100.55, 13.72], [100.56, 13.73]] },
};

const route: PlanningRoutePreview = {
  tenantId,
  status: "fits",
  serviceDate: "2026-09-05",
  driverId,
  stopIds: [stopId],
  calculatedAt: now.toISOString(),
  departureAt: now.toISOString(),
  finishAt: "2026-09-05T06:15:00.000Z",
  distanceMeters: 2400,
  durationSeconds: 900,
  provider: { name: "mapbox", profile: "driving-traffic", freshness: "live" },
  stops: [{ stopId, sequence: 1, eta: "2026-09-05T06:15:00.000Z", departureAt: "2026-09-05T06:15:00.000Z", windowStart: "2026-09-05T06:00:00.000Z", windowEnd: "2026-09-05T08:00:00.000Z", promiseStatus: "safe", waitingSeconds: 0, latenessSeconds: 0, legDurationSeconds: 900, legDistanceMeters: 2400 }],
  blockingReasons: [],
  warnings: [],
  capacity: { status: "fits", dimensions: [], reasons: [], warnings: [] },
  geometry: { type: "LineString", coordinates: [[100.56, 13.73], [100.57, 13.74]] },
};

class Gateway implements IdentityGateway, OperationsRoundDetailGateway, OperationsMapTrailGateway {
  round = detail();
  async authenticate(): Promise<AuthenticatedIdentity | null> { return { authUserId: "auth" }; }
  async authorizeTenant(): Promise<ActorContext | null> { return actor; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return null; }
  async getOperationsRoundDetail(): Promise<OperationsRoundDetail | null> { return this.round; }
  async getOperationsRoundTrail(): Promise<OperationsMapTrail | undefined> { return trail; }
}

function request() {
  return new Request(`http://test/v1/operations/rounds/${roundId}/live-map`, { headers: { authorization: "Bearer token", "x-rounds-tenant-id": tenantId } });
}

test("projects a server remaining route separately from the exact Rounds trail", async () => {
  const gateway = new Gateway();
  let routedOrigin: { latitude: number; longitude: number } | undefined;
  let routedStopIds: string[] = [];
  const response = await operationsLiveMapHandler(request(), roundId, {
    identity: gateway,
    rounds: gateway,
    trails: gateway,
    routes: {
      preview: async () => route,
      previewAssignedChange: async (_actor, _roundIds, input, _observedAt, _changes, origin) => {
        routedOrigin = origin;
        routedStopIds = input.stopIds;
        return route;
      },
    },
    uuid: () => "10000000-0000-4000-8000-000000000099",
    now: () => now,
  });
  assert.equal(response.status, 200);
  const body = await response.json() as { routeStatus: string; remainingRoute?: { kind: string }; actualTrail?: OperationsMapTrail };
  assert.equal(body.routeStatus, "available");
  assert.equal(body.remainingRoute?.kind, "operations_remaining_route");
  assert.equal(body.actualTrail?.source, "rounds_telemetry");
  assert.deepEqual(routedOrigin, { latitude: 13.73, longitude: 100.56, capturedAt: "2026-09-05T05:59:45.000Z" });
  assert.deepEqual(routedStopIds, [stopId]);
});

test("keeps the actual trail but withholds route geometry when position is stale", async () => {
  const gateway = new Gateway();
  gateway.round = detail("2026-09-05T05:55:00.000Z");
  let routeCalls = 0;
  const response = await operationsLiveMapHandler(request(), roundId, {
    identity: gateway,
    rounds: gateway,
    trails: gateway,
    routes: { preview: async () => route, previewAssignedChange: async () => { routeCalls += 1; return route; } },
    uuid: () => "10000000-0000-4000-8000-000000000099",
    now: () => now,
  });
  const body = await response.json() as { routeStatus: string; routeUnavailableReason?: string; actualTrail?: OperationsMapTrail };
  assert.equal(response.status, 200);
  assert.equal(body.routeStatus, "unavailable");
  assert.match(body.routeUnavailableReason ?? "", /stale/);
  assert.equal(body.actualTrail?.sampleCount, 2);
  assert.equal(routeCalls, 0);
});

test("does not expose a live map projection for a non-active Round", async () => {
  const gateway = new Gateway();
  gateway.round = { ...detail(), state: "approved" };
  const response = await operationsLiveMapHandler(request(), roundId, {
    identity: gateway,
    rounds: gateway,
    trails: gateway,
    routes: { preview: async () => route },
    uuid: () => "10000000-0000-4000-8000-000000000099",
    now: () => now,
  });
  assert.equal(response.status, 409);
});
