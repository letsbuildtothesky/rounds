import assert from "node:assert/strict";
import test from "node:test";
import type { DriverSession, OperationsRoundDetail, OperationsSession } from "@rounds/contracts";
import { operationsRoundDetailHandler } from "../src/operations-round-detail-handler.js";
import type { ActorContext, AuthenticatedIdentity, IdentityGateway, OperationsRoundDetailGateway } from "../src/types.js";

const tenantId = "10000000-0000-4000-8000-000000000001";
const roundId = "10000000-0000-4000-8000-000000000010";
const actor: ActorContext = { authUserId: "auth-user", personId: "10000000-0000-4000-8000-000000000002", tenantId, role: "dispatcher" };
const observedAt = new Date("2026-09-02T05:00:00.000Z");
const detail: OperationsRoundDetail = {
  tenantId, observedAt: observedAt.toISOString(), id: roundId, reference: "ROUND-001", serviceDate: "2026-09-02",
  state: "active", version: 3, driver: { id: "10000000-0000-4000-8000-000000000020", displayName: "Somchai" },
  pickup: { id: "10000000-0000-4000-8000-000000000030", displayName: "UrbanFlowers" },
  custodyStopCount: 1, openExceptionCount: 0,
  stops: [{
    stopId: "10000000-0000-4000-8000-000000000040", sequence: 1, stopState: "en_route", stopVersion: 2, destinationVersion: 1,
    deliveryId: "10000000-0000-4000-8000-000000000050", deliveryReference: "UF-001", deliveryState: "en_route",
    recipientName: "Siriporn", recipientPhone: "+66000000000", rawAddress: "Bangkok",
    windowStart: "2026-09-02T02:00:00.000Z", windowEnd: "2026-09-02T05:00:00.000Z",
    manifest: { id: "10000000-0000-4000-8000-000000000060", state: "picked_up_locked", version: 1, items: [{ lineNumber: 1, description: "Bouquet", quantity: 1 }] },
    pickupConfirmed: true, openExceptionCount: 0,
  }],
};

class FakeGateway implements IdentityGateway, OperationsRoundDetailGateway {
  authenticated = true;
  authorized = true;
  found = true;
  seenRoundId = "";
  async authenticate(): Promise<AuthenticatedIdentity | null> { return this.authenticated ? { authUserId: "auth-user" } : null; }
  async authorizeTenant(): Promise<ActorContext | null> { return this.authorized ? actor : null; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return null; }
  async getOperationsRoundDetail(id: string): Promise<OperationsRoundDetail | null> { this.seenRoundId = id; return this.found ? detail : null; }
}

function request(headers: Record<string, string> = {}): Request { return new Request(`http://test/v1/operations/rounds/${roundId}`, { headers }); }
function dependencies(gateway: FakeGateway) { return { identity: gateway, rounds: gateway, uuid: () => "10000000-0000-4000-8000-000000000099", now: () => observedAt }; }

test("authorized Operations member loads ordered Round truth", async () => {
  const gateway = new FakeGateway();
  const response = await operationsRoundDetailHandler(request({ authorization: "Bearer valid", "x-rounds-tenant-id": tenantId }), roundId, dependencies(gateway));
  assert.equal(response.status, 200);
  const body = await response.json() as OperationsRoundDetail;
  assert.equal(body.stops[0]?.manifest.items[0]?.description, "Bouquet");
  assert.equal(gateway.seenRoundId, roundId);
});

test("Round detail requires tenant scope", async () => {
  const response = await operationsRoundDetailHandler(request({ authorization: "Bearer valid" }), roundId, dependencies(new FakeGateway()));
  assert.equal(response.status, 400);
});

test("Round detail rejects an unauthorized tenant", async () => {
  const gateway = new FakeGateway();
  gateway.authorized = false;
  const response = await operationsRoundDetailHandler(request({ authorization: "Bearer valid", "x-rounds-tenant-id": tenantId }), roundId, dependencies(gateway));
  assert.equal(response.status, 403);
});

test("Round detail returns not found within the authorized tenant", async () => {
  const gateway = new FakeGateway();
  gateway.found = false;
  const response = await operationsRoundDetailHandler(request({ authorization: "Bearer valid", "x-rounds-tenant-id": tenantId }), roundId, dependencies(gateway));
  assert.equal(response.status, 404);
});
