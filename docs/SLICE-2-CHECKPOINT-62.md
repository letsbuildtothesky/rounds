# Slice 2 Checkpoint 62 — English N01/N03 recovery parity

Date: 2026-09-06

## Canonical sources used

- `CODEX-BUILD-ORDER.md`
- `specs/engineering/ROUNDS-IMPLEMENTATION-SCOPE-LADDER-v1.0.md`
- `specs/engineering/ROUNDS-IMPLEMENTATION-COVERAGE-AND-GAP-CONTROL-v1.0.md`
- `specs/engineering/ROUNDS-ENGINEERING-ARCHITECTURE-v1.1.md`
- `specs/build/BS-03.md`
- `specs/build/BS-04.md`
- `specs/build/BS-06.md`
- `specs/build/BS-07.md`
- `specs/product/ROUNDS-DRIVER-CANONICAL-MANIFEST-v6.md`
- `specs/product/ROUNDS-DRIVER-UX-BEHAVIOR-MASTER-v3.1.md`
- `specs/product/ROUNDS-DRIVER-UI-CONSTITUTION-v1.2.md`
- `ux/driver/en/screens/ROUNDS-N01-PERMISSIONS-v3-10OF10.html`
- `ux/driver/en/screens/ROUNDS-N03-GPS-UNAVAILABLE-v3-10OF10.html`

## Implemented

- Rendered the canonical English N01 and N03 boards at their `393 × 852`
  reference viewport and compared their app-owned regions with Flutter.
- Corrected N01's first truth-row icon to the supplied benefit checkmark.
- Locked the approved N01 location-denied and ready states with separate
  goldens. The visible sequence remains `1 OF 1` because background location
  and notifications are not yet approved operational capabilities.
- Kept N03 layered over the actual Google navigation canvas. Its golden
  aperture is transparent and cannot substitute a fake map or static route.
- Constrained N03 heading copy to the supplied 340 px measure and preserved a
  single-line access-off title at the reference viewport.
- Added the missing canonical **Location settings** bottom drawer with the
  supplied iPhone and Android paths, **Check location access** and **Not now**.
- **Check location access** closes the drawer and invokes the existing real
  permission inspection/retry path. **Not now** closes without invoking it.
- Locked N03 cached-route, no-cache, access-off and open-drawer states with
  separate English goldens.

## Verification

- Focused N01/N03 geometry, behavior and golden tests pass.
- The complete 173-test Driver suite passes.
- Flutter analysis passes with no issues.
- Repository-wide TypeScript typecheck and all 220 repository tests pass.
- The configured Android debug APK builds successfully.
- Every new golden was inspected at its original resolution against the
  canonical HTML render.

## Honest remaining gate

N01 remains `PARTIAL`: background location requires an approved Android/iOS
policy and notifications require a real promoted push channel. N03 advances
to `IMPLEMENTED`, not `VERIFIED`: true signal-loss with device location still
enabled, background/degraded-network recovery and iOS acceptance remain open.
No new physical-device claim is made in this checkpoint.

## Scope boundary

- No fake map, route, position or permission success was added.
- No unapproved background-location or notification prompt was exposed.
- No Thai presentation screen changed.
- English closure remains the active build order.
