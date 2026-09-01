import type { Freshness } from "@rounds/contracts";

export type FreshnessPolicy = {
  liveThroughMs: number;
  agingThroughMs: number;
  staleThroughMs: number;
};

export const phaseZeroFreshnessPolicy: FreshnessPolicy = {
  liveThroughMs: 20_000,
  agingThroughMs: 45_000,
  staleThroughMs: 5 * 60_000,
};

export function classifyFreshness(
  sourceAt: Date | undefined,
  now: Date,
  policy: FreshnessPolicy = phaseZeroFreshnessPolicy,
): Freshness {
  if (!sourceAt) return "unknown";
  const age = Math.max(0, now.getTime() - sourceAt.getTime());
  if (age <= policy.liveThroughMs) return "live";
  if (age <= policy.agingThroughMs) return "aging";
  if (age <= policy.staleThroughMs) return "stale";
  return "unknown";
}

