import {
  ContractError,
  validateApplyPrePickupDeliveryEditCommand,
  validatePrePickupDeliveryEditRequest,
  type OperationsDeliveryItem,
  type OperationsRoundDetail,
  type PrePickupDeliveryEditPreview,
  type PrePickupDeliveryEditRequest,
  type PrePickupDeliveryEditSnapshot,
  type PrePickupDeliveryManifestItem,
  type PlanningRouteSnapshot,
} from "@rounds/contracts";
import { bearerToken, json, statusForCommandError } from "./http.js";
import { routeSnapshot } from "./planning-route-service.js";
import { RoutingProviderError } from "./routing-provider.js";
import type { ActorContext, PrePickupDeliveryEditDependencies } from "./types.js";

async function authorize(request: Request, dependencies: PrePickupDeliveryEditDependencies, traceId: string) {
  const token = bearerToken(request);
  if (!token) return { response: json(401, { error: { code: "NOT_AUTHENTICATED", message: "Bearer token required" } }, traceId) };
  const tenantId = request.headers.get("x-rounds-tenant-id")?.trim();
  if (!tenantId) return { response: json(400, { error: { code: "VALIDATION_FAILED", message: "x-rounds-tenant-id header is required" } }, traceId) };
  const identity = await dependencies.identity.authenticate(token);
  if (!identity) return { response: json(401, { error: { code: "NOT_AUTHENTICATED", message: "Session is invalid" } }, traceId) };
  const actor = await dependencies.identity.authorizeTenant(identity.authUserId, tenantId);
  if (!actor || !["tenant_owner", "operations_admin", "dispatcher"].includes(actor.role)) {
    return { response: json(403, { error: { code: "NOT_AUTHORIZED", message: "Delivery editing is not permitted" } }, traceId) };
  }
  return { actor };
}

async function requestBody(request: Request): Promise<PrePickupDeliveryEditRequest> {
  const payload = await request.json() as PrePickupDeliveryEditRequest;
  validatePrePickupDeliveryEditRequest(payload);
  return payload;
}

function optional(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}

function normalizeItems(items: PrePickupDeliveryManifestItem[]): PrePickupDeliveryManifestItem[] {
  return items.map((item, index) => {
    const cargoClass = optional(item.cargoClass);
    const handlingNote = optional(item.handlingNote);
    return {
      lineNumber: index + 1,
      description: item.description.trim(),
      quantity: item.quantity,
      ...(cargoClass ? { cargoClass } : {}),
      ...(handlingNote ? { handlingNote } : {}),
    };
  });
}

function snapshot(item: OperationsDeliveryItem): PrePickupDeliveryEditSnapshot {
  return {
    recipientName: item.recipientName,
    recipientPhone: item.recipientPhone,
    rawAddress: item.rawAddress,
    latitude: item.coordinate?.latitude ?? 0,
    longitude: item.coordinate?.longitude ?? 0,
    ...(item.accessNote ? { accessNote: item.accessNote } : {}),
    ...(item.deliveryNote ? { deliveryNote: item.deliveryNote } : {}),
    windowStart: item.promise.windowStart,
    windowEnd: item.promise.windowEnd,
    manifestItems: normalizeItems(item.manifest.items),
  };
}

function applyChanges(before: PrePickupDeliveryEditSnapshot, changes: PrePickupDeliveryEditRequest["changes"]): PrePickupDeliveryEditSnapshot {
  const accessNote = changes.accessNote !== undefined ? optional(changes.accessNote) : before.accessNote;
  const deliveryNote = changes.deliveryNote !== undefined ? optional(changes.deliveryNote) : before.deliveryNote;
  return {
    recipientName: changes.recipientName?.trim() ?? before.recipientName,
    recipientPhone: changes.recipientPhone?.trim() ?? before.recipientPhone,
    rawAddress: changes.rawAddress?.trim() ?? before.rawAddress,
    latitude: changes.latitude ?? before.latitude,
    longitude: changes.longitude ?? before.longitude,
    ...(accessNote ? { accessNote } : {}),
    ...(deliveryNote ? { deliveryNote } : {}),
    windowStart: changes.windowStart ?? before.windowStart,
    windowEnd: changes.windowEnd ?? before.windowEnd,
    manifestItems: normalizeItems(changes.manifestItems ?? before.manifestItems),
  };
}

const scalarFields = ["recipientName", "recipientPhone", "rawAddress", "latitude", "longitude", "accessNote", "deliveryNote"] as const;

function changedFields(before: PrePickupDeliveryEditSnapshot, after: PrePickupDeliveryEditSnapshot): string[] {
  const changed: string[] = scalarFields.filter((field) => (before[field] ?? "") !== (after[field] ?? ""));
  if (Date.parse(before.windowStart) !== Date.parse(after.windowStart)) changed.push("windowStart");
  if (Date.parse(before.windowEnd) !== Date.parse(after.windowEnd)) changed.push("windowEnd");
  if (JSON.stringify(before.manifestItems) !== JSON.stringify(after.manifestItems)) changed.push("manifestItems");
  return changed;
}

function cargoRequirements(items: PrePickupDeliveryManifestItem[]) {
  const grouped = new Map<string, number>();
  for (const item of items) {
    const code = item.cargoClass?.trim().toLowerCase() || "unclassified";
    grouped.set(code, (grouped.get(code) ?? 0) + item.quantity);
  }
  return [...grouped.entries()].map(([cargoClassCode, quantity]) => ({
    cargoClassCode,
    displayName: cargoClassCode === "unclassified" ? "Unclassified cargo" : cargoClassCode,
    quantity,
    classificationStatus: cargoClassCode === "unclassified" ? "unclassified" as const : "classified" as const,
  }));
}

async function calculate(
  payload: PrePickupDeliveryEditRequest,
  dependencies: PrePickupDeliveryEditDependencies,
  actor: ActorContext,
  now: Date,
): Promise<PrePickupDeliveryEditPreview & { item: OperationsDeliveryItem; detail?: OperationsRoundDetail; committedRoutePlan?: PlanningRouteSnapshot }> {
  const projection = await dependencies.deliveries.getOperationsDeliveries(actor, now);
  const item = projection.deliveries.find((delivery) => delivery.deliveryId === payload.deliveryId);
  if (!item) throw new Error("Delivery was not found");
  const reasons: string[] = [];
  if (item.version !== payload.expectedDeliveryVersion || item.stop.version !== payload.expectedStopVersion || item.stop.destinationVersion !== payload.expectedDestinationVersion || item.manifest.version !== payload.expectedManifestVersion) {
    reasons.push("Delivery changed. Refresh before reviewing the edit again.");
  }
  if (item.manifest.state !== "draft") reasons.push("The physical manifest is locked because pickup custody has transferred.");
  if (!["draft", "unplanned", "planned", "assigned", "pickup_pending"].includes(item.state)) reasons.push("This delivery is past the pre-pickup editing boundary.");
  if (["active", "arrived", "completed", "exception", "cancelled"].includes(item.stop.state)) reasons.push("This Stop cannot use the pre-pickup editing workflow.");
  if (!item.coordinate) reasons.push("Set a verified delivery pin before editing this delivery.");
  if (payload.changes.rawAddress !== undefined && payload.changes.rawAddress.trim() !== item.rawAddress && payload.changes.latitude === undefined) {
    reasons.push("Changing the address requires confirming its map pin in the same edit.");
  }

  const before = snapshot(item);
  const after = applyChanges(before, payload.changes);
  const fields = changedFields(before, after);
  if (!fields.length) reasons.push("Nothing changed.");

  let detail: OperationsRoundDetail | undefined;
  let routeAfter;
  let distanceDeltaMeters: number | undefined;
  let durationDeltaSeconds: number | undefined;
  let finishBefore: string | undefined;
  let finishAfter: string | undefined;
  let promiseStatus: "safe" | "early" | "late" | undefined;
  let capacityStatus: "fits" | "blocked" | "review_required" | undefined;
  let committedRoutePlan: PlanningRouteSnapshot | undefined;

  if (item.round) {
    detail = await dependencies.deliveries.getOperationsRoundDetail(item.round.id, actor, now) ?? undefined;
    const stop = detail?.stops.find((candidate) => candidate.stopId === item.stop.id);
    if (!detail || !stop) reasons.push("The assigned Round or Stop no longer exists.");
    else {
      if (payload.expectedRoundVersion === undefined || payload.expectedRoundVersion !== detail.version || item.round.version !== detail.version) reasons.push("Round changed. Refresh before reviewing the edit again.");
      if (!["proposed", "approved", "loading"].includes(detail.state)) reasons.push("Assigned delivery edits are only available before the Round becomes active.");
      if (stop.pickupConfirmed || stop.manifest.state !== "draft") reasons.push("Pickup custody already transferred for this Stop.");
      if (stop.openExceptionCount) reasons.push("Resolve the open Stop exception before editing the delivery.");
      if (!detail.routePlan) reasons.push("The assigned Round has no authoritative route plan.");
      if (!reasons.length) {
        const currentRoute = detail.routePlan!;
        const routeAffecting = fields.some((field) => ["rawAddress", "latitude", "longitude", "windowStart", "windowEnd", "manifestItems"].includes(field));
        if (routeAffecting) {
          if (!dependencies.routes.previewAssignedChange) throw new Error("Assigned Round recalculation is unavailable");
          const stopIds = [...detail.stops].sort((a, b) => a.sequence - b.sequence).map((candidate) => candidate.stopId);
          routeAfter = await dependencies.routes.previewAssignedChange(
            actor,
            [detail.id],
            { serviceDate: detail.serviceDate, driverId: detail.driver.id, stopIds },
            now,
            {
              stopId: item.stop.id,
              coordinate: { latitude: after.latitude, longitude: after.longitude },
              windowStart: after.windowStart,
              windowEnd: after.windowEnd,
              cargoRequirements: cargoRequirements(after.manifestItems),
            },
          );
          if (routeAfter.status === "blocked") reasons.push(...routeAfter.blockingReasons);
          const afterStop = routeAfter.stops.find((candidate) => candidate.stopId === item.stop.id);
          distanceDeltaMeters = routeAfter.distanceMeters - currentRoute.distanceMeters;
          durationDeltaSeconds = routeAfter.durationSeconds - currentRoute.durationSeconds;
          finishBefore = currentRoute.finishAt;
          finishAfter = routeAfter.finishAt;
          promiseStatus = afterStop?.promiseStatus;
          capacityStatus = routeAfter.capacity.status;
          committedRoutePlan = routeSnapshot(routeAfter);
        } else {
          committedRoutePlan = currentRoute;
          capacityStatus = currentRoute.capacity.status;
          promiseStatus = currentRoute.stops.find((candidate) => candidate.stopId === item.stop.id)?.promiseStatus;
        }
      }
    }
  } else if (payload.expectedRoundVersion !== undefined) reasons.push("Delivery is no longer assigned to a Round.");

  return {
    tenantId: actor.tenantId,
    calculatedAt: now.toISOString(),
    deliveryId: item.deliveryId,
    stopId: item.stop.id,
    ...(item.round ? { roundId: item.round.id } : {}),
    applicable: reasons.length === 0,
    blockingReasons: [...new Set(reasons)],
    changedFields: fields,
    before,
    after,
    impact: {
      assignment: item.round ? "assigned" : "unplanned",
      routeRecalculated: Boolean(item.round && routeAfter),
      ...(distanceDeltaMeters !== undefined ? { distanceDeltaMeters } : {}),
      ...(durationDeltaSeconds !== undefined ? { durationDeltaSeconds } : {}),
      ...(finishBefore ? { finishBefore } : {}),
      ...(finishAfter ? { finishAfter } : {}),
      ...(promiseStatus ? { promiseStatus } : {}),
      ...(capacityStatus ? { capacityStatus } : {}),
      buyerUpdatedWithRecipient: item.buyerSameAsRecipient && fields.some((field) => field === "recipientName" || field === "recipientPhone"),
    },
    ...(routeAfter ? { routeAfter } : {}),
    item,
    ...(detail ? { detail } : {}),
    ...(committedRoutePlan ? { committedRoutePlan } : {}),
  };
}

function publicPreview(preview: Awaited<ReturnType<typeof calculate>>): PrePickupDeliveryEditPreview {
  const { item: _item, detail: _detail, committedRoutePlan: _committedRoutePlan, ...result } = preview;
  return result;
}

export async function prePickupDeliveryEditPreviewHandler(request: Request, dependencies: PrePickupDeliveryEditDependencies): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const authorized = await authorize(request, dependencies, traceId);
  if (authorized.response) return authorized.response;
  let payload;
  try { payload = await requestBody(request); }
  catch (error) { return json(422, { error: { code: "VALIDATION_FAILED", message: error instanceof ContractError ? error.message : "Request body is invalid" } }, traceId); }
  try { return json(200, publicPreview(await calculate(payload, dependencies, authorized.actor!, dependencies.now())), traceId); }
  catch (error) {
    if (error instanceof RoutingProviderError) return json(503, { error: { code: "PROVIDER_UNAVAILABLE", message: error.message } }, traceId);
    return json(409, { error: { code: "INVALID_STATE", message: error instanceof Error ? error.message : "Delivery edit cannot be evaluated" } }, traceId);
  }
}

export async function applyPrePickupDeliveryEditHandler(request: Request, dependencies: PrePickupDeliveryEditDependencies): Promise<Response> {
  const traceId = request.headers.get("x-trace-id")?.trim() || dependencies.uuid();
  const authorized = await authorize(request, dependencies, traceId);
  if (authorized.response) return authorized.response;
  const idempotencyKey = request.headers.get("idempotency-key")?.trim();
  if (!idempotencyKey) return json(400, { error: { code: "VALIDATION_FAILED", message: "idempotency-key header is required" } }, traceId);
  let payload;
  try { payload = await requestBody(request); }
  catch (error) { return json(422, { error: { code: "VALIDATION_FAILED", message: error instanceof ContractError ? error.message : "Request body is invalid" } }, traceId); }
  try {
    const preview = await calculate(payload, dependencies, authorized.actor!, dependencies.now());
    if (!preview.applicable || (preview.item.round && !preview.committedRoutePlan)) return json(409, { error: { code: "INVALID_STATE", message: preview.blockingReasons[0] ?? "Delivery edit is blocked", preview: publicPreview(preview) } }, traceId);
    const command = {
      schemaVersion: 1 as const,
      commandType: "delivery.edit_before_pickup" as const,
      commandId: dependencies.uuid(),
      traceId,
      idempotencyKey,
      tenantId: authorized.actor!.tenantId,
      aggregateId: preview.item.deliveryId,
      expectedVersion: payload.expectedDeliveryVersion,
      occurredFromDeviceAt: dependencies.now().toISOString(),
      payload: {
        ...payload,
        stopId: preview.item.stop.id,
        manifestId: preview.item.manifest.id,
        ...(preview.item.round ? { roundId: preview.item.round.id } : {}),
        before: preview.before,
        after: preview.after,
        changedFields: preview.changedFields,
        impact: preview.impact,
        ...(preview.committedRoutePlan ? { routePlan: preview.committedRoutePlan } : {}),
      },
    };
    validateApplyPrePickupDeliveryEditCommand(command);
    const result = await dependencies.deliveries.applyPrePickupDeliveryEdit(command, authorized.actor!);
    if (result.status === "rejected") return json(statusForCommandError(result.error.code), result, traceId);
    return json(200, result, traceId);
  } catch (error) {
    if (error instanceof RoutingProviderError) return json(503, { error: { code: "PROVIDER_UNAVAILABLE", message: error.message } }, traceId);
    return json(409, { error: { code: "INVALID_STATE", message: error instanceof Error ? error.message : "Delivery edit cannot be committed" } }, traceId);
  }
}
