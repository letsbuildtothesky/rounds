import assert from "node:assert/strict";
import test from "node:test";
import type {
  DriverSession,
  ClearDriverShiftExceptionCommand,
  ClearDriverShiftExceptionResult,
  OperationsDriversProjection,
  OperationsSession,
  SetDriverRecurringScheduleCommand,
  SetDriverRecurringScheduleResult,
  SetDriverShiftExceptionCommand,
  SetDriverShiftExceptionResult,
} from "@rounds/contracts";
import { operationsDriversHandler } from "../src/operations-drivers-handler.js";
import { setDriverRecurringScheduleHandler } from "../src/set-driver-recurring-schedule-handler.js";
import { clearDriverShiftExceptionHandler, setDriverShiftExceptionHandler } from "../src/set-driver-shift-exception-handler.js";
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
const exceptionCommitted: SetDriverShiftExceptionResult = {
  status: "committed", aggregateVersion: 1, events: [], state: {
    exceptionId: "94000000-0000-4000-8000-000000000006", driverId, serviceDate: "2026-09-04",
    kind: "off", updatedAt: "2026-09-03T04:00:00.000Z",
  },
};

class FakeGateway implements IdentityGateway, OperationsDriversGateway {
  role: ActorContext["role"] = "dispatcher";
  authorized = true;
  serviceDate = "";
  command?: SetDriverRecurringScheduleCommand;
  exceptionCommand?: SetDriverShiftExceptionCommand;
  clearCommand?: ClearDriverShiftExceptionCommand;
  async authenticate(): Promise<AuthenticatedIdentity | null> { return { authUserId: "auth-user" }; }
  async authorizeTenant(): Promise<ActorContext | null> { return this.authorized ? { ...actor, role: this.role } : null; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return null; }
  async getOperationsDrivers(_actor: ActorContext, serviceDate: string): Promise<OperationsDriversProjection> { this.serviceDate = serviceDate; return projection; }
  async setDriverRecurringSchedule(command: SetDriverRecurringScheduleCommand): Promise<SetDriverRecurringScheduleResult> { this.command = command; return committed; }
  async setDriverShiftException(command: SetDriverShiftExceptionCommand): Promise<SetDriverShiftExceptionResult> { this.exceptionCommand = command; return exceptionCommitted; }
  async clearDriverShiftException(command: ClearDriverShiftExceptionCommand): Promise<ClearDriverShiftExceptionResult> { this.clearCommand = command; return { status: "committed", aggregateVersion: 2, events: [], state: { exceptionId: "94000000-0000-4000-8000-000000000006", driverId, serviceDate: command.payload.serviceDate, clearedAt: "2026-09-03T04:00:00.000Z" } }; }
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

function exceptionRequest(body: unknown): Request {
  return new Request(`http://test/v1/operations/drivers/${driverId}/shift-exception`, { method: "POST", headers: { authorization: "Bearer valid", "content-type": "application/json", "idempotency-key": "exception-1", "if-match-version": "0", "x-rounds-tenant-id": tenantId }, body: JSON.stringify(body) });
}

test("dispatcher commits a date-specific day off", async () => {
  const gateway = new FakeGateway();
  const response = await setDriverShiftExceptionHandler(exceptionRequest({ serviceDate: "2026-09-04", kind: "off", note: "Personal day" }), driverId, dependencies(gateway));
  assert.equal(response.status, 201);
  assert.equal(gateway.exceptionCommand?.payload.kind, "off");
});

test("invalid shift exceptions never reach the gateway", async () => {
  const gateway = new FakeGateway();
  const response = await setDriverShiftExceptionHandler(exceptionRequest({ serviceDate: "2026-09-04", kind: "shift" }), driverId, dependencies(gateway));
  assert.equal(response.status, 422);
  assert.equal(gateway.exceptionCommand, undefined);
});

test("dispatcher restores the recurring schedule with an explicit version", async () => {
  const gateway = new FakeGateway();
  const request = new Request(`http://test/v1/operations/drivers/${driverId}/shift-exception`, { method: "DELETE", headers: { authorization: "Bearer valid", "content-type": "application/json", "idempotency-key": "clear-1", "if-match-version": "2", "x-rounds-tenant-id": tenantId }, body: JSON.stringify({ serviceDate: "2026-09-04" }) });
  const response = await clearDriverShiftExceptionHandler(request, driverId, dependencies(gateway));
  assert.equal(response.status, 201);
  assert.equal(gateway.clearCommand?.expectedVersion, 2);
});
