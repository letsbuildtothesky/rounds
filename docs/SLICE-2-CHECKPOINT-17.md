# Slice 2 · Checkpoint 17

**Status:** versioned own-team E04–E06 live Round change implemented

**Date:** 2026-09-03

## Implemented

- Operations can change only the product-authorized post-pickup fields: future Stop sequence, destination text and confirmed coordinate, entrance/handoff instruction, and promised window.
- Every draft receives a fresh server route calculation before Apply. The preview exposes the real before/after destination and sequence plus ETA, distance, duration, downstream, promise and shift consequences.
- Apply recalculates again and commits the full Stop order, destination version, promise, route snapshot, audit record, system message and event through one tenant-scoped, versioned and idempotent database command.
- The command requires an active assigned own-team Round, verified pickup, a locked physical manifest, no open exception and exact current Round/Stop/destination versions. It cannot alter manifest lines or custody.
- The Driver App restores the server-authored pending change, shows the supplied measured E04–E06 before/after surface, offers the real Operations contact path and sends a durable Driver-only acknowledgement.
- The Operations Round detail exposes the latest change as `Awaiting driver` or `Driver acknowledged`; acknowledgement is also recorded in the shared communication, audit and event ledgers.
- A quiet authenticated Driver session refresh lets a newly committed update appear without restarting the application.

## Verification

- All 134 TypeScript tests pass and workspace TypeScript typechecking is clean.
- All 94 Flutter tests pass; Flutter analysis and the generated-metrics drift gate are clean.
- The Operations production build compiles successfully.
- The Supabase migration was parsed and applied to the linked project. Linked lint reported only the pre-existing PostGIS/search-path warnings.
- The debug APK builds, installs and launches without a Flutter or Android runtime exception on the connected Samsung SM-S928B.
- Automated tests cover actual before/after route consequences, exact future Stop reordering, stale-version rejection, authenticated Driver-only acknowledgement, the measured Driver geometry and representation of every authorized changed field.

## Honest remaining boundary

- No active live demo Round existed during this checkpoint, so the complete signed-in Operations Apply → physical Driver acknowledge → Operations observed transition has not yet been exercised end to end.
- The Operations drawer currently accepts the confirmed latitude/longitude directly. The canonical map-based pin selector remains to be connected before visual acceptance.
- The database pgTAP scenario is authored, but the local runner requires Docker Desktop, which was not available. The migration itself was successfully applied to the linked Supabase project.
- Network paid add-Stop acceptance/decline and fare consent are later-slice behavior and were deliberately not implemented in this own-team change command.
- Final road, degraded-network, background, iOS and supported-device acceptance remain open.

## Next safe work

- Create or advance an explicit live multi-Stop test Round and perform the complete E04–E06 acknowledgement loop, then connect the canonical Operations map pin picker and continue the remaining G01/G04/G05 custody exception outcomes.
