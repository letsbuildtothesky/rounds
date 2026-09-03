import {
  ContractError,
  validatePlanningRoutePreviewRequest,
  validatePlanRoundCommand,
  type PlanningRouteSnapshot,
} from "@rounds/contracts";
import type { PlanRoundDependencies, PlanRoundRequestBody } from "./types.js";
import { bearerToken, json, statusForCommandError } from "./http.js";
import { routeSnapshot } from "./planning-route-service.js";
import { RoutingProviderError } from "./routing-provider.js";

export async function planRoundHandler(
  request: Request,
  dependencies: PlanRoundDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);

  const tenantId = request.headers.get("x-rounds-tenant-id")?.trim();
  const idempotencyKey = request.headers.get("idempotency-key")?.trim();
  if (!tenantId || !idempotencyKey) return json(400, {
    error: { code: "VALIDATION_FAILED", message: "x-rounds-tenant-id and idempotency-key headers are required" },
  }, traceId);

  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const actor = await dependencies.identity.authorizeTenant(identity.authUserId, tenantId);
  if (!actor || !["tenant_owner", "operations_admin", "dispatcher"].includes(actor.role)) {
    return json(403, { error: { code: "NOT_AUTHORIZED", message: "Round approval is not permitted" } }, traceId);
  }

  let requestBody: PlanRoundRequestBody;
  try {
    requestBody = await request.json() as PlanRoundRequestBody;
    if (!requestBody || typeof requestBody.reference !== "string" || !requestBody.reference.trim()) {
      throw new ContractError("reference is required");
    }
    validatePlanningRoutePreviewRequest(requestBody);
  } catch (error) {
    return json(400, { error: { code: "VALIDATION_FAILED", message: error instanceof ContractError ? error.message : "Request body must be JSON" } }, traceId);
  }

  let routePlan: PlanningRouteSnapshot;
  try {
    const preview = await dependencies.routes.preview(actor, requestBody, dependencies.now());
    if (preview.status !== "fits") {
      return json(409, { error: {
        code: "INVALID_STATE",
        message: preview.blockingReasons[0] ?? "The proposed Round does not fit its promised windows or driver shift.",
        routePlan: preview,
      } }, traceId);
    }
    routePlan = routeSnapshot(preview);
  } catch (error) {
    if (error instanceof RoutingProviderError) {
      return json(503, { error: { code: "PROVIDER_UNAVAILABLE", message: error.message } }, traceId);
    }
    return json(409, { error: { code: "INVALID_STATE", message: error instanceof Error ? error.message : "Round route cannot be evaluated" } }, traceId);
  }

  const payload = { ...requestBody, reference: requestBody.reference.trim(), routePlan };

  const command = {
    schemaVersion: 1 as const,
    commandType: "round.plan_and_approve" as const,
    commandId: dependencies.uuid(),
    traceId,
    idempotencyKey,
    tenantId: actor.tenantId,
    aggregateId: dependencies.uuid(),
    expectedVersion: 0,
    occurredFromDeviceAt: dependencies.now().toISOString(),
    payload,
  };

  try {
    validatePlanRoundCommand(command);
  } catch (error) {
    return json(422, {
      error: { code: "VALIDATION_FAILED", message: error instanceof ContractError ? error.message : "Round command is invalid" },
    }, traceId);
  }

  const result = await dependencies.planning.planRound(command, actor);
  if (result.status === "rejected") return json(statusForCommandError(result.error.code), result, traceId);
  return json(result.deduplicated ? 200 : 201, result, traceId);
}
