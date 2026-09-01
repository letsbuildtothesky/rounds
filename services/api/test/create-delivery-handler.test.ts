import assert from "node:assert/strict";
import test from "node:test";
import type {
  CreateDeliveryCommand,
  CreateDeliveryPayload,
  CreateDeliveryResult,
  DriverSession,
  OperationsSession,
} from "@rounds/contracts";
import { createDeliveryHandler } from "../src/create-delivery-handler.js";
import type {
  ActorContext,
  CreateDeliveryDependencies,
  DeliveryCommandGateway,
  IdentityGateway,
} from "../src/types.js";

const payload = (): CreateDeliveryPayload => ({
  sourceSystem: "manual",
  externalId: "UF-001",
  serviceDate: "2026-09-02",
  serviceTimezone: "Asia/Bangkok",
  pickupLocationId: "10000000-0000-4000-8000-000000000020",
  recipient: {
    name: "Siriporn",
    phone: "+66999999999",
    rawAddress: "Park Hyatt Bangkok",
    coordinate: {
      latitude: 13.7439,
      longitude: 100.547,
      provenance: "dispatcher_pin",
    },
  },
  buyer: { sameAsRecipient: true },
  promise: {
    windowStart: "2026-09-02T02:00:00.000Z",
    windowEnd: "2026-09-02T04:00:00.000Z",
  },
  manifest: { items: [{ description: "Flower bouquet", quantity: 1 }] },
});

const actor: ActorContext = {
  authUserId: "auth-user",
  personId: "10000000-0000-4000-8000-000000000010",
  tenantId: "10000000-0000-4000-8000-000000000001",
  role: "dispatcher",
};

class FakeGateway implements IdentityGateway, DeliveryCommandGateway {
  authenticated = true;
  authorizedActor: ActorContext | null = actor;
  commandResult: CreateDeliveryResult = {
    status: "committed",
    aggregateVersion: 1,
    state: {
      deliveryId: "10000000-0000-4000-8000-000000000100",
      deliveryState: "unplanned",
      stopId: "10000000-0000-4000-8000-000000000200",
      manifestId: "10000000-0000-4000-8000-000000000300",
    },
    events: [],
  };
  lastCommand: CreateDeliveryCommand | null = null;
  lastActor: ActorContext | null = null;

  async authenticate(): Promise<{ authUserId: string } | null> {
    return this.authenticated ? { authUserId: "auth-user" } : null;
  }

  async authorizeTenant(): Promise<ActorContext | null> {
    return this.authorizedActor;
  }

  async getOperationsSession(): Promise<OperationsSession | null> {
    return null;
  }

  async getDriverSession(): Promise<DriverSession | null> {
    return null;
  }

  async createDelivery(command: CreateDeliveryCommand, commandActor: ActorContext): Promise<CreateDeliveryResult> {
    this.lastCommand = command;
    this.lastActor = commandActor;
    return this.commandResult;
  }

  async ready(): Promise<boolean> {
    return true;
  }
}

function request(body: unknown = payload(), headers: Record<string, string> = {}): Request {
  return new Request("http://api.rounds.test/v1/deliveries", {
    method: "POST",
    headers: {
      authorization: "Bearer valid-token",
      "content-type": "application/json",
      "x-rounds-tenant-id": actor.tenantId,
      "idempotency-key": "manual:UF-001",
      ...headers,
    },
    body: JSON.stringify(body),
  });
}

function dependencies(gateway: FakeGateway): CreateDeliveryDependencies {
  const ids = [
    "10000000-0000-4000-8000-000000000102",
    "10000000-0000-4000-8000-000000000101",
    "10000000-0000-4000-8000-000000000100",
  ];
  return {
    identity: gateway,
    commands: gateway,
    uuid: () => ids.shift() ?? "10000000-0000-4000-8000-000000000999",
    now: () => new Date("2026-09-01T12:00:00.000Z"),
  };
}

test("requires a bearer session", async () => {
  const gateway = new FakeGateway();
  const response = await createDeliveryHandler(request(payload(), { authorization: "" }), dependencies(gateway));
  assert.equal(response.status, 401);
  assert.equal(gateway.lastCommand, null);
});

test("rejects a viewer before any command reaches the database", async () => {
  const gateway = new FakeGateway();
  gateway.authorizedActor = { ...actor, role: "viewer" };
  const response = await createDeliveryHandler(request(), dependencies(gateway));
  assert.equal(response.status, 403);
  assert.equal(gateway.lastCommand, null);
});

test("derives actor and tenant context, validates, then commits", async () => {
  const gateway = new FakeGateway();
  const response = await createDeliveryHandler(request(), dependencies(gateway));
  assert.equal(response.status, 201);
  assert.equal(response.headers.get("x-trace-id"), "10000000-0000-4000-8000-000000000102");
  assert.equal(gateway.lastActor, actor);
  assert.equal(gateway.lastCommand?.tenantId, actor.tenantId);
  assert.equal(gateway.lastCommand?.expectedVersion, 0);
  assert.equal(gateway.lastCommand?.idempotencyKey, "manual:UF-001");
});

test("rejects invalid delivery input without calling the command gateway", async () => {
  const gateway = new FakeGateway();
  const invalid = payload();
  invalid.manifest.items = [];
  const response = await createDeliveryHandler(request(invalid), dependencies(gateway));
  assert.equal(response.status, 422);
  assert.equal(gateway.lastCommand, null);
});

test("returns 200 for a safely deduplicated external delivery", async () => {
  const gateway = new FakeGateway();
  gateway.commandResult = { ...gateway.commandResult, deduplicated: true } as CreateDeliveryResult;
  const response = await createDeliveryHandler(request(), dependencies(gateway));
  assert.equal(response.status, 200);
});

test("maps idempotency conflicts to HTTP 409", async () => {
  const gateway = new FakeGateway();
  gateway.commandResult = {
    status: "rejected",
    error: { code: "IDEMPOTENCY_CONFLICT", message: "conflict" },
  };
  const response = await createDeliveryHandler(request(), dependencies(gateway));
  assert.equal(response.status, 409);
});
