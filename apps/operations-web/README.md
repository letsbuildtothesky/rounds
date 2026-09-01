# Rounds Operations

Slice 1 Operations surface for authenticated UrbanFlowers staff, canonical manual delivery creation and explicit Team Round assignment.

## Local run

1. Copy `.env.example` to `.env.local` and use the local or development Supabase publishable key.
2. Start the Rounds API with its own environment configuration.
3. Run `npm run dev --workspace @rounds/operations-web`.

The browser signs in directly with Supabase Auth, then uses the resulting access token with the Rounds API. Tenant membership, pickup locations, Team drivers and unplanned deliveries are derived server-side. Dispatch can order compatible Stops and commit one approved Team Round. The UI never receives a Supabase secret/service key.
