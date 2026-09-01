import assert from "node:assert/strict";
import test from "node:test";
import {
  ContractError,
  validateConfirmPickupCommand,
  validateConfirmPickupPayload,
  validateConfirmStopArrivalCommand,
  validatePlanRoundCommand,
  validatePlanRoundPayload,
  validateReportPickupProblemCommand,
} from "../src/index.js";

const payload = () => ({
  reference: "ROUND-2026-001",
  serviceDate: "2026-09-02",
  driverId: "10000000-0000-4000-8000-000000000002",
  stopIds: ["10000000-0000-4000-8000-000000000005"],
});

test("accepts an explicitly ordered Team Round", () => {
  assert.doesNotThrow(() => validatePlanRoundPayload(payload()));
});

test("rejects duplicate Stops", () => {
  const input = payload();
  input.stopIds.push(input.stopIds[0]!);
  assert.throws(() => validatePlanRoundPayload(input), ContractError);
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
