import {
  validateLocationBatch,
  type FleetPosition,
  type LocationBatch,
} from "@rounds/contracts";
import { classifyFreshness } from "./freshness.js";
import { SequenceWatermark } from "./watermark.js";

export type AuthContext = {
  tenantId: string;
  driverId: string;
};

export type IngestResult = {
  ingestWatermark: number;
  acceptedSamples: number;
  duplicateSamples: number;
  currentPosition: FleetPosition;
};

export interface LocationRepository {
  loadWatermark(driverId: string, sessionId: string): Promise<number>;
  insertAccepted(batch: LocationBatch, acceptedSequences: readonly number[]): Promise<void>;
  saveWatermark(driverId: string, sessionId: string, watermark: number): Promise<void>;
  upsertCurrent(tenantId: string, position: FleetPosition, watermark: number): Promise<void>;
}
export class AuthorizationError extends Error {}

export class LocationIngestService {
  constructor(
    private readonly repository: LocationRepository,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async ingest(auth: AuthContext, batch: LocationBatch): Promise<IngestResult> {
    validateLocationBatch(batch);
    if (auth.tenantId !== batch.tenantId || auth.driverId !== batch.driverId) {
      throw new AuthorizationError("location context does not match authenticated driver");
    }

    const initialWatermark = await this.repository.loadWatermark(
      batch.driverId,
      batch.sessionId,
    );
    const watermark = new SequenceWatermark(initialWatermark);
    const decision = watermark.ingest(batch.samples.map((sample) => sample.sequence));
    await this.repository.insertAccepted(batch, decision.acceptedSequences);
    await this.repository.saveWatermark(batch.driverId, batch.sessionId, decision.highestContiguousSequence);

    const latest = batch.samples.at(-1)!;
    const currentPosition: FleetPosition = {
      driverId: batch.driverId,
      latitude: latest.latitude,
      longitude: latest.longitude,
      sourceAt: latest.capturedAt,
      accuracyMeters: latest.accuracyMeters,
      source: latest.source,
      freshness: classifyFreshness(new Date(latest.capturedAt), this.now()),
    };
    await this.repository.upsertCurrent(
      batch.tenantId,
      currentPosition,
      decision.highestContiguousSequence,
    );

    return {
      ingestWatermark: decision.highestContiguousSequence,
      acceptedSamples: decision.acceptedSequences.length,
      duplicateSamples: decision.duplicateSequences.length,
      currentPosition,
    };
  }
}
