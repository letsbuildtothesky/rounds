import assert from "node:assert/strict";
import test from "node:test";
import type {
  ConfirmPickupCommand,
  ConfirmPickupResult,
  DriverSession,
  OperationsSession,
} from "@rounds/contracts";
import { confirmPickupHandler } from "../src/confirm-pickup-handler.js";
import type { ActorContext, AuthenticatedIdentity, IdentityGateway, PickupGateway } from "../src/types.js";

const tenantId = "10000000-0000-4000-8000-000000000001";
const roundId = "10000000-0000-4000-8000-000000000010";
const stopId = "10000000-0000-4000-8000-000000000011";
const manifestId = "10000000-0000-4000-8000-000000000012";

const session: DriverSession = {
  user: { id: "auth-user", displayName: "Driver" },
  driver: { id: "10000000-0000-4000-8000-000000000002", version: 1, preferredLocale: "en" },
  currentRound: {
    id: roundId,
    reference: "ROUND-001",
    serviceDate: "2026-09-02",
    state: "approved",
    version: 1,
    tenant: { id: tenantId, displayName: "UrbanFlowers", timezone: "Asia/Bangkok" },
    pickup: { id: "10000000-0000-4000-8000-000000000020", displayName: "Studio", rawAddress: "Bangkok", contactName: "Dispatch", contactPhone: "+66000000000" },
    stops: [],
  },
};

class FakePickupGateway implements IdentityGateway, PickupGateway {
  driverSession: DriverSession | null = session;
  command: ConfirmPickupCommand | null = null;
  async authenticate(): Promise<AuthenticatedIdentity | null> { return { authUserId: "auth-user" }; }
  async authorizeTenant(): Promise<ActorContext | null> { return null; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return this.driverSession; }
  async confirmPickup(command: ConfirmPickupCommand): Promise<ConfirmPickupResult> {
    this.command = command;
    return {
      status: "committed",
      aggregateVersion: 2,
      state: { roundId, roundState: "active", driverId: session.driver.id, stops: [] },
      events: [],
    };
  }
}

function request() {
  return new Request(`http://test/v1/driver/rounds/${roundId}/pickup`, {
    method: "POST",
    headers: {
      authorization: "Bearer token",
      "content-type": "application/json",
      "idempotency-key": "pickup:round-1",
    },
    body: JSON.stringify({ stops: [{ stopId, manifestId, manifestVersion: 1, confirmedLineNumbers: [1, 2] }] }),
  });
}

const ids = () => {
  const values = [
    "10000000-0000-4000-8000-000000000101",
    "10000000-0000-4000-8000-000000000102",
  ];
  return () => values.shift() ?? "10000000-0000-4000-8000-000000000199";
};

test("Team driver commits exact pickup manifest confirmations", async () => {
  const gateway = new FakePickupGateway();
  const response = await confirmPickupHandler(request(), roundId, {
    identity: gateway, pickup: gateway, uuid: ids(), now: () => new Date("2026-09-01T12:00:00Z"),
  });
  assert.equal(response.status, 201);
  assert.equal(gateway.command?.tenantId, tenantId);
  assert.equal(gateway.command?.expectedVersion, 1);
  assert.deepEqual(gateway.command?.payload.stops[0]?.confirmedLineNumbers, [1, 2]);
});

test("driver cannot confirm a Round assigned to another account", async () => {
  const gateway = new FakePickupGateway();
  gateway.driverSession = { user: session.user, driver: session.driver };
  const response = await confirmPickupHandler(request(), roundId, {
    identity: gateway, pickup: gateway, uuid: ids(), now: () => new Date("2026-09-01T12:00:00Z"),
  });
  assert.equal(response.status, 403);
  assert.equal(gateway.command, null);
});
