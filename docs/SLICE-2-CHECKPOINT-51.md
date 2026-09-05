# Slice 2 Checkpoint 51 — truthful v45 map legend

Date: 2026-09-05

## Canonical sources used

- `CODEX-BUILD-ORDER.md`
- `specs/engineering/ROUNDS-IMPLEMENTATION-COVERAGE-AND-GAP-CONTROL-v1.0.md`
- `ux/operations/rounds-operations-current-v45.html`

The supplied v45 prototype presents four map roles: Own, Network, External and
Traffic impact. The currently authorized English own-fleet application has no
Network, external-provider or traffic layer. Repeating those prototype labels
on the connected application falsely implied that their evidence was visible.

## Implemented

- The map legend is computed from the same datasets passed to the real Mapbox
  renderer.
- Live mode labels real own-driver positions and action Stops only when their
  coordinates exist.
- Plan mode labels real unplanned Stops and labels a proposed route only when
  route geometry with at least two coordinates exists.
- Network, External and Traffic impact remain absent until their authorized
  slices and actual map layers are connected.
- The canonical v45 floating legend placement, typography and marker language
  are retained.

## Acceptance

The signed-in localhost application rendered four real own-driver positions in
Live and Plan modes and showed only `Own driver`. It did not advertise Network,
External, Traffic impact, unplanned work or a route that was not on the map.

## Verification

- All 26 Operations tests pass, including Live, Plan and empty legend cases.
- Operations TypeScript typecheck passes.
- Operations production build passes.

## Still open

- A live travelled-trail versus approved-route projection is not connected.
- Remaining marker-state semantics and physical responsive/device acceptance
  stay open.
