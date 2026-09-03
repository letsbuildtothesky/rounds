import assert from "node:assert/strict";
import test from "node:test";
import { liveChangePinError } from "../src/live-change-policy.js";

test("keeps an unchanged address on its existing physical pin", () => {
  assert.equal(liveChangePinError({
    originalAddress: "88 Wireless Road",
    draftAddress: "88 Wireless Road",
    keepCurrentPin: false,
    pinSelectionMade: false,
  }), undefined);
});

test("requires an explicit pin decision when destination text changes", () => {
  assert.equal(liveChangePinError({
    originalAddress: "88 Wireless Road",
    draftAddress: "Central Embassy entrance",
    keepCurrentPin: false,
    pinSelectionMade: false,
  }), "Set the new physical pin on the map, or explicitly keep the current pin");
});

test("allows an address clarification that explicitly keeps the physical pin", () => {
  assert.equal(liveChangePinError({
    originalAddress: "88 Wireless Road",
    draftAddress: "88 Wireless Road, loading entrance",
    keepCurrentPin: true,
    pinSelectionMade: false,
  }), undefined);
});

test("allows an address change after a real map pin selection", () => {
  assert.equal(liveChangePinError({
    originalAddress: "88 Wireless Road",
    draftAddress: "Central Embassy entrance",
    keepCurrentPin: false,
    pinSelectionMade: true,
  }), undefined);
});
