# E09 — Testing Migration Release and Operations

Rounds engineering specification · Consolidated V2.3 · 8 September 2026

## Review draft versus deployment

This package specifies the designed product. It does not claim migrated database, running API, completed RLS policies, real payments, connected providers or field-validated native navigation. Written acceptance and structural document/schema checks are separate from executed service/device tests. Reviewers use the source traceability, decision register and acceptance matrix to sign off behavior and resolve gates.

## Migration sequence

1. Establish isolated dev/staging/prod projects, roles, secrets and exact extension/SDK compatibility. Preserve original reference artifacts as design sources only.
2. Apply identity/tenancy/configuration migrations, closed policies and two-tenant seed; test access before exposing endpoints.
3. Add calendars/intake/source identity and physical delivery schema; materialize finite horizon; verify duplicate/overnight/admission behavior.
4. Add plan/release/driver conflict, custody/proof and offline bridge; test transactional races and crash recovery.
5. Add Network agreements/change consent and optional Intercity tables/commands gated by entitlements.
6. Add communications/integrations/history/finance projections and asynchronous effects with idempotency; shadow-check counts before replacing old reads.
7. Apply indexes/partitioning/backfills via expand → backfill → verify → switch → contract. No destructive drop until affected code and retained evidence no longer depend on it.

Reference SQL is not an automatic in-place migration of a live predecessor. Real import needs an explicit source mapping for IDs, timezone, promises, vehicle enum, roles, item quantities and accepted/custody evidence. Quarantine ambiguous legacy records; never infer pickup/acceptance from a generic old status. Write reversible migration checkpoints and tested rollback/forward-fix procedures.

## Test layers

Schema/contract: validate OpenAPI/event/policy references, valid/invalid examples, Dart/TypeScript generated parity and migration constraints. Database: role/city/tenant isolation, same-tenant FK, immutable records, overlap exclusion and transaction races. Domain: P01–P15 scenarios plus duplicates/stale/unknown/cancel variants. Adapter: signature, replay/out-of-order, provider-accepted timeout, rate limit, revoked credentials and retry. Native: navigation+telemetry combined, low-cost Android/iPhone, camera/mic/permissions, offline crash/outbox and Thai guidance. UX: desktop/iPad and driver 320px/large-text, focus/touch and full recovery journeys.

Scenario seeds: two tenants with identical display names, two local cities, disabled Intercity, eligible paused freelancer, old offer revision, last-slot race, cross-midnight window, cargo versus stop-limit conflict, partial receipt, proof upload pending, source duplicate and superseded change. No tests use real recipient private data without authorized fixture handling.

## Proposed service targets for reviewer approval

Targets below are engineering acceptance proposals, not achieved metrics or provider guarantees. Normal command API p95 under 500 ms excluding external calls; core query p95 under 400 ms at agreed workload; 99.9% monthly command/query availability objective; committed-work recovery RPO ≤5 minutes and RTO ≤60 minutes; active moving-driver freshness p95 ≤30 seconds in adequate connectivity. Alert on aged proof pending >15 minutes, actionable outbox/notification lag >2 minutes and unexpected acceptance/custody conflicts. Tune thresholds from field and load tests; no notification reminder itself changes state.

Load test 1,000 concurrent active drivers with realistic moving/idle mix, 10–30 second batched location upload, tenant viewer fanout, command/offer races, media upload samples and provider events. Record p50/p95/p99, error rates, DB CPU/IO, connections, queue lag, payload/egress and mobile battery. Capacity claims require measured results and actual provider-account quotas. Later scale requires retest; no automatic 50,000-driver promise.

## Recovery and observability

Trace actor action → command → transaction/event/outbox → adapter request/receipt → projection using command_id/event_id/trace_id and entity IDs. Alerts carry safe operational context, not secret data. Maintain dashboards for stale location, pending proof/outbox age, provider unknowns, dead letters, admission conflicts, offer race results, error/latency and cost per completed delivery/active driver.

Database PITR/backups and object evidence backups are separate requirements. Restore drill verifies both relational facts and referenced media, auth/grants, command receipts and side-effect replay suppression. Test primary outage: operator sees labelled last-known read-only context; Driver captures safely offline; no shadow writable database. After restore, reconcile provider receipts before re-emitting effects. Proposed RPO/RTO must be demonstrated, not assumed from enabling a backup option.

## Build release ladder

R0 combined native field harness and provider-coherence decision. R1 own-team local vertical slice: real intake/slot/pickup/driver/proof/history and pilot source writeback. R2 reliable planning/live changes, full settings/schedules/comms/recovery. R3 freelance broadcast/acceptance/eligibility/consent/earnings contracts and cross-tenant privacy. R4 optional Intercity driver/receiver chain and dependent local work. Product specs describe all these now; deployment can be staged without deleting later requirements. No Lalamove or temperature stage is required.

Each release has reviewed contract/schema, verified authorization, executed applicable acceptance, known gaps explicitly gated, observability, rollback/restore and on-call runbook. No blanket “world class/finished” label replaces evidence.

### QA-SYSTEM-LOAD

Actor: Authorized actor for load harness; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; plus parameters explicitly stated in steps.

When: 1000 drivers sample5s/batch15s;50 operators;30min sustained;5min warm-up;core commands exclude external async time..

Then: At declared test deployment p95read<=400ms,command<=500ms,locationfreshness<=30s; zero double claims/negative balances. Any threshold failure blocks SLO sign-off; changing target is a new decision, not a pass..

Status: written requirement; application execution pending.

### QA-SYSTEM-RESTORE

Actor: Authorized actor for restore drill; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; plus parameters explicitly stated in steps.

When: Restore database and evidence objects to a recovery point after captured proof..

Then: Measured data loss<=5min and service restored<=60min proposed targets; missing bytes detected; no false evidence-complete record or replayed external payment..

Status: written requirement; application execution pending.

### QA-SYSTEM-MIGRATION

Actor: Authorized actor for migration harness; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; plus parameters explicitly stated in steps.

When: Upgrade local schema with queued pickup, pending photo and draft message; run server compatibility migration..

Then: Original IDs/bytes/account scope preserved; old supported clients either work or receive UPGRADE_REQUIRED without discarding data; rollback/forward-fix produces no duplicate custody..

Status: written requirement; application execution pending.
