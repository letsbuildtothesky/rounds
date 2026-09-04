# Slice 2 · Checkpoint 23

**Status:** canonical B01D–B01F Team shift-ending lifecycle connected to server-authoritative attendance and assigned-work truth

**Date:** 2026-09-04

## Implemented

- The authenticated Driver app derives exactly one shift state from the open attendance snapshot and current assigned-Round truth: ending soon within 15 minutes of scheduled end, overtime while assigned work remains after scheduled end, or ready to end after scheduled end with no assigned work.
- English and Thai B01D, B01E and B01F layouts use generated measurements extracted from all six supplied canonical HTML boards. The app does not reinterpret or replace those boards.
- B01D/B01E route context uses the real stored route-plan Stop timing. Missing route timing is displayed as unavailable rather than replaced with a sample ETA.
- Contact actions reuse the real Round/Stop Operations thread and configured pickup contact. Hours and notification destinations remain inactive until their authoritative capabilities exist.
- A typed `driver.end_shift` command is authenticated, versioned, idempotent and safe for the durable Driver outbox.
- Supabase owns the actual end timestamp. It refuses an end before the scheduled boundary and refuses release while an assigned Round is approved, loading or active. A committed end advances attendance once and writes matching audit and domain-event evidence.
- Session restoration first resolves any open attendance snapshot, including an overnight or previous-service-date shift, before deriving a new current-date schedule.
- Ending a Team shift returns the Driver to the existing own-fleet home. The B01F prototype's Network switch target remains deferred and no Network availability is fabricated.

## Verification

- Migration `202609040001_driver_shift_end.sql` compiled and applied to the linked Supabase project.
- Contract and API typechecks pass.
- All 152 TypeScript workspace tests pass.
- Contract/API tests cover validation, authorization, stale-version, custody-lock, idempotency and committed result behavior.
- Flutter static analysis passes and all 111 Flutter tests pass.
- English 393 × 852 B01D and B01F goldens pass; Thai overtime copy/timing and exact fixed-region geometry are covered by widget tests.
- Generated Driver UI metrics report no drift from the checked-in design measurements.
- The Operations production build and configured Android debug APK build pass.
- The APK was installed over the existing data on the connected Samsung SM-S928B, the authenticated assigned-Round surface restored successfully, and the new API route responded with the expected unauthenticated guard. No Flutter runtime error appeared during the launch smoke test.

## Honest remaining boundary

- Local pgTAP execution is unavailable on this Mac because Docker/Podman is absent. The remotely applied database function contains the same early-end, custody and version guards, and the SQL behavior suite is committed for the next Docker-capable run.
- Physical near-end, overtime and end-shift acceptance has not been forced by editing the live Driver schedule or Round. The real device build can be installed and smoke-tested now; natural state acceptance remains a separate gate.
- Overtime is displayed only as factual elapsed time beyond the scheduled end. Pay, approval, adjustment and correction policy are not inferred.
- K00 Hours and M01 Notifications remain separate specified capabilities. The Team shift lifecycle does not invent those destinations.
- B01C is a Network-mode switch board and stays deferred. Ending a Team shift does not silently enroll or activate the Driver in Network mode.

## Next safe work

- Continue the locked own-fleet sequence with K00 Team Hours only after defining its shift-history and correction-request authority; otherwise continue the remaining physical/offline/visual closure work that does not require that product decision.
