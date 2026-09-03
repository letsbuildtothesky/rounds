# Slice 2 · Checkpoint 05

**Status:** canonical existing-Round Stop movement implemented and database-verified; Slice 2 remains in progress

**Date:** 2026-09-03

## Canonical UX contract

- Operations continues to implement `ux/operations/rounds-operations-current-v45.html` as the visual and interaction contract.
- This checkpoint connects v45 `Move to another Round`: destination picker, consequence preview, and explicit confirmation.
- Stops are inserted at the first movable target position, matching the v45 interaction contract.
- No automatic planner, fake route, or client-authoritative committed state was added.

## Implemented

- Only future `assigned` Stops in an `approved` source Round can expose the move action.
- Source and target must be distinct approved own-team Rounds on the same service date and pickup location.
- Custody-confirmed, current, arrived, completed, or open-exception Stops remain locked pending the explicit custody-change policy.
- Preview recalculates only the source and target routes against each driver's current shift, vehicle profile, cargo limits, promise windows, and approved departure.
- The canonical drawer shows Stops before/after, added target time, target finish, promise fit, target driver, and empty-source removal.
- Confirmation reruns the same server calculation instead of trusting the browser preview.
- The command carries both expected Round versions and exact resulting Stop orders and route snapshots.
- Remote migration `202609030010` locks both Rounds, independently rechecks state/custody/order/route identity, safely renumbers both sequences, cancels an emptied source Round, updates both route snapshots, and records two audit entries plus one domain outbox event in one transaction. Migration `202609030011` adds independent active-own-team, fitting-capacity, and route-provider provenance guards.
- Command retries are idempotent and payload conflicts are rejected.

## Verification

- 121 TypeScript tests pass: 36 contracts, 70 API, 5 domain, 6 location ingest, and 4 Operations web tests.
- New API tests prove exact two-Round recalculation order, geometry-free command persistence, both expected versions, and custody blocking before the command gateway.
- New contract tests cover the dual-version command and reject same-Round/invalid-version requests.
- All workspace typechecks pass.
- The Operations production build passes.
- Remote migrations `202609030010` and `202609030011` applied successfully and linked local/remote migration histories match.
- The signed-in localhost browser loaded without a console-visible application failure. It currently has zero approved Rounds for the service date, so a two-Round UI acceptance is not claimed.
- Linked database lint did not return within the bounded verification window and was stopped. The migration itself was parsed and applied by the remote database; no fresh lint pass is claimed.

## Remaining Checkpoint B work

- Run signed-in visual/interaction acceptance when two eligible approved test Rounds exist.
- Complete any remaining connected v45 Round overview/detail actions before advancing to Checkpoint C.
