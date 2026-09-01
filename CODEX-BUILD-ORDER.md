# Rounds · Codex Build Order

**Version:** 1.0

This file controls implementation sequence. The complete Build Spec set exists, but Codex must not build everything in parallel.

## Phase 0 — field evidence
Read:
- `specs/engineering/ROUNDS-PHASE-0-FIELD-VALIDATION-SPEC-v1.2.md`
- `specs/build/BS-03.md`
- `specs/build/BS-04.md`
- `specs/build/BS-06.md`
- `specs/build/BS-07.md`

Build only the combined Flutter navigation + Rounds telemetry harness. Stop with PASS / BRIDGE REQUIRED / NAV FAILURE / LOCATION FAILURE.

## Pilot / Slice 1 — one real UrbanFlowers delivery loop
After human authorization following Phase 0, implement the minimum subsets of:
- BS-00
- BS-01
- BS-02
- BS-03
- BS-04
- BS-05
- BS-06
- BS-07
- BS-08 (manual/internal canonical intake only)
- BS-15 (delivery evidence/history subset)
- BS-16 (only settings needed by Slice 1)
- BS-17 production gates appropriate to pilot

Target: merchant login → delivery → Team driver → Round assignment → pickup/custody → embedded navigation → live position → handoff/POD → completion → History.

## Slice 2 — own-fleet depth
- BS-09 full planning/capacity
- BS-10 exceptions/comms/live changes
- BS-11 customer tracking if promoted
- BS-16 relevant settings

## Slice 3 — UrbanFlowers commerce/API
- BS-08 UrbanFlowers adapter + API/writeback/reconciliation

## Slice 4 — Lalamove
- BS-12

## Slice 5 — preferred/invited Network
- BS-13

## Slice 6 — open Network
- BS-14

## Slice 7 — general SaaS connectors
- BS-08 Shopify/WooCommerce/Public API portions

## Cross-cutting
BS-17 always applies. BS-15 grows as each fulfillment source is added.

## Human gate
Codex must stop at the end of every phase/slice and report tests, gaps and real-device/provider QA. It may not self-promote to the next slice.
