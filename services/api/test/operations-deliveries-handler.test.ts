import assert from "node:assert/strict";
import test from "node:test";
import type { DriverSession, OperationsDeliveriesProjection, OperationsSession } from "@rounds/contracts";
import { operationsDeliveriesHandler } from "../src/operations-deliveries-handler.js";
import type { ActorContext, AuthenticatedIdentity, IdentityGateway, OperationsDeliveriesGateway } from "../src/types.js";

const tenantId = "10000000-0000-4000-8000-000000000001";
const actor: ActorContext = { authUserId: "auth-user", personId: "10000000-0000-4000-8000-000000000002", tenantId, role: "dispatcher" };
const observedAt = new Date("2026-09-02T05:00:00.000Z");
const projection: OperationsDeliveriesProjection = {
  tenantId,
  observedAt: observedAt.toISOString(),
  deliveries: [{
    deliveryId: "10000000-0000-4000-8000-000000000010",
    reference: "UF-001",
    state: "unplanned",
    version: 1,
    sourceSystem: "manual",
    serviceDate: "2026-09-02",
    serviceTimezone: "Asia/Bangkok",
    pickupLocationId: "10000000-0000-4000-8000-000000000020",
    pickupLocationName: "UrbanFlowers",
    buyerSameAsRecipient: true,
    buyerName: "Siriporn",
    buyerPhone: "+66000000000",
    recipientName: "Siriporn",
    recipientPhone: "+66000000000",
    rawAddress: "Bangkok",
    isSurprise: false,
    createdAt: observedAt.toISOString(),
    updatedAt: observedAt.toISOString(),
    stop: { id: "10000000-0000-4000-8000-000000000030", state: "pending", version: 1 },
    promise: { windowStart: "2026-09-02T02:00:00.000Z", windowEnd: "2026-09-02T05:00:00.000Z" },
    manifest: { id: "10000000-0000-4000-8000-000000000040", state: "draft", version: 1, items: [{ lineNumber: 1, description: "Bouquet", quantity: 1 }] },
  }],
};

class FakeGateway implements IdentityGateway, OperationsDeliveriesGateway {
  authenticated = true;
  authorized = true;
  seenAt: Date | null = null;
  async authenticate(): Promise<AuthenticatedIdentity | null> { return this.authenticated ? { authUserId: "auth-user" } : null; }
  async authorizeTenant(): Promise<ActorContext | null> { return this.authorized ? actor : null; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return null; }
  async getOperationsDeliveries(_actor: ActorContext, at: Date): Promise<OperationsDeliveriesProjection> { this.seenAt = at; return projection; }
}

function request(headers: Record<string, string> = {}): Request { return new Request("http://test/v1/operations/deliveries", { headers }); }
function dependencies(gateway: FakeGateway) { return { identity: gateway, deliveries: gateway, uuid: () => "10000000-0000-4000-8000-000000000099", now: () => observedAt }; }

test("authorized Operations member loads canonical delivery truth", async () => {
  const gateway = new FakeGateway();
  const response = await operationsDeliveriesHandler(request({ authorization: "Bearer valid", "x-rounds-tenant-id": tenantId }), dependencies(gateway));
  assert.equal(response.status, 200);
  const body = await response.json() as OperationsDeliveriesProjection;
  assert.equal(body.deliveries[0]?.manifest.items[0]?.description, "Bouquet");
  assert.equal(gateway.seenAt, observedAt);
});

test("delivery projection requires tenant scope", async () => {
  const response = await operationsDeliveriesHandler(request({ authorization: "Bearer valid" }), dependencies(new FakeGateway()));
  assert.equal(response.status, 400);
});

test("delivery projection rejects an unauthorized tenant", async () => {
  const gateway = new FakeGateway();
  gateway.authorized = false;
  const response = await operationsDeliveriesHandler(request({ authorization: "Bearer valid", "x-rounds-tenant-id": tenantId }), dependencies(gateway));
  assert.equal(response.status, 403);
});
