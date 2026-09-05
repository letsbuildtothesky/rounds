import assert from "node:assert/strict";
import test from "node:test";
import type {
  ConfirmDeliveryReturnCommand,
  ConfirmDeliveryReturnResult,
  DriverSession,
  OperationsActionProjection,
  OperationsSession,
  ResolveOperationsExceptionCommand,
  ResolveOperationsExceptionResult,
} from "@rounds/contracts";
import { operationsActionHandler } from "../src/operations-action-handler.js";
import type {
  ActorContext,
  AuthenticatedIdentity,
  IdentityGateway,
  OperationsActionGateway,
} from "../src/types.js";

const tenantId = "10000000-0000-4000-8000-000000000001";
const actor: ActorContext = {
  authUserId: "auth-user",
  personId: "10000000-0000-4000-8000-000000000002",
  tenantId,
  role: "dispatcher",
};
const projection: OperationsActionProjection = {
  tenantId,
  observedAt: "2026-09-02T04:00:00.000Z",
  rounds: [],
  mapStops: [],
  exceptions: [{
    id: "10000000-0000-4000-8000-000000000010",
    deliveryId: "10000000-0000-4000-8000-000000000011",
    deliveryReference: "UF-001",
    recipientName: "Siriporn",
    rawAddress: "Bangkok",
    stopId: "10000000-0000-4000-8000-000000000012",
    stopSequence: 1,
    stopState: "exception",
    stopVersion: 3,
    roundId: "10000000-0000-4000-8000-000000000013",
    roundReference: "ROUND-001",
    roundState: "approved",
    driverId: "10000000-0000-4000-8000-000000000014",
    driverName: "Driver Demo",
    stage: "pickup",
    category: "missing_item",
    note: "One bouquet is missing",
    status: "open",
    manifestVersion: 1,
    reportedAt: "2026-09-02T03:55:00.000Z",
  }],
};

class FakeGateway implements IdentityGateway, OperationsActionGateway {
  authenticated = true;
  authorized = true;
  observedAt: Date | null = null;
  async authenticate(): Promise<AuthenticatedIdentity | null> {
    return this.authenticated ? { authUserId: "auth-user" } : null;
  }
  async authorizeTenant(): Promise<ActorContext | null> { return this.authorized ? actor : null; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return null; }
  async getOperationsAction(_actor: ActorContext, observedAt: Date): Promise<OperationsActionProjection> {
    this.observedAt = observedAt;
    return projection;
  }
  async resolveOperationsException(_command: ResolveOperationsExceptionCommand): Promise<ResolveOperationsExceptionResult> {
    return { status: "rejected", error: { code: "INVALID_STATE", message: "unused" } };
  }
  async confirmDeliveryReturn(_command: ConfirmDeliveryReturnCommand): Promise<ConfirmDeliveryReturnResult> {
    return { status: "rejected", error: { code: "INVALID_STATE", message: "unused" } };
  }
}

function request(headers: Record<string, string> = {}): Request {
  return new Request("http://test/v1/operations/action", { headers });
}

const now = new Date("2026-09-02T04:00:00.000Z");
const dependencies = (gateway: FakeGateway) => ({
  identity: gateway,
  action: gateway,
  uuid: () => "10000000-0000-4000-8000-000000000099",
  now: () => now,
});

test("authorized Operations member loads unresolved action truth", async () => {
  const gateway = new FakeGateway();
  const response = await operationsActionHandler(request({
    authorization: "Bearer valid",
    "x-rounds-tenant-id": tenantId,
  }), dependencies(gateway));
  assert.equal(response.status, 200);
  assert.equal((await response.json() as OperationsActionProjection).exceptions[0]?.category, "missing_item");
  assert.equal(gateway.observedAt, now);
});

test("Action requires a tenant scope", async () => {
  const response = await operationsActionHandler(request({ authorization: "Bearer valid" }), dependencies(new FakeGateway()));
  assert.equal(response.status, 400);
});

test("Action rejects an unauthorized tenant", async () => {
  const gateway = new FakeGateway();
  gateway.authorized = false;
  const response = await operationsActionHandler(request({
    authorization: "Bearer valid",
    "x-rounds-tenant-id": tenantId,
  }), dependencies(gateway));
  assert.equal(response.status, 403);
});
