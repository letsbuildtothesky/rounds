import assert from "node:assert/strict";
import test from "node:test";
import type {
  DriverSession,
  OperationsDriversProjection,
  OperationsSession,
  SetDriverRecurringScheduleCommand,
  SetDriverRecurringScheduleResult,
} from "@rounds/contracts";
import { operationsDriversHandler } from "../src/operations-drivers-handler.js";
import { setDriverRecurringScheduleHandler } from "../src/set-driver-recurring-schedule-handler.js";
import type { ActorContext, AuthenticatedIdentity, IdentityGateway, OperationsDriversGateway } from "../src/types.js";

const tenantId = "94000000-0000-4000-8000-000000000001";
const driverId = "94000000-0000-4000-8000-000000000002";
const profileId = "94000000-0000-4000-8000-000000000003";
const actor: ActorContext = { authUserId: "auth-user", personId: "94000000-0000-4000-8000-000000000004", tenantId, role: "dispatcher" };
const projection: OperationsDriversProjection = {
  tenantId, serviceDate: "2026-09-03", observedAt: "2026-09-03T04:00:00.000Z", drivers: [], vehicleProfiles: [],
  summary: { ownDrivers: 0, scheduled: 0, activeRounds: 0, availableNow: 0, scheduleRequired: 0, vehicleGroups: {} },
};
const committed: SetDriverRecurringScheduleResult = {
  status: "committed", aggregateVersion: 1, events: [], state: {
    scheduleId: "94000000-0000-4000-8000-000000000005", driverId, weekdays: [1, 2, 3, 4, 5], startLocal: "08:00", endLocal: "18:00", vehicleProfileId: profileId, updatedAt: "2026-09-03T04:00:00.000Z",
  },
};

class FakeGateway implements IdentityGateway, OperationsDriversGateway {
  role: ActorContext["role"] = "dispatcher";
  authorized = true;
  serviceDate = "";
  command?: SetDriverRecurringScheduleCommand;
  async authenticate(): Promise<AuthenticatedIdentity | null> { return { authUserId: "auth-user" }; }
  async authorizeTenant(): Promise<ActorContext | null> { return this.authorized ? { ...actor, role: this.role } : null; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return null; }
  async getOperationsDrivers(_actor: ActorContext, serviceDate: string): Promise<OperationsDriversProjection> { this.serviceDate = serviceDate; return projection; }
  async setDriverRecurringSchedule(command: SetDriverRecurringScheduleCommand): Promise<SetDriverRecurringScheduleResult> { this.command = command; return committed; }
}

function dependencies(gateway: FakeGateway) {
  return { identity: gateway, drivers: gateway, uuid: () => "94000000-0000-4000-8000-000000000010", now: () => new Date("2026-09-03T04:00:00.000Z") };
}

test("authorized member loads a tenant-scoped capacity projection", async () => {
  const gateway = new FakeGateway();
  const response = await operationsDriversHandler(new Request("http://test/v1/operations/drivers?serviceDate=2026-09-03", { headers: { authorization: "Bearer valid", "x-rounds-tenant-id": tenantId } }), dependencies(gateway));
  assert.equal(response.status, 200);
  assert.equal(gateway.serviceDate, "2026-09-03");
});

test("driver capacity requires a real service date and authorized tenant", async () => {
  const gateway = new FakeGateway();
  let response = await operationsDriversHandler(new Request("http://test/v1/operations/drivers?serviceDate=2026-02-30", { headers: { authorization: "Bearer valid", "x-rounds-tenant-id": tenantId } }), dependencies(gateway));
  assert.equal(response.status, 400);
  gateway.authorized = false;
  response = await operationsDriversHandler(new Request("http://test/v1/operations/drivers?serviceDate=2026-09-03", { headers: { authorization: "Bearer valid", "x-rounds-tenant-id": tenantId } }), dependencies(gateway));
  assert.equal(response.status, 403);
});

const scheduleBody = { weekdays: [1, 2, 3, 4, 5], startLocal: "08:00", endLocal: "18:00", vehicleProfileId: profileId };
function scheduleRequest(body: unknown): Request {
  return new Request(`http://test/v1/operations/drivers/${driverId}/recurring-schedule`, { method: "POST", headers: { authorization: "Bearer valid", "content-type": "application/json", "idempotency-key": "schedule-1", "if-match-version": "0", "x-rounds-tenant-id": tenantId }, body: JSON.stringify(body) });
}

test("dispatcher commits a recurring driver schedule", async () => {
  const gateway = new FakeGateway();
  const response = await setDriverRecurringScheduleHandler(scheduleRequest(scheduleBody), driverId, dependencies(gateway));
  assert.equal(response.status, 201);
  assert.equal(gateway.command?.aggregateId, driverId);
  assert.equal(gateway.command?.expectedVersion, 0);
});

test("viewer cannot configure schedules and invalid days never reach the gateway", async () => {
  const viewerGateway = new FakeGateway(); viewerGateway.role = "viewer";
  assert.equal((await setDriverRecurringScheduleHandler(scheduleRequest(scheduleBody), driverId, dependencies(viewerGateway))).status, 403);
  const invalidGateway = new FakeGateway();
  assert.equal((await setDriverRecurringScheduleHandler(scheduleRequest({ ...scheduleBody, weekdays: [1, 1] }), driverId, dependencies(invalidGateway))).status, 422);
  assert.equal(invalidGateway.command, undefined);
});
