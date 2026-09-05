import assert from "node:assert/strict";
import test from "node:test";
import type { OperationsCommunicationThread } from "@rounds/contracts";
import {
  composeOperationsContactHistory,
  filterOperationsContactHistory,
} from "../src/operations-contact-history";

const thread: OperationsCommunicationThread = {
  id: "10000000-0000-4000-8000-000000000001",
  roundId: "10000000-0000-4000-8000-000000000002",
  stopId: "10000000-0000-4000-8000-000000000003",
  deliveryId: "10000000-0000-4000-8000-000000000004",
  driverId: "10000000-0000-4000-8000-000000000005",
  priority: "normal",
  roundReference: "ROUND-001",
  deliveryReference: "UF-001",
  recipientName: "Siriporn",
  rawAddress: "Bangkok",
  driverName: "Johannes",
  stopSequence: 1,
  version: 4,
  unreadCount: 0,
  hasUnreadVoice: false,
  updatedAt: "2026-09-05T05:00:00Z",
  contactAttempts: [{
    id: "10000000-0000-4000-8000-000000000050",
    target: "recipient",
    channel: "native_phone",
    outcome: "no_answer",
    occurredAt: "2026-09-05T04:02:00Z",
  }],
  messages: [{
    id: "10000000-0000-4000-8000-000000000010",
    sender: "driver",
    body: "I am at the entrance",
    sentAt: "2026-09-05T04:00:00Z",
    attachments: [{
      kind: "image",
      mediaAssetId: "10000000-0000-4000-8000-000000000011",
      fileName: "entrance.jpg",
      contentType: "image/jpeg",
      byteSize: 1200,
    }],
  }, {
    id: "10000000-0000-4000-8000-000000000020",
    sender: "system",
    body: "Recipient call · No answer",
    sentAt: "2026-09-05T04:02:02Z",
  }, {
    id: "10000000-0000-4000-8000-000000000030",
    sender: "operations",
    body: "Wait two minutes",
    sentAt: "2026-09-05T04:03:00Z",
  }],
};

test("contact ledger composes persisted messages, media and typed calls without duplicate system calls", () => {
  const history = composeOperationsContactHistory(thread);
  assert.deepEqual(history.counts, { messages: 2, calls: 1, media: 1 });
  assert.equal(history.events.length, 4);
  assert.equal(history.events.some((event) => event.id.startsWith("system:")), false);
  assert.equal(history.events[0]?.detail, "Wait two minutes");
  assert.equal(history.events.find((event) => event.group === "calls")?.status, "No answer");
});

test("contact ledger filters do not duplicate the same persisted event", () => {
  const history = composeOperationsContactHistory(thread);
  assert.deepEqual(filterOperationsContactHistory(history.events, "messages").map((event) => event.type), ["Message", "Message"]);
  assert.deepEqual(filterOperationsContactHistory(history.events, "calls").map((event) => event.type), ["Native call"]);
  assert.deepEqual(filterOperationsContactHistory(history.events, "media").map((event) => event.type), ["Photo"]);
});
