# Rounds — Codex repository instructions

This repository is the complete implementation handoff for Rounds.

## 0. Specification maintenance rule

Treat the canonical specification set as maintained source, not an append-only
conversation log.

- Do not add a new `ADDENDUM`, "supersedes earlier wording" block or duplicate
  decision summary to a canonical specification or index.
- Edit the owning section in place and remove or reconcile the superseded text
  in the same change.
- Record each substantive specification change in a short changelog near the
  top of the owning file. A version bump is valid only with a matching
  changelog entry, and the version header must match the filename.
- When one decision closes or changes an item in another active control or
  specification, update that file in the same checkpoint.
- Indexes list authoritative sources and precedence only. They must not become
  an additional product specification or changelog.
- Existing appended material is technical debt to consolidate deliberately.
  Do not delete it until the owning sections have been checked for equivalent
  authoritative coverage.

## 1. Authority and read order
Before changing code, read:
1. `AGENTS.md`
2. `CODEX-BUILD-ORDER.md`
3. the Build Spec(s) for the authorized phase in `specs/build/`
4. `specs/engineering/ROUNDS-IMPLEMENTATION-SCOPE-LADDER-v1.0.md`
5. relevant current product specs in `specs/product/`
6. relevant UX references in `ux/`
7. `specs/engineering/ROUNDS-ENGINEERING-ARCHITECTURE-v1.1.md`

Do not use historical specifications. They are intentionally absent.

## 2. What each layer controls
- Product behavior: `specs/product/`
- Architecture: `specs/engineering/ROUNDS-ENGINEERING-ARCHITECTURE-v1.1.md`
- Implementation mechanics: `specs/build/`
- Build sequence: `CODEX-BUILD-ORDER.md`
- Scope promotion: `specs/engineering/ROUNDS-IMPLEMENTATION-SCOPE-LADDER-v1.0.md`
- Operations visual reference: `ux/operations/rounds-operations-current-v45.html`
- Driver visual reference: `ux/driver/en/screens/`; Thai mirror: `ux/driver/th/`

If current sources conflict, STOP and report exact filenames/sections. Do not guess.

## 3. Complete Build Specs now exist
`specs/build/BUILD-SPEC-INDEX.md` lists the full engineering Build Spec set for product-complete Rounds V1.

Their existence is not permission to implement all of them. Follow `CODEX-BUILD-ORDER.md` strictly.

## 4. Current authorized execution

Human authorization has advanced implementation through **Pilot / Slice 1
closure and Slice 2 own-fleet depth**. Work only on capabilities marked current
in `specs/engineering/ROUNDS-IMPLEMENTATION-COVERAGE-AND-GAP-CONTROL-v1.0.md`.
Phase 0 motorcycle/background/battery/degraded-network evidence remains an open
release gate; implementation progress does not convert that missing evidence
into a PASS. Do not self-promote to Slice 3 or any Network/external-courier
slice.

## 5. Locked architecture
- Supabase PostgreSQL + PostGIS system of record.
- Next.js/React/TypeScript Operations.
- Flutter/Dart Driver, gated by Phase 0.
- Server-authoritative versioned/idempotent commands.
- Dedicated buffered/batched GPS ingest; tenant-aggregated Supabase Broadcast.
- Cross-tenant Network via server projections.
- Embedded Google Navigation `TWO_WHEELER` for Driver subject to Phase 0.
- Mapbox Operations renderer; no authoritative client route logic.
- Thai-first Driver, English secondary.
- POD/evidence survives offline/session loss.

## 6. Code quality
- Build small deterministic vertical slices.
- Add automated tests for every consequential invariant in the active Build Spec.
- Version/repeat migrations.
- Never commit secrets.
- Preserve trace IDs.
- Provider calls/webhooks are idempotent.
- Never fake real-device/provider QA.

## 7. UX
HTML boards are references, not code to paste wholesale. Prototype/demo switches are not production controls. Implement only screens required by current phase/slice, even though 47 boards exist.
