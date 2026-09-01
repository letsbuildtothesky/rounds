# Rounds

Rounds is being implemented sequentially from the canonical product, architecture and Build Specs in this repository.

It contains:
- the current canonical product specs;
- Engineering Architecture v1.1;
- Phase 0 field spec;
- complete Engineering Build Specs for the product-complete V1 design;
- the current Operations HTML reference;
- all 47 English Driver HTML boards;
- a dedicated Thai Driver board folder;
- Codex build-order and repository instructions.

## Current implementation

- `apps/driver_harness` — Phase 0 Flutter navigation/telemetry foundation, now extended with authenticated Slice 1 Team Round retrieval.
- `apps/operations-web` — Pilot/Slice 1 authenticated delivery intake and manual Team Round assignment.
- `apps/telemetry_viewer` — Phase 0 live telemetry viewer.
- `services/location_ingest` — batched location-ingest domain logic.
- `services/api` — Pilot/Slice 1 authenticated command API foundation.
- `packages/contracts` — language-neutral command, delivery, Round, event and location contracts.
- `packages/domain-ts` — server-side state/version helpers.
- `supabase` — forward-only schema migrations, deterministic synthetic seed and pgTAP/RLS tests.

Implementation evidence and current gaps are recorded in `field/` and `docs/`.

## Authority
1. `AGENTS.md`
2. `CODEX-BUILD-ORDER.md`
3. the active Build Specs and Implementation Scope Ladder

## Commands

```bash
npm test
npm run typecheck
npm run build --workspace @rounds/operations-web
npx supabase db lint --linked --schema public --level error --fail-on error
```

The Flutter harness has its own commands under `apps/driver_harness`.
