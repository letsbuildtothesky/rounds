# Slice 2 · Checkpoint 27

**Status:** canonical G03 package-problem subtypes implemented through Driver,
API and PostgreSQL

**Date:** 2026-09-04

## Implemented

- Replaced the approximate G03 presentation with one generated measurement
  contract sourced from the supplied English and Thai v3 boards.
- Implemented the canonical initial, evidence and waiting compositions,
  including the three issue rows, package/custody record, evidence summary,
  fixed action area and inset bottom action drawer.
- Added the real `damaged_item`, `missing_item` and `wrong_item` categories to
  the shared command contract. Missing-package reports require no photo;
  damaged and wrong-package reports require retained and server-verified photo
  evidence.
- Preserved category, note and photo drafts on the phone and kept offline work
  in the existing durable outboxes.
- Applied migration `202609040002_driver_delivery_problem_categories.sql` to
  the linked Supabase project. It preserves assignment, custody, manifest,
  expected-version, idempotency, audit and event invariants for every subtype.
- Kept the waiting state honest. The app does not show the prototype's
  simulated resolution because GAP-006 has not defined missing/wrong package
  dispositions.

## Verification

- Flutter static analysis passes with no issues.
- All 129 Driver tests pass, including English/Thai G03 geometry, subtype photo
  rules, restart draft behavior and the canonical bottom drawer.
- All workspace TypeScript tests pass: Operations 8, contracts 44, domain 5,
  API 90 and location ingest 6.
- Workspace TypeScript typechecking passes.
- The generated Driver metrics freshness check passes.
- The linked Supabase migration is applied, and the Android debug APK builds,
  installs and launches on the connected Samsung SM-S928B.
- A Samsung debug-preview pass covered the English initial state, damaged-photo
  evidence state and inset action drawer. It caught a horizontally shrinking
  photo panel; the panel now uses the board's full 349 px content width and a
  regression assertion locks both width and height.

## Honest remaining boundary

- Thai and waiting-state physical comparison plus live arrived-Stop submissions
  for all three subtypes are still required.
- Reinstalling the normal APK returned the phone to its protected login screen;
  this checkpoint does not embed private pilot credentials or bypass release
  authentication to manufacture a screenshot.
- Only the existing damaged-item physical-return path has an approved terminal
  reconciliation. Missing and wrong-package outcomes stay on Operations hold
  until GAP-006 is decided.

## Next safe work

- Perform the G03 signed-in physical acceptance when the pilot Driver session
  is available, then continue the remaining authorized own-fleet closure items
  in the coverage control without promoting Network or inventing unresolved UX.
