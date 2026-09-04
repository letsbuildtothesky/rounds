import assert from "node:assert/strict";
import test from "node:test";
import type { DriverSession, OperationsSession } from "@rounds/contracts";
import { driverSessionHandler } from "../src/driver-session-handler.js";
import type { ActorContext, AuthenticatedIdentity, IdentityGateway } from "../src/types.js";

const session: DriverSession = {
  user: { id: "auth-user", displayName: "Johannes" },
  driver: { id: "driver-1", version: 1, preferredLocale: "en" },
  team: { tenantId: "tenant-1", displayName: "UrbanFlowers", status: "active" },
  completedRounds: [{
    id: "round-complete-1",
    reference: "ROUND-001",
    serviceDate: "2026-09-03",
    tenant: { id: "tenant-1", displayName: "UrbanFlowers", timezone: "Asia/Bangkok" },
    completedAt: "2026-09-03T06:06:00.000Z",
    stopCount: 1,
    deliveredStopCount: 1,
    formallyClosedStopCount: 0,
    podCount: 1,
    plannedDistanceMeters: 4800,
    plannedDurationSeconds: 2460,
  }],
};

class FakeIdentity implements IdentityGateway {
  authenticated = true;
  driverSession: DriverSession | null = session;

  async authenticate(): Promise<AuthenticatedIdentity | null> {
    return this.authenticated ? { authUserId: "auth-user" } : null;
  }
  async authorizeTenant(): Promise<ActorContext | null> { return null; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return this.driverSession; }
}

const dependencies = (identity: FakeIdentity) => ({
  identity,
  uuid: () => "trace-id",
});

test("assigned driver receives authoritative completed Round history", async () => {
  const response = await driverSessionHandler(
    new Request("http://test/v1/driver/session", {
      headers: { authorization: "Bearer valid" },
    }),
    dependencies(new FakeIdentity()),
  );
  assert.equal(response.status, 200);
  const body = await response.json() as DriverSession;
  assert.equal(body.completedRounds?.length, 1);
  assert.equal(body.team?.displayName, "UrbanFlowers");
  assert.equal(body.completedRounds?.[0]?.podCount, 1);
  assert.equal(body.completedRounds?.[0]?.plannedDistanceMeters, 4800);
});

test("Round history never loads without an authenticated driver", async () => {
  const identity = new FakeIdentity();
  identity.authenticated = false;
  const response = await driverSessionHandler(
    new Request("http://test/v1/driver/session"),
    dependencies(identity),
  );
  assert.equal(response.status, 401);
});
