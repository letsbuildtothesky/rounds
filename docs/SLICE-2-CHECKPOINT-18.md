# Slice 2 · Checkpoint 18

**Status:** current Driver assignment selection corrected and canonical live destination pin picker connected

**Date:** 2026-09-03

## Implemented

- The Driver API no longer selects the oldest unfinished assignment. It deterministically prioritizes active work, then loading work, then approved work; within each state it selects today, the nearest future service date, or the latest past service date.
- The connected Samsung immediately restored the current-day B2 Round after the API change instead of the stale 2026-09-01 Round.
- Operations live delivery changes no longer expose editable latitude and longitude text fields.
- A real Mapbox destination picker now opens over the live-change drawer, starts at the current saved Stop coordinate and records the map center only after Operations confirms `Use this pin`.
- Address-only clarifications can explicitly retain the existing physical pin. If that choice is cleared, an address change is blocked until a real map pin selection is made.
- The server still performs the authoritative route, promise and shift recalculation before Apply; the picker does not manufacture route or arrival truth.

## Verification

- All 140 TypeScript tests pass and workspace TypeScript typechecking is clean.
- The Operations production build compiles successfully and `git diff --check` is clean.
- Automated tests cover current-assignment state/date priority and every permitted live-change address/pin decision.
- The signed-in Operations board was inspected in the browser after hot reload. It still reports the real backend state: four ready Rounds, zero live Rounds, and the saved destination markers.
- The live pin drawer was not forced open against a ready Round because the product correctly allows post-pickup changes only after custody transfer.

## Honest remaining boundary

- No active live demo Round exists yet, so the signed-in Operations Apply → Driver acknowledgement → Operations observed transition and the map picker itself still need physical post-pickup acceptance.
- The current B2 Round is ready on the Driver device, but pickup is about 1.2 km from the connected phone. No arrival or custody event was fabricated.
- The database pgTAP scenario still needs a local Docker-capable runner.
- Final road, degraded-network, background, iOS and supported-device acceptance remain open.

## Next safe work

- At the real pickup, confirm the manifest on the Driver device, then exercise one live destination change through the map picker and acknowledge it on the Driver device.
- In parallel with that later physical acceptance, continue the remaining G01/G04/G05 custody exception outcomes without weakening the real arrival and custody gates.
