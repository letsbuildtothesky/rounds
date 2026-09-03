import assert from "node:assert/strict";
import test from "node:test";
import type {
  DriverSession, MoveRoundStopCommand, MoveRoundStopResult, OperationsRoundDetail, OperationsSession,
  PlanningRoutePreview, PlanningRoutePreviewRequest,
} from "@rounds/contracts";
import { roundMoveHandler, roundMovePreviewHandler } from "../src/round-move-handler.js";
import type { ActorContext, AuthenticatedIdentity, IdentityGateway, OperationsRoundDetailGateway, RoundMoveGateway } from "../src/types.js";

const tenantId = "10000000-0000-4000-8000-000000000001";
const sourceId = "10000000-0000-4000-8000-000000000010";
const targetId = "10000000-0000-4000-8000-000000000011";
const sourceDriver = "10000000-0000-4000-8000-000000000020";
const targetDriver = "10000000-0000-4000-8000-000000000021";
const movedStopId = "10000000-0000-4000-8000-000000000030";
const sourceOtherStopId = "10000000-0000-4000-8000-000000000031";
const targetStopId = "10000000-0000-4000-8000-000000000032";
const actor: ActorContext = { authUserId: "auth", personId: "10000000-0000-4000-8000-000000000002", tenantId, role: "dispatcher" };
const now = new Date("2026-09-03T00:00:00.000Z");

function route(driverId: string, stopIds: string[]): PlanningRoutePreview {
  return {
    tenantId, status: "fits", serviceDate: "2026-09-04", driverId, stopIds,
    calculatedAt: now.toISOString(), departureAt: "2026-09-04T01:00:00.000Z", finishAt: "2026-09-04T03:00:00.000Z",
    distanceMeters: stopIds.length * 1000, durationSeconds: stopIds.length * 600,
    provider: { name: "mapbox", profile: "driving-traffic", freshness: "live" },
    stops: stopIds.map((stopId, index) => ({ stopId, sequence: index + 1, eta: `2026-09-04T0${index + 2}:00:00.000Z`, departureAt: `2026-09-04T0${index + 2}:00:00.000Z`, windowStart: "2026-09-04T01:00:00.000Z", windowEnd: "2026-09-04T09:00:00.000Z", promiseStatus: "safe", waitingSeconds: 0, latenessSeconds: 0, legDurationSeconds: 600, legDistanceMeters: 1000 })),
    blockingReasons: [], warnings: [],
    capacity: { status: "fits", dimensions: [{ kind: "stops", code: "stops", displayName: "Stops", used: stopIds.length, limit: 8, remaining: 8 - stopIds.length, utilizationPercent: 25, status: "fits" }], constrainingDimension: { kind: "stops", code: "stops" }, reasons: [], warnings: [] },
    geometry: { type: "LineString", coordinates: [[100.5, 13.7], [100.6, 13.8]] },
  };
}

function stop(stopId: string, sequence: number) {
  return {
    stopId, sequence, stopState: "assigned", stopVersion: 2,
    deliveryId: stopId.replace(/003[0-2]$/, "0040"), deliveryReference: `UF-${sequence}`, deliveryState: "assigned",
    recipientName: `Recipient ${sequence}`, recipientPhone: "+66000000000", rawAddress: "Bangkok",
    coordinate: { latitude: 13.7 + sequence / 100, longitude: 100.5 + sequence / 100 },
    windowStart: "2026-09-04T01:00:00.000Z", windowEnd: "2026-09-04T09:00:00.000Z",
    manifest: { id: stopId.replace(/003[0-2]$/, "0050"), state: "ready", version: 1, items: [{ lineNumber: 1, description: "Bouquet", quantity: 1, cargoClass: "bouquet" }] },
    pickupConfirmed: false, openExceptionCount: 0,
  };
}

function detail(id: string): OperationsRoundDetail {
  const source = id === sourceId;
  const stopIds = source ? [movedStopId, sourceOtherStopId] : [targetStopId];
  return {
    tenantId, observedAt: now.toISOString(), id, reference: source ? "R-101" : "R-102", serviceDate: "2026-09-04",
    state: "approved", version: source ? 3 : 7,
    routePlan: route(source ? sourceDriver : targetDriver, stopIds),
    driver: { id: source ? sourceDriver : targetDriver, displayName: source ? "Johannes" : "Nok" },
    pickup: { id: "10000000-0000-4000-8000-000000000060", displayName: "UrbanFlowers" },
    stops: stopIds.map((id, index) => stop(id, index + 1)), custodyStopCount: 0, openExceptionCount: 0,
  };
}

class Gateway implements IdentityGateway, OperationsRoundDetailGateway, RoundMoveGateway {
  source = detail(sourceId);
  target = detail(targetId);
  command: MoveRoundStopCommand | null = null;
  async authenticate(): Promise<AuthenticatedIdentity | null> { return { authUserId: "auth" }; }
  async authorizeTenant(): Promise<ActorContext | null> { return actor; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return null; }
  async getOperationsRoundDetail(id: string): Promise<OperationsRoundDetail | null> { return id === sourceId ? this.source : id === targetId ? this.target : null; }
  async moveRoundStop(command: MoveRoundStopCommand): Promise<MoveRoundStopResult> {
    this.command = command;
    return { status: "committed", aggregateVersion: 4, state: { stopId: movedStopId, sourceRoundId: sourceId, targetRoundId: targetId, sourceStopIds: [sourceOtherStopId], targetStopIds: [movedStopId, targetStopId], sourceRoundVersion: 4, targetRoundVersion: 8, sourceRoundRemoved: false }, events: [] };
  }
}

function request(path: string, commit = false): Request {
  return new Request(`http://test${path}`, { method: "POST", headers: { authorization: "Bearer token", "content-type": "application/json", "x-rounds-tenant-id": tenantId, ...(commit ? { "idempotency-key": "move:one" } : {}) }, body: JSON.stringify({ sourceRoundId: sourceId, targetRoundId: targetId, stopId: movedStopId, sourceExpectedVersion: 3, targetExpectedVersion: 7 }) });
}

function dependencies(gateway: Gateway, clock = now, routeRequests: PlanningRoutePreviewRequest[] = []) {
  return {
    identity: gateway, rounds: gateway, now: () => clock,
    uuid: () => "10000000-0000-4000-8000-000000000099",
    routes: { previewAssigned: async (_actor: ActorContext, _roundIds: string[], input: PlanningRoutePreviewRequest) => { routeRequests.push(input); return route(input.driverId, input.stopIds); }, preview: async (_actor: ActorContext, input: PlanningRoutePreviewRequest) => route(input.driverId, input.stopIds) },
  };
}

test("previews both exact resulting Round orders before moving a Stop", async () => {
  const gateway = new Gateway();
  const response = await roundMovePreviewHandler(request("/v1/operations/rounds/move-preview"), dependencies(gateway));
  assert.equal(response.status, 200);
  const body = await response.json() as { movable: boolean; source: { routeAfter: PlanningRoutePreview }; target: { routeAfter: PlanningRoutePreview } };
  assert.equal(body.movable, true);
  assert.deepEqual(body.source.routeAfter.stopIds, [sourceOtherStopId]);
  assert.deepEqual(body.target.routeAfter.stopIds, [movedStopId, targetStopId]);
});

test("recalculates again and commits one geometry-free, dual-version move command", async () => {
  const gateway = new Gateway();
  const response = await roundMoveHandler(request("/v1/operations/rounds/move", true), dependencies(gateway));
  assert.equal(response.status, 200);
  assert.equal(gateway.command?.expectedVersion, 3);
  assert.equal(gateway.command?.payload.targetExpectedVersion, 7);
  assert.deepEqual(gateway.command?.payload.targetStopIds, [movedStopId, targetStopId]);
  assert.equal("geometry" in (gateway.command?.payload.targetRoutePlan ?? {}), false);
});

test("recalculates an unstarted current-day Round from live time when its saved departure has passed", async () => {
  const gateway = new Gateway();
  const routeRequests: PlanningRoutePreviewRequest[] = [];
  const response = await roundMovePreviewHandler(
    request("/v1/operations/rounds/move-preview"),
    dependencies(gateway, new Date("2026-09-04T02:00:00.000Z"), routeRequests),
  );
  assert.equal(response.status, 200);
  assert.equal(routeRequests.length, 2);
  assert.ok(routeRequests.every((routeRequest) => routeRequest.departureAt === undefined));
});

test("custody protection blocks preview and never reaches the move command", async () => {
  const gateway = new Gateway();
  gateway.source = { ...gateway.source, stops: gateway.source.stops.map((item, index) => index === 0 ? { ...item, pickupConfirmed: true } : item) };
  const response = await roundMovePreviewHandler(request("/v1/operations/rounds/move-preview"), dependencies(gateway));
  const body = await response.json() as { movable: boolean; blockingReasons: string[] };
  assert.equal(response.status, 200);
  assert.equal(body.movable, false);
  assert.match(body.blockingReasons.join(" "), /custody/);
  assert.equal(gateway.command, null);
});
