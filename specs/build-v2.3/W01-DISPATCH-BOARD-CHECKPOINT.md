# W01 — deliveries and pickup reports in the Phase39 Dispatch shell

Version 1.3 · 2026-09-10 · Bounded local implementation, not full Dispatch acceptance.

## Changelog

- 1.3: connect stored destinations and source-derived map controls; link current map evidence and preserve configured-provider, category and full-board gates.
- 1.2: connect delivery/context records to source-derived cards, local search and limited read-only details. Share verified Auth lifetime while preserving separate grants and the existing report journal. Record responsive/browser checks; map, category projection, full details/actions and source parity remain open.
- 1.1: add the separate ADR-Q06 delivery-board query and read-only browser adapter with restricted SQL/HTTP/privacy tests. No visible screen, map, shared data or phone change; UI mounting remains next.
- 1.0: mount the existing authorized pickup-report workflow in the source-derived Dispatch shell; add local search, responsive list/detail placement and tablet switching without changing the legacy root, contracts or data.

## Source and baseline

Baseline commit: `19d6c1e7dc570546026cfb41135fae74c6b4e23e`. The current working tree contains substantial earlier work; nothing was reset or replaced wholesale.

Design authority is the unchanged [Phase39 HTML](../source/Rounds-Complete-Project-v2.3/ui/dispatch/index.html), its final effective CSS rules and the user's four original screenshots from 10 September at 11:00–11:01. The original file-URL browser restriction was respected: no rehosting or alternate access. This is not a rendered-original diff or a claim of pixel parity. The existing approved bounded pickup reply form is reused, not a new general Communications board.

## Implemented code

- [DispatchWorkspace](../../apps/operations-web/src/v23/dispatch-workspace.tsx) and [scoped CSS](../../apps/operations-web/src/v23/dispatch-workspace.css): source header/wordmark/navigation, City context, rail, wide-screen detail and tablet surfaces. Prefixes prevent the preserved v45 global styles from overriding the new shell.
- [PickupIssueDrawer](../../apps/operations-web/src/v23/pickup-issue-drawer.tsx): same query/controller/journal and wait/escalate form, now with board placement. Report counts are explicitly **pickup reports**, not all deliveries. Revocation removes the selected identifiers, search and dialogs along with the private projection.
- [Local search](../../apps/operations-web/src/v23/pickup-issue-search.ts): searches only loaded authorized labels/reason/original IDs; no network request, global search, draft deletion or version rebase. Empty results, Clear search and return-focus behavior are explicit.
- [Default-off `/dispatch`](../../apps/operations-web/app/dispatch/page.tsx) uses the same [verified-login host](../../apps/operations-web/app/pickup-issues/pickup-issue-connection.tsx) and [allowlisted configuration](../../apps/operations-web/src/v23/operations-connection-config.ts) as `/pickup-issues`. Controller views are keyed by the entire scope. No environment secret is spread into browser props.

The configured `/dispatch` host now mounts actual authorized workspace/city labels from the delivery read; missing labels use neutral unavailable context, not prototype identities. Read failures mark retained information last-known; revocation removes private labels/counts. Drivers, History, Messages, Settings and Intercity are disabled with explanations. No fake counts, notification dots, user initials, sample deliveries, map coordinates, rain or provider status. The [bounded map connection](W01-DISPATCH-MAP-CHECKPOINT.md) now draws only stored authorized destinations through the actual SDK adapter, with explicit configuration/loading/failure states and source-derived controls. Live provider rendering and full Dispatch acceptance are not claimed.

### Mounted delivery view

[DeliveryBoardView](../../apps/operations-web/src/v23/delivery-board-view.tsx) uses Phase39's existing all-deliveries state (source `clearFilters`/`showAll`, not a new business bucket), final delivery-card CSS and detail-section primitives. Search covers only provided reference/recipient/address/site/brand display fields, preserves server order and does not send requests. Cards open limited read-only details: provided identity, promise window in its server timezone, pickup site and separately labelled raw state axes. Date-crossing windows include both actual dates. This is not the complete Delivery projection, verified entrance, current driver assignment, manifest or action eligibility.

Engineering presentation choice for this bounded read: keep the source Now/Plan/add positions disabled with reasons, label the displayed scope All deliveries, show the configured date read-only and omit unavailable Action/Ready/Road/Done counts/priority. Reuse source quiet/back-button primitives to enter/return from the already approved bounded pickup-report surface. No new modal style, icon library, artwork or product decision was introduced. This is an implementation subset, not approval of additional product states or complete visual parity.

The same verified-login host creates both readers with the exact principal/tenant/city/date/epoch. Auth change disposes both; an issue-grant denial does not turn an authorized delivery read into empty/error, and board.read does not grant replies. Scope mismatch refuses composition. Pickup reports keep their original controller and tab/login journal. Search/selection/resize/list-map navigation and report switching never submit or rebase a reply. Before-unload protection remains active while the report view is unmounted. On smaller screens, closing details waits for the replacement rail to render before returning focus.

### Delivery-board read (ADR-Q06)

- [Restricted projection](../../services/api/src/v23/delivery-board-query.ts) through [the existing HTTP boundary](../../services/api/src/v23/operations-issue-http.ts): explicit view=delivery_board, current board.read permission, exact tenant/city/service date and one repeatable-read snapshot. Requires no pickup report. Returns actual context/labels, total order count, raw readiness/preparation/outcome/evidence axes, stored destination/version and unique current-manifest Round/stop references. A point is not claimed verified; no route, GPS, receipt, full fleet or guessed Action/Ready count is synthesized.
- [Read-only browser adapter](../../apps/operations-web/src/v23/operations-delivery-board.ts): static generated validation,1MiB/15-second bounds, pinned account/epoch/scope, coalescing, immutable results and last-known failure state. Revocation/logout clears private memory; delayed or regressed replies cannot replace current data. No journal, command sender, persistent cache or automatic activation.
- Owning [ADR-Q06](../source/Rounds-Complete-Project-v2.3/specs/decisions/02-TRANSACTION-AND-PROVIDER-ADR.md), [E03](../source/Rounds-Complete-Project-v2.3/specs/engineering/E03-HTTP-API-AND-READ-PROJECTIONS.md), finite OpenAPI result and generated contracts/acceptance were updated together. Default Board and pickup_issues responses remain compatible. Source archive and116 UI/reference files are unchanged.

## Dependencies, migration and offline behavior

The new query variant adds no database migration/schema, command contract, legacy-ID mapping, storage format, Driver route, phone installation or feature-flag activation. All original designs, existing media, queues and applied migrations are preserved. The legacy `/` and standalone `/pickup-issues` remain available under their prior boundaries.

The new route is disabled unless `ROUNDS_V23_OPERATIONS_UI=1` and an isolated operator configures the exact API/principal/tenant/city/date and public Auth values described in [connection configuration](W01-PICKUP-UI-CHECKPOINT.md#dispatch-issue-connection-adr-q05). Configuration is not authority; API authorization is unchanged. A configured Auth/browser/SQL journey has not been accepted or enabled here.

The same tab/login journal persists editable drafts and immutable attempts before POST. Search, resize and tablet Map/List switching preserve drafts without sending. Unknown responses freeze the original reply and require status recovery. No offline permission cache, automatic send, background sync or guaranteed tab-close recovery is introduced. Actual dirty-browser reload and cross-tab logout acceptance remain open.

## Verification evidence

The latest map-extension evidence and current aggregate status are in the [map checkpoint](W01-DISPATCH-MAP-CHECKPOINT.md) and generated [test-results](generated/test-results.json). The following delivery-only evidence predates that extension and is retained as historical scope, not current-fingerprint certification.

Delivery-only aggregate recorded 10 September 07:11:04 UTC: **23/23 groups PASS**, including **165 Operations, 473 PostGIS, 201 API/foundation and 618 full Flutter tests** (435 native-subset cases included, not additional), production build, typechecks, native preservation/process-kill and Android durability checks. Configured-host and source-pixel acceptance remain separate.

Current mounted-view checks add [12 presentation tests](../../apps/operations-web/test/v23-delivery-board-view.test.ts): actual safe labels/counts/window, loading/empty/failure/stale/revocation, independent issue denial, scope mismatch, read-only search/draft preservation, missing names and historical outcomes without partial actions. Operations typecheck and all165 Operations tests passed in the focused run. Initial compile checks found a missing closing brace and a boolean effect cleanup; both were corrected before the passing run. Browser review also exposed focus return occurring before the tablet rail became visible; the final effect waits for rendering and was verified with Back and Escape. These are resolved implementation failures, not skipped checks.

The new [browser record](generated/dispatch-delivery-board-browser-check.json) covers actual compiled delivery UI with explicitly synthetic data, nine viewport sizes, no document overflow, source header/rail/detail measurements, search/selection, last-known/empty/removed/revoked reads and exact multiline report draft preservation across surfaces. No command POST occurred in that test server. The final clean browser tab reported no warnings/errors. [Desktop capture](generated/dispatch-delivery-board-desktop.png) and [tablet capture](generated/dispatch-delivery-board-tablet.png) are raw browser outputs. The screenshot provider painted them at reduced scale with extra blank area, and a later capture failed; they are not suitable for pixel measurement. DOM geometry is separately recorded, and original-source render/diff remains unaccepted. The supplied HTML was not rehosted or accessed through another control mechanism.

[Nine new Operations tests](../../apps/operations-web/test/v23-dispatch-workspace.test.ts) cover bounded composition, disabled unsupported controls, stale counts, authorization removal, local multi-term search, unchanged draft identity, unavailable labels, default-off/no-secret configuration and source geometry/scoping. They complement existing controller, journal, Auth, HTTP and restricted SQL tests rather than replacing them. Exact aggregate commands/results/fingerprints are in [test-results](generated/test-results.json).

Previous shell-only checkpoint, recorded 10 September 06:06:59 UTC:23/23 groups passed, including122 Operations,454 PostGIS,201 API/foundation and618 full Flutter tests (435 native-subset cases included, not additional). This historical run predates ADR-Q06 and does not verify the new delivery read. APK packaging and configured phone/provider acceptance were not part of it.

ADR-Q06 focused runs:31 browser transport tests and19 database-suite tests passed (18 subcases plus suite parent). The actual adapter→local Node HTTP→restricted PostGIS test reads synthetic orders and then proves access revocation clears the browser projection. Only provider identity is doubled there; HTTP, SQL, roles and adapter execute. Tests also cover no writes, exact city/date/archive isolation, pre-arrival states without receipt, contact privacy, same-city entrance binding, null/zero coordinates, duplicate active-stop database rejection, payload bounds, snapshot consistency and client stale/late/error guards. Two initial test-fixture failures hit existing unique constraints; the fixtures were corrected without weakening the database. Screenshots remain the earlier unchanged shell, not delivery-read UI evidence.

Previous delivery-read aggregate recorded10 September06:44:57 UTC:23/23 groups PASS, with153 Operations,473 PostGIS,201 API/foundation and618 full Flutter tests. This predates the mounted delivery view. The435 native-subset tests are included in618, not additional. Current aggregate evidence is in [test-results](generated/test-results.json); no APK, configured Auth/Storage, live phone or source-pixel acceptance is implied.

The earlier report-shell browser checks below used [the actual compiled component fixture](../../apps/operations-web/test/support/pickup-issue-review.tsx) at `?board=1`, with explicit synthetic report/Auth/HTTP data, real React, native fetch, sessionStorage and the actual legacy CSS loaded alongside the new CSS. The current mounted delivery checks use `?deliveries=1` and their separate record above. In both fixtures, the 44px synthetic-test banner sits above the application and is excluded from source-header measurements.

- Source desktop header rows measure 76px each; tablet rows measure 64px each.
- At 1800px the rail is 448px and the right detail is 400px. At 1600px the rail is 416px and the right detail remains 400px. Below 1600px detail replaces the rail; the final source override gives a 320px rail at widths through 1366px.
- Nine viewport checks from 320×640 through 1800×1000 show no document overflow and a reply footer ending at the viewport bottom. Tablet shows one selected list/detail/map surface, not compressed desktop columns.
- Local search can hide the selected row without discarding the detail/draft. Closing then returns focus to search; clearing restores the row. Dirty close → Keep → tablet Map/List → reopen preserves exact multiline instructions and reason.
- Synthetic POST response loss → frozen unknown result → status read displays the recorded instruction and restores heading focus. This is not a real customer send. The browser POST counter endpoint was not read; separate existing SQL/client tests assert one POST/decision.
- Final clean browser instance had no warning/error logs. Actual dirty-browser reload, configured provider/Auth/SQL host, original-source rendering and phone workflow remain unaccepted.

Actual captured images: [desktop](generated/dispatch-pickup-board-desktop.jpg), [tablet](generated/dispatch-pickup-board-tablet.jpg). [Measured browser evidence](generated/dispatch-pickup-board-browser-check.json). Images show synthetic component data, not the user's live workspace. The test server was stopped and the browser viewport restored after review.

## Next boundary

**Ready to implement next:** add the authoritative action/category projection required for Now/Plan controls before enabling those counts, then source intake/planning and actual RouteEstimate connections. Stored-destination map integration and source-derived controls are implemented in the bounded map checkpoint; actual provider acceptance and route/GPS/weather feeds remain open. No sample pins, receipts or readiness inference. Planning/release writes remain separate under BS-03; configured-host activation is not claimed.

**Still not accepted:** full Dispatch sections, planning/timeline, maps/layers/entrances, secure issue-photo viewing, configured browser-to-server login and phone flow, mapped legacy upgrade and original screen-by-screen comparison. Handle each under its owning build spec; passing this section does not close those gates.

**Deferred:** new Thai screens until English functional/visual acceptance; Intercity execution and other later-phase features per the release plan. No shared migration, deployment or push occurred.
