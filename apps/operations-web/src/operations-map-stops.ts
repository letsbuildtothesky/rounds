import type { OperationsMapStop, OperationsRoundSummary } from "@rounds/contracts";

export type OperationsMapStopMarker = {
  stop: OperationsMapStop;
  round: OperationsRoundSummary;
  emphasis: "current" | "future" | "done";
};

const terminalStopStates = new Set(["completed", "cancelled"]);

/** Derive visual emphasis only from authoritative Round order and Stop state. */
export function operationsMapStopMarkers(
  stops: OperationsMapStop[],
  rounds: OperationsRoundSummary[],
): OperationsMapStopMarker[] {
  const roundById = new Map(rounds.map((round) => [round.id, round]));
  const currentStopByRound = new Map<string, string>();

  for (const round of rounds) {
    if (round.state !== "active") continue;
    const current = stops
      .filter((stop) => stop.roundId === round.id && !terminalStopStates.has(stop.stopState))
      .sort((left, right) => left.sequence - right.sequence || left.stopId.localeCompare(right.stopId))[0];
    if (current) currentStopByRound.set(round.id, current.stopId);
  }

  return stops.flatMap((stop) => {
    const round = roundById.get(stop.roundId);
    if (!round) return [];
    const emphasis = terminalStopStates.has(stop.stopState)
      ? "done" as const
      : currentStopByRound.get(stop.roundId) === stop.stopId
        ? "current" as const
        : "future" as const;
    return [{ stop, round, emphasis }];
  }).sort((left, right) => left.round.reference.localeCompare(right.round.reference)
    || left.stop.sequence - right.stop.sequence
    || left.stop.stopId.localeCompare(right.stop.stopId));
}
