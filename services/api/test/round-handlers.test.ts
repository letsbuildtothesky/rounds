import assert from "node:assert/strict";
import test from "node:test";
import type {
  DriverSession,
  OperationsPlanningProjection,
  OperationsSession,
  PlanRoundCommand,
  PlanRoundResult,
  PlanningRoutePreview,
} from "@rounds/contracts";
import { driverSessionHandler } from "../src/driver-session-handler.js";
import { operationsPlanningHandler } from "../src/operations-planning-handler.js";
import { planRoundHandler } from "../src/plan-round-handler.js";
import type { ActorContext, AuthenticatedIdentity, IdentityGateway, RoundGateway } from "../src/types.js";

const tenantId = "10000000-0000-4000-8000-000000000001";
const actor: ActorContext = {
  authUserId: "auth-user",
  personId: "10000000-0000-4000-8000-000000000010",
  tenantId,
  role: "dispatcher",
};
const projection: OperationsPlanningProjection = {
  tenantId,
  drivers: [{ id: "10000000-0000-4000-8000-000000000002", displayName: "Demo Driver" }],
  unplannedDeliveries: [{
    deliveryId: "10000000-0000-4000-8000-000000000100",
    stopId: "10000000-0000-4000-8000-000000000005",
    reference: "UF-001",
    serviceDate: "2026-09-02",
    pickupLocationId: "10000000-0000-4000-8000-000000000020",
    recipientName: "Siriporn",
    rawAddress: "Bangkok",
    windowStart: "2026-09-02T02:00:00Z",
    windowEnd: "2026-09-02T04:00:00Z",
    manifestSummary: "1× Flower bouquet",
    cargoRequirements: [{ cargoClassCode: "bouquet", displayName: "Bouquets", quantity: 1, classificationStatus: "classified" }],
  }],
  activeRounds: [],
};
const driverSession: DriverSession = {
  user: { id: "auth-user", displayName: "Demo Driver" },
  driver: { id: projection.drivers[0]!.id, preferredLocale: "en" },
};
const routePreview: PlanningRoutePreview = {
  tenantId,
  status: "fits",
  serviceDate: "2026-09-02",
  driverId: projection.drivers[0]!.id,
  stopIds: [projection.unplannedDeliveries[0]!.stopId],
  calculatedAt: "2026-09-01T12:00:00.000Z",
  departureAt: "2026-09-02T01:00:00.000Z",
  finishAt: "2026-09-02T02:00:00.000Z",
  distanceMeters: 2500,
  durationSeconds: 900,
  provider: { name: "mapbox", profile: "driving-traffic", freshness: "live" },
  stops: [{ stopId: projection.unplannedDeliveries[0]!.stopId, sequence: 1, eta: "2026-09-02T01:15:00.000Z", departureAt: "2026-09-02T02:00:00.000Z", windowStart: "2026-09-02T02:00:00.000Z", windowEnd: "2026-09-02T04:00:00.000Z", promiseStatus: "early", waitingSeconds: 2700, latenessSeconds: 0, legDurationSeconds: 900, legDistanceMeters: 2500 }],
  blockingReasons: [],
  warnings: [],
  capacity: { status: "fits", dimensions: [{ kind: "stops", code: "stops", displayName: "Stops per departure", used: 1, limit: 8, remaining: 7, utilizationPercent: 13, status: "fits" }], constrainingDimension: { kind: "stops", code: "stops" }, reasons: [], warnings: [] },
  geometry: { type: "LineString", coordinates: [[100.5, 13.7], [100.6, 13.8]] },
};
const routes = { preview: async () => routePreview };

class FakeGateway implements IdentityGateway, RoundGateway {
  authenticated = true;
  authorizedActor: ActorContext | null = actor;
  lastCommand: PlanRoundCommand | null = null;
  driver: DriverSession | null = driverSession;

  async authenticate(): Promise<AuthenticatedIdentity | null> {
    return this.authenticated ? { authUserId: "auth-user" } : null;
  }
  async authorizeTenant(): Promise<ActorContext | null> { return this.authorizedActor; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return this.driver; }
  async getOperationsPlanning(): Promise<OperationsPlanningProjection> { return projection; }
  async planRound(command: PlanRoundCommand): Promise<PlanRoundResult> {
    this.lastCommand = command;
    return {
      status: "committed",
      aggregateVersion: 1,
      state: {
        roundId: command.aggregateId,
        reference: command.payload.reference,
        roundState: "approved",
        driverId: command.payload.driverId,
        stopIds: command.payload.stopIds,
        deliveryIds: [projection.unplannedDeliveries[0]!.deliveryId],
      },
      events: [],
    };
  }
}

const ids = () => {
  const values = [
    "10000000-0000-4000-8000-000000000102",
    "10000000-0000-4000-8000-000000000101",
    "10000000-0000-4000-8000-000000000100",
  ];
  return () => values.shift() ?? "10000000-0000-4000-8000-000000000999";
};

test("returns the purpose-limited planning projection", async () => {
  const gateway = new FakeGateway();
  const response = await operationsPlanningHandler(new Request("http://test/v1/operations/planning", {
    headers: { authorization: "Bearer token", "x-rounds-tenant-id": tenantId },
  }), { identity: gateway, planning: gateway, uuid: ids() });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), projection);
});

test("viewer can inspect planning but cannot approve a Round", async () => {
  const gateway = new FakeGateway();
  gateway.authorizedActor = { ...actor, role: "viewer" };
  const response = await planRoundHandler(new Request("http://test/v1/rounds", {
    method: "POST",
    headers: {
      authorization: "Bearer token",
      "content-type": "application/json",
      "x-rounds-tenant-id": tenantId,
      "idempotency-key": "round:001",
    },
    body: JSON.stringify({
      reference: "ROUND-001",
      serviceDate: "2026-09-02",
      driverId: projection.drivers[0]!.id,
      stopIds: [projection.unplannedDeliveries[0]!.stopId],
      departureAt: routePreview.departureAt,
    }),
  }), { identity: gateway, planning: gateway, routes, uuid: ids(), now: () => new Date("2026-09-01T12:00:00Z") });
  assert.equal(response.status, 403);
  assert.equal(gateway.lastCommand, null);
});

test("commits the explicit Stop order under the authenticated tenant", async () => {
  const gateway = new FakeGateway();
  const response = await planRoundHandler(new Request("http://test/v1/rounds", {
    method: "POST",
    headers: {
      authorization: "Bearer token",
      "content-type": "application/json",
      "x-rounds-tenant-id": tenantId,
      "idempotency-key": "round:001",
    },
    body: JSON.stringify({
      reference: "ROUND-001",
      serviceDate: "2026-09-02",
      driverId: projection.drivers[0]!.id,
      stopIds: [projection.unplannedDeliveries[0]!.stopId],
      departureAt: routePreview.departureAt,
    }),
  }), { identity: gateway, planning: gateway, routes, uuid: ids(), now: () => new Date("2026-09-01T12:00:00Z") });
  assert.equal(response.status, 201);
  assert.equal(gateway.lastCommand?.tenantId, tenantId);
  assert.deepEqual(gateway.lastCommand?.payload.stopIds, [projection.unplannedDeliveries[0]!.stopId]);
  assert.equal(gateway.lastCommand?.payload.departureAt, routePreview.departureAt);
  assert.equal(gateway.lastCommand?.payload.routePlan.departureAt, routePreview.departureAt);
  assert.equal(gateway.lastCommand?.payload.routePlan.provider.name, "mapbox");
  assert.equal("geometry" in (gateway.lastCommand?.payload.routePlan ?? {}), false);
});

test("never reaches the database when server routing misses a promise", async () => {
  const gateway = new FakeGateway();
  const blockedRoutes = { preview: async (): Promise<PlanningRoutePreview> => ({
    ...routePreview,
    status: "blocked",
    blockingReasons: ["Stop 1 arrives after its promised window."],
  }) };
  const response = await planRoundHandler(new Request("http://test/v1/rounds", {
    method: "POST",
    headers: { authorization: "Bearer token", "content-type": "application/json", "x-rounds-tenant-id": tenantId, "idempotency-key": "round:blocked" },
    body: JSON.stringify({ reference: "ROUND-BLOCKED", serviceDate: "2026-09-02", driverId: projection.drivers[0]!.id, stopIds: [projection.unplannedDeliveries[0]!.stopId], departureAt: routePreview.departureAt }),
  }), { identity: gateway, planning: gateway, routes: blockedRoutes, uuid: ids(), now: () => new Date("2026-09-01T12:00:00Z") });
  assert.equal(response.status, 409);
  assert.equal(gateway.lastCommand, null);
});

test("returns the authenticated Team-driver session", async () => {
  const gateway = new FakeGateway();
  const response = await driverSessionHandler(new Request("http://test/v1/driver/session", {
    headers: { authorization: "Bearer token" },
  }), { identity: gateway, uuid: ids() });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), driverSession);
});

test("rejects an identity without an active Team relationship", async () => {
  const gateway = new FakeGateway();
  gateway.driver = null;
  const response = await driverSessionHandler(new Request("http://test/v1/driver/session", {
    headers: { authorization: "Bearer token" },
  }), { identity: gateway, uuid: ids() });
  assert.equal(response.status, 403);
});
