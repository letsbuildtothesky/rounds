import assert from "node:assert/strict";
import test from "node:test";
import { ContractError, validateConfirmDeliveryReturnCommand, type ConfirmDeliveryReturnCommand } from "../src/index.js";

const command: ConfirmDeliveryReturnCommand = {
  schemaVersion: 1,
  commandType: "operations.confirm_delivery_return",
  commandId: "92000000-0000-4000-8000-000000000001",
  traceId: "92000000-0000-4000-8000-000000000002",
  idempotencyKey: "delivery-return:1",
  tenantId: "92000000-0000-4000-8000-000000000003",
  aggregateId: "92000000-0000-4000-8000-000000000004",
  expectedVersion: 6,
  occurredFromDeviceAt: "2026-09-02T07:00:00.000Z",
  payload: {
    exceptionId: "92000000-0000-4000-8000-000000000005",
    note: "Somchai returned the damaged package and Mali accepted it at UrbanFlowers",
  },
};

test("accepts a versioned physical delivery return confirmation", () => {
  assert.doesNotThrow(() => validateConfirmDeliveryReturnCommand(command));
});

test("requires bounded physical-return evidence", () => {
  assert.throws(() => validateConfirmDeliveryReturnCommand({ ...command, payload: { ...command.payload, note: "" } }), ContractError);
  assert.throws(() => validateConfirmDeliveryReturnCommand({ ...command, payload: { ...command.payload, note: "x".repeat(501) } }), ContractError);
});
