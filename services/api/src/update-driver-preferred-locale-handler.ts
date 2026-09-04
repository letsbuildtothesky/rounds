import {
  ContractError,
  validateUpdateDriverPreferredLocaleCommand,
} from "@rounds/contracts";
import type {
  DriverPreferredLocaleDependencies,
  UpdateDriverPreferredLocaleRequestBody,
} from "./types.js";
import { bearerToken, json, statusForCommandError } from "./http.js";

export async function updateDriverPreferredLocaleHandler(
  request: Request,
  dependencies: DriverPreferredLocaleDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, {
    error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" },
  }, traceId);
  const idempotencyKey = request.headers.get("idempotency-key")?.trim();
  if (!idempotencyKey) return json(400, {
    error: { code: "VALIDATION_FAILED", message: "idempotency-key header is required" },
  }, traceId);
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, {
    error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" },
  }, traceId);
  const session = await dependencies.identity.getDriverSession(identity);
  if (!session?.team) return json(403, {
    error: {
      code: "NOT_AUTHORIZED",
      message: "No active Team-driver relationship is available",
    },
  }, traceId);

  let body: UpdateDriverPreferredLocaleRequestBody;
  try {
    body = await request.json() as UpdateDriverPreferredLocaleRequestBody;
  } catch {
    return json(400, {
      error: { code: "VALIDATION_FAILED", message: "Request body must be JSON" },
    }, traceId);
  }
  const command = {
    schemaVersion: 1 as const,
    commandType: "driver.update_preferred_locale" as const,
    commandId: dependencies.uuid(),
    traceId,
    idempotencyKey,
    tenantId: session.team.tenantId,
    aggregateId: session.driver.id,
    expectedVersion: body.expectedVersion,
    occurredFromDeviceAt: dependencies.now().toISOString(),
    payload: { preferredLocale: body.preferredLocale },
  };
  try {
    validateUpdateDriverPreferredLocaleCommand(command);
  } catch (error) {
    return json(422, { error: {
      code: "VALIDATION_FAILED",
      message: error instanceof ContractError
        ? error.message
        : "Preferred locale command is invalid",
    } }, traceId);
  }
  const result = await dependencies.profiles.updateDriverPreferredLocale(
    command,
    identity,
  );
  if (result.status === "rejected") {
    return json(statusForCommandError(result.error.code), result, traceId);
  }
  return json(result.deduplicated ? 200 : 201, result, traceId);
}
