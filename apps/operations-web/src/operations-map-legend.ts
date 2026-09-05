export type OperationsMapLegendEntry = {
  key: "own" | "action" | "unplanned" | "proposed-route" | "remaining-route" | "actual-trail";
  label: string;
  tone: "own" | "destination" | "route" | "live-route" | "trail";
};

type OperationsMapLegendInput = {
  mode: "live" | "plan";
  hasOwnDriverPositions: boolean;
  hasActionStops: boolean;
  hasUnplannedStops: boolean;
  hasProposedRoute: boolean;
  hasRemainingRoute?: boolean;
  hasActualTrail?: boolean;
};

/** Describe only evidence that the live map actually renders. */
export function operationsMapLegendEntries(input: OperationsMapLegendInput): OperationsMapLegendEntry[] {
  const entries: OperationsMapLegendEntry[] = [];

  if (input.hasOwnDriverPositions) {
    entries.push({ key: "own", label: "Own driver", tone: "own" });
  }
  if (input.mode === "live" && input.hasActionStops) {
    entries.push({ key: "action", label: "Action stop", tone: "destination" });
  }
  if (input.mode === "plan" && input.hasUnplannedStops) {
    entries.push({ key: "unplanned", label: "Unplanned stop", tone: "destination" });
  }
  if (input.mode === "plan" && input.hasProposedRoute) {
    entries.push({ key: "proposed-route", label: "Proposed route", tone: "route" });
  }
  if (input.mode === "live" && input.hasRemainingRoute) {
    entries.push({ key: "remaining-route", label: "Remaining route", tone: "live-route" });
  }
  if (input.mode === "live" && input.hasActualTrail) {
    entries.push({ key: "actual-trail", label: "Travelled trail", tone: "trail" });
  }

  return entries;
}
