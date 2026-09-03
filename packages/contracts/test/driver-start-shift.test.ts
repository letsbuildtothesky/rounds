import assert from "node:assert/strict";
import test from "node:test";
import {
  ContractError,
  validateStartDriverShiftCommand,
  type StartDriverShiftCommand,
} from "../src/index.js";

const command: StartDriverShiftCommand = {
  schemaVersion: 1,
  commandType: "driver.start_shift",
  commandId: "97000000-0000-4000-8000-000000000001",
  traceId: "97000000-0000-4000-8000-000000000002",
  idempotencyKey: "driver-shift:2026-09-03",
  tenantId: "97000000-0000-4000-8000-000000000003",
  aggregateId: "97000000-0000-4000-8000-000000000004",
  expectedVersion: 0,
  occurredFromDeviceAt: "2026-09-03T00:52:00.000Z",
  payload: { serviceDate: "2026-09-03" },
};

test("accepts one version-zero Team shift start", () => {
  assert.doesNotThrow(() => validateStartDriverShiftCommand(command));
});

test("rejects malformed service dates and nonzero initial versions", () => {
  assert.throws(
    () => validateStartDriverShiftCommand({ ...command, payload: { serviceDate: "2026-02-30" } }),
    ContractError,
  );
  assert.throws(
    () => validateStartDriverShiftCommand({ ...command, expectedVersion: 1 }),
    ContractError,
  );
});
