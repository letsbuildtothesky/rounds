import {
  ContractError,
  validateCreateDeliveryCommand,
  type CommandErrorCode,
  type CreateDeliveryCommand,
  type CreateDeliveryPayload,
} from "@rounds/contracts";
import type { CreateDeliveryDependencies } from "./types.js";

function json(status: number, body: unknown, traceId?: string): Response {
  const headers = new Headers({ "content-type": "application/json; charset=utf-8" });
  if (traceId) headers.set("x-trace-id", traceId);
  return Response.json(body, { status, headers });
}

function bearerToken(request: Request): string | null {
  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) return null;
  const token = authorization.slice("Bearer ".length).trim();
  return token.length > 0 ? token : null;
}

function statusForError(code: CommandErrorCode): number {
  switch (code) {
    case "NOT_AUTHORIZED":
      return 403;
    case "STALE_VERSION":
    case "IDEMPOTENCY_CONFLICT":
    case "CUSTODY_LOCKED":
    case "INVALID_STATE":
      return 409;
    case "VALIDATION_FAILED":
    case "EVIDENCE_REQUIRED":
      return 422;
    case "PROVIDER_UNAVAILABLE":
      return 503;
  }
}

export async function createDeliveryHandler(
  request: Request,
  dependencies: CreateDeliveryDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const accessToken = bearerToken(request);
  if (!accessToken) {
    return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  }

  const tenantId = request.headers.get("x-rounds-tenant-id")?.trim();
  const idempotencyKey = request.headers.get("idempotency-key")?.trim();
  if (!tenantId || !idempotencyKey) {
    return json(400, {
      error: {
        code: "VALIDATION_FAILED",
        message: "x-rounds-tenant-id and idempotency-key headers are required",
      },
    }, traceId);
  }

  const identity = await dependencies.identity.authenticate(accessToken);
  if (!identity) {
    return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  }

  const actor = await dependencies.identity.authorizeTenant(identity.authUserId, tenantId);
  if (!actor || !["tenant_owner", "operations_admin", "dispatcher"].includes(actor.role)) {
    return json(403, { error: { code: "NOT_AUTHORIZED", message: "Delivery creation is not permitted" } }, traceId);
  }

  let payload: CreateDeliveryPayload;
  try {
    payload = await request.json() as CreateDeliveryPayload;
  } catch {
    return json(400, { error: { code: "VALIDATION_FAILED", message: "Request body must be JSON" } }, traceId);
  }

  const command: CreateDeliveryCommand = {
    schemaVersion: 1,
    commandType: "delivery.create",
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
    validateCreateDeliveryCommand(command);
  } catch (error) {
    const message = error instanceof ContractError ? error.message : "Delivery command is invalid";
    return json(422, { error: { code: "VALIDATION_FAILED", message } }, traceId);
  }

  const result = await dependencies.commands.createDelivery(command, actor);
  if (result.status === "rejected") {
    return json(statusForError(result.error.code), result, traceId);
  }
  return json(result.deduplicated ? 200 : 201, result, traceId);
}
