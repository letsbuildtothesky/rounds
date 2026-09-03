import assert from "node:assert/strict";
import test from "node:test";
import {
  ContractError,
  validateConfirmPickupCommand,
  validateConfirmPickupPayload,
  validateConfirmStopArrivalCommand,
  validateCompleteStopPodCommand,
  validatePreparePodMediaPayload,
  validatePlanRoundCommand,
  validatePlanRoundPayload,
  validatePlanningRoutePreviewRequest,
  validateReportPickupProblemCommand,
  validateReportDeliveryProblemCommand,
} from "../src/index.js";

const payload = () => ({
  reference: "ROUND-2026-001",
  serviceDate: "2026-09-02",
  driverId: "10000000-0000-4000-8000-000000000002",
  stopIds: ["10000000-0000-4000-8000-000000000005"],
  departureAt: "2026-09-02T01:00:00.000Z",
  routePlan: {
    status: "fits" as const,
    serviceDate: "2026-09-02",
    driverId: "10000000-0000-4000-8000-000000000002",
    stopIds: ["10000000-0000-4000-8000-000000000005"],
    calculatedAt: "2026-09-01T12:00:00.000Z",
    departureAt: "2026-09-02T01:00:00.000Z",
    finishAt: "2026-09-02T02:30:00.000Z",
    distanceMeters: 2500,
    durationSeconds: 900,
    provider: { name: "mapbox" as const, profile: "driving-traffic" as const, freshness: "live" as const },
    stops: [{ stopId: "10000000-0000-4000-8000-000000000005", sequence: 1, eta: "2026-09-02T01:15:00.000Z", departureAt: "2026-09-02T02:00:00.000Z", windowStart: "2026-09-02T02:00:00.000Z", windowEnd: "2026-09-02T04:00:00.000Z", promiseStatus: "early" as const, waitingSeconds: 2700, latenessSeconds: 0, legDurationSeconds: 900, legDistanceMeters: 2500 }],
    blockingReasons: [],
    warnings: [],
    capacity: { status: "fits" as const, dimensions: [{ kind: "stops" as const, code: "stops", displayName: "Stops per departure", used: 1, limit: 8, remaining: 7, utilizationPercent: 13, status: "fits" as const }], constrainingDimension: { kind: "stops" as const, code: "stops" }, reasons: [], warnings: [] },
  },
});

test("accepts an explicitly ordered Team Round", () => {
  assert.doesNotThrow(() => validatePlanRoundPayload(payload()));
});

test("rejects duplicate Stops", () => {
  const input = payload();
  input.stopIds.push(input.stopIds[0]!);
  assert.throws(() => validatePlanRoundPayload(input), ContractError);
});

test("requires the requested departure to match the routed departure", () => {
  const missing = payload() as ReturnType<typeof payload> & { departureAt?: string };
  delete missing.departureAt;
  assert.throws(() => validatePlanRoundPayload(missing as ReturnType<typeof payload>), /departureAt/);

  const changed = payload();
  changed.departureAt = "2026-09-02T01:15:00.000Z";
  assert.throws(() => validatePlanRoundPayload(changed), /routePlan departure/);
});

test("validates route preview identity and ordered Stops", () => {
  assert.doesNotThrow(() => validatePlanningRoutePreviewRequest({
    serviceDate: payload().serviceDate,
    driverId: payload().driverId,
    stopIds: payload().stopIds,
  }));
  assert.doesNotThrow(() => validatePlanningRoutePreviewRequest({
    serviceDate: payload().serviceDate,
    driverId: payload().driverId,
    stopIds: payload().stopIds,
    departureAt: "2026-09-02T01:15:00.000Z",
  }));
  assert.throws(() => validatePlanningRoutePreviewRequest({
    serviceDate: payload().serviceDate,
    driverId: payload().driverId,
    stopIds: payload().stopIds,
    departureAt: "tomorrow-ish",
  }), /departureAt/);
});

test("requires a new aggregate command", () => {
  assert.throws(() => validatePlanRoundCommand({
    schemaVersion: 1,
    commandType: "round.plan_and_approve",
    commandId: "10000000-0000-4000-8000-000000000101",
    traceId: "10000000-0000-4000-8000-000000000102",
    idempotencyKey: "round:001",
    tenantId: "10000000-0000-4000-8000-000000000001",
    aggregateId: "10000000-0000-4000-8000-000000000100",
    expectedVersion: 1,
    payload: payload(),
  }), /expectedVersion/);
});

const pickupPayload = {
  stops: [{
    stopId: "10000000-0000-4000-8000-000000000011",
    manifestId: "10000000-0000-4000-8000-000000000012",
    manifestVersion: 1,
    confirmedLineNumbers: [1, 2],
  }],
};

test("accepts exact manifest line confirmations for pickup", () => {
  assert.doesNotThrow(() => validateConfirmPickupPayload(pickupPayload));
  assert.doesNotThrow(() => validateConfirmPickupCommand({
    schemaVersion: 1,
    commandType: "round.confirm_pickup",
    commandId: "10000000-0000-4000-8000-000000000101",
    traceId: "10000000-0000-4000-8000-000000000102",
    idempotencyKey: "pickup:round-1",
    tenantId: "10000000-0000-4000-8000-000000000001",
    aggregateId: "10000000-0000-4000-8000-000000000010",
    expectedVersion: 1,
    payload: pickupPayload,
  }));
});

test("rejects incomplete or duplicate pickup confirmation identifiers", () => {
  assert.throws(() => validateConfirmPickupPayload({
    stops: [{ ...pickupPayload.stops[0]!, confirmedLineNumbers: [] }],
  }), ContractError);
  assert.throws(() => validateConfirmPickupPayload({
    stops: [pickupPayload.stops[0]!, pickupPayload.stops[0]!],
  }), ContractError);
});

test("accepts a structured pickup problem with a bounded note", () => {
  assert.doesNotThrow(() => validateReportPickupProblemCommand({
    schemaVersion: 1,
    commandType: "stop.report_pickup_problem",
    commandId: "10000000-0000-4000-8000-000000000101",
    traceId: "10000000-0000-4000-8000-000000000102",
    idempotencyKey: "problem:stop-1",
    tenantId: "10000000-0000-4000-8000-000000000001",
    aggregateId: "10000000-0000-4000-8000-000000000011",
    expectedVersion: 2,
    payload: {
      manifestId: "10000000-0000-4000-8000-000000000012",
      manifestVersion: 1,
      category: "damaged_item",
      note: "Outer package is crushed",
    },
  }));
});

test("requires verified photo identity for a delivery damage problem", () => {
  assert.doesNotThrow(() => validateReportDeliveryProblemCommand({
    schemaVersion: 1,
    commandType: "stop.report_delivery_problem",
    commandId: "10000000-0000-4000-8000-000000000101",
    traceId: "10000000-0000-4000-8000-000000000102",
    idempotencyKey: "delivery-problem:stop-1",
    tenantId: "10000000-0000-4000-8000-000000000001",
    aggregateId: "10000000-0000-4000-8000-000000000011",
    expectedVersion: 5,
    payload: {
      manifestId: "10000000-0000-4000-8000-000000000012",
      manifestVersion: 1,
      category: "damaged_item",
      mediaAssetId: "10000000-0000-4000-8000-000000000013",
      note: "Outer package is crushed",
    },
  }));
  assert.throws(() => validateReportDeliveryProblemCommand({
    schemaVersion: 1,
    commandType: "stop.report_delivery_problem",
    commandId: "10000000-0000-4000-8000-000000000101",
    traceId: "10000000-0000-4000-8000-000000000102",
    idempotencyKey: "delivery-problem:stop-1",
    tenantId: "10000000-0000-4000-8000-000000000001",
    aggregateId: "10000000-0000-4000-8000-000000000011",
    expectedVersion: 5,
    payload: {
      manifestId: "10000000-0000-4000-8000-000000000012",
      manifestVersion: 1,
      category: "damaged_item",
      mediaAssetId: "not-a-uuid",
    },
  }), ContractError);
});

test("validates explicit arrival evidence without requiring GPS", () => {
  const base = {
    schemaVersion: 1 as const,
    commandType: "stop.confirm_arrival" as const,
    commandId: "10000000-0000-4000-8000-000000000101",
    traceId: "10000000-0000-4000-8000-000000000102",
    idempotencyKey: "arrival:stop-1",
    tenantId: "10000000-0000-4000-8000-000000000001",
    aggregateId: "10000000-0000-4000-8000-000000000011",
    expectedVersion: 4,
  };
  assert.doesNotThrow(() => validateConfirmStopArrivalCommand({ ...base, payload: {} }));
  assert.doesNotThrow(() => validateConfirmStopArrivalCommand({
    ...base,
    payload: {
      position: {
        latitude: 13.7439,
        longitude: 100.547,
        accuracyMeters: 18,
        source: "google_nav",
      },
    },
  }));
  assert.throws(() => validateConfirmStopArrivalCommand({
    ...base,
    payload: {
      position: {
        latitude: 113.7439,
        longitude: 100.547,
        accuracyMeters: 18,
        source: "google_nav",
      },
    },
  }), ContractError);
});

test("requires bounded immutable photo metadata before POD upload", () => {
  assert.doesNotThrow(() => validatePreparePodMediaPayload({
    sha256: "a".repeat(64),
    byteSize: 120000,
    contentType: "image/jpeg",
  }));
  assert.throws(() => validatePreparePodMediaPayload({
    sha256: "bad",
    byteSize: 120000,
    contentType: "image/jpeg",
  }), ContractError);
});

test("validates receiver-first handoff and exact POD manifest evidence", () => {
  const base = {
    schemaVersion: 1 as const,
    commandType: "stop.complete_pod" as const,
    commandId: "10000000-0000-4000-8000-000000000101",
    traceId: "10000000-0000-4000-8000-000000000102",
    idempotencyKey: "pod:stop-1",
    tenantId: "10000000-0000-4000-8000-000000000001",
    aggregateId: "10000000-0000-4000-8000-000000000011",
    expectedVersion: 5,
  };
  assert.doesNotThrow(() => validateCompleteStopPodCommand({ ...base, payload: {
    manifestId: "10000000-0000-4000-8000-000000000012",
    manifestVersion: 1,
    confirmedLineNumbers: [1, 2],
    mediaAssetId: "10000000-0000-4000-8000-000000000013",
    handoffType: "recipient",
    receiverName: "Siriporn",
  } }));
  assert.throws(() => validateCompleteStopPodCommand({ ...base, payload: {
    manifestId: "10000000-0000-4000-8000-000000000012",
    manifestVersion: 1,
    confirmedLineNumbers: [1],
    mediaAssetId: "10000000-0000-4000-8000-000000000013",
    handoffType: "someone_else",
    receiverName: "Reception",
  } }), /receiverRelationship/);
});
