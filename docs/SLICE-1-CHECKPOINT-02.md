# Pilot / Slice 1 · Checkpoint 02

**Status:** Operations authentication and canonical manual intake implemented; Slice 1 remains in progress

**Date:** 2026-09-01

## Authorized scope

This checkpoint implements the next Own-Team UrbanFlowers vertical increment only: a protected Operations surface that authenticates merchant staff and creates one manual delivery through the existing server-authoritative command. It does not promote AI/batch intake, commerce adapters, automated planning, Network or external couriers.

## Implemented

- New Next.js Operations application with the current Rounds visual foundation.
- Supabase email/password session handling with no service secret in the browser.
- Purpose-limited `GET /v1/operations/session` API projection.
- Server-side auth identity, active membership, role, tenant and pickup-location resolution.
- Explicit browser/API CORS boundary for the configured Operations origin.
- Manual delivery form covering merchant pickup, recipient, buyer relationship, destination pin, Bangkok promise window, manifest items, handling notes and surprise protection.
- Canonical manual form normalization into the shared `CreateDeliveryPayload` contract.
- Stable request idempotency across a failed/retried submission.
- Viewer mutation prevention in both the UI and existing API authorization layer.
- Forward-only API privilege migration that keeps browser roles default-deny while granting the API service only the identity/membership reads required by this checkpoint.
- Remote-development synthetic UrbanFlowers seed corrected for extension-qualified PostGIS/pgcrypto functions.
- CI production build coverage for the Operations application.

## Verification

- Operations form unit tests cover canonical normalization, gift buyer separation, required destination coordinates and Bangkok calendar behavior.
- API tests cover authenticated Operations session projection, invalid sessions and accounts without active memberships.
- Full TypeScript workspace tests and typecheck pass.
- Operations production build passes under Next.js 16.3.4.
- Remote migration `202609010005` is applied and linked schema lint reports no errors.
- A temporary synthetic dispatcher authenticated against the linked development Supabase project and created delivery `E2E-20260901-01` through the rendered browser UI.
- Database evidence confirmed exactly one Delivery, one Stop, one Manifest, one audit event and one transactional outbox event in `unplanned` state.
- The temporary authentication user was removed after the test. No reusable password or service credential was committed.

## Remaining gap

A permanent human Operations account has not been provisioned yet. That should be created with a user-selected password or approved production identity method when the user is ready to use the surface directly.

## Next checkpoint

Implement Team-driver assignment plus Round creation/retrieval so the newly created unplanned delivery can move into an approved Own-Team Round and appear in the Driver client.
