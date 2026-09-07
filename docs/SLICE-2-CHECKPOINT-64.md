# Slice 2 Checkpoint 64 — English G01 recipient-unavailable visual lock

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
- `ux/driver/en/screens/ROUNDS-G01-RECIPIENT-UNAVAILABLE-v2-10OF10.html`

## Implemented

- Rendered the supplied English G01 board from a local HTTP origin and audited
  it against Flutter at the canonical `393 × 852` viewport.
- Locked the initial, call-outcome drawer, one-failed-attempt and
  two-failed-attempt states with four separate English goldens.
- Enforced the supplied 310 px title measure and removed the invented manifest
  quantity prefix from the compact current-Stop summary.
- Preserved the real native-dialer handoff, authenticated durable call-attempt
  ledger, repeat-call progression and existing Operations contact path.
- Kept the prototype-only waiting and approved decision states out of product
  code because no authoritative Operations custody disposition exists.

## Verification

- All 7 focused G01 geometry, golden and behavior tests pass.
- The complete 180-test Driver suite passes.
- Flutter analysis passes with no issues.
- Repository-wide TypeScript typecheck and all 220 repository tests pass.
- The configured Android debug APK builds successfully.
- All four new goldens were inspected at their original `393 × 852`
  resolution against the supplied HTML composition.

## Honest remaining gate

G01 remains `PARTIAL`. `GAP-006` must define the typed recipient-unavailable
hold, Operations custody decision, recovery and release before the waiting or
approved states can be implemented. Physical-device visual and real call-event
acceptance also remain open.

## Scope boundary

- No fake Operations response, approval, reassignment or custody release was
  added.
- No Thai presentation screen changed.
- English closure remains the active build order. The next implementable
  board-level target is G04 cannot-complete presentation and existing real
  evidence behavior, still stopping before the unresolved custody outcome.
