# Slice 2 Checkpoint 48 — v45 Operations Rounds overview

Date: 2026-09-05

## Canonical sources used

- `CODEX-BUILD-ORDER.md`
- `specs/product/ROUNDS-SPEC-2-BUSINESS-PRODUCT-MASTER-v2.26.md`
- `specs/product/ROUNDS-SPEC-6-DISPATCH-ROUTE-EDITING-COMMS-v1.11.md`
- `specs/product/ROUNDS-SPEC-8-OPERATIONS-VISUAL-SYSTEM-v1.15.md`
- `ux/operations/rounds-operations-current-v45.html`

The implementation follows `openRoundsOverview()` and the matching round-row
geometry in the supplied v45 board. It keeps only the authorized own-fleet
sections; accepted Network work is not copied into the active slice.

## Implemented

- The map-header `Rounds` control is now real rather than disabled.
- The v45 right drawer separates active/loading own-team Rounds from approved
  upcoming Rounds and shows current authoritative counts.
- Each row enriches the action projection with the existing Round detail API,
  showing persisted vehicle, calculated start/finish and capacity utilization.
  Missing legacy fields are labelled as unavailable instead of invented.
- A failed detail enrichment does not hide the authoritative Round summary or
  break the drawer; available details remain visible with a truthful warning.
- Selecting a row opens the existing full Round execution workspace.
- `Plan next` closes the drawer and enters the connected manual planner.
- Communications shifts beside the drawer on wide desktop through the existing
  v45 coexistence rule.

## Live acceptance

The signed-in localhost board opened the new overview with four authoritative
approved Rounds and no active Rounds. All four rows populated their available
vehicle/capacity facts without a runtime error. Selecting a row closed the
overview and opened its real Round detail. Returning to Dispatch, reopening the
overview and selecting `Plan next` closed the drawer, selected Plan mode and
rendered the real approval timeline.

The first live pass exposed an older saved route plan without a capacity object.
The overview now treats that shape as legacy missing truth and renders
`Capacity not measured`; it does not crash or manufacture a percentage.

## Verification

- All 21 Operations tests pass, including grouping, truthful fallbacks and
  constraining-capacity selection.
- Operations TypeScript typecheck passes.
- Operations production build passes.

## Control-record correction

Checkpoint 18 / commit `f16d671` already implemented the canonical Mapbox
crosshair selector for a post-pickup destination change. The coverage register
no longer lists that control as missing. The physical active multi-Stop
apply/acknowledge acceptance remains open.

## Still open

- Physical active multi-Stop live-change acceptance.
- Remaining supplied v45 own-fleet functions recorded in the coverage register.
- Automatic planning remains intentionally absent until its heuristic,
  persistence and explainability contract are approved.
