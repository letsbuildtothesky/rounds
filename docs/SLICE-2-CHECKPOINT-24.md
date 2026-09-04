# Slice 2 · Checkpoint 24

**Status:** canonical B01/B01B Team Home lifecycle restored and physically verified through pickup-navigation entry

**Date:** 2026-09-04

## Implemented

- The authenticated Driver root now follows the canonical state sequence instead of sending every assigned Round directly to E01:
  - B01 while the Team shift is open and no Round is assigned;
  - B01B while the assigned Round is `approved` or `loading`;
  - D01 only after the Driver explicitly selects **Navigate to pickup**;
  - E01 only after pickup/custody has made the Round `active`.
- English and Thai B01/B01B layouts use generated measurements extracted from the four supplied canonical HTML boards.
- B01 shift time, progress and schedule boundaries are derived from the effective shift and current time.
- B01B pickup identity, address, Stop count, planned Round distance/duration and handling labels are derived from the authenticated session.
- The B01B map uses the real Google map and authoritative pickup coordinate in production. Its static route illustration exists only behind the native-map-disabled widget-test boundary.
- Driver-to-pickup distance and ETA remain `—` until an authoritative route result exists; the prototype's 2.8 km / 9 min values are never presented as live truth.
- Jobs and Profile open their existing real destinations. B01B Dispatch message/call actions reuse the existing Round/Stop communication authority. Unsupported B01 shift-only contact, Hours and Notifications actions remain inactive.

## Verification

- Flutter static analysis passes.
- All 115 Flutter tests pass.
- New lifecycle tests prove waiting, assigned/loading and active routing boundaries.
- English 393 × 852 B01 and B01B golden references pass; the Thai B01B layout is covered at 320 × 720 without overflow.
- Generated Driver UI metrics report no drift from the checked-in design measurements.
- The configured Android debug APK builds successfully and installs over the existing app data on the connected Samsung SM-S928B.
- The authenticated Samsung launch now restores the real B01B **Round assigned / Pickup next** surface with the real Google map and live Round data. Selecting **Navigate to pickup** entered native D01 Google guidance successfully.

## Honest remaining boundary

- The waiting B01 state has automated visual coverage but has not yet been physically exercised against a live open attendance with no assigned Round.
- The home preview has no authoritative driver-to-pickup route result yet, so it does not claim distance, ETA or route geometry. D01 obtains the real provider guidance after the explicit navigation action.
- No shift-level Operations thread/contact identity exists without a Round. B01 contact controls therefore cannot safely send or call yet.
- Hours and Notifications remain separate specified capabilities; this checkpoint does not fabricate those destinations.

## Next safe work

- Continue canonical own-fleet closure using the supplied boards: implement a real promoted capability only where its authority exists, and otherwise complete remaining physical/offline/Thai visual acceptance without inventing product behavior.
