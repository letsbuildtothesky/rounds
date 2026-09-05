import assert from "node:assert/strict";
import test from "node:test";
import type { OperationsDeliveryItem } from "@rounds/contracts";
import {
  deliveryCommandBoundary,
  deliveryMatchesScope,
  deliveryMatchesSearch,
  deliveryQueueTab,
} from "../src/operations-delivery-dispatch";

function delivery(state: OperationsDeliveryItem["state"], overrides: Partial<OperationsDeliveryItem> = {}): OperationsDeliveryItem {
  return {
    deliveryId: "delivery-1",
    reference: "UF-001",
    state,
    version: 1,
    sourceSystem: "manual",
    serviceDate: "2026-09-05",
    serviceTimezone: "Asia/Bangkok",
    pickupLocationId: "pickup-1",
    pickupLocationName: "UrbanFlowers",
    buyerSameAsRecipient: true,
    buyerName: "Siriporn Demo",
    buyerPhone: "+66000000000",
    recipientName: "Siriporn Demo",
    recipientPhone: "+66000000000",
    rawAddress: "88 Wireless Road, Bangkok",
    isSurprise: false,
    createdAt: "2026-09-05T01:00:00.000Z",
    updatedAt: "2026-09-05T01:00:00.000Z",
    stop: { id: "stop-1", state: "assigned", version: 1 },
    promise: { windowStart: "2026-09-05T02:00:00.000Z", windowEnd: "2026-09-05T04:00:00.000Z" },
    manifest: { id: "manifest-1", state: "draft", version: 1, items: [{ lineNumber: 1, description: "Bouquet", quantity: 1 }] },
    ...overrides,
  };
}

test("canonical delivery states enter the v45 Ready, Live and Done queues", () => {
  assert.equal(deliveryQueueTab(delivery("unplanned")), "ready");
  assert.equal(deliveryQueueTab(delivery("pickup_pending")), "ready");
  assert.equal(deliveryQueueTab(delivery("en_route")), "live");
  assert.equal(deliveryQueueTab(delivery("delivered_pending_evidence")), "live");
  assert.equal(deliveryQueueTab(delivery("delivered")), "done");
  assert.equal(deliveryQueueTab(delivery("returned")), "done");
  assert.equal(deliveryQueueTab(delivery("exception")), null);
});

test("Today scope uses the tenant-local service date and All remains complete", () => {
  const item = delivery("assigned");
  assert.equal(deliveryMatchesScope(item, "today", "2026-09-05"), true);
  assert.equal(deliveryMatchesScope(item, "today", "2026-09-06"), false);
  assert.equal(deliveryMatchesScope(item, "all", "2026-09-06"), true);
});

test("delivery search covers reference, recipient, address, phone and Round", () => {
  const item = delivery("assigned", { round: { id: "round-1", reference: "ROUND-88", state: "approved", sequence: 1, driverName: "Johannes" } });
  assert.equal(deliveryMatchesSearch(item, "wireless"), true);
  assert.equal(deliveryMatchesSearch(item, "round-88"), true);
  assert.equal(deliveryMatchesSearch(item, "missing"), false);
});

test("actions route to the existing authoritative workflow instead of inventing edits", () => {
  assert.equal(deliveryCommandBoundary(delivery("unplanned")), "plan");
  assert.equal(deliveryCommandBoundary(delivery("assigned", { round: { id: "round-1", reference: "ROUND-1", state: "approved", sequence: 1, driverName: "Johannes" } })), "round-pre-custody");
  assert.equal(deliveryCommandBoundary(delivery("en_route", { round: { id: "round-1", reference: "ROUND-1", state: "active", sequence: 1, driverName: "Johannes" } })), "round-live");
  assert.equal(deliveryCommandBoundary(delivery("delivered")), "history");
  assert.equal(deliveryCommandBoundary(delivery("exception")), "exception");
});
