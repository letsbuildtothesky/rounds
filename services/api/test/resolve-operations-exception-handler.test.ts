import assert from "node:assert/strict";
import test from "node:test";
import type { DriverSession, OperationsActionProjection, OperationsSession, ResolveOperationsExceptionCommand, ResolveOperationsExceptionResult } from "@rounds/contracts";
import { resolveOperationsExceptionHandler } from "../src/resolve-operations-exception-handler.js";
import type { ActorContext, AuthenticatedIdentity, IdentityGateway, OperationsActionGateway } from "../src/types.js";

const tenantId = "90000000-0000-4000-8000-000000000001";
const exceptionId = "90000000-0000-4000-8000-000000000002";
const stopId = "90000000-0000-4000-8000-000000000003";
const actor: ActorContext = { authUserId: "auth-user", personId: "90000000-0000-4000-8000-000000000004", tenantId, role: "dispatcher" };
const result: ResolveOperationsExceptionResult = { status: "committed", aggregateVersion: 4, state: { exceptionId, stopId, deliveryId: "90000000-0000-4000-8000-000000000005", roundId: "90000000-0000-4000-8000-000000000006", resolution: "pickup_corrected", resolvedAt: "2026-09-02T06:00:00.000Z", stopState: "assigned", deliveryState: "assigned" }, events: [] };

class FakeGateway implements IdentityGateway, OperationsActionGateway {
  role: ActorContext["role"] = "dispatcher";
  command?: ResolveOperationsExceptionCommand;
  async authenticate(): Promise<AuthenticatedIdentity | null> { return { authUserId: "auth-user" }; }
  async authorizeTenant(): Promise<ActorContext | null> { return { ...actor, role: this.role }; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return null; }
  async getOperationsAction(): Promise<OperationsActionProjection> { return { tenantId, observedAt: "", rounds: [], exceptions: [] }; }
  async resolveOperationsException(command: ResolveOperationsExceptionCommand): Promise<ResolveOperationsExceptionResult> { this.command = command; return result; }
}

function request(body: unknown, headers: Record<string,string> = {}): Request { return new Request(`http://test/v1/operations/exceptions/${exceptionId}/resolve`, { method: "POST", headers: { "content-type": "application/json", ...headers }, body: JSON.stringify(body) }); }
function dependencies(gateway: FakeGateway) { let count = 0; return { identity: gateway, action: gateway, uuid: () => count++ === 0 ? "90000000-0000-4000-8000-000000000010" : "90000000-0000-4000-8000-000000000011", now: () => new Date("2026-09-02T06:00:00.000Z") }; }
const body = { stopId, expectedStopVersion: 3, resolution: "pickup_corrected", note: "Bouquet located and checked" };

test("dispatcher commits an audited pickup correction", async () => {
  const gateway = new FakeGateway();
  const response = await resolveOperationsExceptionHandler(request(body, { authorization: "Bearer valid", "x-rounds-tenant-id": tenantId, "idempotency-key": "resolve-1" }), exceptionId, dependencies(gateway));
  assert.equal(response.status, 201);
  assert.equal(gateway.command?.aggregateId, stopId);
  assert.equal(gateway.command?.payload.exceptionId, exceptionId);
  assert.equal(gateway.command?.expectedVersion, 3);
});

test("viewer cannot resolve an exception", async () => {
  const gateway = new FakeGateway(); gateway.role = "viewer";
  const response = await resolveOperationsExceptionHandler(request(body, { authorization: "Bearer valid", "x-rounds-tenant-id": tenantId, "idempotency-key": "resolve-1" }), exceptionId, dependencies(gateway));
  assert.equal(response.status, 403);
});

test("resolution requires an evidence note", async () => {
  const gateway = new FakeGateway();
  const response = await resolveOperationsExceptionHandler(request({ ...body, note: "" }, { authorization: "Bearer valid", "x-rounds-tenant-id": tenantId, "idempotency-key": "resolve-1" }), exceptionId, dependencies(gateway));
  assert.equal(response.status, 422);
});
