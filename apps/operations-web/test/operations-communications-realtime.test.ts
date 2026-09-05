import assert from "node:assert/strict";
import test from "node:test";
import {
  isOperationsCommunicationsHint,
  operationsCommunicationsEvent,
  operationsDispatchTopic,
} from "../src/operations-communications-realtime";

const tenantId = "00000000-0000-4000-8000-000000000001";

test("uses the locked private tenant Dispatch topic", () => {
  assert.equal(operationsDispatchTopic(tenantId), `tenant:${tenantId}:dispatch`);
});

test("accepts a versioned same-tenant communications hint", () => {
  assert.equal(isOperationsCommunicationsHint({
    event: operationsCommunicationsEvent,
    payload: {
      schemaVersion: 1,
      event: operationsCommunicationsEvent,
      tenantId,
      aggregateType: "operations_thread",
      aggregateId: "00000000-0000-4000-8000-000000000002",
      aggregateVersion: 4,
      occurredAt: "2026-09-05T05:00:00Z",
    },
  }, tenantId), true);
});

test("rejects cross-tenant and malformed hints", () => {
  const base = {
    event: operationsCommunicationsEvent,
    payload: {
      schemaVersion: 1,
      event: operationsCommunicationsEvent,
      tenantId,
      aggregateType: "operations_thread",
      aggregateId: "00000000-0000-4000-8000-000000000002",
      aggregateVersion: 4,
      occurredAt: "2026-09-05T05:00:00Z",
    },
  };

  assert.equal(isOperationsCommunicationsHint(base, "10000000-0000-4000-8000-000000000001"), false);
  assert.equal(isOperationsCommunicationsHint({ ...base, payload: { ...base.payload, aggregateVersion: "4" } }, tenantId), false);
  assert.equal(isOperationsCommunicationsHint({ ...base, event: "message.body" }, tenantId), false);
});
