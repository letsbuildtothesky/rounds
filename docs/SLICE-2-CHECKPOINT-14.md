# Slice 2 · Checkpoint 14

**Status:** truthful canonical N01 Team permission recovery implemented

**Date:** 2026-09-03

## Implemented

- L01 Profile now opens the supplied N01 permission surface using generated measurements from the canonical HTML.
- N01 inspects the phone's real location-service and app-permission state instead of storing a local approximation.
- A first denial can be requested again; permanently blocked access opens app settings; disabled device location opens location settings.
- Returning from Android Settings refreshes the displayed permission truth.
- Google navigation now presents a location-recovery state instead of retaining an indefinite loading spinner when operational location cannot start.
- G02 current-location evidence uses the same typed recovery path.
- POD, package-damage and camera-restart flows recognize the native image-picker camera-denial result and open a contextual settings drawer. They do not claim that a photo was captured or retained.
- The surface explains that camera access is contextual. Notification permission is absent because no real push-notification service has been promoted.

## Verification

- All 128 TypeScript tests and all 82 Flutter tests pass.
- Workspace TypeScript typechecking, Flutter static analysis and the generated-metrics drift gate are clean.
- Tests cover the canonical 393 px geometry, short-height behavior, first location request, disabled-service settings handoff, typed permanent denial and contextual camera recovery.
- The debug APK builds, installs and launches on the connected Samsung SM-S928B.
- The physical N01 screen reports the phone's actual `whileInUse` state as ready and displays the contextual camera rule.

## Honest remaining boundary

- Rounds currently requests only location while in use. Background-navigation permission must not be promoted until the Android/iOS service behavior and store policy are accepted.
- Notification permission is intentionally absent until a real push channel and actionable-notification workflow exist.
- Camera status is not polled in advance; the native contextual request remains the source of truth and denial triggers recovery.
- Final physical denial, permanent-denial and return-from-settings acceptance still requires temporarily changing permissions on a test device.

## Next safe work

- Build the supplied N03 GPS-unavailable state around real service/position failures and safe cached-route behavior, keeping GPS loss separate from network loss.
