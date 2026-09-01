import assert from "node:assert/strict";
import test from "node:test";
import {
  assertDeliveryTransition,
  canTransitionDelivery,
  checkExpectedVersion,
  InvalidDeliveryTransitionError,
  normalizedPayloadHash,
} from "../src/index.js";
import type { CommandEnvelope } from "@rounds/contracts";

test("permits the Slice 1 happy-path delivery transitions", () => {
  const path = [
    "unplanned",
    "planned",
    "assigned",
    "pickup_pending",
    "in_custody",
    "en_route",
    "arrived",
    "delivered_pending_evidence",
    "delivered",
  ] as const;

  for (let index = 1; index < path.length; index += 1) {
    assert.equal(canTransitionDelivery(path[index - 1]!, path[index]!), true);
  }
});

test("blocks fabricated delivery completion", () => {
  assert.throws(
    () => assertDeliveryTransition("unplanned", "delivered"),
    InvalidDeliveryTransitionError,
  );
});

test("allows explicit exception transitions only from active operational states", () => {
  assert.equal(canTransitionDelivery("in_custody", "exception"), true);
  assert.equal(canTransitionDelivery("delivered", "exception"), false);
});

test("stale expected versions never advance the aggregate", () => {
  assert.deepEqual(checkExpectedVersion(5, 4), {
    ok: false,
    code: "STALE_VERSION",
    currentVersion: 5,
  });
  assert.deepEqual(checkExpectedVersion(5, 5), { ok: true, nextVersion: 6 });
});

test("payload hashing is stable across object key ordering", () => {
  const envelope = (payload: Record<string, unknown>): CommandEnvelope<string, unknown> => ({
    schemaVersion: 1,
    commandType: "test",
    commandId: "id",
    traceId: "trace",
    idempotencyKey: "key",
    tenantId: "tenant",
    aggregateId: "aggregate",
    expectedVersion: 0,
    payload,
  });

  assert.equal(
    normalizedPayloadHash(envelope({ recipient: { phone: "2", name: "1" }, count: 1 })),
    normalizedPayloadHash(envelope({ count: 1, recipient: { name: "1", phone: "2" } })),
  );
});
