import type { OperationsDriverCapacityItem } from "@rounds/contracts";

type CurrentRound = {
  reference: string;
  state: "approved" | "loading" | "active";
  routePlan?: { finishAt?: string } | null;
};

export function projectCurrentRoundAvailability(
  round: CurrentRound,
  observedAt: Date,
): OperationsDriverCapacityItem["availability"] {
  const finishAt = round.routePlan?.finishAt;
  const finishMs = finishAt ? Date.parse(finishAt) : Number.NaN;
  const hasFutureFinish = Number.isFinite(finishMs) && finishMs > observedAt.getTime();
  const nextAvailable = hasFutureFinish && finishAt ? { nextAvailableAt: finishAt } : {};

  if (round.state === "active") return {
    state: "on_round",
    label: `On ${round.reference}`,
    ...nextAvailable,
    projectionBasis: hasFutureFinish
      ? "Projected from the saved approved route finish; live conditions may change it."
      : finishAt
        ? "The saved route finish has passed; current completion time is not available."
        : "Current Round is active; no saved route finish is available.",
  };

  return {
    state: "loading",
    label: `${round.reference} · ${round.state}`,
    ...nextAvailable,
    projectionBasis: hasFutureFinish
      ? "Projected from the saved approved route finish; execution has not completed."
      : "Assigned work blocks new capacity until the current Round is closed.",
  };
}
