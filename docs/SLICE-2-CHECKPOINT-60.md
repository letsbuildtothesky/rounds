# Slice 2 Checkpoint 60 — Real D01 pickup-arrival boundary

Date: 2026-09-06

## Canonical sources used

- `CODEX-BUILD-ORDER.md`
- `specs/engineering/ROUNDS-IMPLEMENTATION-COVERAGE-AND-GAP-CONTROL-v1.0.md`
- `specs/engineering/ROUNDS-ENGINEERING-ARCHITECTURE-v1.1.md`
- `specs/build/BS-03.md`
- `specs/build/BS-04.md`
- `specs/build/BS-06.md`
- `specs/product/ROUNDS-DRIVER-UX-BEHAVIOR-MASTER-v3.1.md`
- `specs/product/ROUNDS-SPEC-3-DRIVER-BROADCAST-OPERATING-MODEL-v1.9.md`
- `ux/driver/en/screens/ROUNDS-D01-NAVIGATE-TO-PICKUP-v5-10OF10.html`

## Implemented

- Added `round.confirm_pickup_arrival` as a versioned and idempotent
  Team-driver command on the assigned Round.
- The API derives tenant, Driver, Round version and authoritative pickup from
  the authenticated session and rejects a substituted pickup location.
- Migration `202609060001` adds private immutable pickup-arrival evidence with
  a server timestamp, optional measured OS coordinate/accuracy/provenance,
  audit record and domain-event outbox record.
- Pickup arrival is observational. It does not activate the Round, mutate a
  delivery Stop, claim custody or increment the Round version. The later
  manifest/custody confirmation remains `round.confirm_pickup`.
- D01 now captures a fresh high-accuracy OS position when permission and the
  location service are available. Failure to obtain a fresh fix does not
  fabricate evidence and does not block the driver's explicit arrival.
- The existing green action is disabled with an in-button progress indicator
  during submission. D03/D04 opens only after committed or durably queued
  truth. A terminal rejection leaves D01 visible with the real error.
- Committed pickup arrival is projected in the Driver session. A pending
  offline arrival is retained in the encrypted session cache, so an app
  restart resumes D03/D04 rather than sending the Driver back to navigation.

## Verification

- 51 contract tests pass.
- 119 API tests pass.
- Flutter analysis passes.
- Focused D01 position, rejection, geometry, golden and restart-cache tests
  pass.
- The complete 171-test Driver suite passes, including the final
  restart-helper assertion.
- The configured Android debug APK builds and installs successfully on the
  connected Samsung SM-S928B.
- Migration `202609060001` was applied to the linked Supabase project, and
  linked database inspection confirms `round_pickup_arrival_events` exists.

## Honest remaining gate

The newly installed normal APK is currently at the real phone-entry screen,
so this checkpoint does not claim a physical authenticated press of
**I'm at pickup** against the live API. The English D01 visuals were already
accepted on this Samsung and remain locked by unchanged goldens. D01 is
therefore `IMPLEMENTED`, not `VERIFIED` or `ACCEPTED`, until a signed-in,
assigned near-pickup run confirms the command end to end. Docker is not
installed on this Mac, so the checked-in pgTAP file could not be executed by
the CLI; remote migration application and schema inspection passed.

## Scope boundary

- No Thai presentation screen changed.
- No pickup Stop or geofence pass was fabricated.
- The delivery-destination arrival command remains separate.
- English closure remains the active build order.
