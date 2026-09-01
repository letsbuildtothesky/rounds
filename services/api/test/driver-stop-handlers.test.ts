import assert from "node:assert/strict";
import test from "node:test";
import type {
  ConfirmStopArrivalCommand,
  ConfirmStopArrivalResult,
  DriverSession,
  OperationsSession,
  ReportPickupProblemCommand,
  ReportPickupProblemResult,
} from "@rounds/contracts";
import { confirmStopArrivalHandler } from "../src/confirm-stop-arrival-handler.js";
import { reportPickupProblemHandler } from "../src/report-pickup-problem-handler.js";
import type {
  ActorContext,
  AuthenticatedIdentity,
  DriverStopGateway,
  IdentityGateway,
} from "../src/types.js";

const tenantId = "10000000-0000-4000-8000-000000000001";
const stopId = "10000000-0000-4000-8000-000000000011";
const manifestId = "10000000-0000-4000-8000-000000000012";
const roundId = "10000000-0000-4000-8000-000000000010";
const deliveryId = "10000000-0000-4000-8000-000000000013";
const driverId = "10000000-0000-4000-8000-000000000002";

const session: DriverSession = {
  user: { id: "auth-user", displayName: "Driver" },
  driver: { id: driverId, preferredLocale: "en" },
  currentRound: {
    id: roundId,
    reference: "ROUND-001",
    serviceDate: "2026-09-02",
    state: "active",
    version: 2,
    tenant: { id: tenantId, displayName: "UrbanFlowers", timezone: "Asia/Bangkok" },
    pickup: {
      id: "10000000-0000-4000-8000-000000000020",
      displayName: "Studio",
      rawAddress: "Bangkok",
      contactName: "Dispatch",
      contactPhone: "+66000000000",
    },
    stops: [{
      id: stopId,
      sequence: 1,
      state: "active",
      version: 4,
      destinationVersion: 1,
      deliveryId,
      deliveryReference: "UF-001",
      recipientName: "Siriporn",
      recipientPhone: "+66999999999",
      rawAddress: "Bangkok",
      latitude: 13.74,
      longitude: 100.54,
      isSurprise: false,
      windowStart: "2026-09-02T02:00:00Z",
      windowEnd: "2026-09-02T04:00:00Z",
      manifestId,
      manifestVersion: 1,
      manifestItems: [{ lineNumber: 1, description: "Bouquet", quantity: 1 }],
    }],
  },
};

class FakeDriverStopGateway implements IdentityGateway, DriverStopGateway {
  driverSession: DriverSession | null = session;
  problemCommand: ReportPickupProblemCommand | null = null;
  arrivalCommand: ConfirmStopArrivalCommand | null = null;
  async authenticate(): Promise<AuthenticatedIdentity | null> { return { authUserId: "auth-user" }; }
  async authorizeTenant(): Promise<ActorContext | null> { return null; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return this.driverSession; }
  async reportPickupProblem(command: ReportPickupProblemCommand): Promise<ReportPickupProblemResult> {
    this.problemCommand = command;
    return {
      status: "committed",
      aggregateVersion: 5,
      state: {
        exceptionId: "10000000-0000-4000-8000-000000000030",
        stopId,
        deliveryId,
        roundId,
        category: "missing_item",
        stopState: "exception",
        deliveryState: "exception",
      },
      events: [],
    };
  }
  async confirmStopArrival(command: ConfirmStopArrivalCommand): Promise<ConfirmStopArrivalResult> {
    this.arrivalCommand = command;
    return {
      status: "committed",
      aggregateVersion: 5,
      state: {
        arrivalId: "10000000-0000-4000-8000-000000000031",
        stopId,
        deliveryId,
        roundId,
        driverId,
        arrivedAt: "2026-09-01T12:00:00Z",
        stopState: "arrived",
        deliveryState: "arrived",
      },
      events: [],
    };
  }
}

const dependencies = (gateway: FakeDriverStopGateway) => ({
  identity: gateway,
  stops: gateway,
  uuid: () => "10000000-0000-4000-8000-000000000101",
  now: () => new Date("2026-09-01T12:00:00Z"),
});

test("assigned Team driver reports a typed pickup problem", async () => {
  const gateway = new FakeDriverStopGateway();
  const response = await reportPickupProblemHandler(new Request("http://test/problem", {
    method: "POST",
    headers: {
      authorization: "Bearer token",
      "content-type": "application/json",
      "idempotency-key": "problem:stop-1",
    },
    body: JSON.stringify({ manifestId, manifestVersion: 1, category: "missing_item" }),
  }), stopId, dependencies(gateway));
  assert.equal(response.status, 201);
  assert.equal(gateway.problemCommand?.aggregateId, stopId);
  assert.equal(gateway.problemCommand?.expectedVersion, 4);
});

test("driver explicitly confirms arrival with optional GPS evidence", async () => {
  const gateway = new FakeDriverStopGateway();
  const response = await confirmStopArrivalHandler(new Request("http://test/arrival", {
    method: "POST",
    headers: {
      authorization: "Bearer token",
      "content-type": "application/json",
      "idempotency-key": "arrival:stop-1",
    },
    body: JSON.stringify({
      position: { latitude: 13.74, longitude: 100.54, accuracyMeters: 20, source: "google_nav" },
    }),
  }), stopId, dependencies(gateway));
  assert.equal(response.status, 201);
  assert.equal(gateway.arrivalCommand?.expectedVersion, 4);
  assert.equal(gateway.arrivalCommand?.payload.position?.source, "google_nav");
});

test("driver cannot mutate a Stop outside the assigned Round", async () => {
  const gateway = new FakeDriverStopGateway();
  gateway.driverSession = { user: session.user, driver: session.driver };
  const response = await confirmStopArrivalHandler(new Request("http://test/arrival", {
    method: "POST",
    headers: {
      authorization: "Bearer token",
      "content-type": "application/json",
      "idempotency-key": "arrival:stop-1",
    },
    body: "{}",
  }), stopId, dependencies(gateway));
  assert.equal(response.status, 403);
  assert.equal(gateway.arrivalCommand, null);
});
