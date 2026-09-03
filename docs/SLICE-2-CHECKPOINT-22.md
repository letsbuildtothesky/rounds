# Slice 2 · Checkpoint 22

**Status:** canonical B00 Team Start Shift connected to server-authoritative attendance

**Date:** 2026-09-03

## Implemented

- The authenticated Driver session now resolves the current Bangkok-local service date against a date exception first, then the recurring Team schedule, and returns exact local/UTC shift boundaries plus existing attendance.
- A typed `driver.start_shift` command is authenticated, version-zero, idempotent and committed only for the current active Team Driver and current effective shift.
- The database records server-authoritative start time while retaining device occurrence time as evidence. It snapshots the scheduled window/source and creates audit plus domain-outbox records in the same transaction.
- Start Shift never edits the Operations-owned schedule, assignment, Round, Stop, manifest or custody state.
- The Flutter app routes an off-shift Driver with no active custody to the canonical B00 board. Active/custody work remains reachable even if attendance truth is absent, so the new gate cannot strand work already in progress.
- English and Thai B00 layouts use generated measurements taken from their supplied canonical HTML boards, including the 393 px reference geometry and Thai 320 px compact rules.
- Jobs and Profile route to their real existing surfaces. Round-scoped message/call actions route to the real communication paths when a current Round exists. Notifications, Hours and contact without an authoritative Round remain visibly inactive rather than simulated.

## Verification

- Migration `202609030017_driver_shift_start.sql` compiled and applied to the linked Supabase project.
- Contract and API typechecks pass.
- All 147 TypeScript workspace tests pass.
- Flutter static analysis passes and all 108 Flutter tests pass.
- The B00 English reference-width golden, exact fixed-region geometry, Start Shift action and Thai compact layout are covered.
- Generated Driver UI metrics report no drift.
- The Operations production build and Android debug APK build pass.

## Honest remaining boundary

- B00 is `PARTIAL`, not device-accepted. The final Samsung button-to-remote-attendance transition has not yet been exercised.
- Local pgTAP execution is unavailable on this Mac because Docker/Podman is absent. The migration compiled remotely and the SQL behavior test is committed for the next Docker-capable run.
- The B00 board links to shift-level dispatch contact even when no Round exists, but the current communication authority is Round/Stop-scoped. The app does not invent a recipient, phone number or thread.
- M01 Notifications, K00 Hours and B01D–B01F ending/overtime are separately specified capabilities and remain unimplemented.

## Next safe work

- Install a configured debug build and accept the B00 start transition on the connected Samsung, then confirm the returned attendance removes B00 and exposes the canonical waiting/assigned home state.
- Continue the explicit shift lifecycle with B01D–B01F only after extracting their canonical English/Thai layout contracts and confirming overtime/end-shift policy.
