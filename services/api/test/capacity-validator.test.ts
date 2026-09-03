import assert from "node:assert/strict";
import test from "node:test";
import { evaluateCapacity } from "../src/capacity-validator.js";

const base = {
  stopCount: 2,
  maxStopsPerDeparture: 8,
  departurePattern: "multi_stop" as const,
  cargoRequirements: [{ cargoClassCode: "bouquet", displayName: "Bouquets", quantity: 3, classificationStatus: "classified" as const }],
  cargoLimits: [{ cargoClassCode: "bouquet", displayName: "Bouquets", allowed: true, maxQuantity: 4 }],
};

test("identifies cargo as the constraining dimension when it has the highest utilization", () => {
  const result = evaluateCapacity(base);
  assert.equal(result.status, "fits");
  assert.deepEqual(result.constrainingDimension, { kind: "cargo", code: "bouquet" });
  assert.equal(result.dimensions.find((item) => item.code === "bouquet")?.utilizationPercent, 75);
});

test("identifies Stops as a distinct bottleneck", () => {
  const result = evaluateCapacity({ ...base, stopCount: 8, cargoRequirements: [{ ...base.cargoRequirements[0]!, quantity: 1 }] });
  assert.equal(result.status, "fits");
  assert.deepEqual(result.constrainingDimension, { kind: "stops", code: "stops" });
});

test("never treats unclassified cargo as fitting", () => {
  const result = evaluateCapacity({ ...base, cargoRequirements: [{ cargoClassCode: "unclassified", displayName: "Unclassified cargo", quantity: 1, classificationStatus: "unclassified" }] });
  assert.equal(result.status, "review_required");
  assert.match(result.reasons[0] ?? "", /unclassified/);
});

test("blocks a class that the vehicle does not allow", () => {
  const result = evaluateCapacity({ ...base, cargoLimits: [{ cargoClassCode: "bouquet", displayName: "Bouquets", allowed: false }] });
  assert.equal(result.status, "blocked");
  assert.match(result.reasons[0] ?? "", /not allowed/);
});

test("aggregates repeated cargo requirements before applying the limit", () => {
  const result = evaluateCapacity({
    ...base,
    cargoRequirements: [
      { ...base.cargoRequirements[0]!, quantity: 3 },
      { ...base.cargoRequirements[0]!, quantity: 2 },
    ],
  });
  assert.equal(result.status, "blocked");
  assert.equal(result.dimensions.find((item) => item.code === "bouquet")?.used, 5);
});
