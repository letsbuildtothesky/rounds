import assert from "node:assert/strict";
import test from "node:test";
import type {
  DriverOperationsThread,
  DriverSession,
  LogContactAttemptCommand,
  LogContactAttemptResult,
  OperationsSession,
  SendDriverMessageCommand,
  SendDriverMessageResult,
} from "@rounds/contracts";
import { driverOperationsThreadHandler } from "../src/driver-operations-thread-handler.js";
import { logContactAttemptHandler } from "../src/log-contact-attempt-handler.js";
import { sendDriverMessageHandler } from "../src/send-driver-message-handler.js";
import type {
  ActorContext,
  AuthenticatedIdentity,
  DriverCommunicationsGateway,
  IdentityGateway,
} from "../src/types.js";

const tenantId = "10000000-0000-4000-8000-000000000001";
const driverId = "10000000-0000-4000-8000-000000000002";
const roundId = "10000000-0000-4000-8000-000000000010";
const stopId = "10000000-0000-4000-8000-000000000011";
const threadId = "10000000-0000-4000-8000-000000000012";

const session: DriverSession = {
  user: { id: "auth-user", displayName: "Driver" },
  driver: { id: driverId, version: 1, preferredLocale: "en" },
  currentRound: {
    id: roundId,
    reference: "ROUND-001",
    serviceDate: "2026-09-02",
    state: "active",
    version: 2,
    tenant: { id: tenantId, displayName: "UrbanFlowers", timezone: "Asia/Bangkok" },
    pickup: {
      id: "10000000-0000-4000-8000-000000000020",
      displayName: "Studio",
      rawAddress: "Bangkok",
      contactName: "Dispatch",
      contactPhone: "+66000000000",
    },
    stops: [{
      id: stopId,
      sequence: 1,
      state: "active",
      version: 4,
      destinationVersion: 1,
      deliveryId: "10000000-0000-4000-8000-000000000013",
      deliveryReference: "UF-001",
      recipientName: "Siriporn",
      recipientPhone: "+66999999999",
      rawAddress: "Bangkok",
      latitude: 13.74,
      longitude: 100.54,
      isSurprise: false,
      windowStart: "2026-09-02T02:00:00Z",
      windowEnd: "2026-09-02T04:00:00Z",
      manifestId: "10000000-0000-4000-8000-000000000014",
      manifestVersion: 1,
      manifestItems: [{ lineNumber: 1, description: "Bouquet", quantity: 1 }],
    }],
  },
};

class FakeCommunicationsGateway implements IdentityGateway, DriverCommunicationsGateway {
  driverSession: DriverSession | null = session;
  command: SendDriverMessageCommand | null = null;
  contactCommand: LogContactAttemptCommand | null = null;
  readonly thread: DriverOperationsThread = { id: threadId, roundId, stopId, version: 3, messages: [] };
  async authenticate(): Promise<AuthenticatedIdentity | null> { return { authUserId: "auth-user" }; }
  async authorizeTenant(): Promise<ActorContext | null> { return null; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return this.driverSession; }
  async getDriverOperationsThread(): Promise<DriverOperationsThread | null> { return this.thread; }
  async sendDriverMessage(command: SendDriverMessageCommand): Promise<SendDriverMessageResult> {
    this.command = command;
    return {
      status: "committed",
      aggregateVersion: 4,
      state: {
        threadId,
        message: {
          id: "10000000-0000-4000-8000-000000000030",
          sender: "driver",
          body: command.payload.body,
          sentAt: "2026-09-02T03:00:00Z",
        },
      },
      events: [],
    };
  }
  async logContactAttempt(command: LogContactAttemptCommand): Promise<LogContactAttemptResult> {
    this.contactCommand = command;
    return {
      status: "committed",
      aggregateVersion: command.expectedVersion,
      state: {
        stopId,
        deliveryId: "10000000-0000-4000-8000-000000000013",
        roundId,
        operationsThreadId: threadId,
        attempt: {
          id: "10000000-0000-4000-8000-000000000031",
          target: command.payload.target,
          channel: command.payload.channel,
          outcome: command.payload.outcome,
          occurredAt: "2026-09-02T03:00:00Z",
        },
      },
      events: [],
    };
  }
}

const dependencies = (gateway: FakeCommunicationsGateway) => ({
  identity: gateway,
  communications: gateway,
  uuid: () => "10000000-0000-4000-8000-000000000101",
  now: () => new Date("2026-09-02T03:00:00Z"),
});

test("assigned driver loads the stop Operations thread", async () => {
  const gateway = new FakeCommunicationsGateway();
  const response = await driverOperationsThreadHandler(new Request("http://test/thread", {
    headers: { authorization: "Bearer token" },
  }), roundId, stopId, dependencies(gateway));
  assert.equal(response.status, 200);
  assert.equal((await response.json() as DriverOperationsThread).id, threadId);
});

test("assigned driver sends a trimmed versioned message", async () => {
  const gateway = new FakeCommunicationsGateway();
  const response = await sendDriverMessageHandler(new Request("http://test/messages", {
    method: "POST",
    headers: {
      authorization: "Bearer token",
      "content-type": "application/json",
      "idempotency-key": "message:one",
    },
    body: JSON.stringify({ body: "  Running five minutes late  " }),
  }), roundId, stopId, dependencies(gateway));
  assert.equal(response.status, 201);
  assert.equal(gateway.command?.aggregateId, threadId);
  assert.equal(gateway.command?.expectedVersion, 3);
  assert.equal(gateway.command?.payload.body, "Running five minutes late");
});

test("driver cannot read a thread outside the current assignment", async () => {
  const gateway = new FakeCommunicationsGateway();
  gateway.driverSession = { user: session.user, driver: session.driver };
  const response = await driverOperationsThreadHandler(new Request("http://test/thread", {
    headers: { authorization: "Bearer token" },
  }), roundId, stopId, dependencies(gateway));
  assert.equal(response.status, 403);
});

test("assigned driver records a native recipient-call outcome", async () => {
  const gateway = new FakeCommunicationsGateway();
  const response = await logContactAttemptHandler(new Request("http://test/contact-attempts", {
    method: "POST",
    headers: {
      authorization: "Bearer token",
      "content-type": "application/json",
      "idempotency-key": "contact:one",
    },
    body: JSON.stringify({ target: "recipient", channel: "native_phone", outcome: "no_answer" }),
  }), stopId, dependencies(gateway));
  assert.equal(response.status, 201);
  assert.equal(gateway.contactCommand?.aggregateId, stopId);
  assert.equal(gateway.contactCommand?.expectedVersion, 4);
  assert.equal(gateway.contactCommand?.payload.outcome, "no_answer");
});
