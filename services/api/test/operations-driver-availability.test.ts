import assert from "node:assert/strict";
import test from "node:test";
import { projectCurrentRoundAvailability } from "../src/operations-driver-availability.js";

const observedAt = new Date("2026-09-05T04:00:00.000Z");

test("active own Round projects next capacity from its saved future finish", () => {
  const availability = projectCurrentRoundAvailability({
    reference: "ROUND-1",
    state: "active",
    routePlan: { finishAt: "2026-09-05T05:15:00.000Z" },
  }, observedAt);
  assert.equal(availability.state, "on_round");
  assert.equal(availability.nextAvailableAt, "2026-09-05T05:15:00.000Z");
  assert.match(availability.projectionBasis, /saved approved route finish/);
});

test("loading own Round exposes its saved route finish without claiming live certainty", () => {
  const availability = projectCurrentRoundAvailability({
    reference: "ROUND-2",
    state: "loading",
    routePlan: { finishAt: "2026-09-05T06:00:00.000Z" },
  }, observedAt);
  assert.equal(availability.state, "loading");
  assert.equal(availability.nextAvailableAt, "2026-09-05T06:00:00.000Z");
  assert.match(availability.projectionBasis, /execution has not completed/);
});

test("missing or past route finish never fabricates a next available time", () => {
  const missing = projectCurrentRoundAvailability({ reference: "ROUND-3", state: "active" }, observedAt);
  const past = projectCurrentRoundAvailability({ reference: "ROUND-4", state: "active", routePlan: { finishAt: "2026-09-05T03:00:00.000Z" } }, observedAt);
  assert.equal(missing.nextAvailableAt, undefined);
  assert.equal(past.nextAvailableAt, undefined);
  assert.match(past.projectionBasis, /has passed/);
});
