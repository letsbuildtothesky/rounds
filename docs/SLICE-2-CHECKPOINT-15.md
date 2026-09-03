# Slice 2 · Checkpoint 15

**Status:** truthful canonical N03 GPS recovery implemented

**Date:** 2026-09-03

## Implemented

- D01 pickup navigation and E02 Stop navigation now open the supplied, measured N03 recovery surface over the real Google map.
- A 30-second absence of real operational position samples and real position-stream errors trigger GPS recovery. Routing/network errors remain separate.
- Every interruption rechecks the real device location-service and app-permission state before deciding between `GPS SIGNAL LOST` and `LOCATION ACCESS OFF`.
- `Cached route ready` and `Continue with cached route` appear only when the Google Navigation SDK had already reported active guidance. Before guidance exists, N03 truthfully reports that no cached route is available.
- Retry GPS requests a real high-accuracy fix and restarts the operational location stream before dismissing the state.
- Returning from the N01 OS-settings recovery path runs the same real GPS probe.
- Telemetry persistence errors and GPS stream errors are now separate callbacks, so a local SQLite failure cannot be mislabeled as signal loss.
- GPS loss and restoration are written to the local navigation event ledger with the navigation-session identity and cached-route truth.

## Verification

- All 128 TypeScript tests pass and workspace TypeScript typechecking is clean.
- All 87 Flutter tests pass; Flutter static analysis and the generated-metrics drift gate are clean.
- N03 tests cover exact 393 px geometry, the 30-second freshness boundary, service-versus-signal classification, cached-route truth and the no-cache recovery state.
- The debug APK builds, installs and launches on the connected Samsung SM-S928B.
- With real Google guidance active, disabling Android location and closing the Navigation SDK's system warning produced the measured Rounds `LOCATION ACCESS OFF` state. The device location setting was restored immediately after the check.

## Honest remaining boundary

- The Android global-location toggle exercises the permission/service branch, not true satellite signal loss while device location remains enabled.
- True GPS loss, tunnel/urban-canyon recovery, background recovery and live cached-guidance behavior still need road acceptance.
- iOS device acceptance is still blocked on the available Mac toolchain/account setup.
- During active Android guidance, Google Navigation SDK can display its own native `No location access` warning before the Rounds surface. Rounds does not claim control over that provider-owned dialog.

## Next safe work

- Build the supplied N02 offline/reconnecting state around the existing durable command, telemetry and media outboxes, without turning API failure into fabricated success.
