# Rounds · Engineering Build Spec Roadmap

**Version:** 1.1  
**Date:** 2026-09-01  
**Status:** Controlling build-spec sequencing guide

## Principle

Do **not** create a 20-spec waterfall before evidence or code.

The current product/UX library is closed. Engineering specifications are written only far enough ahead to keep the next implementation slice deterministic.

## Step 0 — execute Phase 0 first

`ROUNDS-PHASE-0-FIELD-VALIDATION-SPEC-v1.2.md` is already detailed enough to drive the combined navigation + telemetry harness.

Do not write production feature Build Specs before Phase 0 merely to feel complete.

Phase 0 must return one of:

- PASS;
- BRIDGE REQUIRED;
- NAV FAILURE;
- LOCATION FAILURE.

## After Phase 0 passes — Build Specs required for Pilot/Slice 1

Write these next, in order. They may be separate documents or tightly grouped if doing so reduces duplication without reducing clarity.

1. **BS-00 · Repository / environments / deployment / observability**  
   Monorepo, local Supabase, migrations/seeding, dev/staging/prod, secrets, CI, Vercel `sin1`, Singapore API/worker runtime, worker redundancy, logs/traces/alerts.

2. **BS-01 · Identity / tenancy / roles / authorization**  
   Merchant membership, Team driver identity, JWT claims, RLS, server-only cross-tenant boundary, audit of sensitive access. Public Network identity/KYC is explicitly later.

3. **BS-02 · Core domain model / state machines / concurrency**  
   Delivery, Stop, Round, Manifest, custody, POD, Driver, Shift, Vehicle; aggregate boundaries; monotonic versions; typed command errors; idempotency; audit/event envelope.

4. **BS-03 · Driver local store / offline / auth lifecycle**  
   SQLite model, outbox, evidence survival, proactive token refresh, re-auth flush, conflict behavior, locale persistence.

5. **BS-04 · Location / presence / Realtime**  
   Phase 0 location-source result, sampling/batching, sequence numbers, ingest acknowledgements/watermark, hot current position, short-retention samples, tenant-aggregated Broadcast, freshness, trail finalization and the 1,000-active-driver load target.

6. **BS-05 · POD / media / custody evidence**  
   On-device compression/hash, TUS resumable upload, evidence staging, two-phase commit, `delivered_pending_evidence`, idempotency, orphan-object TTL/cleanup, retention and recovery.

7. **BS-06 · Maps / navigation / address boundary**  
   Phase 0 findings, Google `TWO_WHEELER`, destination ledger/session recovery, planned vs navigated vs actual route behavior, live consequence recalculation, provider-policy boundaries, Operations renderer contract and cost/quota instrumentation.

8. **BS-07 · Localization**  
   Thai-first catalog, English fallback, generated locale keys/contracts, navigation/push locale, Thai typography/wrapping, date/time/number formatting and QA.

After these are sufficient, **build Pilot/Slice 1**. Do not wait for every future SaaS specification.

## Specs written only before their slice

### Before Slice 2 — Own-fleet operations depth

- planning / multi-stop generation and adjustment;
- shifts / vehicles / cargo / capacity;
- batch intake;
- exceptions / communications / live changes.

### Before Slice 3 — UrbanFlowers commerce integration + API foundation

- canonical Delivery API / OpenAPI;
- inbound idempotency;
- UrbanFlowers adapter;
- outbound webhooks / writeback / reconciliation.

### Before Slice 4 — Lalamove

- provider adapter contract;
- quote/booking/idempotency;
- webhook normalization;
- custody-aware cancellation/failure;
- final cost/POD reconciliation.

### Before Slice 5 — Preferred/invited Network

- relationship model;
- availability/privacy;
- offers/acceptance;
- fixed fare/settlement record;
- cross-tenant projections.

### Before Slice 6 — Open Network

- public identity/KYC/face-check decision;
- trust/safety/admin;
- Network Supply;
- open offer waves;
- earnings/settlement views;
- PDPA/security requirements specific to biometrics/public Network.

### Before Slice 7 — General SaaS connectors

- Shopify app;
- WooCommerce/WordPress extension;
- public developer API/onboarding;
- quotas/webhooks/reconciliation.

## Mandatory content of every Build Spec

Every Build Spec must contain, as applicable:

- purpose and non-goals;
- product/UX sources it implements;
- schema/migrations;
- aggregate/state-machine changes;
- commands and request/response contracts;
- authorization/RLS/server-only boundaries;
- idempotency/concurrency;
- events/Broadcast/queues;
- offline/retry behavior;
- error/degraded states;
- privacy/retention implications;
- observability/trace IDs;
- cost/quota implications;
- automated tests;
- acceptance criteria;
- migration/rollback notes;
- explicit parked scope.

## Already accepted technical details to carry forward

Do not lose these during spec writing:

- location ingest sequence/watermark and bounded trail-finalization strategy;
- logical navigation intent survives Flutter view remount without blind rebilling;
- orphan/uncommitted POD objects have retention cleanup;
- active navigation may diverge from planned geometry; update consequences rather than forcing identical polylines;
- realtime position fanout is tenant-aggregated;
- public Network/KYC/earnings are not Slice 1.

