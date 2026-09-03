import {
  ContractError,
  validateAcknowledgeLiveDeliveryChangeCommand,
  validateApplyLiveDeliveryChangeCommand,
  validateLiveDeliveryChangeRequest,
  type LiveDeliveryChangePreview,
  type LiveDeliveryChangeRequest,
  type OperationsRoundDetail,
} from "@rounds/contracts";
import { bearerToken, json, statusForCommandError } from "./http.js";
import { routeSnapshot } from "./planning-route-service.js";
import { RoutingProviderError } from "./routing-provider.js";
import type { DriverLiveDeliveryChangeDependencies, LiveDeliveryChangeDependencies } from "./types.js";

async function authorizeOperations(request: Request, dependencies: LiveDeliveryChangeDependencies, traceId: string) {
  const token = bearerToken(request);
  if (!token) return { response: json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId) };
  const tenantId = request.headers.get("x-rounds-tenant-id")?.trim();
  if (!tenantId) return { response: json(400, { error: { code: "VALIDATION_FAILED", message: "x-rounds-tenant-id header is required" } }, traceId) };
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return { response: json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId) };
  const actor = await dependencies.identity.authorizeTenant(identity.authUserId, tenantId);
  if (!actor || !["tenant_owner", "operations_admin", "dispatcher"].includes(actor.role)) {
    return { response: json(403, { error: { code: "NOT_AUTHORIZED", message: "Live delivery editing is not permitted" } }, traceId) };
  }
  return { actor };
}

async function requestBody(request: Request): Promise<LiveDeliveryChangeRequest> {
  const payload = await request.json() as LiveDeliveryChangeRequest;
  validateLiveDeliveryChangeRequest(payload);
  return payload;
}

function changed(before: LiveDeliveryChangePreview["before"], after: LiveDeliveryChangePreview["after"]): boolean {
  return before.sequence !== after.sequence
    || before.rawAddress !== after.rawAddress
    || before.latitude !== after.latitude
    || before.longitude !== after.longitude
    || (before.accessNote ?? "") !== (after.accessNote ?? "")
    || before.windowStart !== after.windowStart
    || before.windowEnd !== after.windowEnd;
}

async function calculate(
  payload: LiveDeliveryChangeRequest,
  dependencies: LiveDeliveryChangeDependencies,
  actor: NonNullable<Awaited<ReturnType<typeof authorizeOperations>>["actor"]>,
  now: Date,
): Promise<LiveDeliveryChangePreview & { detail: OperationsRoundDetail; stopOrderAfter: string[] }> {
  const detail = await dependencies.changes.getOperationsRoundDetail(payload.roundId, actor, now);
  if (!detail) throw new Error("Round was not found");
  const stop = detail.stops.find((item) => item.stopId === payload.stopId);
  if (!stop) throw new Error("Stop is no longer assigned to this Round");
  const reasons: string[] = [];
  if (detail.version !== payload.expectedRoundVersion) reasons.push("Round changed. Refresh before previewing again.");
  if (stop.stopVersion !== payload.expectedStopVersion || stop.destinationVersion !== payload.expectedDestinationVersion) reasons.push("Delivery changed. Refresh before previewing again.");
  if (detail.state !== "active") reasons.push("Live delivery changes require an active Round.");
  if (!stop.pickupConfirmed || stop.manifest.state !== "picked_up_locked") reasons.push("Pickup verification must be locked before a live delivery change.");
  if (["completed", "cancelled"].includes(stop.stopState) || stop.completedAt) reasons.push("A completed or cancelled Stop cannot be changed.");
  if (stop.openExceptionCount) reasons.push("Resolve the open Stop exception before changing the live delivery.");
  if (!stop.coordinate) reasons.push("The current delivery point is unavailable.");
  if (!detail.routePlan) reasons.push("The active Round has no authoritative route plan.");

  const before = {
    sequence: stop.sequence,
    rawAddress: stop.rawAddress,
    latitude: stop.coordinate?.latitude ?? 0,
    longitude: stop.coordinate?.longitude ?? 0,
    ...(stop.accessNote ? { accessNote: stop.accessNote } : {}),
    windowStart: stop.windowStart,
    windowEnd: stop.windowEnd,
  };
  const after = {
    sequence: payload.changes.sequence ?? before.sequence,
    rawAddress: payload.changes.rawAddress?.trim() ?? before.rawAddress,
    latitude: payload.changes.latitude ?? before.latitude,
    longitude: payload.changes.longitude ?? before.longitude,
    ...(payload.changes.accessNote !== undefined
      ? payload.changes.accessNote.trim() ? { accessNote: payload.changes.accessNote.trim() } : {}
      : before.accessNote ? { accessNote: before.accessNote } : {}),
    windowStart: payload.changes.windowStart ?? before.windowStart,
    windowEnd: payload.changes.windowEnd ?? before.windowEnd,
  };
  const stopOrderAfter = [...detail.stops].sort((a, b) => a.sequence - b.sequence);
  if (after.sequence > detail.stops.length) reasons.push(`Stop order must be between 1 and ${detail.stops.length}.`);
  const terminalPrefix = stopOrderAfter.filter((item) => ["completed", "cancelled"].includes(item.stopState) || item.completedAt).length;
  if (after.sequence !== before.sequence && after.sequence <= terminalPrefix) reasons.push("A future Stop cannot move ahead of a completed Stop.");
  if (after.sequence !== before.sequence && after.sequence <= detail.stops.length) {
    const movingIndex = stopOrderAfter.findIndex((item) => item.stopId === stop.stopId);
    const [moving] = stopOrderAfter.splice(movingIndex, 1);
    stopOrderAfter.splice(after.sequence - 1, 0, moving!);
  }
  if (!changed(before, after)) reasons.push("Nothing changed.");

  let routeAfter;
  let impact;
  if (!reasons.length) {
    if (!dependencies.routes.previewAssignedChange) throw new Error("Live route recalculation is unavailable");
    const remainingStops = stopOrderAfter
      .filter((item) => !["completed", "cancelled"].includes(item.stopState) && !item.completedAt);
    const remainingStopIds = remainingStops.map((item) => item.stopId);
    routeAfter = await dependencies.routes.previewAssignedChange(
      actor,
      [detail.id],
      { serviceDate: detail.serviceDate, driverId: detail.driver.id, stopIds: remainingStopIds },
      now,
      { stopId: stop.stopId, coordinate: { latitude: after.latitude, longitude: after.longitude }, windowStart: after.windowStart, windowEnd: after.windowEnd },
      detail.currentPosition ? { latitude: detail.currentPosition.latitude, longitude: detail.currentPosition.longitude } : undefined,
    );
    if (routeAfter.status === "blocked") reasons.push(...routeAfter.blockingReasons);
    const beforeStop = detail.routePlan!.stops.find((item) => item.stopId === stop.stopId);
    const afterStop = routeAfter.stops.find((item) => item.stopId === stop.stopId);
    impact = {
      distanceDeltaMeters: routeAfter.distanceMeters - detail.routePlan!.distanceMeters,
      durationDeltaSeconds: routeAfter.durationSeconds - detail.routePlan!.durationSeconds,
      ...(beforeStop ? { etaBefore: beforeStop.eta } : {}),
      ...(afterStop ? { etaAfter: afterStop.eta } : {}),
      finishBefore: detail.routePlan!.finishAt,
      finishAfter: routeAfter.finishAt,
      downstreamStopCount: Math.max(0, remainingStopIds.indexOf(stop.stopId) >= 0 ? remainingStopIds.length - remainingStopIds.indexOf(stop.stopId) - 1 : 0),
      promiseStatus: afterStop?.promiseStatus ?? "safe",
      shiftSafe: !routeAfter.blockingReasons.some((reason) => /shift/i.test(reason)),
    };
  }
  return {
    tenantId: actor.tenantId,
    calculatedAt: now.toISOString(),
    roundId: detail.id,
    stopId: stop.stopId,
    applicable: reasons.length === 0,
    blockingReasons: [...new Set(reasons)],
    before,
    after,
    ...(impact ? { impact } : {}),
    ...(routeAfter ? { routeAfter } : {}),
    custody: { driverId: detail.driver.id, manifestId: stop.manifest.id, manifestVersion: stop.manifest.version, verified: true },
    detail,
    stopOrderAfter: stopOrderAfter.map((item) => item.stopId),
  };
}

function publicPreview(preview: Awaited<ReturnType<typeof calculate>>): LiveDeliveryChangePreview {
  const { detail: _detail, stopOrderAfter: _stopOrderAfter, ...result } = preview;
  return result;
}

export async function liveDeliveryChangePreviewHandler(request: Request, dependencies: LiveDeliveryChangeDependencies): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const authorized = await authorizeOperations(request, dependencies, traceId);
  if (authorized.response) return authorized.response;
  let payload;
  try { payload = await requestBody(request); }
  catch (error) { return json(422, { error: { code: "VALIDATION_FAILED", message: error instanceof ContractError ? error.message : "Request body is invalid" } }, traceId); }
  try { return json(200, publicPreview(await calculate(payload, dependencies, authorized.actor!, dependencies.now())), traceId); }
  catch (error) {
    if (error instanceof RoutingProviderError) return json(503, { error: { code: "PROVIDER_UNAVAILABLE", message: error.message } }, traceId);
    return json(409, { error: { code: "INVALID_STATE", message: error instanceof Error ? error.message : "Live change cannot be evaluated" } }, traceId);
  }
}

export async function applyLiveDeliveryChangeHandler(request: Request, dependencies: LiveDeliveryChangeDependencies): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const authorized = await authorizeOperations(request, dependencies, traceId);
  if (authorized.response) return authorized.response;
  const idempotencyKey = request.headers.get("idempotency-key")?.trim();
  if (!idempotencyKey) return json(400, { error: { code: "VALIDATION_FAILED", message: "idempotency-key header is required" } }, traceId);
  let payload;
  try { payload = await requestBody(request); }
  catch (error) { return json(422, { error: { code: "VALIDATION_FAILED", message: error instanceof ContractError ? error.message : "Request body is invalid" } }, traceId); }
  try {
    const preview = await calculate(payload, dependencies, authorized.actor!, dependencies.now());
    if (!preview.applicable || !preview.impact || !preview.routeAfter) return json(409, { error: { code: "INVALID_STATE", message: preview.blockingReasons[0] ?? "Live change is blocked", preview: publicPreview(preview) } }, traceId);
    const command = {
      schemaVersion: 1 as const,
      commandType: "delivery.apply_live_change" as const,
      commandId: dependencies.uuid(),
      traceId,
      idempotencyKey,
      tenantId: authorized.actor!.tenantId,
      aggregateId: payload.stopId,
      expectedVersion: payload.expectedStopVersion,
      occurredFromDeviceAt: dependencies.now().toISOString(),
      payload: {
        ...payload,
        before: preview.before,
        after: preview.after,
        impact: preview.impact,
        routePlan: routeSnapshot(preview.routeAfter),
        stopOrderAfter: preview.stopOrderAfter,
      },
    };
    validateApplyLiveDeliveryChangeCommand(command);
    const result = await dependencies.changes.applyLiveDeliveryChange(command, authorized.actor!);
    if (result.status === "rejected") return json(statusForCommandError(result.error.code), result, traceId);
    return json(200, result, traceId);
  } catch (error) {
    if (error instanceof RoutingProviderError) return json(503, { error: { code: "PROVIDER_UNAVAILABLE", message: error.message } }, traceId);
    return json(409, { error: { code: "INVALID_STATE", message: error instanceof Error ? error.message : "Live change cannot be committed" } }, traceId);
  }
}

export async function acknowledgeLiveDeliveryChangeHandler(request: Request, changeId: string, dependencies: DriverLiveDeliveryChangeDependencies): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const session = await dependencies.identity.getDriverSession(identity);
  if (!session?.team) return json(403, { error: { code: "NOT_AUTHORIZED", message: "No active Team-driver relationship is linked to this account" } }, traceId);
  const idempotencyKey = request.headers.get("idempotency-key")?.trim();
  if (!idempotencyKey) return json(400, { error: { code: "VALIDATION_FAILED", message: "idempotency-key header is required" } }, traceId);
  let expectedChangeVersion: number;
  try { expectedChangeVersion = Number((await request.json() as { expectedChangeVersion?: unknown }).expectedChangeVersion); }
  catch { return json(422, { error: { code: "VALIDATION_FAILED", message: "Request body is invalid" } }, traceId); }
  const command = {
    schemaVersion: 1 as const,
    commandType: "driver.acknowledge_live_change" as const,
    commandId: dependencies.uuid(), traceId, idempotencyKey,
    tenantId: session.team.tenantId, aggregateId: changeId, expectedVersion: expectedChangeVersion,
    occurredFromDeviceAt: dependencies.now().toISOString(),
    payload: { changeId, expectedChangeVersion },
  };
  try { validateAcknowledgeLiveDeliveryChangeCommand(command); }
  catch (error) { return json(422, { error: { code: "VALIDATION_FAILED", message: error instanceof ContractError ? error.message : "Request body is invalid" } }, traceId); }
  const result = await dependencies.changes.acknowledgeLiveDeliveryChange(command, identity);
  if (result.status === "rejected") return json(statusForCommandError(result.error.code), result, traceId);
  return json(200, result, traceId);
}
