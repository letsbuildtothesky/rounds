import type {
  CapacityDimensionResult,
  CapacityEvaluation,
  CargoRequirement,
  VehicleCargoLimit,
} from "@rounds/contracts";

export type CapacityValidationInput = {
  stopCount: number;
  maxStopsPerDeparture: number;
  departurePattern: "multi_stop" | "return_after_every_delivery" | "return_after_round" | "return_when_capacity_exhausted";
  cargoRequirements: CargoRequirement[];
  cargoLimits: VehicleCargoLimit[];
};

const normalizedCode = (value: string) => value.trim().toLowerCase();

export function evaluateCapacity(input: CapacityValidationInput): CapacityEvaluation {
  const reasons: string[] = [];
  const warnings: string[] = [];
  const dimensions: CapacityDimensionResult[] = [];
  const stopLimit = Math.max(0, input.maxStopsPerDeparture);
  const stopStatus = input.stopCount > stopLimit ? "blocked" as const : "fits" as const;
  dimensions.push({
    kind: "stops",
    code: "stops",
    displayName: "Stops per departure",
    used: input.stopCount,
    limit: stopLimit,
    remaining: Math.max(0, stopLimit - input.stopCount),
    utilizationPercent: stopLimit ? Math.round((input.stopCount / stopLimit) * 100) : 100,
    status: stopStatus,
  });
  if (stopStatus === "blocked") reasons.push(`Vehicle allows ${stopLimit} Stop${stopLimit === 1 ? "" : "s"} per departure; this proposal has ${input.stopCount}.`);
  if (input.departurePattern === "return_after_every_delivery" && input.stopCount > 1) {
    reasons.push("Vehicle rules require returning to pickup after every delivery.");
  }

  const limitByCode = new Map(input.cargoLimits.map((limit) => [normalizedCode(limit.cargoClassCode), limit]));
  const requirementByCode = new Map<string, CargoRequirement>();
  for (const requirement of input.cargoRequirements) {
    const code = normalizedCode(requirement.cargoClassCode || "unclassified");
    const existing = requirementByCode.get(code);
    requirementByCode.set(code, existing
      ? { ...existing, quantity: existing.quantity + requirement.quantity }
      : { ...requirement, cargoClassCode: code });
  }

  for (const requirement of requirementByCode.values()) {
    if (requirement.classificationStatus === "unclassified" || requirement.cargoClassCode === "unclassified") {
      dimensions.push({ kind: "cargo", code: "unclassified", displayName: "Unclassified cargo", used: requirement.quantity, status: "review_required" });
      reasons.push(`${requirement.quantity} cargo unit${requirement.quantity === 1 ? " is" : "s are"} unclassified and require Operations review.`);
      continue;
    }
    const limit = limitByCode.get(requirement.cargoClassCode);
    if (!limit) {
      dimensions.push({ kind: "cargo", code: requirement.cargoClassCode, displayName: requirement.displayName, used: requirement.quantity, status: "review_required" });
      reasons.push(`${requirement.displayName} has no configured limit for this vehicle profile.`);
      continue;
    }
    if (!limit.allowed) {
      dimensions.push({ kind: "cargo", code: requirement.cargoClassCode, displayName: requirement.displayName, used: requirement.quantity, status: "blocked" });
      reasons.push(`${requirement.displayName} is not allowed for this vehicle profile.`);
      continue;
    }
    const maximum = limit.maxQuantity;
    if (!maximum) {
      dimensions.push({ kind: "cargo", code: requirement.cargoClassCode, displayName: requirement.displayName, used: requirement.quantity, status: "review_required" });
      reasons.push(`${requirement.displayName} has no approved quantity limit for this vehicle profile.`);
      continue;
    }
    const status = requirement.quantity > maximum ? "blocked" as const : "fits" as const;
    dimensions.push({
      kind: "cargo", code: requirement.cargoClassCode, displayName: requirement.displayName,
      used: requirement.quantity, limit: maximum, remaining: Math.max(0, maximum - requirement.quantity),
      utilizationPercent: Math.round((requirement.quantity / maximum) * 100), status,
    });
    if (status === "blocked") reasons.push(`${requirement.displayName} allows ${maximum} unit${maximum === 1 ? "" : "s"}; this proposal has ${requirement.quantity}.`);
  }

  const ranked = dimensions.filter((dimension) => dimension.limit && dimension.status === "fits")
    .sort((a, b) => (b.utilizationPercent ?? 0) - (a.utilizationPercent ?? 0));
  const firstFailure = dimensions.find((dimension) => dimension.status !== "fits");
  const constraining = firstFailure ?? ranked[0];
  const hasReview = dimensions.some((dimension) => dimension.status === "review_required");
  const hasBlocked = dimensions.some((dimension) => dimension.status === "blocked")
    || (input.departurePattern === "return_after_every_delivery" && input.stopCount > 1);
  return {
    status: hasBlocked ? "blocked" : hasReview ? "review_required" : "fits",
    dimensions,
    ...(constraining ? { constrainingDimension: { kind: constraining.kind, code: constraining.code } } : {}),
    reasons: [...new Set(reasons)],
    warnings,
  };
}
