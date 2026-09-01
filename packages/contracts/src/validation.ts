import type { CreateDeliveryCommand, CreateDeliveryPayload } from "./delivery.js";
import type { LocationBatch, PositionSample } from "./location.js";
import type { PlanRoundCommand, PlanRoundPayload } from "./round.js";

export class ContractError extends Error {}

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
