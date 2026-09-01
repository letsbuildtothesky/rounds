import type { FleetPosition, FleetPositionsEvent } from "@rounds/contracts";

export class TenantPositionAggregator {
  readonly #changedByTenant = new Map<string, Map<string, FleetPosition>>();

  update(tenantId: string, position: FleetPosition): void {
    const changed = this.#changedByTenant.get(tenantId) ?? new Map<string, FleetPosition>();
    changed.set(position.driverId, position);
    this.#changedByTenant.set(tenantId, changed);
  }

  flush(tenantId: string, now: Date): FleetPositionsEvent | undefined {
    const changed = this.#changedByTenant.get(tenantId);
    if (!changed || changed.size === 0) return undefined;
    this.#changedByTenant.delete(tenantId);
    return {
      event: "fleet.positions",
      version: 1,
      tenantId,
      asOf: now.toISOString(),
      drivers: [...changed.values()].sort((left, right) =>
        left.driverId.localeCompare(right.driverId),
      ),
    };
  }
}

