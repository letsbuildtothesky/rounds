import assert from "node:assert/strict";
import test from "node:test";
import type {
  DriverSession,
  OperationsCommunicationThread,
  OperationsCommunicationsProjection,
  OperationsSession,
  SendOperationsMessageCommand,
  SendOperationsMessageResult,
} from "@rounds/contracts";
import { operationsCommunicationsHandler } from "../src/operations-communications-handler.js";
import { sendOperationsMessageHandler } from "../src/send-operations-message-handler.js";
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
  driverId: "10000000-0000-4000-8000-000000000014",
  driverName: "Driver Demo",
  version: 3,
  updatedAt: "2026-09-02T03:00:00Z",
  messages: [],
};

class FakeGateway implements IdentityGateway, OperationsCommunicationsGateway {
  role: ActorContext["role"] = "dispatcher";
  command: SendOperationsMessageCommand | null = null;
  async authenticate(): Promise<AuthenticatedIdentity | null> { return { authUserId: "auth-user" }; }
  async authorizeTenant(): Promise<ActorContext | null> { return { ...actor, role: this.role }; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return null; }
  async getOperationsCommunications(): Promise<OperationsCommunicationsProjection> {
    return { tenantId, threads: [thread] };
  }
  async getOperationsCommunicationThread(id: string): Promise<OperationsCommunicationThread | null> {
    return id === threadId ? thread : null;
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
