import assert from "node:assert/strict";
import test from "node:test";
import type { OperationsRoundDetail, OperationsRoundSummary } from "@rounds/contracts";
import { groupOperationsRounds, roundCapacityLabel, roundVehicleLabel } from "../src/operations-rounds-overview";

function summary(id: string, state: OperationsRoundSummary["state"]): OperationsRoundSummary {
  return { id, reference: id, serviceDate: "2026-09-05", state, driverId: `${id}-driver`, driverName: "Johannes", stopCount: 2, custodyStopCount: 0, openExceptionCount: 0 };
}

test("v45 overview separates current own work from approved upcoming work", () => {
  const groups = groupOperationsRounds([
    summary("active", "active"),
    summary("loading", "loading"),
    summary("approved", "approved"),
    summary("complete", "complete"),
  ]);
  assert.deepEqual(groups.active.map((item) => item.summary.id), ["active", "loading"]);
  assert.deepEqual(groups.upcoming.map((item) => item.summary.id), ["approved"]);
});

test("v45 overview reports real vehicle and the constraining capacity percentage", () => {
  const detail = {
    driver: { id: "driver", displayName: "Johannes", vehicleLabel: "Motorbike + box", vehiclePlate: "ABC 123" },
    routePlan: { capacity: { status: "fits", dimensions: [
      { kind: "stops", code: "stops", displayName: "Stops", used: 2, limit: 4, utilizationPercent: 50, status: "fits" },
      { kind: "cargo", code: "flowers", displayName: "Flowers", used: 8, limit: 10, utilizationPercent: 80, status: "fits" },
    ] } },
  } as OperationsRoundDetail;
  assert.equal(roundVehicleLabel(detail), "Motorbike + box");
  assert.equal(roundCapacityLabel(detail), "80% load");
});

test("v45 overview never invents unavailable vehicle or capacity facts", () => {
  assert.equal(roundVehicleLabel(undefined), "Vehicle not loaded");
  assert.equal(roundCapacityLabel(undefined), "Capacity not measured");
  assert.equal(roundCapacityLabel({ routePlan: {} } as OperationsRoundDetail), "Capacity not measured");
});
