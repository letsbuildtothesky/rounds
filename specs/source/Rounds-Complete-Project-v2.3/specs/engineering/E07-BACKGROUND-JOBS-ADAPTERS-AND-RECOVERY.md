# E07 — Background Jobs Adapters and Recovery

## Reconciliation changelog

- 2026-09-08 · v2.3-r1: Align retry policy, notification identity and written failure cases.

Rounds engineering specification · Consolidated V2.3-r1 · 8 September 2026

## Durable work model

Use pgmq durable queues, Cron for wakeups and the TypeScript worker service with at least two production consumers. Domain commit writes transactional outbox; relay creates deduplicated job/effect work. Queue visibility timeout prevents simultaneous normal delivery within a window, but a message can become visible again after expiry. Consumers must therefore be idempotent; do not assume global exactly-once external effects. [Supabase pgmq behavior](https://supabase.com/docs/guides/queues/pgmq)

Job contains IDs/minimal payload references, tenant scope, kind, dedupe key, available_at, attempts and trace. Claim lease; validate current permissions/state; perform safe adapter action; persist effect receipt; acknowledge/archive queue message. Extend lease for legitimate long work. Crash/lease expiry results in reconciliation, not blind duplicate provider request. Dead-letter work is visible to operators/support with reason and safe retry after correction.

## Job catalogue

| Job | Dedupe / stale guard | Success / recovery |
| --- | --- | --- |
| Slot/shift materialization | template/version/date and resolved override | create coherent occurrences; compare future revisions, retain existing promises |
| Slot hold expiry | reservation ID and held state/deadline | release only expired uncommitted hold under occurrence lock |
| Slot release eligibility | occurrence revision/server time | expose planning work; never starts freelance broadcast |
| Parse/OCR/AI draft | draft ID/input hash/model config | suggestions only if input still current; per-row error/retry |
| Plan generation | plan input/policy hash | expiring proposal; stale result never auto-applies |
| Broadcast wave/expiry | broadcast revision/wave/deadline | eligible invitations or elapsed search; accepted/stopped prevents new offers |
| Change deadline | proposal/version/pending state | expire without changing original agreement |
| Notifications/push | event/recipient/channel/kind; freeze template snapshot on first intent | provider receipt or explicit unknown/failure; no operational success creation |
| Media verification | asset/object/hash/purpose | verified receipt or quarantine/retry; no evidence completion before verification |
| Source intake/reconcile | connection/event/source revision | normalized command or review-needed; no duplicate delivery |
| Writeback | connection/delivery/event/kind | current permitted mapping; reconcile ambiguous external effect |
| ETA refresh | entity/current route/destination version | provider estimate/provenance; stale results discarded |
| Trail finalize/downsample | work/version/source range | allowed derived trail; raw purged only under retention policy |
| Export | export ID/as-of/scope | private output; permission recheck on download |
| Retention/hold review | class/cutoff/hold revision | scoped purge/anonymization; blocked holds logged |
| Billing/usage reconcile | business event/meter/billing period | one ledger effect; corrections explicit |
| Provider webhook normalization | provider account/event ID/hash | authenticated unique receipt; event ordering rules enforced |

## Retry classification

For safe transient failures, schedule at most five retries after the initial attempt: delays of 5, 30, 120, 600 and 1800 seconds, measured from the failed attempt. After the sixth failed attempt total, enter recovery. No random jitter in the default policy. Stop at the job deadline. Use max(schedule delay, valid Retry-After); if beyond deadline, expire/recover without sending. Permanent validation or revoked-authority failures require correction, not automatic retries. Unknown/provider-accepted effects reconcile the original identity and never follow the resend schedule. Synchronous derive/internal actions do not use worker retries. ADR-J01 owns this engineering default; tenant configuration cannot turn unknown effects into resendable work.

## Adapter contracts

Adapter declares supported capabilities, auth/secret references, request/idempotency semantics, timeout behavior, status lookup, signature/replay handling, ordering/version policy, normalized receipt, retryability, rate limits and permitted retained data. Never put provider business logic into Driver/Dispatch frontend. No Lalamove active adapter dependency. Voice, AI, routing, payments and customer-channel provider choices are release-gated by actual credentials/field behavior.

## Operations and disaster replay

Monitor oldest actionable job, attempt distribution, dead letters and unknown external effects. Alert thresholds are in E09. Replay by original event/effect identity with dry-run/selection/authorization; never mass-repeat all notifications after database restore. Rebuild outbox from durable events only after reconciling consumer/provider receipts. An operator can inspect why work is stuck without exposing secrets or full identity documents.


## Integration ingress and receipts

The first-party adapter endpoint POST /v1/integrations/{connection_id}/events authenticates X-Rounds-Signature as base64 HMAC-SHA256 over timestamp + newline + event ID + newline + raw body bytes. Accept timestamps within 300 seconds of server time; compare signatures in constant time, bound body size before allocation, reject unknown/disabled connection, and support explicit secret rotation. Scope comes from the verified connection, never a tenant in payload. Unique (connection,event_id) plus request hash: same hash returns the existing receipt; changed hash returns IDEMPOTENCY_CONFLICT and quarantine. Persist receipt/raw private reference before 202; normalize asynchronously.

Native WooCommerce/Shopify/voice/KYC callbacks must be verified with their own documented signing format by an adapter before this normalization boundary; they cannot be sent directly as if they possessed the Rounds signature. Each native adapter remains disabled until its signing headers, replay identity, consent and provider-specific endpoint fixture are registered. No bearer-session fallback. Unrecognized update fields create review_required rather than dropping operational data.

Notification dedupe key is domain_event_id + recipient_id + channel + kind. Emit queued/provider_accepted/delivered/failed/unknown separately. Unknown external result reconciles before retry. A template rendering failure does not roll back delivered goods.


## Concrete service-action registry

SERVICE-ACTIONS.json supplies each action’s initiating event/timer, execution class, scope, dedupe identity and retry policy. Domain rules and target branches apply to that exact action. derive:* and internal:* entries are synchronous functions, not worker jobs. No placeholder worker:event_* producer is an implementation contract.

Worker retry defaults are 5s, 30s, 120s, 600s and 1800s; then recovery queue. Lease is 60s with 20s heartbeat. These are engineering retry defaults, not delivery promises. Provider-unknown outcomes reconcile the original request reference before any retry that could duplicate an external effect.

Raw-GPS retention runs hourly in batches through purge_expired_gps; it never turns off immutable triggers or impersonates a driver. Provider-specific extraction, voice, verification, billing and commerce actions remain disabled until their adapter contracts and launch settings are approved.

### QA-SYSTEM-WORKER-CRASH

Actor: Authorized actor for worker replay; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; plus parameters explicitly stated in steps.

When: Provider accepts notification; kill worker before receipt ack; visibility expires..

Then: Reconcile same effect key; at most1 provider effect; if provider cannot confirm, state unknown with manual action, not automatic resend..

Status: written requirement; application execution pending.

### QA-V21-NOTIFICATION-RETRY

Actor: Notification worker

Given: One eligible assignment.issued fact; first notification intent uses template version 1

When: Enqueue one event twice; change template from v1 to v2 and replay. Inject six safe transient failures, Retry-After beyond deadline and an unknown provider outcome.

Then: One intent per event/recipient/channel/kind retains template v1. Five retries after the initial attempt wait 5/30/120/600/1800 seconds; sixth total failure enters recovery. Deadline prevents further send. Unknown outcome reconciles original identity without automatic resend.

Status: written requirement; application execution pending.
