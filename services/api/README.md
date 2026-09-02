# Rounds command API

Pilot/Slice 1 server boundary for consequential Operations commands.

Implemented now:

- authenticated/internal health endpoints;
- `POST /v1/deliveries` canonical manual/internal intake;
- `GET /v1/operations/deliveries` tenant-scoped canonical delivery list and detail projection;
- `GET /v1/operations/planning` purpose-limited unplanned delivery and Team-driver projection;
- `POST /v1/rounds` manual ordered Team Round approval;
- `GET /v1/driver/session` authenticated assigned/current Round projection;
- `POST /v1/driver/rounds/:roundId/pickup` exact manifest verification and custody commit;
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

## Commands

```bash
npm run test --workspace @rounds/api
npm run typecheck --workspace @rounds/api
npm run dev --workspace @rounds/api
```
