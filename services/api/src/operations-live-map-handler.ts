import type { OperationsLiveRoundMapProjection } from "@rounds/contracts";
import { bearerToken, json } from "./http.js";
import { RoutingProviderError } from "./routing-provider.js";
import type { OperationsLiveMapDependencies } from "./types.js";

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const terminalStopStates = new Set(["completed", "cancelled"]);

export async function operationsLiveMapHandler(
  request: Request,
  roundId: string,
  dependencies: OperationsLiveMapDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  const tenantId = request.headers.get("x-rounds-tenant-id")?.trim();
  if (!tenantId) return json(400, { error: { code: "VALIDATION_FAILED", message: "x-rounds-tenant-id header is required" } }, traceId);
  if (!uuidPattern.test(roundId)) return json(422, { error: { code: "VALIDATION_FAILED", message: "Round id is invalid" } }, traceId);
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const actor = await dependencies.identity.authorizeTenant(identity.authUserId, tenantId);
  if (!actor) return json(403, { error: { code: "NOT_AUTHORIZED", message: "Live map access is not permitted" } }, traceId);

  const observedAt = dependencies.now();
  const detail = await dependencies.rounds.getOperationsRoundDetail(roundId, actor, observedAt);
  if (!detail) return json(404, { error: { code: "NOT_FOUND", message: "Round was not found" } }, traceId);
  if (detail.state !== "active") return json(409, { error: { code: "INVALID_STATE", message: "Live route and trail are available only for an active Round" } }, traceId);

  const actualTrail = await dependencies.trails.getOperationsRoundTrail(detail.id, detail.driver.id, actor);
  const base: Omit<OperationsLiveRoundMapProjection, "routeStatus"> = {
    tenantId: actor.tenantId,
    roundId: detail.id,
    observedAt: observedAt.toISOString(),
    ...(actualTrail ? { actualTrail } : {}),
  };
  const remainingStops = detail.stops
    .filter((stop) => !terminalStopStates.has(stop.stopState))
    .sort((left, right) => left.sequence - right.sequence);
  if (!remainingStops.length) {
    return json(200, { ...base, routeStatus: "unavailable", routeUnavailableReason: "The active Round has no remaining Stops." } satisfies OperationsLiveRoundMapProjection, traceId);
  }
  if (!detail.currentPosition) {
    return json(200, { ...base, routeStatus: "unavailable", routeUnavailableReason: "The Driver has not supplied a current Rounds position." } satisfies OperationsLiveRoundMapProjection, traceId);
  }
  if (observedAt.getTime() - Date.parse(detail.currentPosition.capturedAt) > 90_000) {
    return json(200, { ...base, routeStatus: "unavailable", routeUnavailableReason: "The Driver position is stale, so no current remaining route is drawn." } satisfies OperationsLiveRoundMapProjection, traceId);
  }
  if (!dependencies.routes.previewAssignedChange) {
    return json(200, { ...base, routeStatus: "unavailable", routeUnavailableReason: "Assigned-Round routing is unavailable." } satisfies OperationsLiveRoundMapProjection, traceId);
  }

  try {
    const route = await dependencies.routes.previewAssignedChange(
      actor,
      [detail.id],
      {
        serviceDate: detail.serviceDate,
        driverId: detail.driver.id,
        stopIds: remainingStops.map((stop) => stop.stopId),
      },
      observedAt,
      { stopId: remainingStops[0]!.stopId },
      detail.currentPosition,
    );
    return json(200, {
      ...base,
      routeStatus: "available",
      remainingRoute: {
        roundId: detail.id,
        driverId: detail.driver.id,
        kind: "operations_remaining_route",
        calculatedAt: route.calculatedAt,
        status: route.status,
        provider: route.provider,
        geometry: route.geometry,
      },
    } satisfies OperationsLiveRoundMapProjection, traceId);
  } catch (error) {
    const reason = error instanceof RoutingProviderError
      ? `Remaining route unavailable: ${error.message}`
      : "Remaining route could not be calculated from current operational truth.";
    return json(200, { ...base, routeStatus: "unavailable", routeUnavailableReason: reason } satisfies OperationsLiveRoundMapProjection, traceId);
  }
}
