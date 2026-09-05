import assert from "node:assert/strict";
import test from "node:test";
import type { OperationsCommunicationThread, OperationsCommunicationsProjection } from "@rounds/contracts";
import { applyCommunicationReadState, communicationUnreadByRound } from "../src/operations-communications-state";

function thread(id: string, roundId: string, unreadCount: number, hasUnreadVoice = false): OperationsCommunicationThread {
  return {
    id,
    roundId,
    stopId: `${id.slice(0, -1)}a`,
    version: 1,
    unreadCount,
    ...(unreadCount ? { firstUnreadMessageId: `${id.slice(0, -1)}b` } : {}),
    hasUnreadVoice,
    messages: [],
    priority: "normal",
    roundReference: "ROUND-1",
    stopSequence: 1,
    deliveryId: `${id.slice(0, -1)}c`,
    deliveryReference: "UF-1",
    recipientName: "Siriporn",
    rawAddress: "Bangkok",
    driverId: `${id.slice(0, -1)}d`,
    driverName: "Johannes",
    contactAttempts: [],
    updatedAt: "2026-09-05T02:00:00Z",
  };
}

test("one read acknowledgement clears the shared topbar and thread state", () => {
  const projection: OperationsCommunicationsProjection = {
    tenantId: "10000000-0000-4000-8000-000000000001",
    totalUnreadCount: 2,
    threads: [thread("10000000-0000-4000-8000-000000000010", "10000000-0000-4000-8000-000000000020", 2, true)],
  };
  const next = applyCommunicationReadState(projection, {
    threadId: projection.threads[0]!.id,
    lastReadMessageId: "10000000-0000-4000-8000-000000000030",
    unreadCount: 0,
    hasUnreadVoice: false,
  });
  assert.equal(next.totalUnreadCount, 0);
  assert.equal(next.threads[0]?.unreadCount, 0);
  assert.equal(next.threads[0]?.hasUnreadVoice, false);
});

test("map unread state aggregates every thread for the same Round", () => {
  const roundId = "10000000-0000-4000-8000-000000000020";
  const projection: OperationsCommunicationsProjection = {
    tenantId: "10000000-0000-4000-8000-000000000001",
    totalUnreadCount: 3,
    threads: [
      thread("10000000-0000-4000-8000-000000000010", roundId, 1),
      thread("10000000-0000-4000-8000-000000000011", roundId, 2, true),
    ],
  };
  assert.deepEqual(communicationUnreadByRound(projection)[roundId], {
    count: 3,
    hasVoice: true,
    threadId: projection.threads[0]!.id,
  });
});
