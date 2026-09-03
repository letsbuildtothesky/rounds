# Slice 2 · Checkpoint 04

**Status:** canonical pre-approval Stop-order and departure adjustment implemented; Slice 2 remains in progress

**Date:** 2026-09-03

## Canonical UX contract

- Operations continues to implement `ux/operations/rounds-operations-current-v45.html` as the visual and interaction contract.
- This checkpoint connects the existing v45 planned-Round behaviors: explicit Stop order controls, departure adjustment, affected Driver-lane recalculation and consequence-first approval.
- No automatic plan generator, invented planning screen or client-authoritative route decision was added.

## Implemented

- Selected Stops can be moved up or down before approval; the ordered Stop identifiers remain the proposal and command truth.
- Every Stop-order change triggers a fresh server route, promise-window, shift and multidimensional cargo/vehicle-capacity preview.
- Operations can adjust the proposed departure in 15-minute increments from the server-selected departure.
- Every departure change recalculates the selected Driver lane and exposes blocking consequences before approval.
- Approval recalculates the same requested departure on the server instead of trusting the browser preview.
- The command contract requires `departureAt`, and the route snapshot must represent the same instant.
- Remote migration `202609030009` independently rejects a command when the requested and server-routed departures are missing, invalid or different.
- Existing idempotent retries still pass through the original command chain so a changed retry produces the existing idempotency conflict rather than bypassing it.
- The v45 planning header remains usable at the intermediate desktop/tablet breakpoint after adding the departure control.

## Verification

- 116 TypeScript tests pass: 34 contracts, 67 API, 5 domain, 6 location ingest and 4 Operations web tests.
- All workspace typechecks pass.
- The Operations production build passes.
- API tests verify explicit departure routing, recalculated ETA and blocking outside the effective shift.
- Contract and handler tests verify the requested departure is valid, reaches the command and matches the fresh server route.
- Signed-in localhost browser acceptance verified the canonical planning surface at the normal app width and at a 1440 px reference width, with no console errors and no horizontal page overflow.
- Remote migration `202609030009` is applied; a second linked dry run reports the database up to date.
- The linked schema lint reports only the existing PostGIS extension findings and the pre-existing unused variable in `send_driver_message_command`.
- The updated pgTAP suite contains missing/mismatched-departure checks, but it could not execute because the local Supabase PostgreSQL instance is not running. No pgTAP pass is claimed.

## Remaining Checkpoint B work

- Move future Stops between existing Rounds through versioned server commands.
- Recalculate only the source and destination Rounds and present both consequence sets before confirmation.
- Complete connected Round overview/detail actions required by the current v45 board.

