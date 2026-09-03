# Slice 2 · Checkpoint 02

**Status:** own-team planning guard and date-specific scheduling implemented; Slice 2 remains in progress

**Date:** 2026-09-03

## Canonical UX contract

- Operations is implemented against `ux/operations/rounds-operations-current-v45.html`.
- Driver is implemented against the English screen contracts in `ux/driver/en/screens/`; Thai remains a later localization pass in the same Flutter application.
- This checkpoint preserves the v45 planning hierarchy: map workspace, persistent bottom planning timeline, Driver/vehicle lanes, explicit fit explanation and right-side schedule drawer (bottom sheet at phone width).
- No placeholder map capability, route result, partner availability, cargo fit or promised-window fit is represented as real.

## Implemented

- The Operations Plan workspace now loads the server-authoritative own-team capacity projection for the selected service date.
- A v45-style bottom planning timeline presents the unplanned pool, selected Stop count, own-team Drivers, scheduled capacity, effective shift, vehicle profile and current Round.
- Client guidance blocks a proposal when the Driver has no effective shift, no active vehicle profile, exceeds the vehicle Stop limit or violates a return-after-every-delivery rule.
- The existing server Round approval command now applies the same static shift/vehicle guard and saves the exact capacity-rule snapshot used at approval.
- Route/promised-window and cargo classification remain explicit warnings until those real server capabilities exist.
- Operations can create or edit a date-specific custom shift or day off through the canonical schedule drawer.
- Operations can explicitly clear a date exception and return the Driver to the recurring schedule.
- Date-exception set/clear commands are tenant-authorized, version checked, idempotent, audited and written to the transactional outbox.
- The Driver capacity projection reports the active date exception and correctly uses an exception shift even when there is no recurring schedule.

## Verification

- Remote migrations `202609030004`, `202609030005` and `202609030006` are applied; local and remote migration histories align and a dry run reports the database up to date.
- 102 TypeScript tests pass: 32 contracts, 55 API, 5 domain, 6 location ingest and 4 Operations web tests.
- All workspace typechecks pass.
- The Operations production build passes.
- Browser acceptance on the signed-in localhost app verified the planning timeline, Stop selection, Driver fit explanation, approval gating and date-exception drawer with no console error. That acceptance exposed the missing clear action, which is now implemented.
- The linked schema lint finds no issue in the new public functions. Its output contains Supabase/PostGIS extension warnings plus the pre-existing unused variable warning in `send_driver_message_command`.
- pgTAP coverage now includes static Stop-limit enforcement, recurring-shift selection, day-off blocking, clear-to-recurring restoration, permissions, audit and outbox. The SQL suite could not execute locally because Docker/Supabase Postgres is not running on this Mac; no pgTAP pass is claimed.

## Acceptance fixture note

The date-exception browser acceptance created a custom 08:00–18:00 override for `2026-09-03` with the note `TEST FIXTURE — recurring hours preserved after command acceptance.` It preserves the effective working hours and does not block planning. The new **Use recurring schedule** action is available to clear it explicitly.

## Next checkpoint

- Extend planning from static capacity to real route-duration and promised-window validation.
- Add explicit cargo classification and vehicle cargo-limit evaluation before representing cargo fit as verified.
- Continue the remaining canonical v45 planning and Round-management states, then complete the corresponding Driver flow states against the English UX contracts.
