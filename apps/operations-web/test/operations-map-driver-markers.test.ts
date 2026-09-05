import assert from "node:assert/strict";
import test from "node:test";
import type { OperationsRoundSummary } from "@rounds/contracts";
import { operationsMapDriverMarkers } from "../src/operations-map-driver-markers";

function round(input: Pick<OperationsRoundSummary, "id" | "reference" | "driverId" | "driverName" | "state" | "currentPosition">): OperationsRoundSummary {
  return { ...input, serviceDate: "2026-09-05", stopCount: 1, custodyStopCount: 0, openExceptionCount: 0 };
}

test("one physical own driver produces one marker across multiple assigned Rounds", () => {
  const position = { latitude: 13.73, longitude: 100.56, capturedAt: "2026-09-05T06:00:00.000Z" };
  const markers = operationsMapDriverMarkers([
    round({ id: "approved-2", reference: "ROUND-2", driverId: "driver-1", driverName: "Johannes", state: "approved", currentPosition: position }),
    round({ id: "active", reference: "ROUND-1", driverId: "driver-1", driverName: "Johannes", state: "active", currentPosition: position }),
    round({ id: "approved-3", reference: "ROUND-3", driverId: "driver-1", driverName: "Johannes", state: "approved", currentPosition: position }),
  ]);

  assert.equal(markers.length, 1);
  assert.equal(markers[0]?.round.id, "active");
  assert.deepEqual(markers[0]?.roundIds, ["approved-2", "active", "approved-3"]);
});

test("deduplicated marker uses the driver's newest hot position", () => {
  const markers = operationsMapDriverMarkers([
    round({ id: "round-1", reference: "ROUND-1", driverId: "driver-1", driverName: "Johannes", state: "active", currentPosition: { latitude: 13.7, longitude: 100.5, capturedAt: "2026-09-05T05:00:00.000Z" } }),
    round({ id: "round-2", reference: "ROUND-2", driverId: "driver-1", driverName: "Johannes", state: "approved", currentPosition: { latitude: 13.8, longitude: 100.6, capturedAt: "2026-09-05T05:05:00.000Z" } }),
  ]);

  assert.equal(markers[0]?.round.id, "round-1");
  assert.equal(markers[0]?.position.latitude, 13.8);
  assert.equal(markers[0]?.position.capturedAt, "2026-09-05T05:05:00.000Z");
});

test("different own drivers remain separate markers", () => {
  const position = { latitude: 13.73, longitude: 100.56, capturedAt: "2026-09-05T06:00:00.000Z" };
  const markers = operationsMapDriverMarkers([
    round({ id: "round-1", reference: "ROUND-1", driverId: "driver-1", driverName: "Johannes", state: "active", currentPosition: position }),
    round({ id: "round-2", reference: "ROUND-2", driverId: "driver-2", driverName: "Somchai", state: "active", currentPosition: position }),
  ]);
  assert.equal(markers.length, 2);
});
