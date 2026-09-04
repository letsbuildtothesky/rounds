import assert from "node:assert/strict";
import test from "node:test";
import {
  validateEndDriverShiftCommand,
  type EndDriverShiftCommand,
} from "../src/index.js";

const attendanceId = "97000000-0000-4000-8000-000000000003";
const command: EndDriverShiftCommand = {
  schemaVersion: 1,
  commandType: "driver.end_shift",
  commandId: "97000000-0000-4000-8000-000000000004",
  traceId: "97000000-0000-4000-8000-000000000005",
  idempotencyKey: "driver-shift-end:attendance:v1",
  tenantId: "97000000-0000-4000-8000-000000000001",
  aggregateId: attendanceId,
  expectedVersion: 1,
  occurredFromDeviceAt: "2026-09-04T10:22:00.000Z",
  payload: { attendanceId },
};

test("EndDriverShift accepts one versioned attendance aggregate", () => {
  assert.doesNotThrow(() => validateEndDriverShiftCommand(command));
});

test("EndDriverShift rejects mismatched attendance and invalid versions", () => {
  assert.throws(() => validateEndDriverShiftCommand({
    ...command,
    payload: { attendanceId: "97000000-0000-4000-8000-000000000006" },
  }));
  assert.throws(() => validateEndDriverShiftCommand({ ...command, expectedVersion: 0 }));
});
