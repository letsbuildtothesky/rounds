# Slice 2 Checkpoint 47 — Operations Contact History ledger

Date: 2026-09-05

## Canonical sources used

- `specs/build/BS-10.md`
- `specs/product/ROUNDS-SPEC-2-BUSINESS-PRODUCT-MASTER-v2.26.md`
- `specs/product/ROUNDS-SPEC-6-DISPATCH-ROUTE-EDITING-COMMS-v1.11.md`
- `specs/product/ROUNDS-SPEC-8-OPERATIONS-VISUAL-SYSTEM-v1.15.md`
- `ux/operations/rounds-operations-current-v45.html`

The implementation follows the supplied v45 Contact History drawer, summary,
filter and audit-row structure. It does not add another chat surface or enable
the illustrative call prototype.

## Implemented

- The Communications header's Contact history action now opens its own v45
  right drawer for the selected Driver/Stop instead of leaving context for the
  unrelated global delivery History workspace.
- The Operations communications projection includes the real typed native
  recipient/Operations call attempts already committed by the assigned Driver.
- The ledger composes persisted Driver, Operations and system messages,
  location/photo/file/voice content and typed contact attempts in reverse
  chronological order.
- `All`, `Messages`, `Calls` and `Files & media` filters use the supplied v45
  control and row geometry. Summary counts are derived from those same rows.
- Typed call attempts replace their generated system-message projection, so one
  call is not shown twice. The outcome remains explicitly Driver-recorded rather
  than carrier-verified.
- The Message driver and Back to Round actions preserve the existing operational
  context. Call driver remains disabled because a real dispatcher-to-driver VoIP
  provider and lifecycle have not been connected; no fake call event is written.

## Acceptance

The signed-in localhost board loaded a real Operations thread and opened the new
Contact history drawer beside the canonical 438 px Communications window. The
real ledger showed 20 persisted events for that thread, with 12 messages and 8
files/media. `Files & media` displayed exactly eight rows, the empty `Calls`
filter truthfully displayed no call events, and Close returned to the live board.
The linked database currently contains zero typed contact attempts, so the live
call count of zero is authoritative rather than seeded prototype data.

## Automated verification

- All 18 Operations tests pass, including ledger composition, filtering and
  generated-system-call de-duplication.
- All 100 API tests and all 49 contract tests pass.
- All repository TypeScript typechecks pass.
- The Operations production build passes.

## Still open

- Integrate the specified dispatcher-to-driver in-app VoIP lifecycle only after
  its real provider/signaling/push architecture is approved and connected.
- Record and accept at least one real typed contact attempt in the Operations
  ledger during physical end-to-end testing.
- Complete the normal-browser Operations voice capture/send and file-popup
  acceptance passes.
- Resolve GAP-009 before claiming a production committed-media retention rule.
