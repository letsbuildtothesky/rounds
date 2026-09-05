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

test("live map names the server remaining route and Rounds-owned trail separately", () => {
  assert.deepEqual(operationsMapLegendEntries({
    mode: "live",
    hasOwnDriverPositions: true,
    hasActionStops: false,
    hasUnplannedStops: false,
    hasProposedRoute: false,
    hasRemainingRoute: true,
    hasActualTrail: true,
  }), [
    { key: "own", label: "Own driver", tone: "own" },
    { key: "remaining-route", label: "Remaining route", tone: "live-route" },
    { key: "actual-trail", label: "Travelled trail", tone: "trail" },
  ]);
});
