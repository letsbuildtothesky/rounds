# Slice 2 · Checkpoint 33

**Status:** durable H01 current-location attachment implemented

**Date:** 2026-09-04

## Implemented

- Adds the canonical Driver `+` bottom drawer with the first fully working
  attachment action: Location.
- Captures the phone's real current position only after operational location
  permission succeeds.
- Stages Location before Send and allows optional accompanying text.
- Persists the staged location per Stop across process restart.
- Queues location with the existing offline-capable message command without
  claiming server success while local.
- Validates coordinates, accuracy, capture time, label and attachment bounds
  in the shared contract and server database command.
- Stores the attachment as structured JSON in the shared Operations thread.
- Renders the location card in Driver and Operations with an external Google
  Maps handoff and a useful copy reference.
- Projects durable shared locations into H03 Contact History.

## Verification

- Remote Supabase migration `202609040004` applied successfully.
- The linked remote database schema lint found no new public-schema error; its
  reported errors are pre-existing PostGIS extension-body findings.
- TypeScript typecheck and all 160 workspace tests pass.
- Flutter static analysis passes with no issues.
- All 143 Driver tests pass, including location draft restore and H03 evidence.

## Honest remaining boundary

- The attachment drawer exposes only the released Location action. It does not
  expose Camera, Photo or File controls that cannot yet complete durably.
- Media bytes and voice remain gated by the durable upload path and GAP-009
  retention policy.
- Physical Samsung location-stage/send/map-open acceptance remains open.

## Next safe work

- Build, install and physically exercise this checkpoint on Samsung, then move
  to H01 unread/read semantics or the next fully specified English gap while
  media retention remains unresolved.
