# Slice 2 · Checkpoint 06

**Status:** canonical existing-Round Stop movement accepted against the live linked project; Slice 2 remains in progress

**Date:** 2026-09-03

## Live acceptance

- Created three clearly labelled acceptance deliveries: `B2-MOVE-A-0903`, `B2-MOVE-B-0903`, and `B2-MOVE-C-0903`.
- Configured the demo motorbike profile as an explicit two-Stop `multi_stop` profile and classified the three test items as `bouquet` with an approved demo limit. This replaces the migrated review-only default for the demo tenant; it is not an inferred production capacity.
- Approved `B2-ROUND-A-0903` with two Stops and `B2-ROUND-B-0903` with one Stop through the signed-in Operations UI.
- Opened the canonical v45 Round workspace, chose `B2-MOVE-A-0903`, selected the target Round, and received a server-authoritative preview showing target load `1 → 2`, `+7 min`, `+0.8 km`, target finish `12:00 → 12:03`, and fitting window/capacity checks.
- Confirmed the move through the UI. The source now contains `B2-MOVE-B-0903`; the target contains `B2-MOVE-A-0903`, then `B2-MOVE-C-0903`.
- Both Round versions advanced from 1 to 2. The command idempotency record is committed, with two audit events and one `round.stop_moved` outbox event.

## Routing defects found and fixed

- Mapbox rejects fractional seconds in `depart_at`; the provider boundary now normalizes JavaScript ISO timestamps to RFC 3339 whole seconds.
- Automatic current-day planning no longer sends the browser preview's already-aging departure back as an explicit departure during approval. The server calculates the committed departure at approval time.
- Existing approved Rounds whose saved departure has passed now recalculate from live time during a pre-custody Stop move. A genuinely future dispatcher-selected departure remains preserved.

## Verification

- 122 TypeScript tests pass: 36 contracts, 71 API, 5 domain, 6 location ingest, and 4 Operations web tests.
- New coverage proves Mapbox departure normalization, server-owned automatic approval departure, and live-time recalculation for an unstarted current-day Round.
- All workspace typechecks pass.
- The Operations production build passes.
- `git diff --check` passes.
- Signed-in browser acceptance and linked-database verification both pass for the real two-Round move.

## Remaining Checkpoint B work

- Continue the v45 inventory from the next unconnected Round overview/detail action.
- Keep using the supplied English/Thai driver boards and canonical Operations v45 file as UX contracts; do not invent substitute screens.
