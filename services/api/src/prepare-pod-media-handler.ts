import {
  ContractError,
  validatePreparePodMediaPayload,
  type PreparePodMediaPayload,
} from "@rounds/contracts";
import type { PodDependencies } from "./types.js";
import { bearerToken, json, statusForCommandError } from "./http.js";

export async function preparePodMediaHandler(
  request: Request,
  stopId: string,
  dependencies: PodDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const session = await dependencies.identity.getDriverSession(identity);
  const stop = session?.currentRound?.stops.find((candidate) => candidate.id === stopId);
  if (!stop) return json(403, { error: { code: "NOT_AUTHORIZED", message: "Stop is not assigned to this Team driver" } }, traceId);
  let payload: PreparePodMediaPayload;
  try {
    payload = await request.json() as PreparePodMediaPayload;
    validatePreparePodMediaPayload(payload);
  } catch (error) {
    return json(422, { error: {
      code: "VALIDATION_FAILED",
      message: error instanceof ContractError ? error.message : "Photo metadata is invalid",
    } }, traceId);
  }
  const result = await dependencies.stops.preparePodMedia(
    stopId,
    identity,
    dependencies.uuid(),
    payload.sha256,
    payload.byteSize,
    payload.contentType,
  );
  if (result.status === "rejected") {
    const error = result.error as { code: Parameters<typeof statusForCommandError>[0]; message: string };
    return json(statusForCommandError(error.code), result, traceId);
  }
  return json(result.deduplicated ? 200 : 201, result, traceId);
}
