# Slice 2 · Checkpoint 08

**Status:** canonical G02 location-observation entry implemented and verified on the connected Samsung; G02 and Checkpoint C remain in progress

**Date:** 2026-09-03

## Implemented

- D01 **Report an issue** now enters the canonical G02 address, pin and entrance problem screen in pickup context. The delivery exception drawer enters the same screen in delivery context.
- The measured 393 × 852 G02 layout contract lives in `apps/driver_harness/design/driver_ui_spec.json` and generates Flutter constants for the top bar, content, choice rows, footer and inset bottom drawers.
- G02 exposes the four canonical problem families: wrong pin, wrong entrance/access, wrong written address and inability to find the location.
- Location-dependent reports request the phone's real current GPS position and record latitude, longitude and reported accuracy. The comparison graphic is derived from the authoritative expected coordinate and that real observation; it is not a pretend map or a fabricated corrected pin.
- A submitted observation is sent through the existing persistent Driver–Operations thread. When the server is unavailable, the existing SQLite command outbox retains the exact Round and Stop context for retry after restart.
- Online and offline outcomes remain explicit. The UI says **Sent to Operations**, **Saved locally** or **Waiting to sync**; it never says the pin was corrected or the route was changed.
- Pickup context uses the authoritative pickup phone and copy. Delivery context uses the recipient phone and copy. Both offer the existing durable Operations chat and a return to navigation.

## Verification

- Flutter static analysis passes with no findings.
- All 66 Flutter tests pass.
- New tests cover exact G02 top-bar/footer geometry, real-location observation semantics, offline-safe outcome wording, delivery-flow entry, pickup contact authority and the checked-in 393 × 852 visual baseline.
- Generated metrics match the committed design contract.
- The debug Android APK was rebuilt and installed over the existing app while retaining the signed-in Driver session.
- On the connected Samsung SM-S928B, a real approved Round opened D01 and then canonical G02. The physical screen showed the live pickup identity/address, four canonical choices and pickup-specific contact action with the expected measured layout.

## Honest remaining boundary

- The current durable record is an Operations conversation message, not yet a typed location-exception command and resolution record.
- G02 does not mutate the pickup or delivery pin, because a Driver observation is not global location truth and the supplied policy requires Operations confirmation.
- Delivery destination changes after pickup still need original-destination preservation, a versioned server command, route/downstream consequence recalculation and E04–E06 Driver acknowledgement.
- The supplied product policy does not define authority for mutating a shared pickup location. Until that is defined, pickup reports remain observations for Operations review rather than automatic corrections.

## Next

- Add the typed server-side delivery-location observation and Operations resolution contract.
- Connect an Operations-confirmed delivery destination change to route consequence recalculation and E04–E06 acknowledgement.
- Keep pickup-location mutation out of the automatic path unless product authority is explicitly defined.
