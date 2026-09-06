import {
  ContractError,
  validateConfirmPickupArrivalCommand,
  type ConfirmPickupArrivalPayload,
} from "@rounds/contracts";
import type { ConfirmPickupDependencies } from "./types.js";
import { bearerToken, json, statusForCommandError } from "./http.js";

export async function confirmPickupArrivalHandler(
  request: Request,
  roundId: string,
  dependencies: ConfirmPickupDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  const idempotencyKey = request.headers.get("idempotency-key")?.trim();
  if (!idempotencyKey) return json(400, {
    error: { code: "VALIDATION_FAILED", message: "idempotency-key header is required" },
  }, traceId);

  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const session = await dependencies.identity.getDriverSession(identity);
  if (!session?.currentRound || session.currentRound.id !== roundId) return json(403, {
    error: { code: "NOT_AUTHORIZED", message: "Round is not assigned to this Team driver" },
  }, traceId);

  let payload: ConfirmPickupArrivalPayload;
  try {
    payload = await request.json() as ConfirmPickupArrivalPayload;
  } catch {
    return json(400, { error: { code: "VALIDATION_FAILED", message: "Request body must be JSON" } }, traceId);
  }
  if (payload.pickupLocationId !== session.currentRound.pickup.id) return json(422, {
    error: { code: "VALIDATION_FAILED", message: "Pickup location does not match the assigned Round" },
  }, traceId);

  const command = {
    schemaVersion: 1 as const,
    commandType: "round.confirm_pickup_arrival" as const,
    commandId: dependencies.uuid(),
    traceId,
    idempotencyKey,
    tenantId: session.currentRound.tenant.id,
    aggregateId: roundId,
    expectedVersion: session.currentRound.version,
    occurredFromDeviceAt: dependencies.now().toISOString(),
    payload,
  };
  try {
    validateConfirmPickupArrivalCommand(command);
  } catch (error) {
    return json(422, { error: {
      code: "VALIDATION_FAILED",
      message: error instanceof ContractError ? error.message : "Pickup arrival command is invalid",
    } }, traceId);
  }

  const result = await dependencies.pickup.confirmPickupArrival(command, identity);
  if (result.status === "rejected") return json(statusForCommandError(result.error.code), result, traceId);
  return json(result.deduplicated ? 200 : 201, result, traceId);
}
