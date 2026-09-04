import assert from "node:assert/strict";
import test from "node:test";
import type {
  DriverSession,
  EndDriverShiftCommand,
  EndDriverShiftResult,
  OperationsSession,
} from "@rounds/contracts";
import { endDriverShiftHandler } from "../src/end-driver-shift-handler.js";
import type {
  ActorContext,
  AuthenticatedIdentity,
  DriverShiftGateway,
  IdentityGateway,
} from "../src/types.js";

const tenantId = "97000000-0000-4000-8000-000000000001";
const driverId = "97000000-0000-4000-8000-000000000002";
const attendanceId = "97000000-0000-4000-8000-000000000003";
const session: DriverSession = {
  user: { id: "auth-user", displayName: "Johannes" },
  driver: { id: driverId, version: 1, preferredLocale: "en" },
  team: { tenantId, displayName: "UrbanFlowers", status: "active" },
  shift: {
    effective: {
      serviceDate: "2026-09-04", timezone: "Asia/Bangkok", source: "recurring",
      startAt: "2026-09-04T01:00:00.000Z", endAt: "2026-09-04T10:00:00.000Z",
      startLocal: "08:00", endLocal: "17:00", crossesMidnight: false,
    },
    attendance: {
      id: attendanceId, version: 1, serviceDate: "2026-09-04",
      startedAt: "2026-09-04T01:00:00.000Z",
    },
  },
};

class FakeShiftGateway implements IdentityGateway, DriverShiftGateway {
  authenticated = true;
  driverSession: DriverSession | null = session;
  command: EndDriverShiftCommand | null = null;

  async authenticate(): Promise<AuthenticatedIdentity | null> {
    return this.authenticated ? { authUserId: "auth-user" } : null;
  }
  async authorizeTenant(): Promise<ActorContext | null> { return null; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return this.driverSession; }
  async startDriverShift(): Promise<never> { throw new Error("not used"); }
  async endDriverShift(command: EndDriverShiftCommand): Promise<EndDriverShiftResult> {
    this.command = command;
    return {
      status: "committed", aggregateVersion: 2,
      state: {
        id: attendanceId, version: 2, serviceDate: "2026-09-04", driverId,
        startedAt: "2026-09-04T01:00:00.000Z", endedAt: "2026-09-04T10:22:00.000Z",
        scheduledStartAt: "2026-09-04T01:00:00.000Z", scheduledEndAt: "2026-09-04T10:00:00.000Z",
        workedMinutes: 562, pastScheduledEndMinutes: 22,
      },
      events: [],
    };
  }
}

const request = (body: unknown = { attendanceId }) => new Request(
  "http://test/v1/driver/shifts/end",
  {
    method: "POST",
    headers: {
      authorization: "Bearer valid", "content-type": "application/json",
      "idempotency-key": "driver-shift:end:attendance:v1",
    },
    body: JSON.stringify(body),
  },
);
const dependencies = (gateway: FakeShiftGateway) => ({
  identity: gateway, shifts: gateway,
  uuid: () => "97000000-0000-4000-8000-000000000004",
  now: () => new Date("2026-09-04T10:22:00.000Z"),
});

test("active Team Driver ends the open attendance aggregate", async () => {
  const gateway = new FakeShiftGateway();
  const response = await endDriverShiftHandler(request(), dependencies(gateway));
  assert.equal(response.status, 201);
  assert.equal(gateway.command?.aggregateId, attendanceId);
  assert.equal(gateway.command?.expectedVersion, 1);
});

test("shift end requires authentication and open attendance", async () => {
  const unauthenticated = new FakeShiftGateway();
  unauthenticated.authenticated = false;
  assert.equal((await endDriverShiftHandler(request(), dependencies(unauthenticated))).status, 401);

  const noAttendance = new FakeShiftGateway();
  noAttendance.driverSession = { ...session, shift: { effective: session.shift!.effective } };
  assert.equal((await endDriverShiftHandler(request(), dependencies(noAttendance))).status, 403);
});

test("shift end validates the attendance identity before the gateway", async () => {
  const gateway = new FakeShiftGateway();
  const response = await endDriverShiftHandler(
    request({ attendanceId: "97000000-0000-4000-8000-000000000009" }),
    dependencies(gateway),
  );
  assert.equal(response.status, 422);
  assert.equal(gateway.command, null);
});
