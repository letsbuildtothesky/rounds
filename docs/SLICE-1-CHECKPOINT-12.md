# Slice 1 checkpoint 12 — server-backed Round execution workspace

## Delivered

- Added `GET /v1/operations/rounds/:roundId`, protected by bearer identity and explicit tenant authorization.
- Added an ordered Round projection containing the assigned Team driver and vehicle, pickup, current position, Stop sequence, delivery promise and state, manifest lines, custody confirmation, arrival/completion timestamps, open exception counts and exact Stop communication thread.
- Connected the Dispatch Round drawer to a full v45 Round execution workspace.
- Added desktop ordered-Stop inspection and phone list-to-detail navigation.
- Kept the workspace read-only except for navigation to a real existing communication thread and local ID copy actions.

## Acceptance evidence

- Browser acceptance opened live tenant Round `ROUND-DEVICE-210002` from the Ready queue.
- The API returned its real assigned driver, vehicle, pickup, one ordered Stop, promise, destination pin, manifest, custody state and latest driver position.
- Desktop acceptance was checked at 1280 × 900.
- Phone Stop list, Stop selection and detail return were checked at 390 × 844.
- A Stop without a communication thread correctly showed a disabled `No Stop thread yet` action rather than fabricating a conversation.

## Verification

- `npm run typecheck --workspace @rounds/api`
- `npm test --workspace @rounds/api`
- `npm run typecheck --workspace @rounds/operations-web`
- `npm test --workspace @rounds/operations-web`
- `npm run build --workspace @rounds/operations-web`

## Deliberate boundary

This checkpoint does not add reassignment, cancellation, reordering or exception-resolution mutations. Those require explicit domain commands and audit semantics before their controls should exist.
