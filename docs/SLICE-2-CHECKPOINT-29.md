# Slice 2 · Checkpoint 29

**Status:** canonical English/Thai L01 Driver Profile implemented

**Date:** 2026-09-04

## Implemented

- Replaced the active L01 Team profile's English-only copy with one locale
  authority sourced from the supplied English and Thai L01 boards.
- Localized the profile header, identity and Team status, vehicle and app
  sections, language control, permissions/support labels, bottom navigation,
  language drawer and sign-out confirmation.
- Made an L01 language selection rerender the open profile immediately while
  preserving the existing local-first, authenticated and offline-safe
  preference behavior.
- Added the Thai L01 board to the generated measurement contract. The Flutter
  screen now selects the board's separate Thai typography and spacing plus the
  exact English/Thai 320 px overrides instead of approximating one layout.
- Removed the unsupported `Assigned` vehicle value. L01 displays only the real
  vehicle label and plate projected by the authenticated Driver session.
- Preserved the current safe Team subset: no fake identity editing,
  verification, notification, Network or payout state was added from the
  interactive HTML prototype.

## Verification

- Flutter static analysis passes with no issues.
- All 133 Driver tests pass.
- The generated Driver measurement freshness check passes.
- L01 tests cover 393 px canonical regions, immediate English-to-Thai screen
  replacement, the Thai language/sign-out copy and 320 px no-overflow behavior.

## Honest remaining boundary

- L01 remains `IMPLEMENTED` until its English and Thai compositions are
  visually accepted on the connected phone.
- Opening Permissions or Round support enters separately owned N01 and H01
  surfaces. This checkpoint does not claim those child screens are fully
  localized.
- The inactive notification and Hours controls remain unavailable rather than
  pretending that unfinished channels or workflows exist.

## Next safe work

- Build and install the normal protected APK, physically compare L01 when an
  authenticated Driver session is available, then continue the supplied-board
  active-screen localization audit with N01 and H01 as separate capabilities.
