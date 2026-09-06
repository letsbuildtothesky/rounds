# Slice 2 Checkpoint 59 — English D01 board parity and arrival audit

Date: 2026-09-06

## Canonical sources used

- `CODEX-BUILD-ORDER.md`
- `specs/engineering/ROUNDS-IMPLEMENTATION-SCOPE-LADDER-v1.0.md`
- `specs/engineering/ROUNDS-ENGINEERING-ARCHITECTURE-v1.1.md`
- `specs/build/BUILD-SPEC-INDEX.md`
- `specs/build/BS-03.md`
- `specs/build/BS-04.md`
- `specs/build/BS-06.md`
- `specs/product/ROUNDS-DRIVER-CANONICAL-MANIFEST-v6.md`
- `specs/product/ROUNDS-DRIVER-UX-BEHAVIOR-MASTER-v3.1.md`
- `specs/product/ROUNDS-SPEC-3-DRIVER-BROADCAST-OPERATING-MODEL-v1.9.md`
- `ux/driver/en/screens/ROUNDS-D01-NAVIGATE-TO-PICKUP-v5-10OF10.html`

## Implemented

- Added non-release-only `d01` and `d01-near` direct-review routes. They use
  explicit local review values and cannot replace live Google Navigation
  events in a release or native-navigation build.
- Rebuilt the non-native D01 map from the supplied HTML coordinate system:
  six physical blocks, five roads, the exact Bézier route, Driver arrow,
  pickup/home marker, pickup label and both map labels.
- Locked the supplied en-route `320 m`, maneuver, `6 min` and `1.2 km` values
  and the near-pickup `80 m`, arrival instruction, `1 min` and explicit action
  in review fixtures only. Production values remain provider-authored.
- Corrected the near-pickup dock copy to the supplied `Entrance on your left`.
- Corrected the shared action drawer to honor Android's persistent system
  navigation inset so the final action is not covered on the Samsung.

## Verification

- Focused D01 widget and interaction tests pass.
- Separate 393 × 852 English goldens now lock en-route and near-pickup review
  states. The existing production golden remains separate and still shows
  unknown values until live Google events arrive.
- Both English D01 states were built, installed and visually inspected on the
  connected Samsung SM-S928B. The en-route composition, near-pickup action and
  four-row pickup action drawer pass rendered-device inspection.
- Flutter analysis and the complete Driver suite pass at this checkpoint.

## Functional audit result

The locked D01 behavior says the explicit pickup-arrival action records an
arrival event and captures/validates location where available before entering
D03/D04. Current production code only performs the screen transition. No
pickup-arrival command, immutable event or server timestamp exists.

The existing `stop.confirm_arrival` command belongs to a delivery destination
Stop and cannot be reused at the merchant pickup without corrupting Stop
state. This is now tracked as `GAP-016`; D01 is therefore `PARTIAL` despite its
accepted English visual parity.

## Deliberate boundary

- No fake pickup Stop, local success claim or destination-arrival command was
  introduced to make the status look complete.
- No Thai presentation screen was added or changed. English closure remains
  the active build order.
- Normal D01 continues to use the authoritative pickup coordinate and live
  embedded Google `TWO_WHEELER` navigation.

## Next authorized work

Lock and implement the pickup-arrival event boundary end to end: aggregate
owner, idempotency/version rule, server timestamp, optional measured position,
dense-city tolerance semantics and offline sequencing into D03/D04. Then
repeat the near-pickup action on the physical device against the real service.
