import assert from "node:assert/strict";
import test from "node:test";
import type { OperationsSession } from "@rounds/contracts";
import { operationsSessionHandler } from "../src/operations-session-handler.js";
import type {
  ActorContext,
  AuthenticatedIdentity,
  IdentityGateway,
} from "../src/types.js";

const session: OperationsSession = {
  user: { id: "auth-user", email: "dispatcher@example.test", displayName: "Dispatcher" },
  tenants: [{
    id: "10000000-0000-4000-8000-000000000001",
    displayName: "UrbanFlowers",
    timezone: "Asia/Bangkok",
    role: "dispatcher",
    locations: [{
      id: "10000000-0000-4000-8000-000000000020",
      code: "BKK-STUDIO",
      displayName: "UrbanFlowers Studio",
      rawAddress: "Bangkok",
      pickupContactName: "Operations",
      pickupContactPhone: "+66000000000",
    }],
  }],
};

class FakeIdentity implements IdentityGateway {
  authenticated = true;
  authorizedSession: OperationsSession | null = session;

  async authenticate(): Promise<AuthenticatedIdentity | null> {
    return this.authenticated ? { authUserId: "auth-user", email: "dispatcher@example.test" } : null;
  }

  async authorizeTenant(): Promise<ActorContext | null> {
    return null;
  }

  async getOperationsSession(): Promise<OperationsSession | null> {
    return this.authorizedSession;
  }
}

function request(authorization = "Bearer valid-token"): Request {
  return new Request("http://api.rounds.test/v1/operations/session", {
    headers: { authorization },
  });
}

test("returns the authorized Operations tenant and pickup locations", async () => {
  const response = await operationsSessionHandler(request(), {
    identity: new FakeIdentity(),
    uuid: () => "10000000-0000-4000-8000-000000000099",
  });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), session);
});

test("requires a valid bearer session", async () => {
  const identity = new FakeIdentity();
  identity.authenticated = false;
  const response = await operationsSessionHandler(request(), {
    identity,
    uuid: () => "10000000-0000-4000-8000-000000000099",
  });
  assert.equal(response.status, 401);
});

test("rejects an account without an active Operations membership", async () => {
  const identity = new FakeIdentity();
  identity.authorizedSession = null;
  const response = await operationsSessionHandler(request(), {
    identity,
    uuid: () => "10000000-0000-4000-8000-000000000099",
  });
  assert.equal(response.status, 403);
});
