import assert from "node:assert/strict";
import test from "node:test";
import type { DriverSession, OperationsSession } from "@rounds/contracts";
import {
  acceptDriverTeamInviteHandler,
  pendingDriverTeamInviteHandler,
  resolveDriverTeamInviteHandler,
} from "../src/driver-team-invite-handler.js";
import type {
  ActorContext,
  AuthenticatedIdentity,
  DriverTeamInvite,
  DriverTeamInviteGateway,
  IdentityGateway,
} from "../src/types.js";

const invite: DriverTeamInvite = {
  id: "a5000000-0000-4000-8000-000000000001",
  tenantId: "a5000000-0000-4000-8000-000000000002",
  businessName: "UrbanFlowers",
  businessInitials: "UF",
  locationLabel: "Bangkok · Delivery team",
  expiresAt: "2026-09-06T00:00:00.000Z",
};

const session: DriverSession = {
  user: { id: "auth-user", displayName: "Johannes" },
  driver: { id: "driver", version: 1, preferredLocale: "en" },
  team: { tenantId: invite.tenantId, displayName: "UrbanFlowers", status: "active" },
};

class FakeGateway implements IdentityGateway, DriverTeamInviteGateway {
  authenticated = true;
  pending: DriverTeamInvite | null = invite;
  resolved: DriverTeamInvite | null = invite;
  accepted = true;
  acceptedArguments: unknown[] | null = null;

  async authenticate(): Promise<AuthenticatedIdentity | null> {
    return this.authenticated ? { authUserId: "auth-user" } : null;
  }
  async authorizeTenant(): Promise<ActorContext | null> { return null; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return this.accepted ? session : null; }
  async pendingTeamInvite(): Promise<DriverTeamInvite | null> { return this.pending; }
  async resolveTeamInvite(code: string): Promise<DriverTeamInvite | null> {
    assert.equal(code, "234567");
    return this.resolved;
  }
  async acceptTeamInvite(
    inviteId: string,
    code: string | undefined,
    locale: "th-TH" | "en",
  ): Promise<boolean> {
    this.acceptedArguments = [inviteId, code, locale];
    return this.accepted;
  }
}

const dependencies = (gateway: FakeGateway) => ({
  identity: gateway,
  invites: gateway,
  uuid: () => "trace-id",
});

test("verified phone receives its real pending Team invitation", async () => {
  const gateway = new FakeGateway();
  const response = await pendingDriverTeamInviteHandler(new Request("http://test", {
    headers: { authorization: "Bearer token" },
  }), dependencies(gateway));
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), invite);

  gateway.pending = null;
  assert.equal((await pendingDriverTeamInviteHandler(new Request("http://test", {
    headers: { authorization: "Bearer token" },
  }), dependencies(gateway))).status, 204);
});

test("manual invite lookup validates six digits and phone-bound result", async () => {
  const gateway = new FakeGateway();
  const invalid = await resolveDriverTeamInviteHandler(new Request("http://test", {
    method: "POST", headers: { authorization: "Bearer token" },
    body: JSON.stringify({ code: "1234" }),
  }), dependencies(gateway));
  assert.equal(invalid.status, 422);

  gateway.resolved = null;
  const missing = await resolveDriverTeamInviteHandler(new Request("http://test", {
    method: "POST", headers: { authorization: "Bearer token" },
    body: JSON.stringify({ code: "234567" }),
  }), dependencies(gateway));
  assert.equal(missing.status, 404);
});

test("accepting an invite creates a session only through the gateway", async () => {
  const gateway = new FakeGateway();
  const response = await acceptDriverTeamInviteHandler(new Request("http://test", {
    method: "POST", headers: { authorization: "Bearer token" },
    body: JSON.stringify({
      inviteId: invite.id,
      code: "234567",
      preferredLocale: "en",
    }),
  }), dependencies(gateway));
  assert.equal(response.status, 201);
  assert.deepEqual(gateway.acceptedArguments, [invite.id, "234567", "en"]);
  assert.deepEqual((await response.json() as { session: DriverSession }).session, session);
});

test("invite acceptance rejects identifiers that are not UUIDs", async () => {
  const gateway = new FakeGateway();
  const response = await acceptDriverTeamInviteHandler(new Request("http://test", {
    method: "POST", headers: { authorization: "Bearer token" },
    body: JSON.stringify({
      inviteId: "not-a-real-invite-id",
      preferredLocale: "en",
    }),
  }), dependencies(gateway));
  assert.equal(response.status, 422);
  assert.equal(gateway.acceptedArguments, null);
});

test("all invitation routes require a valid authenticated identity", async () => {
  const gateway = new FakeGateway();
  gateway.authenticated = false;
  const response = await pendingDriverTeamInviteHandler(new Request("http://test", {
    headers: { authorization: "Bearer invalid" },
  }), dependencies(gateway));
  assert.equal(response.status, 401);
});
