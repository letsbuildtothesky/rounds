import assert from "node:assert/strict";
import test from "node:test";
import type {
  DriverSession,
  CommunicationThreadReadState,
  OperationsCommunicationThread,
  OperationsCommunicationsProjection,
  OperationsSession,
  SendOperationsMessageCommand,
  SendOperationsMessageResult,
  PrepareMessageMediaPayload,
} from "@rounds/contracts";
import { operationsCommunicationsHandler } from "../src/operations-communications-handler.js";
import { prepareOperationsMessageMediaHandler, verifyOperationsMessageMediaHandler } from "../src/prepare-operations-message-media-handler.js";
import { sendOperationsMessageHandler } from "../src/send-operations-message-handler.js";
import { markOperationsCommunicationThreadReadHandler } from "../src/mark-communication-thread-read-handler.js";
import type {
  ActorContext,
  AuthenticatedIdentity,
  IdentityGateway,
  OperationsCommunicationsGateway,
} from "../src/types.js";

const tenantId = "10000000-0000-4000-8000-000000000001";
const threadId = "10000000-0000-4000-8000-000000000012";
const actor: ActorContext = {
  authUserId: "auth-user",
  personId: "10000000-0000-4000-8000-000000000002",
  tenantId,
  role: "dispatcher",
};
const thread: OperationsCommunicationThread = {
  id: threadId,
  priority: "normal",
  roundId: "10000000-0000-4000-8000-000000000010",
  roundReference: "ROUND-001",
  stopId: "10000000-0000-4000-8000-000000000011",
  stopSequence: 1,
  deliveryId: "10000000-0000-4000-8000-000000000013",
  deliveryReference: "UF-001",
  recipientName: "Siriporn",
  rawAddress: "Bangkok",
  destinationPosition: { latitude: 13.744, longitude: 100.54 },
  driverId: "10000000-0000-4000-8000-000000000014",
  driverName: "Driver Demo",
  contactAttempts: [],
  version: 3,
  unreadCount: 1,
  firstUnreadMessageId: "10000000-0000-4000-8000-000000000031",
  hasUnreadVoice: false,
  updatedAt: "2026-09-02T03:00:00Z",
  messages: [],
};

class FakeGateway implements IdentityGateway, OperationsCommunicationsGateway {
  role: ActorContext["role"] = "dispatcher";
  command: SendOperationsMessageCommand | null = null;
  markedReadMessageId: string | null = null;
  async authenticate(): Promise<AuthenticatedIdentity | null> { return { authUserId: "auth-user" }; }
  async authorizeTenant(): Promise<ActorContext | null> { return { ...actor, role: this.role }; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return null; }
  async getOperationsCommunications(): Promise<OperationsCommunicationsProjection> {
    return { tenantId, totalUnreadCount: thread.unreadCount, threads: [thread] };
  }
  async getOperationsCommunicationThread(id: string): Promise<OperationsCommunicationThread | null> {
    return id === threadId ? thread : null;
  }
  async markOperationsCommunicationThreadRead(
    id: string,
    lastReadMessageId: string,
  ): Promise<CommunicationThreadReadState | null> {
    if (id !== threadId) return null;
    this.markedReadMessageId = lastReadMessageId;
    return { threadId, lastReadMessageId, unreadCount: 0, hasUnreadVoice: false };
  }
  async sendOperationsMessage(command: SendOperationsMessageCommand): Promise<SendOperationsMessageResult> {
    this.command = command;
    return {
      status: "committed",
      aggregateVersion: 4,
      state: {
        threadId,
        message: {
          id: "10000000-0000-4000-8000-000000000030",
          sender: "operations",
          body: command.payload.body,
          sentAt: "2026-09-02T03:01:00Z",
        },
      },
      events: [],
    };
  }
  async prepareOperationsMessageMedia(
    id: string,
    _actor: ActorContext,
    assetId: string,
    payload: PrepareMessageMediaPayload,
  ): Promise<Record<string, unknown>> {
    return { status: "prepared", mediaAssetId: assetId, threadId: id, kind: payload.kind };
  }
  async verifyOperationsMessageMedia(assetId: string): Promise<Record<string, unknown>> {
    return { status: "verified", mediaAssetId: assetId, assetState: "uploaded_uncommitted" };
  }
}

const dependencies = (gateway: FakeGateway) => ({
  identity: gateway,
  communications: gateway,
  uuid: () => "10000000-0000-4000-8000-000000000101",
  now: () => new Date("2026-09-02T03:01:00Z"),
});

test("authorized Operations member loads tenant threads", async () => {
  const gateway = new FakeGateway();
  const response = await operationsCommunicationsHandler(new Request("http://test/communications", {
    headers: { authorization: "Bearer token", "x-rounds-tenant-id": tenantId },
  }), dependencies(gateway));
  assert.equal(response.status, 200);
  assert.equal((await response.json() as OperationsCommunicationsProjection).threads[0]?.driverName, "Driver Demo");
});

test("dispatcher sends a trimmed versioned Operations reply", async () => {
  const gateway = new FakeGateway();
  const response = await sendOperationsMessageHandler(new Request("http://test/messages", {
    method: "POST",
    headers: {
      authorization: "Bearer token",
      "content-type": "application/json",
      "idempotency-key": "operations:one",
      "x-rounds-tenant-id": tenantId,
    },
    body: JSON.stringify({ body: "  Continue to the recipient  " }),
  }), threadId, dependencies(gateway));
  assert.equal(response.status, 201);
  assert.equal(gateway.command?.aggregateId, threadId);
  assert.equal(gateway.command?.expectedVersion, 3);
  assert.equal(gateway.command?.payload.body, "Continue to the recipient");
});

test("dispatcher can prepare and verify private message media", async () => {
  const gateway = new FakeGateway();
  const prepare = await prepareOperationsMessageMediaHandler(new Request("http://test/message-media", {
    method: "POST",
    headers: {
      authorization: "Bearer token",
      "content-type": "application/json",
      "x-rounds-tenant-id": tenantId,
    },
    body: JSON.stringify({
      kind: "voice",
      fileName: "dispatch-note.webm",
      contentType: "audio/webm",
      byteSize: 512,
      sha256: "a".repeat(64),
      durationMilliseconds: 1200,
    }),
  }), threadId, dependencies(gateway));
  assert.equal(prepare.status, 201);
  const prepared = await prepare.json() as { mediaAssetId: string };
  const verify = await verifyOperationsMessageMediaHandler(new Request("http://test/verify", {
    method: "POST",
    headers: { authorization: "Bearer token", "x-rounds-tenant-id": tenantId },
  }), prepared.mediaAssetId, dependencies(gateway));
  assert.equal(verify.status, 200);
});

test("Operations reply preserves staged attachments in the versioned command", async () => {
  const gateway = new FakeGateway();
  const attachment = {
    kind: "location" as const,
    label: "Dispatcher location",
    latitude: 13.744,
    longitude: 100.54,
    capturedAt: "2026-09-02T03:01:00.000Z",
  };
  const response = await sendOperationsMessageHandler(new Request("http://test/messages", {
    method: "POST",
    headers: {
      authorization: "Bearer token",
      "content-type": "application/json",
      "idempotency-key": "operations:location",
      "x-rounds-tenant-id": tenantId,
    },
    body: JSON.stringify({ body: "", attachments: [attachment] }),
  }), threadId, dependencies(gateway));
  assert.equal(response.status, 201);
  assert.deepEqual(gateway.command?.payload.attachments, [attachment]);
});

test("viewer cannot reply to a driver", async () => {
  const gateway = new FakeGateway();
  gateway.role = "viewer";
  const response = await sendOperationsMessageHandler(new Request("http://test/messages", {
    method: "POST",
    headers: {
      authorization: "Bearer token",
      "content-type": "application/json",
      "idempotency-key": "operations:viewer",
      "x-rounds-tenant-id": tenantId,
    },
    body: JSON.stringify({ body: "Not permitted" }),
  }), threadId, dependencies(gateway));
  assert.equal(response.status, 403);
  assert.equal(gateway.command, null);
});

test("viewer can clear only their own Operations unread cursor", async () => {
  const gateway = new FakeGateway();
  gateway.role = "viewer";
  const lastReadMessageId = "10000000-0000-4000-8000-000000000031";
  const response = await markOperationsCommunicationThreadReadHandler(new Request("http://test/read", {
    method: "POST",
    headers: {
      authorization: "Bearer token",
      "content-type": "application/json",
      "x-rounds-tenant-id": tenantId,
    },
    body: JSON.stringify({ lastReadMessageId }),
  }), threadId, dependencies(gateway));
  assert.equal(response.status, 200);
  assert.equal(gateway.markedReadMessageId, lastReadMessageId);
  assert.equal((await response.json() as CommunicationThreadReadState).unreadCount, 0);
});
