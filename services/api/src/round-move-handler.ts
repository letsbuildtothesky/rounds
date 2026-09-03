import {
  ContractError,
  validateMoveRoundStopCommand,
  validateMoveRoundStopRequest,
  type MoveRoundStopPreview,
  type MoveRoundStopRequest,
  type OperationsRoundDetail,
  type PlanningRoutePreview,
} from "@rounds/contracts";
import { bearerToken, json, statusForCommandError } from "./http.js";
import { routeSnapshot } from "./planning-route-service.js";
import { RoutingProviderError } from "./routing-provider.js";
import type { RoundMoveDependencies } from "./types.js";

async function authorize(request: Request, dependencies: RoundMoveDependencies, traceId: string) {
  const token = bearerToken(request);
  if (!token) return { response: json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId) };
  const tenantId = request.headers.get("x-rounds-tenant-id")?.trim();
  if (!tenantId) return { response: json(400, { error: { code: "VALIDATION_FAILED", message: "x-rounds-tenant-id header is required" } }, traceId) };
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return { response: json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId) };
  const actor = await dependencies.identity.authorizeTenant(identity.authUserId, tenantId);
  if (!actor || !["tenant_owner", "operations_admin", "dispatcher"].includes(actor.role)) {
    return { response: json(403, { error: { code: "NOT_AUTHORIZED", message: "Round editing is not permitted" } }, traceId) };
  }
  return { actor };
}

async function body(request: Request): Promise<MoveRoundStopRequest> {
  const payload = await request.json() as MoveRoundStopRequest;
  validateMoveRoundStopRequest(payload);
  return payload;
}

async function calculate(
  payload: MoveRoundStopRequest,
  dependencies: RoundMoveDependencies,
  actor: NonNullable<Awaited<ReturnType<typeof authorize>>["actor"]>,
  now: Date,
): Promise<MoveRoundStopPreview & { sourceDetail: OperationsRoundDetail; targetDetail: OperationsRoundDetail }> {
  const [sourceDetail, targetDetail] = await Promise.all([
    dependencies.rounds.getOperationsRoundDetail(payload.sourceRoundId, actor, now),
    dependencies.rounds.getOperationsRoundDetail(payload.targetRoundId, actor, now),
  ]);
  if (!sourceDetail || !targetDetail) throw new Error("Source or target Round was not found.");
  const reasons: string[] = [];
  if (sourceDetail.version !== payload.sourceExpectedVersion) reasons.push("Source Round changed. Refresh before moving the Stop.");
  if (targetDetail.version !== payload.targetExpectedVersion) reasons.push("Target Round changed. Refresh before moving the Stop.");
  if (sourceDetail.state !== "approved" || targetDetail.state !== "approved") reasons.push("Stops may move only between approved Rounds before pickup begins.");
  if (sourceDetail.serviceDate !== targetDetail.serviceDate) reasons.push("Source and target Rounds must use the same service date.");
  if (!sourceDetail.pickup.id || sourceDetail.pickup.id !== targetDetail.pickup.id) reasons.push("Source and target Rounds must use the same pickup location.");
  const stop = sourceDetail.stops.find((item) => item.stopId === payload.stopId);
  if (!stop) reasons.push("The Stop is no longer in the source Round.");
  if (targetDetail.stops.some((item) => item.stopId === payload.stopId)) reasons.push("The Stop is already in the target Round.");
  if (stop && (stop.stopState !== "assigned" || stop.pickupConfirmed || stop.arrivedAt || stop.completedAt)) {
    reasons.push("Current, custody, arrived, or completed Stops cannot be moved without a custody workflow.");
  }
  if (stop?.openExceptionCount) reasons.push("Resolve the Stop's open exception before moving it.");
  if (!sourceDetail.routePlan || !targetDetail.routePlan) reasons.push("Both Rounds need an approved server route before a Stop can move.");

  const sourceStopIds = sourceDetail.stops.filter((item) => item.stopId !== payload.stopId).map((item) => item.stopId);
  const targetStopIds = [payload.stopId, ...targetDetail.stops.map((item) => item.stopId)];
  let sourceAfter: PlanningRoutePreview | undefined;
  let targetAfter: PlanningRoutePreview | undefined;
  if (reasons.length === 0) {
    if (!dependencies.routes.previewAssigned) throw new Error("Assigned Round routing is unavailable");
    [sourceAfter, targetAfter] = await Promise.all([
      sourceStopIds.length ? dependencies.routes.previewAssigned(actor, [sourceDetail.id, targetDetail.id], {
        serviceDate: sourceDetail.serviceDate,
        driverId: sourceDetail.driver.id,
        stopIds: sourceStopIds,
        departureAt: sourceDetail.routePlan!.departureAt,
      }, now) : Promise.resolve(undefined),
      dependencies.routes.previewAssigned(actor, [sourceDetail.id, targetDetail.id], {
        serviceDate: targetDetail.serviceDate,
        driverId: targetDetail.driver.id,
        stopIds: targetStopIds,
        departureAt: targetDetail.routePlan!.departureAt,
      }, now),
    ]);
    if (sourceAfter?.status === "blocked") reasons.push(...sourceAfter.blockingReasons.map((reason) => `${sourceDetail.reference}: ${reason}`));
    if (targetAfter.status === "blocked") reasons.push(...targetAfter.blockingReasons.map((reason) => `${targetDetail.reference}: ${reason}`));
  }
  return {
    tenantId: actor.tenantId,
    calculatedAt: now.toISOString(),
    stopId: payload.stopId,
    movable: reasons.length === 0,
    blockingReasons: [...new Set(reasons)],
    source: {
      roundId: sourceDetail.id, reference: sourceDetail.reference, driverId: sourceDetail.driver.id,
      driverName: sourceDetail.driver.displayName, stopsBefore: sourceDetail.stops.length, stopsAfter: sourceStopIds.length,
      ...([sourceDetail.driver.vehicleLabel, sourceDetail.driver.vehiclePlate].filter(Boolean).length ? { vehicleLabel: [sourceDetail.driver.vehicleLabel, sourceDetail.driver.vehiclePlate].filter(Boolean).join(" · ") } : {}),
      ...(sourceDetail.routePlan ? { routeBefore: sourceDetail.routePlan } : {}),
      ...(sourceAfter ? { routeAfter: sourceAfter } : {}), removed: sourceStopIds.length === 0,
    },
    target: {
      roundId: targetDetail.id, reference: targetDetail.reference, driverId: targetDetail.driver.id,
      driverName: targetDetail.driver.displayName, stopsBefore: targetDetail.stops.length, stopsAfter: targetStopIds.length,
      ...([targetDetail.driver.vehicleLabel, targetDetail.driver.vehiclePlate].filter(Boolean).length ? { vehicleLabel: [targetDetail.driver.vehicleLabel, targetDetail.driver.vehiclePlate].filter(Boolean).join(" · ") } : {}),
      ...(targetDetail.routePlan ? { routeBefore: targetDetail.routePlan } : {}),
      ...(targetAfter ? { routeAfter: targetAfter } : {}), removed: false,
    },
    sourceDetail,
    targetDetail,
  };
}

function publicPreview(preview: Awaited<ReturnType<typeof calculate>>): MoveRoundStopPreview {
  const { sourceDetail: _sourceDetail, targetDetail: _targetDetail, ...result } = preview;
  return result;
}

export async function roundMovePreviewHandler(request: Request, dependencies: RoundMoveDependencies): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const authorized = await authorize(request, dependencies, traceId);
  if (authorized.response) return authorized.response;
  let payload: MoveRoundStopRequest;
  try { payload = await body(request); }
  catch (error) { return json(422, { error: { code: "VALIDATION_FAILED", message: error instanceof ContractError ? error.message : "Request body is invalid" } }, traceId); }
  try { return json(200, publicPreview(await calculate(payload, dependencies, authorized.actor!, dependencies.now())), traceId); }
  catch (error) {
    if (error instanceof RoutingProviderError) return json(503, { error: { code: "PROVIDER_UNAVAILABLE", message: error.message } }, traceId);
    return json(409, { error: { code: "INVALID_STATE", message: error instanceof Error ? error.message : "Round move cannot be evaluated" } }, traceId);
  }
}

export async function roundMoveHandler(request: Request, dependencies: RoundMoveDependencies): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const authorized = await authorize(request, dependencies, traceId);
  if (authorized.response) return authorized.response;
  const idempotencyKey = request.headers.get("idempotency-key")?.trim();
  if (!idempotencyKey) return json(400, { error: { code: "VALIDATION_FAILED", message: "idempotency-key header is required" } }, traceId);
  let payload: MoveRoundStopRequest;
  try { payload = await body(request); }
  catch (error) { return json(422, { error: { code: "VALIDATION_FAILED", message: error instanceof ContractError ? error.message : "Request body is invalid" } }, traceId); }
  try {
    const preview = await calculate(payload, dependencies, authorized.actor!, dependencies.now());
    if (!preview.movable || !preview.target.routeAfter) return json(409, { error: { code: "INVALID_STATE", message: preview.blockingReasons[0] ?? "Move is blocked", preview: publicPreview(preview) } }, traceId);
    const sourceStopIds = preview.sourceDetail.stops.filter((item) => item.stopId !== payload.stopId).map((item) => item.stopId);
    const targetStopIds = [payload.stopId, ...preview.targetDetail.stops.map((item) => item.stopId)];
    const command = {
      schemaVersion: 1 as const, commandType: "round.move_stop" as const, commandId: dependencies.uuid(), traceId,
      idempotencyKey, tenantId: authorized.actor!.tenantId, aggregateId: payload.sourceRoundId,
      expectedVersion: payload.sourceExpectedVersion, occurredFromDeviceAt: dependencies.now().toISOString(),
      payload: {
        ...payload, sourceStopIds, targetStopIds,
        ...(preview.source.routeAfter ? { sourceRoutePlan: routeSnapshot(preview.source.routeAfter) } : {}),
        targetRoutePlan: routeSnapshot(preview.target.routeAfter),
      },
    };
    validateMoveRoundStopCommand(command);
    const result = await dependencies.rounds.moveRoundStop(command, authorized.actor!);
    if (result.status === "rejected") return json(statusForCommandError(result.error.code), result, traceId);
    return json(200, result, traceId);
  } catch (error) {
    if (error instanceof RoutingProviderError) return json(503, { error: { code: "PROVIDER_UNAVAILABLE", message: error.message } }, traceId);
    return json(409, { error: { code: "INVALID_STATE", message: error instanceof Error ? error.message : "Round move cannot be committed" } }, traceId);
  }
}
