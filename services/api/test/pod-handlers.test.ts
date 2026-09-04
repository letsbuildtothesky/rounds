import assert from "node:assert/strict";
import test from "node:test";
import type {
  CompleteStopPodCommand,
  CompleteStopPodResult,
  ReportDeliveryProblemCommand,
  ReportDeliveryProblemResult,
  DriverSession,
  OperationsSession,
} from "@rounds/contracts";
import { completeStopPodHandler } from "../src/complete-stop-pod-handler.js";
import { preparePodMediaHandler } from "../src/prepare-pod-media-handler.js";
import { prepareExceptionMediaHandler } from "../src/prepare-exception-media-handler.js";
import { reportDeliveryProblemHandler } from "../src/report-delivery-problem-handler.js";
import type { ActorContext, AuthenticatedIdentity, IdentityGateway, PodGateway } from "../src/types.js";

const stopId = "10000000-0000-4000-8000-000000000011";
const mediaAssetId = "10000000-0000-4000-8000-000000000013";
const session: DriverSession = {
  user: { id: "auth-user", displayName: "Driver" },
  driver: { id: "10000000-0000-4000-8000-000000000002", preferredLocale: "en" },
  currentRound: {
    id: "10000000-0000-4000-8000-000000000010",
    reference: "ROUND-001", serviceDate: "2026-09-02", state: "active", version: 2,
    tenant: { id: "10000000-0000-4000-8000-000000000001", displayName: "UrbanFlowers", timezone: "Asia/Bangkok" },
    pickup: { id: "10000000-0000-4000-8000-000000000020", displayName: "Studio", rawAddress: "Bangkok", contactName: "Ops", contactPhone: "+660000000" },
    stops: [{
      id: stopId, sequence: 1, state: "arrived", version: 5, destinationVersion: 1,
      deliveryId: "10000000-0000-4000-8000-000000000014", deliveryReference: "UF-001",
      recipientName: "Siriporn", recipientPhone: "+66999999999", rawAddress: "Bangkok",
      latitude: 13.74, longitude: 100.54, isSurprise: false,
      windowStart: "2026-09-02T02:00:00Z", windowEnd: "2026-09-02T04:00:00Z",
      manifestId: "10000000-0000-4000-8000-000000000012", manifestVersion: 1,
      manifestItems: [{ lineNumber: 1, description: "Bouquet", quantity: 1 }],
    }],
  },
};

class FakePodGateway implements IdentityGateway, PodGateway {
  verificationResult: Record<string, unknown> = { status: "verified" };
  verificationCalls = 0;
  completed: CompleteStopPodCommand | null = null;
  deliveryProblem: ReportDeliveryProblemCommand | null = null;
  async authenticate(): Promise<AuthenticatedIdentity | null> { return { authUserId: "auth-user" }; }
  async authorizeTenant(): Promise<ActorContext | null> { return null; }
  async getOperationsSession(): Promise<OperationsSession | null> { return null; }
  async getDriverSession(): Promise<DriverSession | null> { return session; }
  async preparePodMedia(): Promise<Record<string, unknown>> {
    return { status: "prepared", mediaAssetId, bucket: "pod-evidence", path: "private/photo.jpg", assetState: "staged", tusEndpoint: "https://storage/upload/resumable", uploadAuthorization: "driver_session" };
  }
  async prepareExceptionMedia(): Promise<Record<string, unknown>> {
    return { status: "prepared", mediaAssetId, bucket: "pod-evidence", path: "private/exception.jpg", assetState: "staged", tusEndpoint: "https://storage/upload/resumable", uploadAuthorization: "driver_session" };
  }
  async verifyPodMedia(): Promise<Record<string, unknown>> {
    this.verificationCalls += 1;
    return this.verificationResult;
  }
  async reportDeliveryProblem(command: ReportDeliveryProblemCommand): Promise<ReportDeliveryProblemResult> {
    this.deliveryProblem = command;
    return { status: "committed", aggregateVersion: 6, state: {
      exceptionId: "10000000-0000-4000-8000-000000000040",
      ...(command.payload.mediaAssetId ? { mediaAssetId: command.payload.mediaAssetId } : {}),
      stopId, deliveryId: session.currentRound!.stops[0]!.deliveryId,
      roundId: session.currentRound!.id, category: command.payload.category,
      stopState: "exception", deliveryState: "exception",
    }, events: [] };
  }
  async completeStopPod(command: CompleteStopPodCommand): Promise<CompleteStopPodResult> {
    this.completed = command;
    return { status: "committed", aggregateVersion: 6, state: {
      podId: "10000000-0000-4000-8000-000000000030", mediaAssetId,
      custodyEventId: "10000000-0000-4000-8000-000000000031",
      manifestVerificationId: "10000000-0000-4000-8000-000000000032",
      stopId, deliveryId: session.currentRound!.stops[0]!.deliveryId,
      roundId: session.currentRound!.id, driverId: session.driver.id,
      handoffType: "recipient", deliveredAt: "2026-09-01T12:00:00Z",
      stopState: "completed", deliveryState: "delivered", roundState: "complete", roundVersion: 3,
    }, events: [] };
  }
}

const dependencies = (gateway: FakePodGateway) => ({
  identity: gateway, stops: gateway,
  uuid: () => "10000000-0000-4000-8000-000000000101",
  now: () => new Date("2026-09-01T12:00:00Z"),
});

test("prepares a private resumable photo target for an assigned arrived Stop", async () => {
  const gateway = new FakePodGateway();
  const response = await preparePodMediaHandler(new Request("http://test/pod-media", {
    method: "POST", headers: { authorization: "Bearer token", "content-type": "application/json" },
    body: JSON.stringify({ sha256: "a".repeat(64), byteSize: 1000, contentType: "image/jpeg" }),
  }), stopId, dependencies(gateway));
  assert.equal(response.status, 201);
  const body = await response.json() as Record<string, unknown>;
  assert.equal(body.mediaAssetId, mediaAssetId);
  assert.equal(body.uploadAuthorization, "driver_session");
});

test("verifies durable bytes before committing POD", async () => {
  const gateway = new FakePodGateway();
  const request = new Request("http://test/pod", {
    method: "POST", headers: { authorization: "Bearer token", "content-type": "application/json", "idempotency-key": "pod:stop-1" },
    body: JSON.stringify({
      manifestId: session.currentRound!.stops[0]!.manifestId, manifestVersion: 1,
      confirmedLineNumbers: [1], mediaAssetId, handoffType: "recipient", receiverName: "Siriporn",
    }),
  });
  const response = await completeStopPodHandler(request, stopId, dependencies(gateway));
  assert.equal(response.status, 201);
  assert.equal(gateway.completed?.expectedVersion, 5);
});

test("missing uploaded bytes block delivery completion", async () => {
  const gateway = new FakePodGateway();
  gateway.verificationResult = { status: "rejected", error: { code: "EVIDENCE_REQUIRED", message: "Photo upload is not complete yet" } };
  const response = await completeStopPodHandler(new Request("http://test/pod", {
    method: "POST", headers: { authorization: "Bearer token", "content-type": "application/json", "idempotency-key": "pod:stop-1" },
    body: JSON.stringify({ manifestId: session.currentRound!.stops[0]!.manifestId, manifestVersion: 1, confirmedLineNumbers: [1], mediaAssetId, handoffType: "recipient", receiverName: "Siriporn" }),
  }), stopId, dependencies(gateway));
  assert.equal(response.status, 422);
  assert.equal(gateway.completed, null);
});

test("prepares and verifies evidence before reporting delivery damage", async () => {
  const gateway = new FakePodGateway();
  const prepareResponse = await prepareExceptionMediaHandler(new Request("http://test/exception-media", {
    method: "POST", headers: { authorization: "Bearer token", "content-type": "application/json" },
    body: JSON.stringify({ sha256: "b".repeat(64), byteSize: 2000, contentType: "image/jpeg" }),
  }), stopId, dependencies(gateway));
  assert.equal(prepareResponse.status, 201);

  const response = await reportDeliveryProblemHandler(new Request("http://test/delivery-problem", {
    method: "POST",
    headers: { authorization: "Bearer token", "content-type": "application/json", "idempotency-key": "delivery-problem:stop-1" },
    body: JSON.stringify({
      manifestId: session.currentRound!.stops[0]!.manifestId,
      manifestVersion: 1,
      category: "damaged_item",
      mediaAssetId,
      note: "Package is crushed",
    }),
  }), stopId, dependencies(gateway));
  assert.equal(response.status, 201);
  assert.equal(gateway.deliveryProblem?.expectedVersion, 5);
  assert.equal(gateway.deliveryProblem?.payload.mediaAssetId, mediaAssetId);
});

test("unuploaded damage evidence never creates an exception", async () => {
  const gateway = new FakePodGateway();
  gateway.verificationResult = { status: "rejected", error: { code: "EVIDENCE_REQUIRED", message: "Photo upload is not complete yet" } };
  const response = await reportDeliveryProblemHandler(new Request("http://test/delivery-problem", {
    method: "POST",
    headers: { authorization: "Bearer token", "content-type": "application/json", "idempotency-key": "delivery-problem:stop-1" },
    body: JSON.stringify({ manifestId: session.currentRound!.stops[0]!.manifestId, manifestVersion: 1, category: "damaged_item", mediaAssetId }),
  }), stopId, dependencies(gateway));
  assert.equal(response.status, 422);
  assert.equal(gateway.deliveryProblem, null);
});

test("reports a missing package without fabricating photo evidence", async () => {
  const gateway = new FakePodGateway();
  const response = await reportDeliveryProblemHandler(new Request("http://test/delivery-problem", {
    method: "POST",
    headers: { authorization: "Bearer token", "content-type": "application/json", "idempotency-key": "delivery-problem:missing:stop-1" },
    body: JSON.stringify({
      manifestId: session.currentRound!.stops[0]!.manifestId,
      manifestVersion: 1,
      category: "missing_item",
    }),
  }), stopId, dependencies(gateway));
  assert.equal(response.status, 201);
  assert.equal(gateway.verificationCalls, 0);
  assert.equal(gateway.deliveryProblem?.payload.category, "missing_item");
  assert.equal(gateway.deliveryProblem?.payload.mediaAssetId, undefined);
});
