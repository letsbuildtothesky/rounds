import assert from "node:assert/strict";
import test from "node:test";
import { ContractError, validatePlanRoundCommand, validatePlanRoundPayload } from "../src/index.js";

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
