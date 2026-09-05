import assert from "node:assert/strict";
import test from "node:test";
import type { OperationsMapStop, OperationsRoundSummary } from "@rounds/contracts";
import { operationsMapStopMarkers } from "../src/operations-map-stops";

function round(id: string, state: OperationsRoundSummary["state"]): OperationsRoundSummary {
  return { id, reference: `ROUND-${id}`, serviceDate: "2026-09-05", state, driverId: `driver-${id}`, driverName: `Driver ${id}`, stopCount: 3, custodyStopCount: 0, openExceptionCount: 0 };
}

function stop(roundId: string, sequence: number, stopState: string): OperationsMapStop {
  return { roundId, stopId: `${roundId}-stop-${sequence}`, sequence, stopState, deliveryId: `${roundId}-delivery-${sequence}`, deliveryReference: `${roundId}-${sequence}`, recipientName: `Recipient ${sequence}`, rawAddress: `Address ${sequence}`, coordinate: { latitude: 13.7 + sequence / 100, longitude: 100.5 + sequence / 100 } };
}

test("active Round emphasizes the first non-terminal Stop and keeps later Stops future", () => {
  const markers = operationsMapStopMarkers([
    stop("A", 3, "active"),
    stop("A", 1, "completed"),
    stop("A", 2, "arrived"),
  ], [round("A", "active")]);

  assert.deepEqual(markers.map((marker) => [marker.stop.sequence, marker.emphasis]), [
    [1, "done"],
    [2, "current"],
    [3, "future"],
  ]);
});

test("approved and loading Rounds do not invent a current Stop", () => {
  const markers = operationsMapStopMarkers([
    stop("A", 1, "assigned"),
    stop("B", 1, "assigned"),
  ], [round("A", "approved"), round("B", "loading")]);

  assert.deepEqual(markers.map((marker) => marker.emphasis), ["future", "future"]);
});

test("orphan Stop data is not rendered", () => {
  assert.deepEqual(operationsMapStopMarkers([stop("missing", 1, "active")], []), []);
});
