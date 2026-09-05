import assert from "node:assert/strict";
import test from "node:test";
import { operationsMapLegendEntries } from "../src/operations-map-legend";

test("live map legend exposes only rendered own-fleet evidence", () => {
  assert.deepEqual(operationsMapLegendEntries({
    mode: "live",
    hasOwnDriverPositions: true,
    hasActionStops: true,
    hasUnplannedStops: true,
    hasProposedRoute: true,
  }), [
    { key: "own", label: "Own driver", tone: "own" },
    { key: "action", label: "Action stop", tone: "destination" },
  ]);
});

test("plan map legend identifies unplanned work and a real proposed route", () => {
  assert.deepEqual(operationsMapLegendEntries({
    mode: "plan",
    hasOwnDriverPositions: false,
    hasActionStops: true,
    hasUnplannedStops: true,
    hasProposedRoute: true,
  }), [
    { key: "unplanned", label: "Unplanned stop", tone: "destination" },
    { key: "proposed-route", label: "Proposed route", tone: "route" },
  ]);
});

test("map legend is absent when there is no rendered operational evidence", () => {
  assert.deepEqual(operationsMapLegendEntries({
    mode: "live",
    hasOwnDriverPositions: false,
    hasActionStops: false,
    hasUnplannedStops: false,
    hasProposedRoute: false,
  }), []);
});
