# Rounds · Implementation Baseline Checkpoint

**Version:** 1.0  
**Date:** 2026-09-01  
**Status:** READY FOR PHASE 0; production Build Specs intentionally not yet written

## What this checkpoint does

This checkpoint closes the specification-cleanup phase and creates the only package implementation agents should consume.

It does **not** redesign Rounds.

## Product canon

- Current product checkpoint: v43 implementation-readiness cleanup.
- Operations UX remains `rounds-edge-states-v45.html`.
- Driver UX remains the returned 47-screen English board library; Thai is the primary Thailand production locale and mirrors the same behavior/state model.
- Product-complete V1 is explicitly separated from Pilot/Slice 1.

## Conflicts removed

- Mapbox no longer owns Driver active navigation in Mapping spec.
- Driver active navigation = embedded Google Navigation / TWO_WHEELER subject to Phase 0.
- Mapbox = Operations renderer for V1, not route truth.
- planning/routing + address/geocoding remain abstracted and vendor-term constrained.
- old “visual design still to be reworked” language removed.
- stale spec/UX filename references in current controlling files normalized.
- old Driver MASTER/PHASE docs removed from implementation authority.
- old repository `SPEC.md` is replaced by a pointer.
- Phase 0 no longer says it is waiting for Driver screens.
- Build Spec roadmap formatting fixed.

## Implementation scope

Phase 0 first.

Pilot/Slice 1 after a successful gate:

`UrbanFlowers → Own/Team driver → delivery → small real Round → pickup/custody → embedded navigation → live location → handoff/POD → History`

Public Network, KYC/face-check, earnings/Get Paid, Lalamove, production commerce connectors, advanced Address Intelligence and Rounds Direct are parked until their slices.

## Accepted pre-Build-Spec engineering constraints

- telemetry batch sequencing / ingest watermark / bounded trail finalization;
- logical nav destination recovery across Flutter view remounts;
- orphan POD object cleanup;
- planned/navigation/actual route consequence reconciliation;
- tenant-aggregated Broadcast position fanout;
- no broad cross-tenant client RLS for Network;
- Thai-first localization;
- implementation agents must stop on current-source conflict.

## Validation performed

- Canonical index references resolve.
- Markdown file-reference scan across implementation baseline: zero unresolved local `.md`/`.html` references.
- 47 Driver HTML boards present.
- Operations HTML present.
- Inline JavaScript syntax check: 41 HTML files with inline JS checked, zero syntax failures.
- Historical specs are not included in implementation baseline.

## Next

Execute Phase 0. Do not begin another architecture/specification review cycle.

After Phase 0 passes, write only the Build Specs required for Pilot/Slice 1 following the Build Spec Roadmap v1.1.
