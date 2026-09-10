# W01 — Dispatch Plan list and safe date switching

Version 1.0 · 2026-09-10 · Bounded local implementation; not full planning or production acceptance.

## Changelog

- 1.0 (2026-09-10): connect the approved Plan date/queue/brand controls to actual scoped reads, preserve original report drafts and test date/auth races. No new design, API contract, schema or phone cutover.

## Baseline and design authority

Baseline commit: `19d6c1e7dc570546026cfb41135fae74c6b4e23e`. Continue the existing React/Next.js workspace and Flutter repository; preserve accumulated changes. Owning requirements: BS-03/12/13, P04 pre-arrival planning, P05 independent state axes and ADR-Q06 finite authorized delivery read.

Unchanged [Phase39 HTML](../source/Rounds-Complete-Project-v2.3/ui/dispatch/index.html), SHA-256 `6a0019ec88cdaa422c5d56831d42f78745665de30681769a0d3515047fd1663c`. Source controls: nowTab/planTab/planDateInput, plan-queue-tabs and plan-brand-filter; effective CSS1480–1516, earlier queue primitives1099–1107 and source renderDeliveries. Static source and supplied screenshots were consulted. The original file-URL restriction was respected; no alternate original-source browser route or rehosting was attempted.

## Implemented code and engineering decisions

- [Plan filters](../../apps/operations-web/src/v23/dispatch-plan-pool.ts): same search and exact brand-ID predicates feed list rows and counts. Unplanned is an open order with no server-projected current-manifest planning reference. Unknown/preparing/held/inbound work remains visible; no receipt or readiness is invented. All includes every returned unarchived order with truthful raw outcome, including historical terminal records; it is not an eligibility list for a write command. Equal brand names never join different brand IDs.
- [Delivery view](../../apps/operations-web/src/v23/delivery-board-view.tsx) and [scoped CSS](../../apps/operations-web/src/v23/dispatch-workspace.css): existing Plan tab/date/Unplanned/All/brand controls, source spacing and selected states. All is initially selected to preserve the prior complete read. Search/brand filters update counts together. Removed brands remain explicitly selected with an empty result until cleared. Empty date, empty filter, initial failure, same-date last-known and revoked access remain distinct. Date keyboard focus returns after scope replacement.
- [Read adapter](../../apps/operations-web/src/v23/operations-delivery-board.ts): forServiceDate creates a fresh immutable scope with the same origin, principal, tenant, city and login epoch. No private prior-date data is inherited. The parent owns child-reader authorization lifetime; denial on any reader clears the entire delivery family. Disposing one obsolete date aborts only that read, discards late responses and detaches it. No mutable scope, persisted date cache or bearer exposure is added.
- [Workspace](../../apps/operations-web/src/v23/dispatch-workspace.tsx): date changes replace/dispose the owned date reader without replacing the separate report controller or journal. Selection/search/brand/map are reset for a new date. Reports remain bound to their original date and commands; a differing date is explicitly included on the Pickup issues link. Same-date refresh preserves filter and selection. Map continues to show the full authorized date context, not a silently filtered or speculative route.

The view says **Read-only plan list**. Now/Action/Ready/On road/Done require authoritative issue/execution projections and remain disabled. Add, route proposals, lanes, Save/Stage/Release, current-driver assignment and release eligibility are not implemented by this checkpoint. This is a useful connected part of Plan, not a completed Plan module. No business rule or missing-state artwork was invented to enable a deferred control.

## Dependencies and compatibility

Uses the existing default-off verified-login host and ADR-Q06 board.read API. No HTTP/wire/schema/local-storage migration, widened grants, new credentials, shared database writes, legacy ID remap or phone installation. Existing report command IDs, bytes, original dates and draft storage remain unchanged. Network failure on a new date cannot borrow another date's rows; refresh failure may retain only labelled same-date last-known data. No new offline execution authority or automatic sends.

## Acceptance and evidence

[16 new tests](../../apps/operations-web/test/v23-dispatch-plan-pool.test.ts) cover the Plan predicates, all raw readiness/preparation values, historical outcomes, staged awaiting-receipt work, exact brand IDs/counts/order, fresh/invalid/empty dates, late reads, child/parent disposal, family-wide authorization denial, changed login and same-date versus other-date failure. Existing [presentation tests](../../apps/operations-web/test/v23-delivery-board-view.test.ts) now assert the connected Plan controls and disabled mutation/Now surface. The [real local HTTP/PostGIS integration test](../../services/api/test/v23/delivery-board.postgis.ts) exercises switching to an empty date and back, no domain writes and cascading grant revocation through the actual browser adapter. Auth is a labelled provider double; SQL/HTTP are real isolated components.

Final frozen-code aggregate recorded10 September2026 at08:14:09 UTC:23/23 groups PASS, including198 Operations,473 PostGIS,201 API/foundation and618 full Flutter tests (435 native-subset cases included, not additional). Operations typecheck and production build, SQLCipher process-kill and Android durability-barrier checks passed. See [current results and fingerprints](generated/test-results.json). These are local automated checks, not configured-provider, phone or visual-parity acceptance.

[Browser evidence](generated/dispatch-plan-browser-check.json) uses compiled React/controller/native fetch against an explicitly synthetic HTTP/Auth/map fixture. Checked Unplanned11/All12, brand-filter1/1, two rows on11 September, genuinely empty12 September, original10 September pickup reply draft preserved exactly, explicit Keep and close, offline last-known failure and denied-access removal. No command POST occurred. Browser date fill alone did not dispatch a React change in this environment; committing with the native keyboard stepper did, and returned header/date/rows were checked. No claim is based solely on a text-field value.

Responsive review:1800×1100 desktop,768×1024 tablet and390×844 narrow, with zero document horizontal overflow at each measured size. Captures were taken after layout settled (the first immediate post-resize image was superseded). [Desktop](generated/dispatch-plan-pool/desktop-1800.png), [tablet](generated/dispatch-plan-pool/tablet-768.png), [narrow](generated/dispatch-plan-pool/narrow-390.png). The diagnostic map port is not geography or proposed product artwork. Source screenshot pixel parity, configured Mapbox/Auth/SQL and full planning interaction acceptance remain open.

## Next

Implement the authoritative Now category/action facts and their source tabs, then intake/planning proposals and explicit Save/Stage/Release. Preserve unknown physical state and do not use a list filter as command authorization. Phone/Thai work is unchanged; no deployment, shared migration or push.
