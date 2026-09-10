# W01 — Dispatch Now status tabs

Version 1.0 · 2026-09-10 · Bounded local implementation; full action and configured-provider acceptance remain open.

## Changelog

- 1.0 (2026-09-10): connect same-snapshot server categories/reasons to the approved Now status tabs, exact filters and current-city-day navigation; preserve the remembered Plan date and original report drafts.

## Baseline and authority

Baseline commit: `19d6c1e7dc570546026cfb41135fae74c6b4e23e`. Continue the existing React/Next.js repository and preserve accumulated work. Owning requirements: BS-03/12/13, P04 planning before arrival, P05 independent execution/custody/outcome axes, E03 finite read projections and ADR-Q07.

Unchanged [Phase39 HTML](../source/Rounds-Complete-Project-v2.3/ui/dispatch/index.html), SHA-256 `6a0019ec88cdaa422c5d56831d42f78745665de30681769a0d3515047fd1663c`. Static source anchors: bucket/statusText/nextAction around1971–1975, renderDeliveries5391 onward, status-tabs CSS201–207 and effective overrides1499–1502. Source markup and user-supplied screenshots were consulted. Original file-URL browser restriction was respected; no alternate original-source route or rehosting was attempted. Functional compiled-component captures below are not a pixel-parity certificate.

## Implemented

- [Server projection](../../services/api/src/v23/delivery-now-projection.ts) reads current whole-unit collection, current stop attempts, assignments and same-scope unresolved issues inside the existing restricted repeatable-read board transaction. Only finite category/reason values leave this layer; private issue details, driver identities and assignment IDs do not. Duplicate/invalid physical facts fail closed. The same transaction supplies the city-local current service date.
- [Board HTTP](../../services/api/src/v23/operations-issue-http.ts) supports opt-in `display=now` for delivery_board only. [E03](../source/Rounds-Complete-Project-v2.3/specs/engineering/E03-HTTP-API-AND-READ-PROJECTIONS.md), OpenAPI, generated wire/static validators, ADR-Q07 and P05 acceptance changed together. Original callers without the extension retain their exact shape. `display=labels` remains pickup-issues-only.
- Issue/dispute/unresolved states have Action priority. Actual whole-unit collection puts open work On road; this means recorded custody, not live GPS movement. Handoff awaiting completion retains its own label. Done preserves Delivered/Returned/Cancelled/Rescheduled rather than relabelling all outcomes as delivered. Review/hold/preparation/receipt/departure blockers stay explicit. Unknown/planned work is available through Show all and Plan, not made Ready. Ready is only a queue classification; each write must recheck its own product/authority rules.
- [Client adapter](../../apps/operations-web/src/v23/operations-delivery-board.ts) validates exact one-entry-per-delivery closure, finite reason/bucket agreement and current date before publishing. Opt-in follows immutable child date readers. Missing, duplicate, foreign or mismatched facts are rejected. Existing family-wide Auth denial, scoped last-known data, cancellation and late-response guards remain.
- [Now filters](../../apps/operations-web/src/v23/dispatch-now-pool.ts) use the exact server projection, search predicate and brand IDs for both rows and counts. No frontend status inference. [View](../../apps/operations-web/src/v23/delivery-board-view.tsx) uses source Action/Ready/On road/Done tabs, orange Action selected styling and actual reason labels. Keyboard Now/Plan navigation, date-reader focus and narrow footer wrapping are covered. Read-only details distinguish operational status from permission.
- [Workspace](../../apps/operations-web/src/v23/dispatch-workspace.tsx) opens Now on the server's current city day, retains the previously selected Plan date and creates/disposes immutable date readers. An old-day Now response is hidden with a reload explanation, including map points. Original-date pickup reports and unsent reply drafts keep their separate controller/journal and explicit date label.

## Compatibility and scope

No database schema, role/grant, encrypted mobile schema, existing media, command ID, original assignment or report-draft migration. No wider issue-detail disclosure. No new offline execution or automatic sends. No legacy root/feature-flag activation, phone installation, shared migration, deployment or push. English only; source assets and Thai references unchanged.

The Now **lists** are connected; individual operational decision workflows, intake, full delivery details, lanes and Save/Stage/Release are not completed here. Existing own-team pickup wait/escalate stays in the separately authorized report workflow. No placeholder action mutates a record or reports fake success. Configured Auth/SQL/Mapbox and installed-phone validation remain separate gates.

## Verification

[14 new Operations tests](../../apps/operations-web/test/v23-dispatch-now.test.ts) cover conservative Ready, every departure blocker, collection/handoff/terminal/issue precedence, unknown scheduled work, exact brand/search/counts, invalid projection closure, opt-in inheritance, last-known failures, denial and current-day mismatch. Existing presentation tests were updated for the optional Now controls.

[Focused PostGIS suite](../../services/api/test/v23/delivery-board.postgis.ts):25 tests PASS, including six new cases for extension compatibility/no writes/current day, issue linkage and archival/isolation, pre-arrival/declined/unknown work, collection/outcome classification, current versus cancelled/archived attempts and invalid collection timestamps. **One test executes the actual restricted pickup handler and then observes Ready → On road.** Handoff/completion branches in this reader suite are deliberately seeded read fixtures, not claimed as executed commands; existing arrival/POD suites separately exercise those commands. Auth is a labelled provider double; HTTP/SQL are real isolated components.

Frozen-code aggregate recorded10 September2026 at08:36:59 UTC:23/23 groups PASS, including212 Operations,479 PostGIS,201 API/foundation and618 full Flutter tests (435 native-subset cases included, not additional). API/Operations typechecks, Operations production build, SQLCipher process-kill and Android durability-barrier checks passed. Exact commands, logs and fingerprints are in [current results](generated/test-results.json); passing code does not close the unperformed acceptance gates above.

[Browser evidence](generated/dispatch-now-browser-check.json) uses compiled production React/controller code with synthetic HTTP/Auth/map. Action4/Ready2/On road2/Done2 and two scheduled orders; exact brand/search; actual Delivered/Returned labels; Escape detail dismissal; keyboard Now/Plan; empty12September and two-row11September; Now10September and remembered Plan11September; exact original10September reply text retained without sending. Network failure is labelled last-known; revoked board access removes all delivery/private-map content. Server fixture evidence recorded zero command POSTs.

Responsive review at1800×1100,768×1024 and390×844 measured zero document horizontal overflow. Captures after settled layout: [desktop](generated/dispatch-now/desktop-1800.png), [tablet](generated/dispatch-now/tablet-768.png), [narrow](generated/dispatch-now/narrow-390.png). The synthetic map port is a diagnostic test control, not geography or proposed artwork. Original-source overlay/pixel matching and real SDK/provider rendering remain unaccepted.

## Next

Connect the first individual Action workflow using its existing approved drawer and exact server command, then continue manual intake and plan/release work. Retain the source UI and validate each end-to-end workflow; do not treat these list categories as command eligibility or the whole Dispatch module as done.
