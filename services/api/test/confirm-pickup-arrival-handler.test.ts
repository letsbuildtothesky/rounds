import assert from "node:assert/strict";
import test from "node:test";
import type {
  ConfirmPickupArrivalCommand,
  ConfirmPickupArrivalResult,
  ConfirmPickupResult,
  DriverSession,
  OperationsSession,
} from "@rounds/contracts";
import { confirmPickupArrivalHandler } from "../src/confirm-pickup-arrival-handler.js";
import type { ActorContext, AuthenticatedIdentity, IdentityGateway, PickupGateway } from "../src/types.js";

const tenantId = "10000000-0000-4000-8000-000000000001";
const driverId = "10000000-0000-4000-8000-000000000002";
const roundId = "10000000-0000-4000-8000-000000000010";
const pickupLocationId = "10000000-0000-4000-8000-000000000020";

const session: DriverSession = {
  user: { id: "auth-user", displayName: "Driver" },
  driver: { id: driverId, version: 1, preferredLocale: "en" },
  currentRound: {
    id: roundId,
    reference: "ROUND-001",
    serviceDate: "2026-09-06",
    state: "approved",
    version: 4,
    tenant: { id: tenantId, displayName: "UrbanFlowers", timezone: "Asia/Bangkok" },
    pickup: { id: pickupLocationId, displayName: "Studio", rawAddress: "Bangkok", contactName: "Dispatch", contactPhone: "+66000000000" },
    stops: [],
  },
};

class FakeGateway implements IdentityGateway, PickupGateway {
  driverSession: DriverSession | null = session;
  command: ConfirmPickupArrivalCommand | null = null;
  result: ConfirmPickupArrivalResult = {
    status: "committed",
    aggregateVersion: 4,
    state: {
      arrivalId: "10000000-0000-4000-8000-000000000103",
      roundId,
      pickupLocationId,
      driverId,
      arrivedAt: "2026-09-06T08:00:00Z",
      hasPositionEvidence: true,
    },
    events: [],
  };
  async authenticate(): Promise<AuthenticatedIdentity | null> { return { authUserId: "auth-user" }; }
  async authorizeTenant(): Promise<ActorContext | null> { return null; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return this.driverSession; }
  async confirmPickup(): Promise<ConfirmPickupResult> { throw new Error("not used"); }
  async confirmPickupArrival(command: ConfirmPickupArrivalCommand): Promise<ConfirmPickupArrivalResult> {
    this.command = command;
    return this.result;
  }
}

function request(body: unknown = {
  pickupLocationId,
  position: { latitude: 13.73, longitude: 100.57, accuracyMeters: 9, source: "rounds_os" },
}) {
  return new Request(`http://test/v1/driver/rounds/${roundId}/pickup-arrival`, {
    method: "POST",
    headers: {
      authorization: "Bearer token",
      "content-type": "application/json",
      "idempotency-key": "pickup-arrival:round-1:v4",
    },
    body: JSON.stringify(body),
  });
}

test("Team driver records pickup arrival against the server-assigned Round", async () => {
  const gateway = new FakeGateway();
  const response = await confirmPickupArrivalHandler(request(), roundId, {
    identity: gateway,
    pickup: gateway,
    uuid: () => "10000000-0000-4000-8000-000000000101",
    now: () => new Date("2026-09-06T08:00:00Z"),
  });
  assert.equal(response.status, 201);
  assert.equal(gateway.command?.tenantId, tenantId);
  assert.equal(gateway.command?.aggregateId, roundId);
  assert.equal(gateway.command?.expectedVersion, 4);
  assert.equal(gateway.command?.payload.position?.source, "rounds_os");
});

test("handler rejects a client-substituted pickup before the gateway", async () => {
  const gateway = new FakeGateway();
  const response = await confirmPickupArrivalHandler(request({
    pickupLocationId: "10000000-0000-4000-8000-000000000099",
  }), roundId, {
    identity: gateway,
    pickup: gateway,
    uuid: () => "10000000-0000-4000-8000-000000000101",
    now: () => new Date("2026-09-06T08:00:00Z"),
  });
  assert.equal(response.status, 422);
  assert.equal(gateway.command, null);
});

test("handler rejects a Round not assigned to the authenticated driver", async () => {
  const gateway = new FakeGateway();
  gateway.driverSession = { user: session.user, driver: session.driver };
  const response = await confirmPickupArrivalHandler(request(), roundId, {
    identity: gateway,
    pickup: gateway,
    uuid: () => "10000000-0000-4000-8000-000000000101",
    now: () => new Date("2026-09-06T08:00:00Z"),
  });
  assert.equal(response.status, 403);
  assert.equal(gateway.command, null);
});
