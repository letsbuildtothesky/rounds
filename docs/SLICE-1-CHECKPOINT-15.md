# Slice 1 checkpoint 15 — terminal return reconciliation

## Delivered

- Added a forward database migration that reconciles the parent Round after Operations confirms a physical delivery return.
- A Round now becomes `complete` when every assigned Stop is either delivered (`completed`) or formally closed (`cancelled`). A multi-Stop Round remains active while any operational Stop remains.
- Return results now expose the authoritative Round state and version alongside the returned Delivery and closed Stop state.
- The Driver no longer selects a previously completed or closed Stop as its next navigation target.
- The Driver completion board distinguishes delivered Stops from formally closed Stops instead of claiming every terminal outcome was delivered.
- The existing damage Action remains unresolved until a person truthfully confirms physical receipt; this checkpoint does not synthesize that event.

## Verification

- 48 API tests, 24 contract tests, 5 domain tests, 6 location-ingest tests and 4 Operations web tests pass.
- 55 Flutter tests pass, including terminal-outcome copy and closed-Stop navigation protection.
- All TypeScript workspace checks and Flutter analysis pass.
- The Operations production build succeeds.
- Forward migration `202609020007_complete_round_after_confirmed_return.sql` is applied to the linked Supabase project; local and remote histories match.
- Linked-schema lint reports no issue in the new command wrapper. Its output still contains Supabase/PostGIS extension diagnostics and the pre-existing unused-variable warning in `public.send_driver_message_command`.

## Deliberate boundary

This checkpoint records only an already-completed physical return. It does not order the driver to return, insert a return Stop, create replacement work or claim merchant receipt before a person supplies the required evidence note.
