import assert from "node:assert/strict";
import test from "node:test";
import type {
  DriverSession,
  OperationsSession,
  StartDriverShiftCommand,
  StartDriverShiftResult,
  EndDriverShiftCommand,
  EndDriverShiftResult,
} from "@rounds/contracts";
import { startDriverShiftHandler } from "../src/start-driver-shift-handler.js";
import type {
  ActorContext,
  AuthenticatedIdentity,
  DriverShiftGateway,
  IdentityGateway,
} from "../src/types.js";

const tenantId = "98000000-0000-4000-8000-000000000001";
const driverId = "98000000-0000-4000-8000-000000000002";
const attendanceId = "98000000-0000-4000-8000-000000000003";
const session: DriverSession = {
  user: { id: "auth-user", displayName: "Johannes" },
  driver: { id: driverId, preferredLocale: "en" },
  team: { tenantId, displayName: "UrbanFlowers", status: "active" },
  shift: {
    effective: {
      serviceDate: "2026-09-03",
      timezone: "Asia/Bangkok",
      source: "recurring",
      startAt: "2026-09-03T01:00:00.000Z",
      endAt: "2026-09-03T10:00:00.000Z",
      startLocal: "08:00",
      endLocal: "17:00",
      crossesMidnight: false,
    },
  },
};

class FakeShiftGateway implements IdentityGateway, DriverShiftGateway {
  authenticated = true;
  driverSession: DriverSession | null = session;
  command: StartDriverShiftCommand | null = null;

  async authenticate(): Promise<AuthenticatedIdentity | null> {
    return this.authenticated ? { authUserId: "auth-user" } : null;
  }
  async authorizeTenant(): Promise<ActorContext | null> { return null; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return this.driverSession; }
  async startDriverShift(command: StartDriverShiftCommand): Promise<StartDriverShiftResult> {
    this.command = command;
    return {
      status: "committed",
      aggregateVersion: 1,
      state: {
        id: attendanceId,
        version: 1,
        serviceDate: command.payload.serviceDate,
        driverId,
        startedAt: "2026-09-03T00:52:00.000Z",
        scheduledStartAt: "2026-09-03T01:00:00.000Z",
        scheduledEndAt: "2026-09-03T10:00:00.000Z",
        scheduleSource: "recurring",
      },
      events: [],
    };
  }
  async endDriverShift(_command: EndDriverShiftCommand): Promise<EndDriverShiftResult> {
    throw new Error("not used");
  }
}

const request = (body: unknown = { serviceDate: "2026-09-03" }) => new Request(
  "http://test/v1/driver/shifts/start",
  {
    method: "POST",
    headers: {
      authorization: "Bearer valid",
      "content-type": "application/json",
      "idempotency-key": "driver-shift:2026-09-03",
    },
    body: JSON.stringify(body),
  },
);

const dependencies = (gateway: FakeShiftGateway) => ({
  identity: gateway,
  shifts: gateway,
  uuid: () => "98000000-0000-4000-8000-000000000004",
  now: () => new Date("2026-09-03T00:52:00.000Z"),
});

test("active Team Driver starts the effective shift", async () => {
  const gateway = new FakeShiftGateway();
  const response = await startDriverShiftHandler(request(), dependencies(gateway));
  assert.equal(response.status, 201);
  assert.equal(gateway.command?.aggregateId, driverId);
  assert.equal(gateway.command?.tenantId, tenantId);
  assert.equal(gateway.command?.expectedVersion, 0);
});

test("shift start requires an authenticated effective Team shift", async () => {
  const unauthenticated = new FakeShiftGateway();
  unauthenticated.authenticated = false;
  assert.equal((await startDriverShiftHandler(request(), dependencies(unauthenticated))).status, 401);

  const noShift = new FakeShiftGateway();
  const { shift: _shift, ...sessionWithoutShift } = session;
  noShift.driverSession = sessionWithoutShift;
  assert.equal((await startDriverShiftHandler(request(), dependencies(noShift))).status, 403);
});

test("shift start validates the service date before the gateway", async () => {
  const gateway = new FakeShiftGateway();
  const response = await startDriverShiftHandler(request({ serviceDate: "not-a-date" }), dependencies(gateway));
  assert.equal(response.status, 422);
  assert.equal(gateway.command, null);
});
