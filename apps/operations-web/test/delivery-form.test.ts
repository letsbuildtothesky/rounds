import assert from "node:assert/strict";
import test from "node:test";
import {
  buildCreateDeliveryPayload,
  defaultDeliveryDraft,
  DeliveryFormError,
  todayInBangkok,
} from "../src/delivery-form.js";

function validDraft() {
  return {
    ...defaultDeliveryDraft("2026-09-02"),
    reference: "UF-10452",
    pickupLocationId: "10000000-0000-4000-8000-000000000020",
    recipientName: "Siriporn",
    recipientPhone: "+66812345678",
    address: "Park Hyatt Bangkok",
    latitude: "13.7439",
    longitude: "100.5470",
    items: [{ description: "Bouquet", quantity: "2", handlingNote: "Fragile" }],
  };
}

test("normalizes the manual form into the canonical delivery contract", () => {
  const payload = buildCreateDeliveryPayload(validDraft());
  assert.equal(payload.sourceSystem, "manual");
  assert.equal(payload.externalId, "UF-10452");
  assert.equal(payload.promise.windowStart, "2026-09-02T02:00:00.000Z");
  assert.equal(payload.promise.windowEnd, "2026-09-02T05:00:00.000Z");
  assert.deepEqual(payload.manifest.items[0], {
    description: "Bouquet",
    quantity: 2,
    handlingNote: "Fragile",
  });
});

test("keeps buyer and recipient separate for a gift", () => {
  const payload = buildCreateDeliveryPayload({
    ...validDraft(),
    buyerSameAsRecipient: false,
    buyerName: "Maya",
    buyerPhone: "+66987654321",
    isSurprise: true,
  });
  assert.deepEqual(payload.buyer, {
    sameAsRecipient: false,
    name: "Maya",
    phone: "+66987654321",
  });
  assert.equal(payload.isSurprise, true);
});

test("rejects an incomplete operational destination pin", () => {
  assert.throws(
    () => buildCreateDeliveryPayload({ ...validDraft(), latitude: "" }),
    DeliveryFormError,
  );
});

test("uses the Bangkok calendar day", () => {
  assert.equal(todayInBangkok(new Date("2026-09-01T18:30:00.000Z")), "2026-09-02");
});
