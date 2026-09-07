# Slice 2 Checkpoint 63 — English E04–E06 live-change visual lock

Date: 2026-09-07

## Canonical sources used

- `CODEX-BUILD-ORDER.md`
- `specs/engineering/ROUNDS-IMPLEMENTATION-SCOPE-LADDER-v1.0.md`
- `specs/engineering/ROUNDS-IMPLEMENTATION-COVERAGE-AND-GAP-CONTROL-v1.0.md`
- `specs/engineering/ROUNDS-ENGINEERING-ARCHITECTURE-v1.1.md`
- `specs/build/BS-10.md`
- `specs/product/ROUNDS-DRIVER-CANONICAL-MANIFEST-v6.md`
- `specs/product/ROUNDS-DRIVER-UX-BEHAVIOR-MASTER-v3.1.md`
- `specs/product/ROUNDS-DRIVER-UI-CONSTITUTION-v1.2.md`
- `ux/driver/en/screens/ROUNDS-E04-E05-E06-LIVE-ROUND-CHANGE-v3-10OF10.html`

## Implemented

- Audited the four approved English Team live-change states: entrance,
  destination, Stop order and promised window.
- Locked each state at the canonical `393 × 852` viewport with a separate
  golden. The boards preserve the supplied 64 px top bar, 370 px map region,
  panel spacing, diff rows, route-impact row and action hierarchy.
- Rebuilt the non-native/reference map painter from the supplied HTML geometry:
  clipped streets, buildings, labels, old/new routes, Driver marker and
  entrance pins now reproduce the approved board instead of a loose sketch.
  Production continues to use the real Google navigation map.
- Corrected real-data presentation so entrance instructions, next-Stop copy and
  earlier/later promise changes are derived from the authoritative before/after
  values while retaining the approved language.
- Made ETA rendering deterministic under test without changing production time
  behavior.
- Verified that **Contact Operations** opens the existing real thread and that
  **Acknowledge & continue** invokes the existing durable acknowledgement
  boundary.

## Verification

- Focused E04–E06 behavior and golden tests pass: 5 tests.
- The complete 176-test Driver suite passes.
- Flutter analysis passes with no issues.
- Repository-wide TypeScript typecheck and all 220 repository tests pass.
- The configured Android debug APK builds successfully.
- All four new goldens were inspected at their original `393 × 852`
  resolution.

## Honest remaining gate

E04–E06 remains `IMPLEMENTED`, not `VERIFIED` or `ACCEPTED`. The complete live
Operations apply → physical Driver acknowledgement → Operations-observed
transition still needs to run against an active multi-Stop Round, followed by
real-device visual and motorcycle-road acceptance.

## Scope boundary

- No fake production map, route, position or acknowledgement was added.
- The Network paid add-Stop flow remains deferred.
- No Thai presentation screen changed.
- English closure remains the active build order. The next authorized
  board-level target is G01 recipient-unavailable closure without inventing the
  unresolved custody outcome in `GAP-006`.
