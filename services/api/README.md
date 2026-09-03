# Rounds command API

Pilot/Slice 1 server boundary for consequential Operations commands.

Implemented now:

- authenticated/internal health endpoints;
- `POST /v1/deliveries` canonical manual/internal intake;
- `GET /v1/operations/deliveries` tenant-scoped canonical delivery list and detail projection;
- `GET /v1/operations/rounds/:roundId` tenant-scoped ordered Round, Stop, custody, manifest, exception and communication truth;
- `POST /v1/operations/exceptions/:exceptionId/resolve` audited pickup-correction release back to assigned work;
- `POST /v1/operations/exceptions/:exceptionId/confirm-return` audited confirmation that a delivery-stage damaged item is physically back with the merchant;
- `GET /v1/operations/planning` purpose-limited unplanned delivery and Team-driver projection;
- `POST /v1/rounds` manual ordered Team Round approval;
- `GET /v1/driver/session` authenticated assigned/current Round plus the Driver's tenant-scoped completed Team Round history;
- `POST /v1/driver/shifts/start` explicit, idempotent Team shift attendance start against the server-resolved effective schedule;
- `POST /v1/driver/rounds/:roundId/pickup` exact manifest verification and custody commit;
- `POST /v1/driver/stops/:stopId/contact-attempts` audited native-phone outcome selected by the assigned Driver;
- `POST /v1/driver/stops/:stopId/location-problem` typed pickup/delivery location observation with optional real-device GPS evidence and an explicit Operations hold;
- Supabase access-token verification;
- active tenant-membership authorization;
- server-created command/trace/aggregate IDs;
- validated command envelope;
- server-only `create_delivery_command` RPC;
- server-only `plan_and_approve_round_command` RPC;
- server-only `confirm_round_pickup_command` RPC;
- structured JSON request logs.

The API requires an explicit `APP_ENV`. Copy `.env.example` to an ignored local `.env` and use environment-specific secrets. Never expose `SUPABASE_SECRET_KEY` to Next.js or Flutter.

## Delivery request

Headers:

```text
Authorization: Bearer <Supabase access token>
x-rounds-tenant-id: <active tenant UUID>
Idempotency-Key: <stable key for this create intent>
x-trace-id: <optional UUID>
```

Body is the `CreateDeliveryPayload` contract from `@rounds/contracts`. The API derives the actor from the verified Supabase session and active membership; actor identity and role are never accepted from the request body.

Round approval uses the same headers and a `PlanRoundPayload`. Stop order is explicit. The database validates that every Stop is unplanned, pending, on the same service date and pickup location, and that the selected driver has an active Team relationship.

Pickup confirmation is Driver-only. The API derives the Driver, tenant and
current Round from the access token. The request carries every assigned Stop's
manifest ID/version and exact confirmed line numbers. The database validates
the complete Round before creating verification/custody evidence or changing
any state.

Location-problem reporting is deliberately observation-only. The server
snapshots the authoritative pickup or destination, preserves the locked
manifest and destination version, and creates an audited Operations exception
and thread entry. Existing generic exception resolvers are blocked from
resolving these categories until the address-correction and Driver-
acknowledgement policies in GAP-006/GAP-007 are approved.

Contact-attempt reporting records the Driver-selected result of a native phone
handoff (`reached`, `no_answer`, `busy` or `call_failed`). It is not carrier or
telephony-provider proof. Each attempt is authenticated, tenant-scoped,
versioned and idempotent, and is projected into both the Driver Stop ledger and
the Operations communication thread without changing Stop or custody state.

The Driver session includes up to 30 completed Team Rounds assigned to that
Driver. History is derived from authoritative Round/Stop state, durable POD
records and the immutable planned route snapshot. Planned distance and duration
remain explicitly labelled as planned; Network fares and actual route metrics
are never inferred.

The same session exposes the authenticated Driver's active Team name and the
existing assigned vehicle label/plate for the read-only Team profile. It does
not infer verification, Network membership, payout details or editable account
authority.

For a scheduled Team Driver, the session also exposes the current local service
date's effective recurring/date-exception shift and any committed attendance.
Starting that shift uses server time as operational truth, retains device time
only as evidence, and never changes schedule, assignment or custody state.

## Commands

```bash
npm run test --workspace @rounds/api
npm run typecheck --workspace @rounds/api
npm run dev --workspace @rounds/api
```
