import assert from "node:assert/strict";
import test from "node:test";
import type {
  DriverSession,
  OperationsSession,
  UpdateDriverPreferredLocaleCommand,
  UpdateDriverPreferredLocaleResult,
} from "@rounds/contracts";
import { updateDriverPreferredLocaleHandler } from "../src/update-driver-preferred-locale-handler.js";
import type {
  ActorContext,
  AuthenticatedIdentity,
  DriverProfileGateway,
  IdentityGateway,
} from "../src/types.js";

const tenantId = "97000000-0000-4000-8000-000000000001";
const driverId = "97000000-0000-4000-8000-000000000002";
const session: DriverSession = {
  user: { id: "auth-user", displayName: "Johannes" },
  driver: { id: driverId, version: 7, preferredLocale: "en" },
  team: { tenantId, displayName: "UrbanFlowers", status: "active" },
};

class FakeProfileGateway implements IdentityGateway, DriverProfileGateway {
  authenticated = true;
  driverSession: DriverSession | null = session;
  command: UpdateDriverPreferredLocaleCommand | null = null;
  result: UpdateDriverPreferredLocaleResult = {
    status: "committed",
    aggregateVersion: 8,
    state: {
      driverId,
      preferredLocale: "th-TH",
      previousLocale: "en",
    },
    events: [],
  };

  async authenticate(): Promise<AuthenticatedIdentity | null> {
    return this.authenticated ? { authUserId: "auth-user" } : null;
  }
  async authorizeTenant(): Promise<ActorContext | null> { return null; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> {
    return this.driverSession;
  }
  async updateDriverPreferredLocale(
    command: UpdateDriverPreferredLocaleCommand,
  ): Promise<UpdateDriverPreferredLocaleResult> {
    this.command = command;
    return this.result;
  }
}

function request(body: unknown = { expectedVersion: 7, preferredLocale: "th-TH" }) {
  return new Request("http://test/v1/driver/preferences/locale", {
    method: "POST",
    headers: {
      authorization: "Bearer valid",
      "content-type": "application/json",
      "idempotency-key": "driver-locale:v7:th-TH",
    },
    body: JSON.stringify(body),
  });
}

function dependencies(gateway: FakeProfileGateway) {
  return {
    identity: gateway,
    profiles: gateway,
    uuid: () => "97000000-0000-4000-8000-000000000003",
    now: () => new Date("2026-09-04T06:00:00.000Z"),
  };
}

test("active Team Driver versions a canonical profile locale update", async () => {
  const gateway = new FakeProfileGateway();
  const response = await updateDriverPreferredLocaleHandler(
    request(),
    dependencies(gateway),
  );
  assert.equal(response.status, 201);
  assert.equal(gateway.command?.aggregateId, driverId);
  assert.equal(gateway.command?.tenantId, tenantId);
  assert.equal(gateway.command?.expectedVersion, 7);
  assert.equal(gateway.command?.payload.preferredLocale, "th-TH");
});

test("locale update requires authentication and an active Team relationship", async () => {
  const unauthenticated = new FakeProfileGateway();
  unauthenticated.authenticated = false;
  assert.equal((await updateDriverPreferredLocaleHandler(
    request(),
    dependencies(unauthenticated),
  )).status, 401);

  const noTeam = new FakeProfileGateway();
  const { team: _team, ...sessionWithoutTeam } = session;
  noTeam.driverSession = sessionWithoutTeam;
  assert.equal((await updateDriverPreferredLocaleHandler(
    request(),
    dependencies(noTeam),
  )).status, 403);
});

test("locale update rejects unsupported locale and reports stale versions", async () => {
  const invalid = new FakeProfileGateway();
  assert.equal((await updateDriverPreferredLocaleHandler(
    request({ expectedVersion: 7, preferredLocale: "fr" }),
    dependencies(invalid),
  )).status, 422);
  assert.equal(invalid.command, null);

  const stale = new FakeProfileGateway();
  stale.result = {
    status: "rejected",
    error: { code: "STALE_VERSION", message: "refresh" },
  };
  assert.equal((await updateDriverPreferredLocaleHandler(
    request(),
    dependencies(stale),
  )).status, 409);
});
