# Dispatch Phase39 section-to-build map

Version 0.6 · 2026-09-10 · Section-level implementation evidence; full rendered/functional matching pending.

## Changelog

- 0.6 (2026-09-10): connect the pickup Action card/detail to existing authorized report review and wait/escalate. No new board design, full-section completion or installed-phone claim.
- 0.5 (2026-09-10): connect source Now status tabs/counts to ADR-Q07 server facts, exact filter predicates and current-day reads; keep decision commands and full-section acceptance distinct.
- 0.4 (2026-09-10): connect Plan date/Unplanned/All/brand list controls and original-date draft-preserving reads; keep Now categories, timeline and planning writes open.
- 0.3 (2026-09-10): record authorized delivery cards/context/search/details and bounded Mapbox controls; distinguish this code from configured provider and full-section acceptance.
- 0.2 (2026-09-10): record the bounded pickup-report list/detail/reply workflow mounted in the source-derived header/rail/tablet shell. Keep all other section ownership and acceptance requirements open.
- 0.1 (2026-09-08): map static source selectors to query/command and build-spec owners.

Exact source: [Phase39 HTML](../source/Rounds-Complete-Project-v2.3/ui/dispatch/index.html). Selector anchors below were found in static markup. Script-created drawers/variants must be expanded under BS-12 before their checkpoint. No live-state or pixel-parity claim is made by this map.

Current bounded implementation: [delivery cards/context/search/details and pickup reports](W01-DISPATCH-BOARD-CHECKPOINT.md), with separate authorization and original-version reply/recovery; [Mapbox and Phase39 map controls](W01-DISPATCH-MAP-CHECKPOINT.md) connect stored destinations, style/camera and selection. [Plan list controls](W01-DISPATCH-PLAN-POOL-CHECKPOINT.md) add date selection, Unplanned/All and brand filters. [Now status tabs](W01-DISPATCH-NOW-CHECKPOINT.md) add same-snapshot Action/Ready/On road/Done and actual reason labels, current-city-day reads and remembered Plan dates. The [pickup Action workflow](W01-DISPATCH-PICKUP-ACTION-CHECKPOINT.md) connects exact independently authorized reports to existing review/wait/escalate controls while preserving original drafts and holds. Other operational actions, timeline/planning writes, full details, real route/GPS/weather/traffic feeds, entrance inspection and the other sections remain unfinished. Map-port/browser-double checks are not live provider acceptance. Unconnected/deferred actions are disabled, not linked into legacy demo flows. No whole-row completion is implied.

| Surface / selector anchors | Query / command boundary | Build ownership and mandatory variants |
| --- | --- | --- |
| Header `dispatchHome`, `driversNav`, `historyNav`, `workspaceSettings`, `businessSettings`, `locationPicker` | Workspace/Settings, SaveCity/Site/Brand/Policy, membership/features | BS-01/12. City change dirty draft, disabled capability, revoked permission, tablet navigation. |
| Dispatch `nowTab`, `planTab`, `deliverySearch`, `windowPicker`, `driverFilter` | Board/Plan/Delivery; filters are local/query state | BS-03. Loading/empty/no-match/stale/offline/error, same filter/count definitions, no demo All clear. |
| Manual `addDelivery`, `addSubmit`, `cancelAddDelivery`, `addFormMap` | SaveDeliveryDraft/ReviewAddress/CommitDelivery, HoldSlot | BS-02. Full form, source review, conflict/duplicate, invalid slot, draft discard; not replaced by AI. |
| Assisted intake `intakeQuickEntry`, `intakeFiles`, `intakeSourceRead`, `intakeCommit` | CreateIntakeBatch/ExtractDraft/CommitIntakeBatch/OperationStatus | BS-02. Stale extraction, unsupported file, per-row failure, no late overwrite. |
| Plan `planDateInput`, `planNewRound`, `planSave`, `planReleaseButton`, `routeImpactApply`, `routeImpactRefresh` | Generate/Preview/Apply/Save/Stage/ReleasePlan | BS-03. Overnight lanes, drag/touch/keyboard alternative, invalid capacity, stale proposal, before-receipt staged work, readiness blocker. |
| Fleet `fleetDriversTab`, `fleetVehiclesTab`, `fleetDate`, `fleetAddDriver`, `fleetAddVehicle`, `fleetRules` | Drivers/DriverHome, shift/vehicle/relationship commands | BS-06. Date exceptions, archived resources, conflicting vehicle, empty date, actual free-after. |
| Map `mapDisplayButton`, `tiltMap`, `fitBoard`, `focusMap`, `rotateMapLeft`, `rotateMapRight`, `resetMapNorth` | Actual Mapbox camera/style; RouteEstimate separately | BS-08.2D/3D/satellite,20° turns/North, fit/return/attribution; no decorative route. |
| Layers `retryTraffic`, `nsMapToggle`, map drawer weather controls | Scoped position/supply and configured weather/routing adapters | BS-08/10. Auto/On/Off rain, stale/provider unavailable, no GPS leak or double weather delay. |
| Entrance `inspectionMapTab`, `inspectionStreetTab`, `inspectionEdit`, `streetRetry`, `inspectionConnect`, `streetExternal` | Entrance, ReportLocationObservation/ConfirmEntrance/ApplyEntrance/RetireEntrance | BS-08. No imagery/key/setup/failure; preserve private instructions and actual reviewed revision. |
| Contact `messagesButton`, `cmDraft`, `cmAttach`, `cmVoice`, `cmMinimize`, `cmClose`, driver-map actions | OpenConversation/GetConversation/SendMessage/read/call commands | BS-07. Direct ordinary click, tray/unread, background no focus theft, per-thread attachments/draft, real call states. |
| Delivery/issue `proofRecipient`, `proofReason`, `resolutionConfirm`, `cancelDeliveryReason`, return drawer | Delivery/ReturnTasks/Transfers; Report/ResolveIssue, handoff/proof/return/cancel commands | BS-04. No forged driver event; correct acting role; real custody and proof-pending labels. Prototype Confirm delivered does not bypass proof. |
| History `hrCity`, `hrSource`, `hrFrom`, `hrTo`, `ivTab-activity/proof/communication/address`, `ivDownload` | GetHistory/Delivery, RequestExport/CorrectIncidentCause | BS-09. Snapshot filters, denominators, pending evidence, authorised assets, export/revocation and correction provenance. |
| Configuration `openDeliveryRules`, `openProofRules`, `openPlanRules`, `saveIntakeRules`, `settingsMapConnection` | Settings/Connections/SlotOccurrences, typed editors | BS-01/02/09. Save/conflict/discard/high-impact confirmation, configured versus verified, privacy/retention gates. |
| Network `broadcastLaunch`, `bcNew`, `bcSettingsOpen`, `bcSubmit` | Broadcasts/Offers/NetworkSupply, Start/Revise/Stop/RestartBroadcast, RespondOffer | BS-10 R3. Operator decision regardless own capacity; one winner, expiry, consent, unknown result. |
| Intercity `networkMode`, `cityHandoffs`, `networkOpsSave`, `networkFormSubmit` | Trips, trip/load/receipt commands and staged local plan | BS-11 R4. Actual receiving role, partial inbound quantities, whole-order local pickup, independent readiness, active-work capability disable. |

## Explicit exclusions, not accidental omissions

No temperature/cold hardware module (`temperatureOpen`, `temperatureCapability`, `coldAdd` etc), Lalamove booking, sample address/reply/connected/send controls, simulated customer sends or Release demo plan. No wallet/COD/bank-transfer execution. Their omission is a current-spec scope requirement even where source prototype retains them. Keep historical evidence accessible where required; don't delete reference HTML to hide the discrepancy.

## Review evidence

Each section must receive its own state/control mapping under BS-12, live query/command traces and screenshot comparisons at every applicable viewport. The1,052-element static inventory is a discovery aid, not an exhaustive dynamic interaction audit. Manual reviewer can inspect `generated/ui-controls-static.json` by source path/line/ID; record resolved dynamic controls rather than treating absent static IDs as absent features.
