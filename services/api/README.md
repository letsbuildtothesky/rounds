# Rounds command API

Pilot/Slice 1 server boundary for consequential Operations commands.

Implemented now:

- authenticated/internal health endpoints;
- `POST /v1/deliveries` canonical manual/internal intake;
- Supabase access-token verification;
- active tenant-membership authorization;
- server-created command/trace/aggregate IDs;
- validated command envelope;
- server-only `create_delivery_command` RPC;
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

## Commands

```bash
npm run test --workspace @rounds/api
npm run typecheck --workspace @rounds/api
npm run dev --workspace @rounds/api
```
