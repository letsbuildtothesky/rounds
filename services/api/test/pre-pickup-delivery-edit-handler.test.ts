import assert from "node:assert/strict";
import test from "node:test";
import type {
  ApplyPrePickupDeliveryEditCommand,
  ApplyPrePickupDeliveryEditResult,
  DriverSession,
  OperationsDeliveriesProjection,
  OperationsRoundDetail,
  OperationsSession,
  PlanningRoutePreview,
} from "@rounds/contracts";
import { applyPrePickupDeliveryEditHandler, prePickupDeliveryEditPreviewHandler } from "../src/pre-pickup-delivery-edit-handler.js";
import type { ActorContext, AuthenticatedIdentity, IdentityGateway, OperationsDeliveriesGateway, OperationsRoundDetailGateway, PrePickupDeliveryEditDependencies, PrePickupDeliveryEditGateway } from "../src/types.js";

const tenantId = "10000000-0000-4000-8000-000000000001";
const deliveryId = "10000000-0000-4000-8000-000000000010";
const stopId = "10000000-0000-4000-8000-000000000011";
const manifestId = "10000000-0000-4000-8000-000000000012";
const roundId = "10000000-0000-4000-8000-000000000013";
const driverId = "10000000-0000-4000-8000-000000000014";
const pickupId = "10000000-0000-4000-8000-000000000015";
const commandId = "10000000-0000-4000-8000-000000000099";
const now = new Date("2026-09-05T05:00:00.000Z");
const actor: ActorContext = { authUserId: "auth", personId: "10000000-0000-4000-8000-000000000002", tenantId, role: "dispatcher" };

function projection(assigned = false): OperationsDeliveriesProjection {
  return { tenantId, observedAt: now.toISOString(), deliveries: [{
    deliveryId, reference: "UF-001", state: assigned ? "assigned" : "unplanned", version: 3, sourceSystem: "manual",
    serviceDate: "2026-09-05", serviceTimezone: "Asia/Bangkok", pickupLocationId: pickupId, pickupLocationName: "UrbanFlowers",
    buyerSameAsRecipient: true, buyerName: "Siriporn", buyerPhone: "+66000000000", recipientName: "Siriporn", recipientPhone: "+66000000000",
    rawAddress: "Old address", coordinate: { latitude: 13.7, longitude: 100.5 }, accessNote: "Gate A", isSurprise: false,
    createdAt: now.toISOString(), updatedAt: now.toISOString(), stop: { id: stopId, state: "assigned", version: 4, destinationVersion: 2 },
    promise: { windowStart: "2026-09-05T06:00:00+00:00", windowEnd: "2026-09-05T08:00:00+00:00" },
    manifest: { id: manifestId, state: "draft", version: 2, items: [{ lineNumber: 1, description: "Bouquet", quantity: 1, cargoClass: "flowers" }] },
    ...(assigned ? { round: { id: roundId, reference: "ROUND-1", state: "approved", version: 7, sequence: 1, driverName: "Johannes" } } : {}),
  }] };
}

function route(): PlanningRoutePreview {
  return {
    tenantId, status: "fits", serviceDate: "2026-09-05", driverId, stopIds: [stopId], calculatedAt: now.toISOString(),
    departureAt: now.toISOString(), finishAt: "2026-09-05T05:30:00.000Z", distanceMeters: 5200, durationSeconds: 1200,
    provider: { name: "mapbox", profile: "driving-traffic", freshness: "live" },
    stops: [{ stopId, sequence: 1, eta: "2026-09-05T05:20:00.000Z", departureAt: "2026-09-05T05:20:00.000Z", windowStart: "2026-09-05T06:00:00.000Z", windowEnd: "2026-09-05T08:00:00.000Z", promiseStatus: "early", waitingSeconds: 2400, latenessSeconds: 0, legDurationSeconds: 1200, legDistanceMeters: 5200 }],
    blockingReasons: [], warnings: [], capacity: { status: "fits", dimensions: [], reasons: [], warnings: [] }, geometry: { type: "LineString", coordinates: [[100.5, 13.7], [100.6, 13.8]] },
  };
}

function roundDetail(): OperationsRoundDetail {
  const current = route();
  return {
    tenantId, observedAt: now.toISOString(), id: roundId, reference: "ROUND-1", serviceDate: "2026-09-05", state: "approved", version: 7,
    routePlan: { ...current, distanceMeters: 5000, durationSeconds: 1100, finishAt: "2026-09-05T05:28:00.000Z" },
    driver: { id: driverId, displayName: "Johannes" }, pickup: { id: pickupId, displayName: "UrbanFlowers" },
    stops: [{ stopId, sequence: 1, stopState: "assigned", stopVersion: 4, destinationVersion: 2, deliveryId, deliveryReference: "UF-001", deliveryState: "assigned", recipientName: "Siriporn", recipientPhone: "+66000000000", rawAddress: "Old address", accessNote: "Gate A", coordinate: { latitude: 13.7, longitude: 100.5 }, windowStart: "2026-09-05T06:00:00.000Z", windowEnd: "2026-09-05T08:00:00.000Z", manifest: { id: manifestId, state: "draft", version: 2, items: [{ lineNumber: 1, description: "Bouquet", quantity: 1, cargoClass: "flowers" }] }, pickupConfirmed: false, openExceptionCount: 0 }],
    custodyStopCount: 0, openExceptionCount: 0,
  };
}

class Gateway implements IdentityGateway, OperationsDeliveriesGateway, OperationsRoundDetailGateway, PrePickupDeliveryEditGateway {
  assigned = false;
  locked = false;
  applied: ApplyPrePickupDeliveryEditCommand | null = null;
  async authenticate(): Promise<AuthenticatedIdentity | null> { return { authUserId: "auth" }; }
  async authorizeTenant(): Promise<ActorContext | null> { return actor; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return null; }
  async getOperationsDeliveries(): Promise<OperationsDeliveriesProjection> {
    const value = projection(this.assigned);
    if (this.locked) value.deliveries[0]!.manifest.state = "picked_up_locked";
    return value;
  }
  async getOperationsRoundDetail(): Promise<OperationsRoundDetail | null> { return roundDetail(); }
  async applyPrePickupDeliveryEdit(command: ApplyPrePickupDeliveryEditCommand): Promise<ApplyPrePickupDeliveryEditResult> {
    this.applied = command;
    return { status: "committed", aggregateVersion: 4, state: { deliveryId, deliveryVersion: 4, stopId, stopVersion: 5, destinationVersion: 3, manifestId, manifestVersion: 3 }, events: [] };
  }
}

function requestBody(assigned = false) {
  return { deliveryId, expectedDeliveryVersion: 3, expectedStopVersion: 4, expectedDestinationVersion: 2, expectedManifestVersion: 2, ...(assigned ? { expectedRoundVersion: 7 } : {}), changes: { recipientName: "Siriporn New", rawAddress: "New address", latitude: 13.8, longitude: 100.6, manifestItems: [{ lineNumber: 1, description: "Bouquet", quantity: 2, cargoClass: "flowers" }] } };
}

function dependencies(gateway: Gateway): PrePickupDeliveryEditDependencies {
  return { identity: gateway, deliveries: gateway, uuid: () => commandId, now: () => now, routes: { preview: async () => route(), previewAssignedChange: async () => route() } };
}

test("previews an unplanned edit without inventing a route", async () => {
  const gateway = new Gateway();
  const response = await prePickupDeliveryEditPreviewHandler(new Request("http://test/v1/operations/delivery-edits/preview", { method: "POST", headers: { authorization: "Bearer token", "x-rounds-tenant-id": tenantId, "content-type": "application/json" }, body: JSON.stringify(requestBody()) }), dependencies(gateway));
  assert.equal(response.status, 200);
  const body = await response.json() as { applicable: boolean; changedFields: string[]; impact: { assignment: string; routeRecalculated: boolean } };
  assert.equal(body.applicable, true); assert.equal(body.impact.assignment, "unplanned"); assert.equal(body.impact.routeRecalculated, false); assert.ok(body.changedFields.includes("manifestItems"));
});

test("assigned edit recalculates route and capacity before apply", async () => {
  const gateway = new Gateway(); gateway.assigned = true;
  let cargoQuantity = 0;
  const deps = dependencies(gateway);
  deps.routes.previewAssignedChange = async (_actor, _roundIds, _request, _now, changes) => { cargoQuantity = changes.cargoRequirements?.[0]?.quantity ?? 0; return route(); };
  const response = await applyPrePickupDeliveryEditHandler(new Request("http://test/v1/operations/delivery-edits", { method: "POST", headers: { authorization: "Bearer token", "x-rounds-tenant-id": tenantId, "idempotency-key": "edit:one", "content-type": "application/json" }, body: JSON.stringify(requestBody(true)) }), deps);
  assert.equal(response.status, 200); assert.equal(cargoQuantity, 2); assert.equal(gateway.applied?.payload.routePlan?.distanceMeters, 5200); assert.equal("geometry" in (gateway.applied?.payload.routePlan ?? {}), false);
});

test("equivalent timestamp formats do not invent a route-impacting window change", async () => {
  const gateway = new Gateway(); gateway.assigned = true;
  let routePreviewCalls = 0;
  const deps = dependencies(gateway);
  deps.routes.previewAssignedChange = async () => { routePreviewCalls += 1; return route(); };
  const body = {
    deliveryId,
    expectedDeliveryVersion: 3,
    expectedStopVersion: 4,
    expectedDestinationVersion: 2,
    expectedManifestVersion: 2,
    expectedRoundVersion: 7,
    changes: {
      accessNote: "Gate B",
      windowStart: "2026-09-05T06:00:00.000Z",
      windowEnd: "2026-09-05T08:00:00.000Z",
    },
  };
  const response = await prePickupDeliveryEditPreviewHandler(new Request("http://test/v1/operations/delivery-edits/preview", { method: "POST", headers: { authorization: "Bearer token", "x-rounds-tenant-id": tenantId, "content-type": "application/json" }, body: JSON.stringify(body) }), deps);
  assert.equal(response.status, 200);
  const result = await response.json() as { changedFields: string[]; impact: { routeRecalculated: boolean } };
  assert.deepEqual(result.changedFields, ["accessNote"]);
  assert.equal(result.impact.routeRecalculated, false);
  assert.equal(routePreviewCalls, 0);
});

test("picked-up manifest blocks pre-pickup editing", async () => {
  const gateway = new Gateway(); gateway.locked = true;
  const response = await applyPrePickupDeliveryEditHandler(new Request("http://test/v1/operations/delivery-edits", { method: "POST", headers: { authorization: "Bearer token", "x-rounds-tenant-id": tenantId, "idempotency-key": "edit:locked", "content-type": "application/json" }, body: JSON.stringify(requestBody()) }), dependencies(gateway));
  assert.equal(response.status, 409); assert.equal(gateway.applied, null);
});

test("address text cannot silently keep an unconfirmed pin", async () => {
  const gateway = new Gateway();
  const body = requestBody(); delete (body.changes as { latitude?: number }).latitude; delete (body.changes as { longitude?: number }).longitude;
  const response = await prePickupDeliveryEditPreviewHandler(new Request("http://test/v1/operations/delivery-edits/preview", { method: "POST", headers: { authorization: "Bearer token", "x-rounds-tenant-id": tenantId, "content-type": "application/json" }, body: JSON.stringify(body) }), dependencies(gateway));
  const result = await response.json() as { applicable: boolean; blockingReasons: string[] };
  assert.equal(result.applicable, false); assert.match(result.blockingReasons.join(" "), /map pin/);
});
