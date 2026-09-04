# Slice 2 · Checkpoint 30

**Status:** canonical English/Thai N01 Driver Permissions implemented

**Date:** 2026-09-04

## Implemented

- Connected the active Driver locale to N01 from the profile, pickup and Stop
  navigation, GPS recovery, location-problem recovery and real camera-evidence
  paths.
- Localized the real location states and contextual location/camera recovery
  drawers from the supplied English and Thai N01 boards.
- Added the supplied Thai N01 board to the generated measurement contract.
  The Flutter surface now selects its separate Thai typography, vertical rhythm
  and 320 px overrides instead of treating translated copy as English geometry.
- Preserved the existing OS-backed state machine: N01 inspects location service
  and app permission state, requests only in-use location, distinguishes a
  permanent block and opens the appropriate device settings.
- Replaced the invented `TEAM PILOT` label with a truthful one-step indicator
  while retaining the canonical top-bar composition.
- Kept background location and notifications unavailable. Their later designed
  steps are not exposed until the platform policy and a real promoted push
  channel exist.

## Verification

- Flutter static analysis passes with no issues.
- All 136 Driver tests pass.
- The generated Driver measurement freshness check passes.
- N01 tests cover its canonical 393 px English geometry, real location request,
  service-disabled recovery, Thai 393 px copy and interaction, Thai 320 px
  no-overflow behavior, and localized camera recovery.
- The normal protected debug APK builds, installs and launches on the connected
  Samsung `SM-S928B`.

## Honest remaining boundary

- N01 remains `PARTIAL`: background-navigation permission policy is unresolved,
  notification permission has no promoted real push channel, and the complete
  physical denied/permanently-blocked/settings-return matrix is not accepted.
- Install and launch are verified on Android. This checkpoint does not claim a
  visual acceptance or iOS permission pass.
- The interactive HTML prototype still contains all three designed steps; the
  app shows only the one currently supported real permission step.

## Next safe work

- Continue the supplied-board active-screen localization audit with H01 Driver
  support chat, preserving its real thread/message behavior and offline queue.
