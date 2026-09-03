import assert from "node:assert/strict";
import test from "node:test";
import type {
  AcknowledgeLiveDeliveryChangeCommand, AcknowledgeLiveDeliveryChangeResult, ApplyLiveDeliveryChangeCommand,
  ApplyLiveDeliveryChangeResult, DriverSession, OperationsRoundDetail, OperationsSession, PlanningRoutePreview,
} from "@rounds/contracts";
import { acknowledgeLiveDeliveryChangeHandler, applyLiveDeliveryChangeHandler, liveDeliveryChangePreviewHandler } from "../src/live-delivery-change-handler.js";
import type { ActorContext, AuthenticatedIdentity, IdentityGateway, LiveDeliveryChangeDependencies, LiveDeliveryChangeGateway, OperationsRoundDetailGateway } from "../src/types.js";

const tenantId = "10000000-0000-4000-8000-000000000001";
const roundId = "10000000-0000-4000-8000-000000000010";
const stopId = "10000000-0000-4000-8000-000000000020";
const secondStopId = "10000000-0000-4000-8000-000000000021";
const driverId = "10000000-0000-4000-8000-000000000030";
const changeId = "10000000-0000-4000-8000-000000000040";
const now = new Date("2026-09-03T06:00:00.000Z");
const actor: ActorContext = { authUserId: "auth", personId: "10000000-0000-4000-8000-000000000002", tenantId, role: "dispatcher" };

function route(): PlanningRoutePreview {
  return {
    tenantId, status: "fits", serviceDate: "2026-09-03", driverId, stopIds: [stopId], calculatedAt: now.toISOString(),
    departureAt: now.toISOString(), finishAt: "2026-09-03T06:20:00.000Z", distanceMeters: 5200, durationSeconds: 1200,
    provider: { name: "mapbox", profile: "driving-traffic", freshness: "live" },
    stops: [{ stopId, sequence: 1, eta: "2026-09-03T06:20:00.000Z", departureAt: "2026-09-03T06:20:00.000Z", windowStart: "2026-09-03T06:00:00.000Z", windowEnd: "2026-09-03T08:00:00.000Z", promiseStatus: "safe", waitingSeconds: 0, latenessSeconds: 0, legDurationSeconds: 1200, legDistanceMeters: 5200 }],
    blockingReasons: [], warnings: [], capacity: { status: "fits", dimensions: [], reasons: [], warnings: [] },
    geometry: { type: "LineString", coordinates: [[100.5, 13.7], [100.6, 13.8]] },
  };
}

function detail(): OperationsRoundDetail {
  const beforeRoute = route();
  return {
    tenantId, observedAt: now.toISOString(), id: roundId, reference: "ROUND-1", serviceDate: "2026-09-03", state: "active", version: 7,
    routePlan: { ...beforeRoute, distanceMeters: 4000, durationSeconds: 900, finishAt: "2026-09-03T06:15:00.000Z" },
    driver: { id: driverId, displayName: "Johannes" }, pickup: { id: "10000000-0000-4000-8000-000000000050", displayName: "UrbanFlowers" },
    stops: [{ stopId, sequence: 1, stopState: "active", stopVersion: 4, destinationVersion: 2, deliveryId: "10000000-0000-4000-8000-000000000060", deliveryReference: "UF-1", deliveryState: "en_route", recipientName: "Siriporn", recipientPhone: "+66000000000", rawAddress: "Old entrance", accessNote: "Tower A", coordinate: { latitude: 13.7, longitude: 100.5 }, windowStart: "2026-09-03T06:00:00.000Z", windowEnd: "2026-09-03T08:00:00.000Z", manifest: { id: "10000000-0000-4000-8000-000000000070", state: "picked_up_locked", version: 3, items: [{ lineNumber: 1, description: "Bouquet", quantity: 1 }] }, pickupConfirmed: true, openExceptionCount: 0 }],
    custodyStopCount: 1, openExceptionCount: 0, currentPosition: { latitude: 13.69, longitude: 100.49, capturedAt: now.toISOString() },
  };
}

class Gateway implements IdentityGateway, OperationsRoundDetailGateway, LiveDeliveryChangeGateway {
  round = detail();
  applied: ApplyLiveDeliveryChangeCommand | null = null;
  acknowledged: AcknowledgeLiveDeliveryChangeCommand | null = null;
  async authenticate(): Promise<AuthenticatedIdentity | null> { return { authUserId: "auth" }; }
  async authorizeTenant(): Promise<ActorContext | null> { return actor; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return { user: { id: "auth", displayName: "Johannes" }, driver: { id: driverId, preferredLocale: "en" }, team: { tenantId, displayName: "UrbanFlowers", status: "active" } }; }
  async getOperationsRoundDetail(): Promise<OperationsRoundDetail | null> { return this.round; }
  async applyLiveDeliveryChange(command: ApplyLiveDeliveryChangeCommand): Promise<ApplyLiveDeliveryChangeResult> { this.applied = command; return { status: "committed", aggregateVersion: 5, state: { changeId, changeVersion: 1, roundId, roundVersion: 8, stopId, stopVersion: 5, destinationVersion: 3, driverAckStatus: "pending" }, events: [] }; }
  async acknowledgeLiveDeliveryChange(command: AcknowledgeLiveDeliveryChangeCommand): Promise<AcknowledgeLiveDeliveryChangeResult> { this.acknowledged = command; return { status: "committed", aggregateVersion: 2, state: { changeId, changeVersion: 1, roundId, stopId, driverAckStatus: "acknowledged", acknowledgedAt: now.toISOString() }, events: [] }; }
}

function body() {
  return { roundId, stopId, expectedRoundVersion: 7, expectedStopVersion: 4, expectedDestinationVersion: 2, changes: { rawAddress: "Gate B", latitude: 13.8, longitude: 100.6, accessNote: "Use Gate B" } };
}

function dependencies(gateway: Gateway) {
  return { identity: gateway, changes: gateway, uuid: () => changeId, now: () => now, routes: {
    preview: async () => route(), previewAssignedChange: async () => route(),
  } };
}

test("previews the actual destination diff and routed consequence", async () => {
  const gateway = new Gateway();
  const response = await liveDeliveryChangePreviewHandler(new Request("http://test/v1/operations/live-delivery-changes/preview", { method: "POST", headers: { authorization: "Bearer token", "x-rounds-tenant-id": tenantId, "content-type": "application/json" }, body: JSON.stringify(body()) }), dependencies(gateway));
  assert.equal(response.status, 200);
  const result = await response.json() as { applicable: boolean; after: { rawAddress: string }; impact: { distanceDeltaMeters: number } };
  assert.equal(result.applicable, true); assert.equal(result.after.rawAddress, "Gate B"); assert.equal(result.impact.distanceDeltaMeters, 1200);
});

test("recalculates before apply and builds a versioned command", async () => {
  const gateway = new Gateway();
  const response = await applyLiveDeliveryChangeHandler(new Request("http://test/v1/operations/live-delivery-changes", { method: "POST", headers: { authorization: "Bearer token", "x-rounds-tenant-id": tenantId, "idempotency-key": "live:one", "content-type": "application/json" }, body: JSON.stringify(body()) }), dependencies(gateway));
  assert.equal(response.status, 200); assert.equal(gateway.applied?.expectedVersion, 4); assert.equal(gateway.applied?.payload.routePlan.distanceMeters, 5200); assert.equal("geometry" in (gateway.applied?.payload.routePlan ?? {}), false);
});

test("reorders future Stops before routing and commits the exact full order", async () => {
  const gateway = new Gateway();
  const second = { ...gateway.round.stops[0]!, stopId: secondStopId, sequence: 2, deliveryId: "10000000-0000-4000-8000-000000000061", deliveryReference: "UF-2" };
  gateway.round = {
    ...gateway.round,
    stops: [...gateway.round.stops, second],
    routePlan: { ...gateway.round.routePlan!, stopIds: [stopId, secondStopId] },
  };
  let routedStopIds: string[] = [];
  const reorderedRoute = {
    ...route(),
    stopIds: [secondStopId, stopId],
    stops: [
      { ...route().stops[0]!, stopId: secondStopId, sequence: 1 },
      { ...route().stops[0]!, stopId, sequence: 2 },
    ],
  };
  const deps: LiveDeliveryChangeDependencies = dependencies(gateway);
  deps.routes.previewAssignedChange = async (_actor, _roundIds, request) => {
    routedStopIds = request.stopIds;
    return reorderedRoute;
  };
  const response = await applyLiveDeliveryChangeHandler(new Request("http://test/v1/operations/live-delivery-changes", {
    method: "POST",
    headers: { authorization: "Bearer token", "x-rounds-tenant-id": tenantId, "idempotency-key": "live:order", "content-type": "application/json" },
    body: JSON.stringify({ roundId, stopId, expectedRoundVersion: 7, expectedStopVersion: 4, expectedDestinationVersion: 2, changes: { sequence: 2 } }),
  }), deps);
  assert.equal(response.status, 200);
  assert.deepEqual(routedStopIds, [secondStopId, stopId]);
  assert.deepEqual(gateway.applied?.payload.stopOrderAfter, [secondStopId, stopId]);
  assert.equal(gateway.applied?.payload.after.sequence, 2);
});

test("stale Round state blocks apply before the database command", async () => {
  const gateway = new Gateway(); gateway.round = { ...gateway.round, version: 8 };
  const response = await applyLiveDeliveryChangeHandler(new Request("http://test/v1/operations/live-delivery-changes", { method: "POST", headers: { authorization: "Bearer token", "x-rounds-tenant-id": tenantId, "idempotency-key": "live:stale", "content-type": "application/json" }, body: JSON.stringify(body()) }), dependencies(gateway));
  assert.equal(response.status, 409); assert.equal(gateway.applied, null);
});

test("only the authenticated Driver emits acknowledgement", async () => {
  const gateway = new Gateway();
  const response = await acknowledgeLiveDeliveryChangeHandler(new Request(`http://test/v1/driver/live-delivery-changes/${changeId}/acknowledge`, { method: "POST", headers: { authorization: "Bearer token", "idempotency-key": "ack:one", "content-type": "application/json" }, body: JSON.stringify({ expectedChangeVersion: 1 }) }), changeId, { identity: gateway, changes: gateway, uuid: () => changeId, now: () => now });
  assert.equal(response.status, 200); assert.equal(gateway.acknowledged?.commandType, "driver.acknowledge_live_change");
});
