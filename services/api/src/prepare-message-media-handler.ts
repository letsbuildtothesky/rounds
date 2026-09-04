import type { PrepareMessageMediaPayload } from "@rounds/contracts";
import type { DriverCommunicationsDependencies } from "./types.js";
import { bearerToken, json, statusForCommandError } from "./http.js";

const supportedKinds = new Set(["image", "file", "voice"]);

function validPayload(payload: PrepareMessageMediaPayload): boolean {
  return supportedKinds.has(payload.kind)
    && typeof payload.fileName === "string" && payload.fileName.trim().length > 0 && payload.fileName.trim().length <= 240
    && typeof payload.contentType === "string" && payload.contentType.trim().length > 0 && payload.contentType.trim().length <= 120
    && Number.isInteger(payload.byteSize) && payload.byteSize >= 1 && payload.byteSize <= 15728640
    && typeof payload.sha256 === "string" && /^[0-9a-f]{64}$/.test(payload.sha256)
    && (payload.kind === "voice"
      ? Number.isInteger(payload.durationMilliseconds) && payload.durationMilliseconds! >= 250 && payload.durationMilliseconds! <= 600000
      : payload.durationMilliseconds === undefined);
}

export async function prepareMessageMediaHandler(
  request: Request,
  roundId: string,
  stopId: string,
  dependencies: DriverCommunicationsDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const session = await dependencies.identity.getDriverSession(identity);
  const stop = session?.currentRound?.id === roundId
    ? session.currentRound.stops.find((candidate) => candidate.id === stopId)
    : undefined;
  if (!stop) return json(403, { error: { code: "NOT_AUTHORIZED", message: "Stop is not assigned to this Team driver" } }, traceId);
  let payload: PrepareMessageMediaPayload;
  try {
    payload = await request.json() as PrepareMessageMediaPayload;
  } catch {
    return json(400, { error: { code: "VALIDATION_FAILED", message: "Request body must be JSON" } }, traceId);
  }
  if (!validPayload(payload)) return json(422, {
    error: { code: "VALIDATION_FAILED", message: "Message attachment metadata is invalid" },
  }, traceId);
  const result = await dependencies.communications.prepareMessageMedia(
    roundId, stopId, identity, dependencies.uuid(), payload,
  );
  if (result.status === "rejected") {
    const error = result.error as { code: Parameters<typeof statusForCommandError>[0]; message: string };
    return json(statusForCommandError(error.code), result, traceId);
  }
  return json(result.deduplicated ? 200 : 201, result, traceId);
}

export async function verifyMessageMediaHandler(
  request: Request,
  assetId: string,
  dependencies: DriverCommunicationsDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const token = bearerToken(request);
  if (!token) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId);
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId);
  const result = await dependencies.communications.verifyMessageMedia(assetId, identity);
  if (result.status === "rejected") {
    const error = result.error as { code: Parameters<typeof statusForCommandError>[0]; message: string };
    return json(statusForCommandError(error.code), result, traceId);
  }
  return json(200, result, traceId);
}
