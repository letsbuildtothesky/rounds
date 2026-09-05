# Slice 2 Checkpoint 49 — real v45 History CSV export

Date: 2026-09-05

## Canonical sources used

- `specs/product/ROUNDS-SPEC-9-HISTORY-OPERATING-MEMORY-v1.5.md`
- `specs/engineering/ROUNDS-IMPLEMENTATION-COVERAGE-AND-GAP-CONTROL-v1.0.md`
- `ux/operations/rounds-operations-current-v45.html`

SPEC-9 requires History Export to produce a real machine-readable file instead
of a decorative success toast. This checkpoint connects that behavior only to
the durable own-fleet delivery-history projection available in the active
slice. It does not copy illustrative incident rows from the prototype.

## Implemented

- The canonical v45 History header now includes `Export CSV` beside Refresh.
- Export is disabled until at least one authoritative terminal record loads.
- The generated UTF-8 CSV contains:
  - occurrence timestamp;
  - delivery and Round references;
  - recipient, address and Driver;
  - delivered/returned outcome;
  - handoff and receiver truth where applicable;
  - verified photo count and manifest version;
  - damaged-item category, Driver report and Operations resolution where
    applicable.
- Every cell is quoted and embedded quotes are escaped. A UTF-8 BOM preserves
  Thai and other Unicode text in common spreadsheet applications.
- The dated filename uses the tenant calendar timezone.

## Acceptance

The signed-in localhost v45 History workspace loaded three real terminal
delivery records without error and exposed one enabled `Export CSV` action.
The pure export tests verify its header, Unicode-ready encoding, comma/quote
escaping, delivered handoff fields and returned-item resolution evidence.

## Verification

- All 23 Operations tests pass.
- Operations TypeScript typecheck passes.
- Operations production build passes.

## Still open

- Durable incident, Driver-history and management-overview projections remain
  required before their supplied tabs and combined incident export can be
  enabled.
- Batch delivery import remains blocked by `GAP-008`; no CSV intake template or
  partial-failure behavior has been invented here.
