# Slice 2 Checkpoint 55 — authoritative current/future Stop map emphasis

Date: 2026-09-05

## Canonical sources used

- `CODEX-BUILD-ORDER.md`
- `specs/product/ROUNDS-SPEC-4-MAPPING-ADDRESS-INTELLIGENCE-v1.8.md`
- `specs/product/ROUNDS-SPEC-6-DISPATCH-ROUTE-EDITING-COMMS-v1.11.md`
- `specs/engineering/ROUNDS-ENGINEERING-ARCHITECTURE-v1.1.md`
- `specs/engineering/ROUNDS-IMPLEMENTATION-COVERAGE-AND-GAP-CONTROL-v1.0.md`
- `ux/operations/rounds-operations-current-v45.html`

The supplied v45 map uses numbered circles for Round Stops, orange for the
current Stop, navy for future Stops and reduced opacity for completed Stops.
The live app previously had real own-driver and exception/unplanned markers but
did not project the assigned Stop sequence onto the map.

## Implemented

- The Operations Action projection now returns one tenant-scoped batch of real
  assigned Stop order, state, delivery identity and saved destination pins.
- Stops without an authoritative saved coordinate are omitted rather than
  placed at a fallback location.
- Stop markers use the persisted Round sequence number.
- For an active Round, only the earliest non-terminal Stop is current.
- Approved/loading Round Stops remain future; completed/cancelled Stops remain
  visible but faded.
- An open action exception reuses its real Stop marker rather than stacking a
  second marker at the same coordinate.
- Own-driver markers retain the visually strongest stacking order.
- Clicking a numbered Stop opens the existing canonical Round workspace with
  that exact Stop selected.

## Acceptance

The signed-in localhost board loaded five numbered future Stops from the live
Supabase projection across four approved Rounds. Accessible labels exposed the
real Round, sequence, delivery reference and recipient. Clicking Stop 2 for
`B2-ROUND-B-0903` opened the Round workspace with `B2 Move Test C` and
`STOP 2 · #B2-MOVE-C-0903` selected.

The current live fixture contains no active Round. Current-Stop emphasis is
therefore proven by the deterministic selector test and remains open for live
physical acceptance rather than being simulated.

## Verification

- Contracts typecheck passes.
- All 103 API tests pass and API typecheck passes.
- All 32 Operations tests pass, including current/future/terminal selection.
- Operations TypeScript typecheck passes.
- Operations production build passes.
- Signed-in browser acceptance passes for real Stop projection and exact Stop
  selection.

## Still open

- Physical current-Stop emphasis acceptance with an actual active Round.
- Planned route, active-navigation leg and actual trail must remain separate;
  no line is inferred from Stop coordinates.
- Physical touch long-press and responsive-device comparison remain open.
