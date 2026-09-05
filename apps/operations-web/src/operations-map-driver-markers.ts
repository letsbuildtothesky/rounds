import type { OperationsRoundSummary, RoundState } from "@rounds/contracts";

export type OperationsMapDriverMarker = {
  round: OperationsRoundSummary;
  roundIds: string[];
  position: NonNullable<OperationsRoundSummary["currentPosition"]>;
};

const statePriority: Record<RoundState, number> = {
  active: 6,
  loading: 5,
  approved: 4,
  proposed: 3,
  complete: 2,
  cancelled: 1,
};

function preferredRound(current: OperationsRoundSummary, candidate: OperationsRoundSummary): OperationsRoundSummary {
  const stateDifference = statePriority[candidate.state] - statePriority[current.state];
  if (stateDifference !== 0) return stateDifference > 0 ? candidate : current;
  if (candidate.serviceDate !== current.serviceDate) return candidate.serviceDate < current.serviceDate ? candidate : current;
  return candidate.reference.localeCompare(current.reference, undefined, { numeric: true }) < 0 ? candidate : current;
}

/** One hot physical position becomes one own-driver marker, regardless of how many Rounds reference that driver. */
export function operationsMapDriverMarkers(rounds: OperationsRoundSummary[]): OperationsMapDriverMarker[] {
  const byDriver = new Map<string, OperationsMapDriverMarker>();

  for (const round of rounds) {
    if (!round.currentPosition) continue;
    const existing = byDriver.get(round.driverId);
    if (!existing) {
      byDriver.set(round.driverId, { round, roundIds: [round.id], position: round.currentPosition });
      continue;
    }

    const existingTime = Date.parse(existing.position.capturedAt);
    const candidateTime = Date.parse(round.currentPosition.capturedAt);
    byDriver.set(round.driverId, {
      round: preferredRound(existing.round, round),
      roundIds: [...existing.roundIds, round.id],
      position: Number.isFinite(candidateTime) && (!Number.isFinite(existingTime) || candidateTime > existingTime)
        ? round.currentPosition
        : existing.position,
    });
  }

  return [...byDriver.values()];
}
