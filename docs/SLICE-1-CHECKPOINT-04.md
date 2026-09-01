# Pilot / Slice 1 · Checkpoint 04

**Status:** Pickup manifest verification and first custody transfer implemented; Slice 1 remains in progress

**Date:** 2026-09-01

## Authorized scope

This checkpoint adds the English Own-Team pickup path after Round assignment. The Driver confirms every structured physical manifest line for every Stop in the assigned Round. Only the server can commit pickup, lock the manifest and transfer custody from the merchant location to the assigned Team driver.

## Implemented

- Shared `round.confirm_pickup` command/result/event contracts and strict line-confirmation validation.
- Durable `manifest_verifications` and `custody_events` evidence tables.
- Server-only, idempotent `confirm_round_pickup_command` transaction.
- Re-authorization of the active Team driver and exact Round assignment at commit time.
- Expected Round-version enforcement and stale-command rejection.
- Full-Round validation before any write, preventing partial custody for a multi-Stop pickup.
- Exact manifest ID/version and line-set checks; incomplete verification returns `EVIDENCE_REQUIRED`.
- Atomic manifest lock, merchant-to-driver custody events, Delivery `assigned → pickup_pending → in_custody`, Stop activation, Round activation, audit event and transactional outbox event.
- Authenticated Driver pickup API and English manifest checklist based on the canonical D03/D04 board.
- Pickup CTA remains disabled until every physical line is checked; a network/server failure never renders committed success.
- Operations Dispatch projection now shows assigned Rounds and server-committed custody progress.

## Verification

- 24 pgTAP assertions pass against linked development, including stale version, incomplete evidence, rollback, immutable lock, custody, audit, outbox, idempotency and direct-client denial.
- Linked migrations `202609010001` through `202609010008` align and remote schema lint reports no errors.
- A temporary authenticated Driver retrieved development Round `74532074-0b54-4050-a95c-510a53a5e936`, committed its exact manifest through the HTTP API and retrieved the Round as `active` with its Stop `active`.
- The same live record now has one pickup verification, one merchant-to-driver custody event, an `in_custody` Delivery and a `picked_up_locked` manifest.
- Temporary authentication identity was deleted after the test; no credentials were committed.
- TypeScript tests/typecheck, Next.js production builds, Flutter analysis and Flutter tests pass.

## Remaining gaps

- Offline pickup intent/outbox persistence is not yet implemented. When offline, the current client stays on the pickup screen and truthfully reports failure; it does not claim custody.
- Pickup Problem currently exposes the entry action but the durable structured exception record is still ahead.
- Physical Samsung testing remains required.
- Thai presentation remains deferred until the English execution loop is complete.

## Next checkpoint

Add the Driver offline command outbox and durable pickup-problem recovery, then implement server-authoritative arrival before handoff/POD.
