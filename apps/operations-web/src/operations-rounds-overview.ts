import type { OperationsRoundDetail, OperationsRoundSummary } from "@rounds/contracts";

export type OperationsRoundOverviewItem = {
  summary: OperationsRoundSummary;
  detail?: OperationsRoundDetail;
};

export type OperationsRoundOverviewGroups = {
  active: OperationsRoundOverviewItem[];
  upcoming: OperationsRoundOverviewItem[];
};

export function groupOperationsRounds(
  rounds: OperationsRoundSummary[],
  details: ReadonlyMap<string, OperationsRoundDetail> = new Map(),
): OperationsRoundOverviewGroups {
  const items = rounds.map((summary) => ({ summary, detail: details.get(summary.id) }));
  return {
    active: items.filter(({ summary }) => summary.state === "active" || summary.state === "loading"),
    upcoming: items.filter(({ summary }) => summary.state === "approved"),
  };
}

export function roundCapacityLabel(detail?: OperationsRoundDetail): string {
  const percentages = detail?.routePlan?.capacity?.dimensions
    .map((dimension) => dimension.utilizationPercent)
    .filter((value): value is number => value != null && Number.isFinite(value));
  if (percentages?.length) return `${Math.round(Math.max(...percentages))}% load`;
  if (detail?.routePlan?.capacity?.status === "fits") return "Capacity fits";
  if (detail?.routePlan?.capacity?.status === "review_required") return "Capacity review";
  if (detail?.routePlan?.capacity?.status === "blocked") return "Capacity blocked";
  return "Capacity not measured";
}

export function roundVehicleLabel(detail?: OperationsRoundDetail): string {
  if (!detail) return "Vehicle not loaded";
  return detail.driver.vehicleLabel ?? detail.driver.vehiclePlate ?? "Vehicle not recorded";
}
