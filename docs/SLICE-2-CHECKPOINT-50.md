# Slice 2 Checkpoint 50 — own-driver next-capacity projection

Date: 2026-09-05

## Canonical sources used

- `specs/product/ROUNDS-SPEC-2-BUSINESS-PRODUCT-MASTER-v2.26.md`
- `specs/product/ROUNDS-SPEC-6-DISPATCH-ROUTE-EDITING-COMMS-v1.11.md`
- `specs/engineering/ROUNDS-IMPLEMENTATION-COVERAGE-AND-GAP-CONTROL-v1.0.md`
- `ux/operations/rounds-operations-current-v45.html`

The supplied Drivers surface promises to show when own-fleet capacity becomes
available. Until this checkpoint, an occupied Driver always said that route
completion was not connected even when the current Round already contained a
saved approved route finish.

## Implemented

- The Drivers projection now selects the current Round's saved route snapshot.
- A valid future `finishAt` becomes the occupied Driver's `nextAvailableAt`.
- Active and loading/approved work keep distinct availability states and labels.
- Projection copy explicitly says the time comes from the saved approved route;
  it does not claim a fresh traffic ETA or actual completion time.
- Missing, invalid or elapsed route finishes produce no next-available time.
- The v45 Driver row shows the projected local time and its provenance. The
  existing fleet-level Next capacity KPI consumes the same field.

## Acceptance

The signed-in localhost Drivers workspace loaded one authoritative own-team
Driver without an API or rendering error. Its current saved route finish is no
longer in the future, so the UI correctly kept the conservative
`Assigned work blocks new capacity` fallback instead of inventing a time.

## Verification

- All 103 API tests pass, including future active/loading route finishes and
  absent/elapsed finish behavior.
- API and Operations TypeScript typechecks pass.

## Still open

- Refreshing a current Round finish against live execution/traffic evidence is
  needed before this can be described as a live ETA.
- Production vehicle/cargo values remain subject to UrbanFlowers approval under
  `GAP-002` and `GAP-003`.
