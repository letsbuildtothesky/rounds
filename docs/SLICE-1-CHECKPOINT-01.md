# Pilot / Slice 1 · Checkpoint 01

**Status:** foundation implemented; Slice 1 remains in progress

**Date:** 2026-09-01

**Phase 0:** implementation complete, physical field gate still pending and intentionally resumable

## Authorized scope

The human authorized moving into Pilot/Slice 1 while the remaining Phase 0 motorcycle/iPhone/low-cost-Android field checks are deferred. This checkpoint implements only the Own-Team UrbanFlowers foundation. It does not promote Network, Lalamove, commerce adapters, optimization or the full Driver board library.

## Implemented

- Multi-tenant identity and membership schema.
- Global Driver identity plus UrbanFlowers Team relationship schema.
- Canonical Delivery, Stop, promise, manifest, Round and ordered Round Stop records.
- Default-deny RLS with active-tenant read policies for Operations roles.
- Server-only `delivery.create` command with membership authorization.
- Expected version `0` for creation and versioned Delivery transition guard.
- Tenant-scoped idempotency ledger and external-source deduplication.
- Atomic audit event and transactional domain-event outbox.
- Picked-up manifest item immutability guard.
- Contract-first TypeScript command, Delivery and event envelopes.
- Domain transition/version helpers.
- Authenticated `POST /v1/deliveries` API handler that derives actor/role from Supabase rather than trusting client identity fields.
- Deterministic synthetic UrbanFlowers seed aligned with the Phase 0 tenant, driver, device, Round and Stop UUIDs.
- Pinned Node/Flutter/Supabase CI jobs for contracts, domain/API tests, fresh migrations, pgTAP/RLS, linting and secret/dependency checks.

## Verification

- Remote development migration `202609010004` applied successfully.
- Linked Supabase schema lint reports no errors.
- TypeScript tests cover contract validation, delivery transition rules, stale versions, canonical payload hashing, API authentication/authorization and HTTP result mapping.
- TypeScript workspace typecheck passes.
- pgTAP/RLS suite is committed under `supabase/tests/`; executing it currently requires Docker Desktop or another PostgreSQL test runner on this Mac. The linked Supabase CLI command still attempted Docker, so this suite is not claimed as executed yet.

## Next checkpoint

Build the first Operations surface for merchant authentication and manual delivery creation against this command API, then add Team-driver assignment and Round retrieval. The API service still needs deployment configuration and production observability before any live pilot claim.
