# Slice 2 · Checkpoint 38

**Status:** Operations v45 surface parity correction across Dispatch, Drivers, History and intake

**Date:** 2026-09-04

## Correction

- Re-audits the running Operations app against the final
  `ux/operations/rounds-operations-current-v45.html` reference instead of
  extending an independently styled dashboard.
- Restores the canonical desktop shell proportions, light visual tokens,
  segmented Live/Plan control, 320 px laptop rail and 410 px contextual
  drawer.
- Keeps the real Mapbox operating surface, real own-team records and real
  planning actions while matching the reference hierarchy and control
  placement.
- Corrects Plan to the canonical one-row date navigation, Today action,
  planning subtitle and explicit draft/approval language.
- Rebuilds Drivers as the canonical command surface with connected own-team
  capacity, schedule and availability truth rather than prototype totals.
- Moves History into the shared v45 shell and restyles the connected terminal
  delivery ledger, evidence counts, filters and return notes to the canonical
  hierarchy.
- Reduces manual delivery intake to the canonical contextual drawer geometry
  and section rhythm while retaining the complete connected destination,
  promise and manifest contract.
- Removes unsupported claims such as automatic dispatch and on-time status.
  Weather, Network supply and unsupported history tabs remain visibly
  unavailable until real sources exist.

## Verification

- Localhost browser comparison covers the canonical and running Live and Plan
  boards at the desktop reference viewport.
- Browser acceptance confirms Dispatch, Drivers and History stay inside the
  same v45 application shell and History renders three connected terminal
  records without the legacy shell.
- Responsive rules prevent the rebuilt Drivers and History command surfaces
  from retaining desktop-only grids below 820 px and 700 px.
- All 169 repository tests pass.
- Operations TypeScript typecheck and the optimized Next.js production build
  pass.

## Explicit remaining boundaries

- Weather requires an approved live weather/radar provider and data contract.
- Network supply requires approved partner capacity data and belongs outside
  the connected own-team slice.
- Overview, driver-history and incident-history ledgers require their own
  server projections before those History tabs can become active.
- Automatic planning remains unavailable; current planning is explicit,
  capacity-checked and committed only after dispatcher approval.
