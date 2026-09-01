# Pilot / Slice 1 · Checkpoint 05

**Status:** Durable Driver command outbox, pickup exceptions and explicit arrival implemented; Slice 1 remains in progress

**Date:** 2026-09-01

## Authorized scope

This checkpoint continues the English-first Own-Team UrbanFlowers delivery loop. It adds the minimum Slice 1 exception needed to stop an unsafe pickup, makes destination arrival an explicit server command, and replaces local-only command success with a persistent SQLite outbox. Broader Slice 2 communications, exception resolution workflows and post-pickup live changes remain parked.

## Implemented

- Shared, validated contracts for `stop.report_pickup_problem` and `stop.confirm_arrival`.
- Stop aggregate versions in the authenticated Driver Round projection.
- Server-authoritative Team-driver endpoints:
  - `POST /v1/driver/stops/:stopId/pickup-problem`
  - `POST /v1/driver/stops/:stopId/arrival`
- Atomic database commands with active-Team authorization, aggregate-version checks, stable idempotency, audit events and transactional domain-event outbox records.
- Typed pickup problems: missing item, wrong item and damaged item. Reporting one interrupts ordinary pickup and moves the Stop/Delivery to explicit exception state without creating custody.
- Explicit arrival records with optional current-position evidence, accuracy/provenance and override reason. Delivery advances through the legal custody state path and the Stop receives an authoritative `arrived_at` timestamp.
- English Driver pickup-problem sheet with exact delivery selection, typed reason and optional note.
- Google Navigation arrival callback now reveals the Driver confirmation action but does not declare physical arrival by itself.
- SQLite Driver command outbox with the required durable envelope fields and states: pending, sending, blocked dependency, conflict, committed and terminal failure.
- Pickup, pickup-problem and arrival requests are written locally before network send, retain one idempotency key across retries, survive relaunch and never display committed success before server acknowledgement.
- Session restore/sign-in flushes pending commands in causal creation order. Authentication loss preserves the outbox.
- Operations assigned-Round projection exposes open exception counts and highlights Rounds needing Operations attention.
- Forward migration `202609010009_driver_exceptions_arrivals.sql` applied to the linked development project.

## Verification

- Contract tests validate typed pickup problems, bounded notes, Stop versions and optional arrival position evidence.
- API tests cover command construction, assigned-Team authorization and denial outside the assigned Round.
- Flutter tests cover honest pending arrival plus SQLite process-close/reopen persistence and duplicate enqueue deduplication.
- Linked pgTAP adds 28 assertions for authorization, stale-version rejection, legal transitions, evidence, audit/outbox records and idempotent retries.
- All linked database tests execute in rollback transactions and linked `public` schema lint reports no errors.
- Live authenticated development smoke test committed arrival through the real TypeScript API for Round `74532074-0b54-4050-a95c-510a53a5e936` and Stop `ff191a74-be9d-4602-b2c5-8873e8769725`; the server returned HTTP 201, the Stop is `arrived`, and exactly one durable arrival record exists.
- The temporary smoke-test authentication user and identity link were removed. No password, access token or service secret was committed.

## Deliberate remaining gaps

- SQLite now durably protects consequential commands, but the full assigned-Round/manifest offline read cache, GPS buffer unification and media dependency graph still need to grow with POD.
- Pickup exceptions are visible to Operations, but evidence photo upload, chat and Operations resolution are later exception/communications depth.
- Arrival currently accepts optional evidence; the Flutter command does not yet attach the last road-snapped coordinate. The server and contract are ready for that wiring after physical-device accuracy validation.
- Handoff verification, resumable POD upload/commit, Stop/Delivery completion and History remain ahead in Slice 1.
- Thai presentation remains intentionally deferred until the English operational loop works end to end. It will be one localized application, not a second codebase.
- Production security/data-retention hardening remains tracked in `docs/SECURITY-HARDENING-BACKLOG.md` as previously authorized for later completion.

## Next checkpoint

Implement handoff verification plus the two-phase, resumable POD evidence path, then commit Stop/Delivery completion and expose the evidence in Operations History.
