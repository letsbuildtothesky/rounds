# W01 — authorized delivery map and Phase39 controls

Version 1.0 · 2026-09-10 · Bounded local implementation; live provider and full-board acceptance remain open.

## Changelog

- 1.0 (2026-09-10): connect the Mapbox SDK to the authorized delivery reader and port source-derived map controls. Record real component tests with an explicitly synthetic map port, safety boundaries and remaining integration gates. No source artwork, shared data or installed-client changes.

## Authority and baseline

Baseline commit: `19d6c1e7dc570546026cfb41135fae74c6b4e23e`; accumulated working-tree changes are preserved. Owning requirements: BS-08/12/13, P10/E06/E10 and ADR-M01. This extends the [delivery-board checkpoint](W01-DISPATCH-BOARD-CHECKPOINT.md), not a second application.

Unchanged design: [Phase39 HTML](../source/Rounds-Complete-Project-v2.3/ui/dispatch/index.html), SHA-256 `6a0019ec88cdaa422c5d56831d42f78745665de30681769a0d3515047fd1663c`. Source anchors: toolbar1731–1738; modal1823–1835; style choices2258–2259; placement2278–2287; icons1622–1653; effective CSS90–107,246–253,462–515,546–553. The original file-URL browser restriction remains respected; no alternate access or rehosting of that source occurred. Static source and the user's supplied screenshots are comparison references, not an executed-source screenshot diff.

## Implemented

- [Controller](../../apps/operations-web/src/v23/dispatch-map-controller.ts): immutable stored-destination projection, longitude/latitude validation, zero/dateline-safe fit bounds, initial fit once, selection/camera retention, style changes, ±20° rotation, North, fit/focus, 18-second initial/style timeout, explicit failure/retry, late-callback fences and idempotent disposal.
- [Production Mapbox adapter](../../apps/operations-web/src/v23/dispatch-mapbox.ts): installed Mapbox GL JS, instance-scoped public token, real geographic markers, style/camera events, native zoom/compass, resize observer, retained attribution and complete marker/listener/map cleanup. The existing SDK is reused through a typed port; v2.3 orders are not coerced into legacy Round/GPS contracts. The legacy map and routes are unchanged.
- [Map view](../../apps/operations-web/src/v23/dispatch-map-view.tsx), [CSS](../../apps/operations-web/src/v23/dispatch-map.css) and [source icons](../../apps/operations-web/src/v23/dispatch-map-icons.ts): source-derived toolbar, 352px modal, Operations/Satellite/3D Site selected states, delivery-layer visibility, rotation/North/fit/focus/return and unavailable states. Site targets the selected stored point at zoom17.1/pitch55. Operations uses light-v11; Satellite uses standard-satellite; Site uses standard with source day/faded/3D configuration.
- [DeliveryBoardView](../../apps/operations-web/src/v23/delivery-board-view.tsx) connects existing authorized rows/selection. Marker clicks open the same limited delivery detail; map visibility and style do not create commands, alter orders or replace the independent pickup-report journal. Revoked board access unmounts the map and removes private labels/pins.
- [Allowlisted configuration](../../apps/operations-web/src/v23/operations-connection-config.ts) passes only a valid existing `NEXT_PUBLIC_MAPBOX_TOKEN` when the v2.3 host is explicitly configured. Secret `sk` tokens, malformed values and prototype fallback keys are rejected. No feature flag or account was enabled here.

## Engineering choices and limits

Stored destinations are not verified entrances, stop numbers or current driver locations. Missing/invalid/unprojectable points remain visibly not mapped; zero coordinates are valid. With no authorized point the camera starts neutral at world scale, not an invented Bangkok position. Map rendering does not establish order readiness, route geometry, traffic-aware ETA or weather. Refreshed rows do not constantly refit and interrupt the operator's camera.

Source toolbar spacing, 40px controls, 40×24 switches and typography are retained in scoped CSS. A small provenance sublabel uses the source helper-text treatment; the bottom caption is raised8px from source32 to40 to reserve native attribution space. Generic source pin artwork is used because this projection has no confirmed stop ordinal. Labels wrap rather than overflow. These are bounded accessibility/provenance adaptations, not full pixel parity. At narrow widths Fit/Focus remain accessible inside the menu; Escape and Show workspace return without clearing selection. Actual native attribution/marker behavior still needs provider rendering review.

Drivers, Routes, Freelancer supply, Traffic, Rain, Inspect entrance and Street View remain explicitly unavailable with reasons. No fake rain polygons, sample route lines, simulated GPS, commercial connection or inferred entrance approval is added. Rain Auto/On/Off, route freshness/estimates, full entrance inspection and tracking are still separate BS-08 work, not completed by a basemap.

Public SDK behavior was checked against [Mapbox Map API](https://docs.mapbox.com/mapbox-gl-js/api/map/) and [token guidance](https://docs.mapbox.com/help/dive-deeper/access-tokens/) on10 September2026, plus installed3.29.0 types. This validates implementation options, not this operator's token restrictions, provider terms, imagery coverage or live account configuration.

## Dependencies, migration and offline compatibility

Requires the existing authorized ADR-Q06 reader and verified-login host, `ROUNDS_V23_OPERATIONS_UI=1`, exact isolated API/Auth/scope configuration, and a reviewed public Mapbox token with appropriate origin restrictions. Configuration does not grant board access. No shared environment was configured or activated.

No database migration, API contract change, persistent map cache, legacy-ID remapping, queue/photo deletion, phone installation or Thai screen work. The report journal and original evidence/attempt identity are unchanged. Last-known authorized rows are labelled on reader failure; provider failure destroys the failed map and allows explicit retry. The board remains usable. Revocation clears the map. Offline basemap availability is not promised; no offline entitlement cache or automatic command submission is introduced.

## Verification

Focused Operations typecheck and182 tests passed, including17 new [map tests](../../apps/operations-web/test/v23-dispatch-map.test.ts). They cover exact source icon/style/CSS anchors, token validation, coordinate/antimeridian cases, no fallback city, first fit, hidden markers, selection/style races, camera actions, invalid targets, timeout/failure/retry, async creation/late callbacks, disposal and truthful server-rendered controls. The Mapbox port is a labelled test double in these tests; real GPU/SDK/provider execution is not represented as tested.

Final aggregate recorded10 September2026 at07:35:22 UTC: **23/23 groups PASS**, including182 Operations,473 PostGIS,201 API/foundation and618 full Flutter tests (435 native-subset cases included, not additional). Typechecks, production build, source/wire validators, SQLCipher process-kill and Android durability checks passed. No current automated failures remain. Actual commands, logs and final source/code/tool fingerprints are in [test-results](generated/test-results.json); the earlier165-Operations-test checkpoint is not used to certify these changes. APK packaging, configured provider and phone acceptance were not run.

[Browser evidence](generated/dispatch-map-browser-check.json) uses real compiled React, controller, native fetch and test HTTP with a clearly labelled synthetic map port. Three of12 synthetic orders have points. It checks desktop/tablet/narrow layouts, selection/style changes, ±20°/North/Site camera arguments, layers, focus/Escape, provider-error teardown/retry and revoked access removal. Zero command POSTs occurred; the browser reported no warnings/errors. This is not live Mapbox, configured Auth/SQL, source pixel parity or phone evidence.

[Desktop screenshot](generated/dispatch-map-controls-desktop.png) and [tablet screenshot](generated/dispatch-map-controls-tablet.png) are actual current browser captures; this run produced full-size images without the previous capture scaling issue. Their diagnostic map region is intentionally not geography and is not a proposed product UI.

## Next and release gates

**Ready to implement:** authoritative Now/Plan/category/action projection under BS-03, followed by existing source intake/planning controls and real RouteEstimate connections. No invented counts or physical receipt. The bounded Mapbox code is implemented, not the full BS-08 module.

**Not yet accepted:** configured Mapbox/Auth/SQL journey; actual WebGL markers through pan/zoom/rotation and style failures; native attribution at supported viewports; full source screenshot matching; route/GPS/traffic/weather providers; entrance/Street View workflow; phone integration and complete W01 acceptance. Genuine account/provider/policy choices remain gated under the existing decisions; no new business choice is invented here.

No deployment, shared migration, phone change or push.
