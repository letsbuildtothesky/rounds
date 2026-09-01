# Rounds Operations

Slice 1 Operations surface for authenticated UrbanFlowers staff, canonical manual delivery creation, explicit Team Round assignment and server-committed pickup custody progress.

## Local run

1. Copy `.env.example` to `.env.local` and use the local or development Supabase publishable key.
2. Start the Rounds API with its own environment configuration.
3. Run `npm run dev --workspace @rounds/operations-web`.

The browser signs in directly with Supabase Auth, then uses the resulting access token with the Rounds API. Tenant membership, pickup locations, Team drivers, unplanned deliveries and active Round custody counts are derived server-side. Dispatch can order compatible Stops and commit one approved Team Round, then see when the assigned Driver has committed custody. The UI never receives a Supabase secret/service key.
