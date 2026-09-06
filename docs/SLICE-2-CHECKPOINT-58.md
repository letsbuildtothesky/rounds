# Slice 2 Checkpoint 58 — English Driver board review gate

Date: 2026-09-06

## Canonical sources used

- `CODEX-BUILD-ORDER.md`
- `specs/build/BS-01.md`
- `specs/build/BS-02.md`
- `specs/build/BS-03.md`
- `specs/build/BS-04.md`
- `specs/build/BS-06.md`
- `specs/build/BS-09.md`
- `specs/build/BS-10.md`
- `specs/build/BS-15.md`
- `specs/build/BS-17.md`
- `specs/product/ROUNDS-DRIVER-UX-BEHAVIOR-MASTER-v3.1.md`
- `specs/product/ROUNDS-SPEC-6-COMMUNICATIONS-MESSAGING-v1.4.md`
- `specs/product/ROUNDS-SPEC-10-DRIVERS-LIVE-AVAILABILITY-CONTACT-v1.4.md`
- `ux/driver/en/screens/ROUNDS-B00-START-SHIFT-v1-10OF10.html`
- `ux/driver/en/screens/ROUNDS-B01-TEAM-DRIVER-HOME-v4-10OF10.html`
- `ux/driver/en/screens/ROUNDS-B01B-TEAM-HOME-ROUND-ASSIGNED-v3-10OF10.html`

## Implemented

- Added explicit non-release direct-review routes for B00, B01 and B01B. They
  let the supplied English boards be rendered on a physical phone without
  starting a real shift or changing a live Round.
- Kept all review fixtures outside release behavior. Normal app routes still
  use authenticated server data.
- Rebuilt the B01B non-native review map from the supplied HTML geometry:
  blocks, roads, route curve, Driver position, pickup marker and labels.
- Clipped every painted road and route segment to the map region after the
  visual comparison caught one diagonal road escaping into the ETA row.
- Kept the supplied `2.8 km` and `9 min` values inside the review fixture only.
  Production continues to render `—` until an authoritative driver-to-pickup
  route projection exists.

## Verification

- `flutter analyze` passes.
- All 167 Driver tests pass.
- A dedicated 393 × 852 English review golden locks the exact B01B fixture;
  the separate production golden still proves unknown route metrics are not
  invented.
- The corrected B01B review build was installed and visually compared on the
  connected Samsung SM-S928B.

## Deliberate boundary

- Production B01B continues to use the real Google map and authoritative
  pickup coordinate.
- B00 shift-level Operations contact remains blocked until a real no-Round
  thread/contact authority exists.
- Hours and Notifications remain inactive because their authoritative data
  and notification policy are not complete. No destination was invented.
- No Thai screen was added or changed. English closure remains the active
  gate.

## Next authorized work

Continue English board-by-board closure using the supplied HTML as the visual
contract and the specifications as the behavior/authority contract. A board
passes only after its real interactions, automated regression evidence and
rendered comparison agree.
