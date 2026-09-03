import assert from "node:assert/strict";
import test from "node:test";
import type { OperationsDriverCapacityItem } from "@rounds/contracts";
import { createPlanningRouteService } from "../src/planning-route-service.js";
import { MapboxRoutingProvider } from "../src/routing-provider.js";
import type { ActorContext, PlanningRouteContextGateway } from "../src/types.js";

const tenantId = "10000000-0000-4000-8000-000000000001";
const driverId = "10000000-0000-4000-8000-000000000002";
const stopId = "10000000-0000-4000-8000-000000000003";
const actor: ActorContext = { authUserId: "auth", personId: "10000000-0000-4000-8000-000000000004", tenantId, role: "dispatcher" };
const driver: OperationsDriverCapacityItem = {
  driverId, displayName: "Johannes", initials: "JO", presence: { state: "unknown" },
  availability: { state: "off_shift", label: "Later", projectionBasis: "test" },
  effectiveShift: { source: "recurring", startAt: "2026-09-04T01:00:00.000Z", endAt: "2026-09-04T10:00:00.000Z", crossesMidnight: false },
  vehicleProfile: { id: "10000000-0000-4000-8000-000000000005", code: "CAR", displayName: "Car", vehicleGroup: "car", departurePattern: "multi_stop", maxStopsPerDeparture: 8, planningDeliveriesPerBlock: 4, pickupTurnaroundMinutes: 10, requiresReview: false, version: 1 },
  completedDeliveriesToday: 0,
};

function gateway(windowStart = "2026-09-04T02:00:00.000Z", windowEnd = "2026-09-04T04:00:00.000Z"): PlanningRouteContextGateway {
  return { async getPlanningRouteContext() { return {
    timezone: "Asia/Bangkok",
    pickup: { id: "pickup", coordinate: { latitude: 13.73, longitude: 100.53 } },
    driver,
    stops: [{ deliveryId: "delivery", stopId, reference: "UF-1", serviceDate: "2026-09-04", pickupLocationId: "pickup", recipientName: "Siriporn", rawAddress: "Bangkok", coordinate: { latitude: 13.75, longitude: 100.56 }, windowStart, windowEnd, manifestSummary: "1× bouquet" }],
    blockingReasons: [], warnings: [],
  }; } };
}

const route = {
  provider: "mapbox" as const,
  profile: "driving-traffic" as const,
  distanceMeters: 2500,
  durationSeconds: 900,
  typicalDurationSeconds: 800,
  legs: [{ distanceMeters: 2500, durationSeconds: 900 }],
  geometry: { type: "LineString" as const, coordinates: [[100.53, 13.73], [100.56, 13.75]] as [number, number][] },
};

test("waits after an early routed arrival and accepts the promised window", async () => {
  const service = createPlanningRouteService(gateway(), { calculate: async () => route });
  const preview = await service.preview(actor, { serviceDate: "2026-09-04", driverId, stopIds: [stopId] }, new Date("2026-09-03T12:00:00.000Z"));
  assert.equal(preview.status, "fits");
  assert.equal(preview.stops[0]?.promiseStatus, "early");
  assert.equal(preview.stops[0]?.waitingSeconds, 2700);
  assert.deepEqual(preview.geometry.coordinates[1], [100.56, 13.75]);
});

test("blocks approval when routed arrival misses the promise", async () => {
  const service = createPlanningRouteService(gateway("2026-09-04T01:00:00.000Z", "2026-09-04T01:10:00.000Z"), { calculate: async () => route });
  const preview = await service.preview(actor, { serviceDate: "2026-09-04", driverId, stopIds: [stopId] }, new Date("2026-09-03T12:00:00.000Z"));
  assert.equal(preview.status, "blocked");
  assert.match(preview.blockingReasons[0] ?? "", /after its promised window/);
});

test("normalizes a successful Mapbox Directions response without exposing its token", async () => {
  let requestedUrl = "";
  const provider = new MapboxRoutingProvider("secret-token", async (input) => {
    requestedUrl = String(input);
    return Response.json({ code: "Ok", routes: [{ distance: 2500, duration: 900, duration_typical: 800, legs: [{ distance: 2500, duration: 900 }], geometry: { type: "LineString", coordinates: [[100.53, 13.73], [100.56, 13.75]] } }] });
  });
  const result = await provider.calculate({ coordinates: [{ latitude: 13.73, longitude: 100.53 }, { latitude: 13.75, longitude: 100.56 }], departureAt: "2026-09-04T01:00:00.000Z" });
  assert.equal(result.durationSeconds, 900);
  assert.match(requestedUrl, /driving-traffic/);
  assert.match(requestedUrl, /depart_at=/);
  assert.ok(!JSON.stringify(result).includes("secret-token"));
});
