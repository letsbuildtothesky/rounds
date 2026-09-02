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
import { confirmDeliveryReturnHandler } from "../src/confirm-delivery-return-handler.js";
import type { ActorContext, AuthenticatedIdentity, IdentityGateway, OperationsActionGateway } from "../src/types.js";

const tenantId = "91000000-0000-4000-8000-000000000001";
const exceptionId = "91000000-0000-4000-8000-000000000002";
const stopId = "91000000-0000-4000-8000-000000000003";
const actor: ActorContext = { authUserId: "auth-user", personId: "91000000-0000-4000-8000-000000000004", tenantId, role: "dispatcher" };
const result: ConfirmDeliveryReturnResult = {
  status: "committed",
  aggregateVersion: 7,
  state: {
    exceptionId,
    stopId,
    deliveryId: "91000000-0000-4000-8000-000000000005",
    roundId: "91000000-0000-4000-8000-000000000006",
    resolution: "delivery_returned",
    returnedAt: "2026-09-02T07:00:00.000Z",
    stopState: "cancelled",
    deliveryState: "returned",
    roundState: "complete",
    roundVersion: 5,
  },
  events: [],
};

class FakeGateway implements IdentityGateway, OperationsActionGateway {
  role: ActorContext["role"] = "dispatcher";
  command?: ConfirmDeliveryReturnCommand;
  async authenticate(): Promise<AuthenticatedIdentity | null> { return { authUserId: "auth-user" }; }
  async authorizeTenant(): Promise<ActorContext | null> { return { ...actor, role: this.role }; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return null; }
  async getOperationsAction(): Promise<OperationsActionProjection> { return { tenantId, observedAt: "", rounds: [], exceptions: [] }; }
  async resolveOperationsException(_command: ResolveOperationsExceptionCommand): Promise<ResolveOperationsExceptionResult> { return { status: "rejected", error: { code: "INVALID_STATE", message: "unused" } }; }
  async confirmDeliveryReturn(command: ConfirmDeliveryReturnCommand): Promise<ConfirmDeliveryReturnResult> { this.command = command; return result; }
}

function request(body: unknown, headers: Record<string, string> = {}): Request {
  return new Request(`http://test/v1/operations/exceptions/${exceptionId}/confirm-return`, {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
}

function dependencies(gateway: FakeGateway) {
  let count = 0;
  return {
    identity: gateway,
    action: gateway,
    uuid: () => count++ === 0 ? "91000000-0000-4000-8000-000000000010" : "91000000-0000-4000-8000-000000000011",
    now: () => new Date("2026-09-02T07:00:00.000Z"),
  };
}

const body = { stopId, expectedStopVersion: 6, note: "Somchai returned the damaged package to Mali at UrbanFlowers" };
const headers = { authorization: "Bearer valid", "x-rounds-tenant-id": tenantId, "idempotency-key": "confirm-return-1" };

test("dispatcher confirms an audited physical delivery return", async () => {
  const gateway = new FakeGateway();
  const response = await confirmDeliveryReturnHandler(request(body, headers), exceptionId, dependencies(gateway));
  assert.equal(response.status, 201);
  assert.equal(gateway.command?.commandType, "operations.confirm_delivery_return");
  assert.equal(gateway.command?.payload.exceptionId, exceptionId);
  assert.equal(gateway.command?.expectedVersion, 6);
});

test("viewer cannot confirm a delivery return", async () => {
  const gateway = new FakeGateway(); gateway.role = "viewer";
  const response = await confirmDeliveryReturnHandler(request(body, headers), exceptionId, dependencies(gateway));
  assert.equal(response.status, 403);
});

test("delivery return confirmation requires physical-return evidence", async () => {
  const gateway = new FakeGateway();
  const response = await confirmDeliveryReturnHandler(request({ ...body, note: "" }, headers), exceptionId, dependencies(gateway));
  assert.equal(response.status, 422);
});
