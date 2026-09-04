import type { PrepareMessageMediaPayload } from "@rounds/contracts";
import type { OperationsCommunicationsDependencies } from "./types.js";
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

async function operationsActor(request: Request, dependencies: OperationsCommunicationsDependencies) {
  const token = bearerToken(request);
  if (!token) return null;
  const identity = await dependencies.identity.authenticate(token);
  const tenantId = request.headers.get("x-rounds-tenant-id")?.trim();
  if (!identity || !tenantId) return null;
  const actor = await dependencies.identity.authorizeTenant(identity.authUserId, tenantId);
  return actor && actor.role !== "viewer" ? actor : null;
}

export async function prepareOperationsMessageMediaHandler(
  request: Request,
  threadId: string,
  dependencies: OperationsCommunicationsDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const actor = await operationsActor(request, dependencies);
  if (!actor) return json(403, { error: { code: "NOT_AUTHORIZED", message: "Preparing driver message media is not permitted" } }, traceId);
  let payload: PrepareMessageMediaPayload;
  try {
    payload = await request.json() as PrepareMessageMediaPayload;
  } catch {
    return json(400, { error: { code: "VALIDATION_FAILED", message: "Request body must be JSON" } }, traceId);
  }
  if (!validPayload(payload)) return json(422, {
    error: { code: "VALIDATION_FAILED", message: "Message attachment metadata is invalid" },
  }, traceId);
  const result = await dependencies.communications.prepareOperationsMessageMedia(
    threadId, actor, dependencies.uuid(), payload,
  );
  if (result.status === "rejected") {
    const error = result.error as { code: Parameters<typeof statusForCommandError>[0]; message: string };
    return json(statusForCommandError(error.code), result, traceId);
  }
  return json(result.deduplicated ? 200 : 201, result, traceId);
}

export async function verifyOperationsMessageMediaHandler(
  request: Request,
  assetId: string,
  dependencies: OperationsCommunicationsDependencies,
): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const actor = await operationsActor(request, dependencies);
  if (!actor) return json(403, { error: { code: "NOT_AUTHORIZED", message: "Verifying driver message media is not permitted" } }, traceId);
  const result = await dependencies.communications.verifyOperationsMessageMedia(assetId, actor);
  if (result.status === "rejected") {
    const error = result.error as { code: Parameters<typeof statusForCommandError>[0]; message: string };
    return json(statusForCommandError(error.code), result, traceId);
  }
  return json(200, result, traceId);
}
