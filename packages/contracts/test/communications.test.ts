import assert from "node:assert/strict";
import test from "node:test";
import { ContractError, validateSendDriverMessageCommand } from "../src/index.js";

const base = {
  schemaVersion: 1 as const,
  commandType: "thread.send_message" as const,
  commandId: "10000000-0000-4000-8000-000000000101",
  traceId: "10000000-0000-4000-8000-000000000102",
  idempotencyKey: "message:thread-1:one",
  tenantId: "10000000-0000-4000-8000-000000000001",
  aggregateId: "10000000-0000-4000-8000-000000000011",
  expectedVersion: 1,
};

test("accepts a bounded versioned driver message", () => {
  assert.doesNotThrow(() => validateSendDriverMessageCommand({
    ...base,
    payload: { body: "Running five minutes late" },
  }));
});

test("rejects empty and oversized message bodies", () => {
  assert.throws(() => validateSendDriverMessageCommand({
    ...base,
    payload: { body: "   " },
  }), ContractError);
  assert.throws(() => validateSendDriverMessageCommand({
    ...base,
    payload: { body: "x".repeat(2001) },
  }), ContractError);
});
