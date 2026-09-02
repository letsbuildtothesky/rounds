# Slice 1 checkpoint 14 — audited delivery return confirmation

## Delivered

- Added the explicit `operations.confirm_delivery_return` command and `POST /v1/operations/exceptions/:exceptionId/confirm-return` server boundary.
- Restricted the command to active tenant owners, Operations admins and dispatchers; viewers remain read-only.
- Constrained this outcome to a matching open delivery-stage `damaged_item` exception on an exception-blocked Stop in an active Round.
- Required an Operations evidence note and current Stop version before commit.
- Atomically marks the exception resolved, records the original delivery as `returned`, closes its delivery Stop as `cancelled` without false POD, increments versions, and emits audit and domain-outbox evidence.
- Added a separate v45 confirmation panel with explicit physical-truth copy. It does not pretend to schedule a future return or create replacement work.

## Verification

- API handler coverage includes dispatcher commit, viewer denial and missing-evidence rejection.
- Database acceptance covers authorization, stale version, canonical state transition, atomic states, audit evidence, outbox evidence, idempotency and direct-client RPC denial.
- API and Operations web type checks, tests and production build are required before this checkpoint is pushed.

## Deliberate boundary

This command records a return only after the merchant physically receives the damaged item. Ordering a future return, inserting a return Stop, creating replacement work, partial delivery and merchant-approved continuation remain separate consequential workflows with distinct physical and customer effects.
