# Slice 2 Checkpoint 53 — one live marker per own driver

Date: 2026-09-05

## Canonical sources used

- `CODEX-BUILD-ORDER.md`
- `specs/product/ROUNDS-SPEC-4-MAPPING-ADDRESS-INTELLIGENCE-v1.8.md`
- `specs/engineering/ROUNDS-ENGINEERING-ARCHITECTURE-v1.1.md`
- `specs/engineering/ROUNDS-IMPLEMENTATION-COVERAGE-AND-GAP-CONTROL-v1.0.md`
- `ux/operations/rounds-operations-current-v45.html`

The live map iterated Round summaries. Because one Team driver currently has
four approved Rounds and each summary references the same hot driver position,
four identical `DT` markers were stacked on the same coordinate. The v45 map
language defines the marker as an own-driver role, not a Round-row role.

## Implemented

- Positioned Round summaries are grouped by authenticated own-driver identity.
- One physical Driver now produces one own-driver marker.
- The newest valid hot position supplies the marker coordinate.
- Active, loading and approved state priority deterministically selects which
  authoritative Round primary click opens; same-state ties prefer the earliest
  service date and then reference.
- The marker retains every represented Round id so unread message/voice state
  is aggregated instead of lost during deduplication.
- Accessible marker text discloses the selected Round and how many Rounds the
  marker represents.

## Acceptance

The signed-in live board previously showed four coincident `DT` markers for one
Team driver. After hot reload it showed one marker labelled `4 Rounds on board`.
Primary click selected Ready and opened the authoritative
`ROUND-20260901-094250` Round drawer.

## Verification

- All 29 Operations tests pass, including one-driver/many-Round, newest-position
  and separate-driver cases.
- Operations TypeScript typecheck passes.
- Operations production build passes.

## Still open

- Active planned-route, active-navigation and actual-trail evidence must remain
  separate; no line is fabricated from the hot point.
- Current/future Stop emphasis and desktop right-click/touch long-press quick
  contact remain to be connected to real map data.
