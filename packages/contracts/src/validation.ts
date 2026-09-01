import type { LocationBatch, PositionSample } from "./location.js";

export class ContractError extends Error {}

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

