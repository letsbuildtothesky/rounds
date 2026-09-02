# Slice 1 checkpoint 13 — audited pickup exception resolution

## Delivered

- Added the `operations.resolve_exception` command and `POST /v1/operations/exceptions/:exceptionId/resolve` server boundary.
- Restricted resolution to active tenant owners, Operations admins and dispatchers; viewers remain read-only.
- Constrained this first resolution to a corrected pickup issue on a matching open exception, blocked Stop and approved/loading Round.
- Required an Operations evidence note and current Stop version before commit.
- Atomically marks the exception resolved, timestamps it, returns the Stop and delivery to `assigned`, increments versions, and records both audit and domain-outbox evidence.
- Added the v45 resolution panel to the existing Action drawer with explicit consequence copy and no generic or fake resolution options.

## Verification

- 43 API tests passed, including dispatcher commit, viewer denial and missing-note rejection.
- 4 Operations web tests passed.
- API and Operations web TypeScript checks passed.
- The production Operations web build passed.
- Migration `202609020003_operations_exception_resolution.sql` was applied to the linked Supabase project.
- Linked remote `public` schema lint returned no errors and the local/remote migration histories match.
- The live tenant Action queue refreshed successfully after deployment and currently contains no unresolved exceptions.

## Database acceptance

`supabase/tests/008_operations_exception_resolution_test.sql` covers stale-version rejection, viewer denial, atomic state restoration, audit evidence, outbox evidence, idempotent retry and denial of direct authenticated-client RPC execution. Local pgTAP execution requires Docker and remains enforced by CI; Docker is not installed on this workstation.

## Deliberate boundary

This command only releases a corrected pre-custody pickup issue. Delivery-stage damage, cancellation, return-to-pickup and reassignment require separate explicit commands because their physical custody and customer consequences differ.
