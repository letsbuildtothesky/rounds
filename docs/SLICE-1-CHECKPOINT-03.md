# Pilot / Slice 1 · Checkpoint 03

**Status:** Team Round assignment and authenticated Driver retrieval implemented; Slice 1 remains in progress

**Date:** 2026-09-01

## Authorized scope

This checkpoint implements the next Own-Team UrbanFlowers increment only: Operations can explicitly order compatible unplanned delivery Stops, select an active Team driver and approve one small Round. The authenticated Driver client can retrieve that authoritative Round and render its Stops and physical manifest. Automated optimization, Network offers, external couriers and broader own-fleet planning remain parked.

The new screens are implemented in English first as requested. Domain contracts and state do not contain language-specific behavior; Thai presentation remains a later UX pass over the same system.

## Implemented

- Shared Round state, planning command, Operations planning projection and Driver Round projection contracts.
- Server-authoritative `round.plan_and_approve` command with idempotency, actor/tenant re-authorization and a transactional audit/outbox event.
- Validation that the selected driver is an active Team driver.
- Validation that every selected Stop is unique, unplanned, pending, on the requested service date, not already assigned and shares the pilot pickup location.
- Atomic Delivery transitions from `unplanned → planned → assigned`, Stop assignment and ordered `round_stops` creation.
- Authenticated Operations planning endpoint and Dispatch workspace.
- Viewer read-only behavior; viewers cannot approve Rounds.
- Authenticated Driver session endpoint that returns only the linked Team driver's current work.
- PostGIS EWKB point decoding for server-provided navigation coordinates.
- Flutter Team sign-in, secure access/refresh token storage, refresh retry, assigned Round/Stop/manifest rendering and navigation using the authoritative destination.
- Forward migrations `202609010006` and `202609010007` applied to development; linked schema lint passes.

## Verification

- Contract tests cover ordered Stops, duplicate rejection and new-aggregate semantics.
- API tests cover planning projection, viewer denial, command construction, Team-driver session authorization and PostGIS coordinate decoding.
- Flutter analyze passes; Flutter tests cover Driver projection parsing, assigned Round persistence, navigation intent and honest pending state.
- Full TypeScript workspace tests/typecheck and both Next.js production builds pass.
- Linked development pgTAP SQL executes successfully inside a rollback transaction.
- A synthetic development delivery was created through the API, returned in the Operations planning projection, approved as Round `74532074-0b54-4050-a95c-510a53a5e936`, and retrieved through the authenticated Driver endpoint with exactly one assigned Stop.
- Temporary dispatcher/driver/visual-QA authentication users were removed after verification. No password, access token or service secret was committed.

## Remaining gaps

- No permanent human Operations or Driver account has been provisioned.
- The authenticated Driver retrieval path has not yet been exercised on the physical Samsung device; this is required before a pilot claim.
- Thai UX is intentionally deferred until the English operational loop works end to end.
- Full Driver offline Round cache/outbox, pickup custody, POD evidence and completion remain ahead in Slice 1.

## Next checkpoint

Implement structured pickup manifest verification and the server-authoritative custody transition, including offline-safe Driver intent that never claims committed pickup before the API confirms it.
