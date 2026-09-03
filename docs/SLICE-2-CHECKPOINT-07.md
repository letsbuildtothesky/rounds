# Slice 2 · Checkpoint 07

**Status:** canonical D01 pickup navigation implemented and verified on the connected Samsung; Checkpoint C remains in progress

**Date:** 2026-09-03

## Implemented

- An approved assigned Round now opens D01 Navigate to Pickup instead of skipping directly to manifest confirmation.
- D01 reads the authoritative pickup id, name, address and coordinate from the Driver session projection. A missing coordinate blocks navigation honestly instead of substituting a pin.
- The embedded Google Navigation surface routes to that pickup with its native `TWO_WHEELER` provider. The custom D01 instruction card is driven by live Google maneuver text, maneuver type and distance rather than static directions.
- The measured 393 × 852 D01 contract now lives in `apps/driver_harness/design/driver_ui_spec.json` and generates Flutter constants for the top instrument, instruction card and pickup dock.
- Live route time and distance feed the pickup dock. Remaining route distance at or below 100 m, or Google's native arrival callback, reveals the explicit **I'm at pickup** action.
- That action transitions to the existing canonical D03/D04 manifest confirmation screen; route arrival alone does not claim pickup or custody.
- The D01 More control opens the canonical bottom drawer with Call pickup, Message Operations, Report an issue and Open in Maps. Call and Maps use native external intents; Operations messaging uses the durable in-app thread.

## Verification

- Flutter static analysis passes with no findings.
- All 61 Flutter tests pass.
- New tests cover the exact D01 dock and near-state geometry, top-instrument geometry, assigned-Round entry, action-drawer contract, external Maps destination and D01→D03/D04 transition.
- A checked-in 393 × 852 D01 golden baseline passes.
- The debug Android APK builds successfully and was installed over the existing app while retaining the signed-in Driver session.
- On the connected Samsung SM-S928B, the real approved Round opened D01, Google returned a live route to the UrbanFlowers pickup, the measured card displayed live maneuver text, and the dock displayed live ETA/distance. The pickup-actions drawer also passed rendered-device inspection.

## Honest remaining boundary

- The phone was not physically moved to within 100 m of the pickup during this checkpoint. The reveal rule and transition are automated-test verified, but physical proximity/arrival acceptance remains open.
- G02 destination/pin correction is still partial. D01 reaches the existing issue entry, but no fabricated corrected pin, Operations approval or route consequence is claimed. Durable G02 is the next Checkpoint C capability.
- Motorcycle road, degraded-network, background and battery gates remain open.

## Next

- Implement the canonical G02 address/pin/entrance problem path and Operations outcome without inventing the unresolved authority rules.
- Continue G01/G04/G05 only where the supplied boards and current product policy authorize the state transition.
