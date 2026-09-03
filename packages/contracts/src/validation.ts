import type { CreateDeliveryCommand, CreateDeliveryPayload } from "./delivery.js";
import type {
  SendDriverMessageCommand,
  SendDriverMessagePayload,
  SendOperationsMessageCommand,
  SendOperationsMessagePayload,
} from "./communications.js";
import type { LocationBatch, PositionSample } from "./location.js";
import { deliveryProblemCategories, pickupProblemCategories, podHandoffTypes } from "./round.js";
import type {
  ConfirmPickupCommand,
  ConfirmPickupPayload,
  ConfirmStopArrivalCommand,
  ConfirmStopArrivalPayload,
  CompleteStopPodCommand,
  CompleteStopPodPayload,
  PreparePodMediaPayload,
  PlanRoundCommand,
  PlanRoundPayload,
  PlanningRoutePreviewRequest,
  ReportPickupProblemCommand,
  ReportPickupProblemPayload,
  ReportDeliveryProblemCommand,
  ReportDeliveryProblemPayload,
} from "./round.js";
import {
  operationsExceptionResolutions,
  type ConfirmDeliveryReturnCommand,
  type ConfirmDeliveryReturnPayload,
  type ResolveOperationsExceptionCommand,
  type ResolveOperationsExceptionPayload,
  type SetDriverRecurringScheduleCommand,
  type SetDriverRecurringSchedulePayload,
  type SetDriverShiftExceptionCommand,
  type SetDriverShiftExceptionPayload,
  type ClearDriverShiftExceptionCommand,
} from "./operations.js";

export class ContractError extends Error {}

export function validateSetDriverRecurringSchedulePayload(payload: SetDriverRecurringSchedulePayload): void {
  if (!Array.isArray(payload.weekdays) || payload.weekdays.length < 1 || payload.weekdays.length > 7) {
    throw new ContractError("weekdays must contain one to seven ISO weekdays");
  }
  const distinct = new Set(payload.weekdays);
  if (distinct.size !== payload.weekdays.length || payload.weekdays.some((day) => !Number.isInteger(day) || day < 1 || day > 7)) {
    throw new ContractError("weekdays must contain unique integers from 1 to 7");
  }
  if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(payload.startLocal) || !/^([01]\d|2[0-3]):[0-5]\d$/.test(payload.endLocal)) {
    throw new ContractError("schedule times must use HH:mm");
  }
  if (payload.startLocal === payload.endLocal) throw new ContractError("schedule start and end must differ");
  assertUuid(payload.vehicleProfileId, "vehicleProfileId");
  if (payload.note !== undefined && payload.note.trim().length > 500) throw new ContractError("note exceeds 500 characters");
}

export function validateSetDriverRecurringScheduleCommand(command: SetDriverRecurringScheduleCommand): void {
  if (command.schemaVersion !== 1 || command.commandType !== "operations.set_driver_recurring_schedule") {
    throw new ContractError("unsupported SetDriverRecurringSchedule command envelope");
  }
  assertUuid(command.commandId, "commandId");
  assertUuid(command.traceId, "traceId");
  assertUuid(command.tenantId, "tenantId");
  assertUuid(command.aggregateId, "aggregateId");
  assertNonEmpty(command.idempotencyKey, "idempotencyKey");
  if (command.idempotencyKey.length > 200) throw new ContractError("idempotencyKey exceeds 200 characters");
  if (!Number.isInteger(command.expectedVersion) || command.expectedVersion < 0) {
    throw new ContractError("SetDriverRecurringSchedule expectedVersion must be a non-negative integer");
  }
  validateSetDriverRecurringSchedulePayload(command.payload);
}

export function validateSetDriverShiftExceptionPayload(payload: SetDriverShiftExceptionPayload): void {
  const parsedServiceDate = new Date(`${payload.serviceDate}T00:00:00Z`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(payload.serviceDate)
    || Number.isNaN(parsedServiceDate.valueOf())
    || parsedServiceDate.toISOString().slice(0, 10) !== payload.serviceDate) {
    throw new ContractError("serviceDate must be a real YYYY-MM-DD date");
  }
  if (payload.kind !== "shift" && payload.kind !== "off") throw new ContractError("exception kind must be shift or off");
  if (payload.kind === "off") {
    if (payload.startLocal !== undefined || payload.endLocal !== undefined || payload.vehicleProfileId !== undefined) {
      throw new ContractError("an off-day exception cannot include shift times or vehicle profile");
    }
  } else {
    if (!payload.startLocal || !payload.endLocal || !payload.vehicleProfileId) {
      throw new ContractError("a shift exception requires times and vehicle profile");
    }
    if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(payload.startLocal) || !/^([01]\d|2[0-3]):[0-5]\d$/.test(payload.endLocal)) {
      throw new ContractError("exception times must use HH:mm");
    }
    if (payload.startLocal === payload.endLocal) throw new ContractError("exception start and end must differ");
    assertUuid(payload.vehicleProfileId, "vehicleProfileId");
  }
  if (payload.note !== undefined && payload.note.trim().length > 500) throw new ContractError("note exceeds 500 characters");
}

export function validateSetDriverShiftExceptionCommand(command: SetDriverShiftExceptionCommand): void {
  if (command.schemaVersion !== 1 || command.commandType !== "operations.set_driver_shift_exception") {
    throw new ContractError("unsupported SetDriverShiftException command envelope");
  }
  assertUuid(command.commandId, "commandId");
  assertUuid(command.traceId, "traceId");
  assertUuid(command.tenantId, "tenantId");
  assertUuid(command.aggregateId, "aggregateId");
  assertNonEmpty(command.idempotencyKey, "idempotencyKey");
  if (command.idempotencyKey.length > 200) throw new ContractError("idempotencyKey exceeds 200 characters");
  if (!Number.isInteger(command.expectedVersion) || command.expectedVersion < 0) {
    throw new ContractError("SetDriverShiftException expectedVersion must be a non-negative integer");
  }
  validateSetDriverShiftExceptionPayload(command.payload);
}

export function validateClearDriverShiftExceptionCommand(command: ClearDriverShiftExceptionCommand): void {
  if (command.schemaVersion !== 1 || command.commandType !== "operations.clear_driver_shift_exception") throw new ContractError("unsupported ClearDriverShiftException command envelope");
  assertUuid(command.commandId, "commandId"); assertUuid(command.traceId, "traceId"); assertUuid(command.tenantId, "tenantId"); assertUuid(command.aggregateId, "aggregateId");
  assertNonEmpty(command.idempotencyKey, "idempotencyKey");
  if (command.idempotencyKey.length > 200) throw new ContractError("idempotencyKey exceeds 200 characters");
  if (!Number.isInteger(command.expectedVersion) || command.expectedVersion < 1) throw new ContractError("ClearDriverShiftException expectedVersion must be a positive integer");
  const parsed = new Date(`${command.payload.serviceDate}T00:00:00Z`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(command.payload.serviceDate) || Number.isNaN(parsed.valueOf()) || parsed.toISOString().slice(0, 10) !== command.payload.serviceDate) throw new ContractError("serviceDate must be a real YYYY-MM-DD date");
}

export function validateResolveOperationsExceptionPayload(payload: ResolveOperationsExceptionPayload): void {
  assertUuid(payload.exceptionId, "exceptionId");
  if (!operationsExceptionResolutions.includes(payload.resolution)) throw new ContractError("resolution is not supported");
  assertNonEmpty(payload.note, "note");
  if (payload.note.trim().length > 500) throw new ContractError("note exceeds 500 characters");
}

export function validateResolveOperationsExceptionCommand(command: ResolveOperationsExceptionCommand): void {
  if (command.schemaVersion !== 1 || command.commandType !== "operations.resolve_exception") throw new ContractError("unsupported ResolveOperationsException command envelope");
  assertUuid(command.commandId, "commandId");
  assertUuid(command.traceId, "traceId");
  assertUuid(command.tenantId, "tenantId");
  assertUuid(command.aggregateId, "aggregateId");
  assertNonEmpty(command.idempotencyKey, "idempotencyKey");
  if (command.idempotencyKey.length > 200) throw new ContractError("idempotencyKey exceeds 200 characters");
  if (!Number.isInteger(command.expectedVersion) || command.expectedVersion < 1) throw new ContractError("ResolveOperationsException expectedVersion must be a positive integer");
  validateResolveOperationsExceptionPayload(command.payload);
}

export function validateConfirmDeliveryReturnPayload(payload: ConfirmDeliveryReturnPayload): void {
  assertUuid(payload.exceptionId, "exceptionId");
  assertNonEmpty(payload.note, "note");
  if (payload.note.trim().length > 500) throw new ContractError("note exceeds 500 characters");
}

export function validateConfirmDeliveryReturnCommand(command: ConfirmDeliveryReturnCommand): void {
  if (command.schemaVersion !== 1 || command.commandType !== "operations.confirm_delivery_return") throw new ContractError("unsupported ConfirmDeliveryReturn command envelope");
  assertUuid(command.commandId, "commandId");
  assertUuid(command.traceId, "traceId");
  assertUuid(command.tenantId, "tenantId");
  assertUuid(command.aggregateId, "aggregateId");
  assertNonEmpty(command.idempotencyKey, "idempotencyKey");
  if (command.idempotencyKey.length > 200) throw new ContractError("idempotencyKey exceeds 200 characters");
  if (!Number.isInteger(command.expectedVersion) || command.expectedVersion < 1) throw new ContractError("ConfirmDeliveryReturn expectedVersion must be a positive integer");
  validateConfirmDeliveryReturnPayload(command.payload);
}

export function validateSendDriverMessagePayload(payload: SendDriverMessagePayload): void {
  assertNonEmpty(payload.body, "body");
  if (payload.body.trim().length > 2000) throw new ContractError("body exceeds 2000 characters");
}

export function validateSendDriverMessageCommand(command: SendDriverMessageCommand): void {
  if (command.schemaVersion !== 1 || command.commandType !== "thread.send_message") {
    throw new ContractError("unsupported SendDriverMessage command envelope");
  }
  assertUuid(command.commandId, "commandId");
  assertUuid(command.traceId, "traceId");
  assertUuid(command.tenantId, "tenantId");
  assertUuid(command.aggregateId, "aggregateId");
  assertNonEmpty(command.idempotencyKey, "idempotencyKey");
  if (command.idempotencyKey.length > 200) throw new ContractError("idempotencyKey exceeds 200 characters");
  if (!Number.isInteger(command.expectedVersion) || command.expectedVersion < 1) {
    throw new ContractError("SendDriverMessage expectedVersion must be a positive integer");
  }
  validateSendDriverMessagePayload(command.payload);
}

export function validateSendOperationsMessagePayload(payload: SendOperationsMessagePayload): void {
  validateSendDriverMessagePayload(payload);
}

export function validateSendOperationsMessageCommand(command: SendOperationsMessageCommand): void {
  if (command.schemaVersion !== 1 || command.commandType !== "thread.send_operations_message") {
    throw new ContractError("unsupported SendOperationsMessage command envelope");
  }
  assertUuid(command.commandId, "commandId");
  assertUuid(command.traceId, "traceId");
  assertUuid(command.tenantId, "tenantId");
  assertUuid(command.aggregateId, "aggregateId");
  assertNonEmpty(command.idempotencyKey, "idempotencyKey");
  if (command.idempotencyKey.length > 200) throw new ContractError("idempotencyKey exceeds 200 characters");
  if (!Number.isInteger(command.expectedVersion) || command.expectedVersion < 1) {
    throw new ContractError("SendOperationsMessage expectedVersion must be a positive integer");
  }
  validateSendOperationsMessagePayload(command.payload);
}

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function assertNonEmpty(value: string, field: string): void {
  if (value.trim().length === 0) throw new ContractError(`${field} is required`);
}

function assertUuid(value: string, field: string): void {
  if (!uuidPattern.test(value)) throw new ContractError(`${field} must be a UUID`);
}

function assertTimestamp(value: string, field: string): number {
  const parsed = Date.parse(value);
  if (!Number.isFinite(parsed)) throw new ContractError(`${field} must be an ISO timestamp`);
  return parsed;
}

function assertFinite(value: number, field: string): void {
  if (!Number.isFinite(value)) throw new ContractError(`${field} must be finite`);
}

export function validateSample(sample: PositionSample): void {
  if (!Number.isInteger(sample.sequence) || sample.sequence < 1) {
    throw new ContractError("sequence must be a positive integer");
  }
  assertFinite(sample.latitude, "latitude");
  assertFinite(sample.longitude, "longitude");
  assertFinite(sample.accuracyMeters, "accuracyMeters");
  if (sample.latitude < -90 || sample.latitude > 90) {
    throw new ContractError("latitude out of range");
  }
  if (sample.longitude < -180 || sample.longitude > 180) {
    throw new ContractError("longitude out of range");
  }
  if (sample.accuracyMeters < 0) {
    throw new ContractError("accuracyMeters must be non-negative");
  }
  if (!Number.isFinite(Date.parse(sample.capturedAt))) {
    throw new ContractError("capturedAt must be an ISO timestamp");
  }
}

export function validateLocationBatch(batch: LocationBatch): void {
  if (batch.schemaVersion !== 1) throw new ContractError("unsupported schemaVersion");
  if (batch.samples.length === 0) throw new ContractError("samples cannot be empty");
  if (batch.samples.length > 200) throw new ContractError("batch exceeds 200 samples");
  for (const sample of batch.samples) validateSample(sample);

  const sequences = batch.samples.map((sample) => sample.sequence);
  if (sequences[0] !== batch.firstSequence) {
    throw new ContractError("firstSequence does not match samples");
  }
  if (sequences.at(-1) !== batch.lastSequence) {
    throw new ContractError("lastSequence does not match samples");
  }
  for (let index = 1; index < sequences.length; index += 1) {
    if (sequences[index] !== sequences[index - 1]! + 1) {
      throw new ContractError("sample sequences must be contiguous");
    }
  }
}

export function validateCreateDeliveryPayload(payload: CreateDeliveryPayload): void {
  assertNonEmpty(payload.externalId, "externalId");
  assertNonEmpty(payload.serviceTimezone, "serviceTimezone");
  assertUuid(payload.pickupLocationId, "pickupLocationId");
  if (!/^\d{4}-\d{2}-\d{2}$/.test(payload.serviceDate)) {
    throw new ContractError("serviceDate must be YYYY-MM-DD");
  }

  assertNonEmpty(payload.recipient.name, "recipient.name");
  assertNonEmpty(payload.recipient.phone, "recipient.phone");
  assertNonEmpty(payload.recipient.rawAddress, "recipient.rawAddress");
  assertNonEmpty(payload.recipient.coordinate.provenance, "recipient.coordinate.provenance");
  assertFinite(payload.recipient.coordinate.latitude, "recipient.coordinate.latitude");
  assertFinite(payload.recipient.coordinate.longitude, "recipient.coordinate.longitude");
  if (payload.recipient.coordinate.latitude < -90 || payload.recipient.coordinate.latitude > 90) {
    throw new ContractError("recipient.coordinate.latitude out of range");
  }
  if (payload.recipient.coordinate.longitude < -180 || payload.recipient.coordinate.longitude > 180) {
    throw new ContractError("recipient.coordinate.longitude out of range");
  }

  if (!payload.buyer.sameAsRecipient) {
    assertNonEmpty(payload.buyer.name, "buyer.name");
    assertNonEmpty(payload.buyer.phone, "buyer.phone");
  }

  const start = assertTimestamp(payload.promise.windowStart, "promise.windowStart");
  const end = assertTimestamp(payload.promise.windowEnd, "promise.windowEnd");
  if (end <= start) throw new ContractError("promise window end must be after start");

  if (payload.manifest.items.length === 0) {
    throw new ContractError("manifest.items cannot be empty");
  }
  payload.manifest.items.forEach((item, index) => {
    assertNonEmpty(item.description, `manifest.items[${index}].description`);
    if (!Number.isInteger(item.quantity) || item.quantity <= 0) {
      throw new ContractError(`manifest.items[${index}].quantity must be a positive integer`);
    }
  });
}

export function validateCreateDeliveryCommand(command: CreateDeliveryCommand): void {
  if (command.schemaVersion !== 1 || command.commandType !== "delivery.create") {
    throw new ContractError("unsupported CreateDelivery command envelope");
  }
  assertUuid(command.commandId, "commandId");
  assertUuid(command.traceId, "traceId");
  assertUuid(command.tenantId, "tenantId");
  assertUuid(command.aggregateId, "aggregateId");
  assertNonEmpty(command.idempotencyKey, "idempotencyKey");
  if (command.idempotencyKey.length > 200) {
    throw new ContractError("idempotencyKey exceeds 200 characters");
  }
  if (command.expectedVersion !== 0) {
    throw new ContractError("CreateDelivery expectedVersion must be 0");
  }
  validateCreateDeliveryPayload(command.payload);
}

export function validatePlanRoundPayload(payload: PlanRoundPayload): void {
  assertNonEmpty(payload.reference, "reference");
  assertUuid(payload.driverId, "driverId");
  if (!/^\d{4}-\d{2}-\d{2}$/.test(payload.serviceDate)) {
    throw new ContractError("serviceDate must be YYYY-MM-DD");
  }
  if (payload.stopIds.length === 0) throw new ContractError("stopIds cannot be empty");
  if (new Set(payload.stopIds).size !== payload.stopIds.length) {
    throw new ContractError("stopIds cannot contain duplicates");
  }
  payload.stopIds.forEach((stopId, index) => assertUuid(stopId, `stopIds[${index}]`));
  if (!payload.routePlan || payload.routePlan.status !== "fits") {
    throw new ContractError("routePlan must be a server-calculated fit");
  }
  if (payload.routePlan.driverId !== payload.driverId || payload.routePlan.serviceDate !== payload.serviceDate) {
    throw new ContractError("routePlan driver and service date must match the Round");
  }
  if (JSON.stringify(payload.routePlan.stopIds) !== JSON.stringify(payload.stopIds)) {
    throw new ContractError("routePlan stop order must match stopIds");
  }
  if (!Number.isFinite(payload.routePlan.durationSeconds) || payload.routePlan.durationSeconds < 0) {
    throw new ContractError("routePlan durationSeconds must be non-negative");
  }
}

export function validatePlanningRoutePreviewRequest(payload: PlanningRoutePreviewRequest): void {
  assertUuid(payload.driverId, "driverId");
  if (!/^\d{4}-\d{2}-\d{2}$/.test(payload.serviceDate)) {
    throw new ContractError("serviceDate must be YYYY-MM-DD");
  }
  if (!Array.isArray(payload.stopIds) || payload.stopIds.length === 0) {
    throw new ContractError("stopIds cannot be empty");
  }
  if (new Set(payload.stopIds).size !== payload.stopIds.length) {
    throw new ContractError("stopIds cannot contain duplicates");
  }
  payload.stopIds.forEach((stopId, index) => assertUuid(stopId, `stopIds[${index}]`));
}

export function validatePlanRoundCommand(command: PlanRoundCommand): void {
  if (command.schemaVersion !== 1 || command.commandType !== "round.plan_and_approve") {
    throw new ContractError("unsupported PlanRound command envelope");
  }
  assertUuid(command.commandId, "commandId");
  assertUuid(command.traceId, "traceId");
  assertUuid(command.tenantId, "tenantId");
  assertUuid(command.aggregateId, "aggregateId");
  assertNonEmpty(command.idempotencyKey, "idempotencyKey");
  if (command.idempotencyKey.length > 200) {
    throw new ContractError("idempotencyKey exceeds 200 characters");
  }
  if (command.expectedVersion !== 0) {
    throw new ContractError("PlanRound expectedVersion must be 0");
  }
  validatePlanRoundPayload(command.payload);
}

export function validateConfirmPickupPayload(payload: ConfirmPickupPayload): void {
  if (payload.stops.length === 0) throw new ContractError("stops cannot be empty");
  if (new Set(payload.stops.map((stop) => stop.stopId)).size !== payload.stops.length) {
    throw new ContractError("stops cannot contain duplicate stopId values");
  }
  if (new Set(payload.stops.map((stop) => stop.manifestId)).size !== payload.stops.length) {
    throw new ContractError("stops cannot contain duplicate manifestId values");
  }
  payload.stops.forEach((stop, index) => {
    assertUuid(stop.stopId, `stops[${index}].stopId`);
    assertUuid(stop.manifestId, `stops[${index}].manifestId`);
    if (!Number.isInteger(stop.manifestVersion) || stop.manifestVersion < 1) {
      throw new ContractError(`stops[${index}].manifestVersion must be a positive integer`);
    }
    if (stop.confirmedLineNumbers.length === 0) {
      throw new ContractError(`stops[${index}].confirmedLineNumbers cannot be empty`);
    }
    if (new Set(stop.confirmedLineNumbers).size !== stop.confirmedLineNumbers.length) {
      throw new ContractError(`stops[${index}].confirmedLineNumbers cannot contain duplicates`);
    }
    stop.confirmedLineNumbers.forEach((lineNumber) => {
      if (!Number.isInteger(lineNumber) || lineNumber < 1) {
        throw new ContractError(`stops[${index}].confirmedLineNumbers must contain positive integers`);
      }
    });
  });
}

export function validateConfirmPickupCommand(command: ConfirmPickupCommand): void {
  if (command.schemaVersion !== 1 || command.commandType !== "round.confirm_pickup") {
    throw new ContractError("unsupported ConfirmPickup command envelope");
  }
  assertUuid(command.commandId, "commandId");
  assertUuid(command.traceId, "traceId");
  assertUuid(command.tenantId, "tenantId");
  assertUuid(command.aggregateId, "aggregateId");
  assertNonEmpty(command.idempotencyKey, "idempotencyKey");
  if (command.idempotencyKey.length > 200) {
    throw new ContractError("idempotencyKey exceeds 200 characters");
  }
  if (!Number.isInteger(command.expectedVersion) || command.expectedVersion < 1) {
    throw new ContractError("ConfirmPickup expectedVersion must be a positive integer");
  }
  validateConfirmPickupPayload(command.payload);
}

export function validateReportPickupProblemPayload(payload: ReportPickupProblemPayload): void {
  assertUuid(payload.manifestId, "manifestId");
  if (!Number.isInteger(payload.manifestVersion) || payload.manifestVersion < 1) {
    throw new ContractError("manifestVersion must be a positive integer");
  }
  if (!pickupProblemCategories.includes(payload.category)) {
    throw new ContractError("category is not a supported pickup problem");
  }
  if (payload.note !== undefined && payload.note.trim().length > 500) {
    throw new ContractError("note exceeds 500 characters");
  }
}

export function validateReportPickupProblemCommand(command: ReportPickupProblemCommand): void {
  if (command.schemaVersion !== 1 || command.commandType !== "stop.report_pickup_problem") {
    throw new ContractError("unsupported ReportPickupProblem command envelope");
  }
  validateStopCommandEnvelope(command, "ReportPickupProblem");
  validateReportPickupProblemPayload(command.payload);
}

export function validateReportDeliveryProblemPayload(payload: ReportDeliveryProblemPayload): void {
  assertUuid(payload.manifestId, "manifestId");
  assertUuid(payload.mediaAssetId, "mediaAssetId");
  if (!Number.isInteger(payload.manifestVersion) || payload.manifestVersion < 1) {
    throw new ContractError("manifestVersion must be a positive integer");
  }
  if (!deliveryProblemCategories.includes(payload.category)) {
    throw new ContractError("category is not a supported delivery problem");
  }
  if (payload.note !== undefined && payload.note.trim().length > 500) {
    throw new ContractError("note exceeds 500 characters");
  }
}

export function validateReportDeliveryProblemCommand(command: ReportDeliveryProblemCommand): void {
  if (command.schemaVersion !== 1 || command.commandType !== "stop.report_delivery_problem") {
    throw new ContractError("unsupported ReportDeliveryProblem command envelope");
  }
  validateStopCommandEnvelope(command, "ReportDeliveryProblem");
  validateReportDeliveryProblemPayload(command.payload);
}

export function validateConfirmStopArrivalPayload(payload: ConfirmStopArrivalPayload): void {
  if (payload.overrideReason !== undefined && payload.overrideReason.trim().length > 500) {
    throw new ContractError("overrideReason exceeds 500 characters");
  }
  if (!payload.position) return;
  assertFinite(payload.position.latitude, "position.latitude");
  assertFinite(payload.position.longitude, "position.longitude");
  assertFinite(payload.position.accuracyMeters, "position.accuracyMeters");
  if (payload.position.latitude < -90 || payload.position.latitude > 90) {
    throw new ContractError("position.latitude out of range");
  }
  if (payload.position.longitude < -180 || payload.position.longitude > 180) {
    throw new ContractError("position.longitude out of range");
  }
  if (payload.position.accuracyMeters < 0) {
    throw new ContractError("position.accuracyMeters must be non-negative");
  }
  if (!["google_nav", "rounds_os", "unknown"].includes(payload.position.source)) {
    throw new ContractError("position.source is unsupported");
  }
}

export function validateConfirmStopArrivalCommand(command: ConfirmStopArrivalCommand): void {
  if (command.schemaVersion !== 1 || command.commandType !== "stop.confirm_arrival") {
    throw new ContractError("unsupported ConfirmStopArrival command envelope");
  }
  validateStopCommandEnvelope(command, "ConfirmStopArrival");
  validateConfirmStopArrivalPayload(command.payload);
}

export function validatePreparePodMediaPayload(payload: PreparePodMediaPayload): void {
  if (!/^[0-9a-f]{64}$/.test(payload.sha256)) {
    throw new ContractError("sha256 must be a lowercase SHA-256 digest");
  }
  if (!Number.isInteger(payload.byteSize) || payload.byteSize < 1 || payload.byteSize > 6291456) {
    throw new ContractError("byteSize must be between 1 byte and 6 MiB");
  }
  if (!["image/jpeg", "image/png"].includes(payload.contentType)) {
    throw new ContractError("contentType must be image/jpeg or image/png");
  }
}

export function validateCompleteStopPodPayload(payload: CompleteStopPodPayload): void {
  assertUuid(payload.manifestId, "manifestId");
  assertUuid(payload.mediaAssetId, "mediaAssetId");
  if (!Number.isInteger(payload.manifestVersion) || payload.manifestVersion < 1) {
    throw new ContractError("manifestVersion must be a positive integer");
  }
  if (!payload.confirmedLineNumbers.length || new Set(payload.confirmedLineNumbers).size !== payload.confirmedLineNumbers.length) {
    throw new ContractError("confirmedLineNumbers must be non-empty and unique");
  }
  payload.confirmedLineNumbers.forEach((line) => {
    if (!Number.isInteger(line) || line < 1) throw new ContractError("confirmedLineNumbers must contain positive integers");
  });
  if (!podHandoffTypes.includes(payload.handoffType)) throw new ContractError("handoffType is unsupported");
  const receiverName = payload.receiverName?.trim();
  const relationship = payload.receiverRelationship?.trim();
  const location = payload.leftAtLocation?.trim();
  if (payload.handoffType === "recipient" && (!receiverName || relationship || location)) {
    throw new ContractError("recipient handoff requires receiverName only");
  }
  if (payload.handoffType === "someone_else" && (!receiverName || !relationship || location)) {
    throw new ContractError("someone_else handoff requires receiverName and receiverRelationship");
  }
  if (payload.handoffType === "left_at_location" && (receiverName || relationship || !location)) {
    throw new ContractError("left_at_location handoff requires leftAtLocation only");
  }
  if ((payload.note?.trim().length ?? 0) > 500) throw new ContractError("note exceeds 500 characters");
  if (payload.position) validateConfirmStopArrivalPayload({ position: payload.position });
}

export function validateCompleteStopPodCommand(command: CompleteStopPodCommand): void {
  if (command.schemaVersion !== 1 || command.commandType !== "stop.complete_pod") {
    throw new ContractError("unsupported CompleteStopPod command envelope");
  }
  validateStopCommandEnvelope(command, "CompleteStopPod");
  validateCompleteStopPodPayload(command.payload);
}

function validateStopCommandEnvelope(
  command: ReportPickupProblemCommand | ReportDeliveryProblemCommand | ConfirmStopArrivalCommand | CompleteStopPodCommand,
  name: string,
): void {
  assertUuid(command.commandId, "commandId");
  assertUuid(command.traceId, "traceId");
  assertUuid(command.tenantId, "tenantId");
  assertUuid(command.aggregateId, "aggregateId");
  assertNonEmpty(command.idempotencyKey, "idempotencyKey");
  if (command.idempotencyKey.length > 200) {
    throw new ContractError("idempotencyKey exceeds 200 characters");
  }
  if (!Number.isInteger(command.expectedVersion) || command.expectedVersion < 1) {
    throw new ContractError(`${name} expectedVersion must be a positive integer`);
  }
}
