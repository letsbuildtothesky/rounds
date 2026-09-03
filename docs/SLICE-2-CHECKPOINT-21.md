# Slice 2 · Checkpoint 21

**Status:** canonical A01 splash and Thai-first A01B language entry implemented from both supplied UX boards

**Date:** 2026-09-03

## Implemented

- The shared A01 splash now matches its canonical 393 px geometry, word/dot entrance timing and 1.25-second automatic transition. A full-screen tap performs the prototype's explicit skip action.
- Session restoration continues independently from the visual splash, preserving the existing startup recovery boundary.
- The previous generic language selector has been replaced by the canonical A01B editorial layout.
- English and Thai use measurements extracted separately from their supplied HTML boards: typography, vertical rhythm, row geometry, selected edge/radio treatment, footer and 320 px compact rules.
- Thai remains the default first-run locale for Thailand. Selecting English changes the whole selector to the English board before confirmation.
- Confirmation persists the pre-auth locale locally, survives relaunch/offline and routes returning Drivers past A01B after the shared splash.

## Verification

- Generated A01/A01B metric drift is checked from `driver_ui_spec.json`.
- Automated widget coverage verifies splash timing, centered geometry, tap skip, Thai-first state, English selection, local relaunch persistence, returning-Driver routing, reference-width regions and 320 px Thai layout without clipping.
- Flutter static analysis passes with no issues, all 106 Driver tests pass, generated metrics report no drift, and the Android debug APK builds successfully.

## Honest remaining boundary

- A01 is `IMPLEMENTED`, not physically accepted: Android/iOS visual and timing review remains open.
- A01B remains `PARTIAL` because authenticated `driver.preferred_locale` writeback, complete localization-key coverage for every active Driver screen and human Thai review are not complete.
- The board's visual selection does not authorize separate Thai/English applications; this remains one Flutter state machine and one domain model.

## Next safe work

- Continue Checkpoint D with a measured screen-by-screen visual parity ledger for the in-scope English own-fleet boards, correcting shared components before isolated screen overrides.
- Complete authenticated locale synchronization and active-flow localization before claiming Thai pilot readiness.
