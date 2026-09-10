# Rounds

The current task is v2.3-r1 reconciliation and implementation in this repository.
Start with [active Build Specs](specs/build-v2.3/README.md),
[module readiness](specs/build-v2.3/READINESS.md) and the
[first workflow](specs/build-v2.3/FIRST-WORKFLOW.md).

**2026-09-10 checkpoint update:** source authority remains the reconciled
v2.3 specs and unchanged Phase39/Refresh26 designs. Isolated restricted-role
handlers now cover the bounded local pickup, arrival, handoff, proof/completion
and pickup-issue workflow. ADR-M04 adds original-purpose pickup photo reservation,
byte verification and damaged/wrong report attachment enforcement. The native
pickup issue queue now binds damaged/wrong photos through original-report camera
intent, encrypted upload/verification and explicit ReportIssue materialization.
The staged G03 choices/evidence form now preserves editable encrypted drafts and
photo retakes, then explicitly freezes and sends the report through that queue.
ADR-Q04 now reads original reported issue status and actual saved Operations
instructions through the restricted query and receipt-bound native lease. This
does not create decisions or authorize collection/continuation. ResolveIssue,
approved recovery destinations and host/phone activation remain next. See the [current implementation and
verification boundaries](specs/build-v2.3/README.md) and its linked test logs.
The installed app has not switched to this v2.3 workflow. Full UI/workflow,
configured providers, data mapping and phone acceptance remain open.
No shared migration, installation or deployment occurred in this increment.

For public GitHub publication, eight supplied HTML references have only their
embedded account-specific map token replaced by a placeholder. Designs are not
restyled. [Original archive/provenance instructions](specs/source/archives/README.md)
explain the private input required for original-source verification.

The original ZIP remains byte-identical and Git-ignored under specs/source/archives. Owning
specs/contracts/acceptance are reconciled in place, with original and working
hashes. Build Specs carry repository baselines and scoped readiness; generated
coverage is not completed-feature evidence. Legacy specs/UX remain comparison
material, not competing current authority.

## Preserved implementation (not v2.3 certified)

- `apps/driver_harness` — Phase 0 Flutter navigation/telemetry foundation, authenticated Team Round retrieval and physical pickup verification.
- `apps/operations-web` — Pilot/Slice 1 authenticated delivery intake, manual Team Round assignment and custody progress.
- `apps/telemetry_viewer` — Phase 0 live telemetry viewer.
- `services/location_ingest` — batched location-ingest domain logic.
- `services/api` — Pilot/Slice 1 authenticated command API foundation.
- `packages/contracts` — language-neutral command, delivery, Round, pickup/custody, event and location contracts.
- `packages/domain-ts` — server-side state/version helpers.
- `supabase` — forward-only schema migrations, deterministic synthetic seed and pgTAP/RLS tests.

Implementation evidence and current gaps are recorded in `field/` and `docs/`.

## Authority
1. `AGENTS.md`
2. `CODEX-BUILD-ORDER.md`
3. `specs/build-v2.3/SOURCE-AUTHORITY.md` and the active Build Specs

## Commands

```bash
npm test
npm run typecheck
npm run build --workspace @rounds/operations-web
npx supabase db lint --linked --schema public --level error --fail-on error
```

The Flutter harness has its own commands under `apps/driver_harness`.
