# Rounds — master feature register and specification handoff

Updated: 7 September 2026. Revision: 5. UI baseline: `Rounds-Fresh-Phase39-Blue-Workspace.html` (Phase 36 workflows plus brand alignment passes 1–3).

## 1. Purpose and finish line

This is the consolidated feature register for rewriting the Rounds specifications. It brings together the current dispatch prototype, decisions made during the rebuild, requirements carried from the original board/specs, remaining workflow gaps and deferred ideas. The complete previous improvement MD is retained in Appendix A so its acceptance rules, evidence and limitations are not lost.

**Proceed to specification reconciliation now.** Keep the approved visual foundation. Remaining interactions can be specified as explicit gaps; there is no requirement to keep adding HTML phases before starting the specs. This replaces the earlier sequence in Appendix A that put all UI closeout before the rewrite. The feature inventory was established at Phase 36. Phases 37–39 align the shared identity, contextual panels and workspace controls; no new operational workflow is claimed.

This register is a handoff, not a claim of exhaustive production completion. Source-level inventory was checked against the fresh modules, the original board's workflow entry points, the supplied canonical index and driver manifest. A clause-by-clause comparison of all legacy specs and real browser/device verification remain explicit tasks in the rewrite. Requirements without verified fresh-board parity are recorded rather than silently discarded or labelled finished.

## 2. Status and authority

| Status | Meaning |
| --- | --- |
| Prototype | An interaction/data path exists in the current standalone HTML. Usually session data; does not mean a deployed service. |
| Partial | Some behavior exists, but the specified wider workflow or live integration is incomplete. |
| Required | Agreed next work, or an inherited requirement to retain and reconcile; not confirmed implemented. |
| Deferred | Preserved future scope; excluded from the current core release unless explicitly reopened. |

Status applies to the feature as described, not every possible edge case. Existing test results are in Appendix A; no new browser, provider or device validation is claimed by this documentation update.

When sources conflict, use this order: explicit latest user decisions; approved fresh interaction and this register's stated corrections; retained legacy requirements that do not conflict; legacy implementation detail. A bug, sample default or unconnected prototype control must never become product authority merely because it exists in code. During the rewrite, record each old clause as retained, changed, deferred or superseded, with its new owner and acceptance condition.

## 3. Locked product decisions

1. Rounds is a multi-tenant dispatch SaaS plus a driver app. UrbanFlowers is a sample tenant, not the product definition. Brands, pickups, cargo, windows and vehicles must be configurable for other businesses.
2. Preserve the Rounds wordmark geometry and orange dot; the approved brand colour is now blue, shared with the refreshed driver app. Preserve the approved header, board hierarchy, readable delivery rail, contextual drawers, map-first workspace and approved entrance-inspection composition. Improvements must preserve original operational capability.
3. Local city operations work independently. A one-city business does not need an Intercity board. Multiple local cities may operate with Intercity disabled. Feature visibility follows tenant configuration and permissions.
4. Intercity is an optional national transport board: cities/hubs, vehicles between cities, progress, expected arrival and time remaining, then destination receipt and local doorstep delivery. A visual strategy-game analogy does not justify decorative gameplay or invented telemetry.
5. Only the operator starts a freelancer broadcast. Rounds must not require exhausted own-fleet capacity, a capacity check of the own team, or an automatic fallback decision before permitting that choice.
6. Broadcast recipients are eligible freelancers who have made themselves open for work. Own-team assignment is a separate flow. Nearest-first area expansion is the initial policy; reputation ranking is deferred. Job vehicle/cargo feasibility checks still apply and are distinct from checking whether the merchant has spare drivers.
7. Concurrent broadcasts in many cities are supported as separate city-scoped jobs. One local broadcast Round has one city, pickup and service date; it does not accidentally merge transport legs or deliveries from different cities.
8. Manual Add Delivery remains directly available. Paste, screenshot, image and AI are optional accelerators into the same editable delivery draft. Reading or creating a draft never automatically dispatches it.
9. AI may suggest Thai address corrections. Preserve original input, highlight the suggested change and require human review. Never invent a house/unit number or silently replace the written address with a geocoder label. Text approval and entrance-pin confirmation are different decisions.
10. Open driver actions by clicking/tapping the driver on the map; Message opens the relevant conversation. Header inbox is secondary. Unaccepted unknown freelancers do not expose casual Message/Call or exact GPS.
11. Capacity means stops and physical cargo per departure. Three bike stops is a configurable example, not a universal limit. Return/reload occupies time and therefore affects next availability and later Rounds.
12. Accepted work, promised windows, physical custody and completed proof are protected. Freelancer consent, operational authority and any customer agreement are separate records.
13. Lalamove is removed from current scope. Temperature is deferred. Existing sample/legacy code does not override those decisions.
14. Operations targets laptop/desktop and iPad. Driver mobile is a separate role-specific app with concise task/map UI. Do not squeeze the full operator board onto a phone.
15. Missing, stale, estimated, sample, queued and confirmed data must be distinguishable. Do not call a click a delivered notification, iframe load verified imagery, or sample movement live GPS.

## 3A. Shared Driver / Dispatch identity — pass 1 implemented

Approved from the four supplied Driver screens in `ROUNDS-REFRESH-01-TWO-SCREENS(1).html` and `ROUNDS-REFRESH-02-TWO-SCREENS(1).html`. The new instruction to use blue supersedes historical statements that implied a fixed near-black wordmark colour. Logo shape, size, orange dot and existing header geometry remain unchanged.

| Token / role | Value | Usage |
| --- | --- | --- |
| Brand / action blue | `#1754A6` | Wordmark, current navigation text/icon, primary buttons, selected controls and enabled switches. |
| Blue hover | `#14488D` | Primary button hover. |
| Selected surface | `#EDF4FD` | City/Intercity and Now/Plan selected surfaces; secondary-control hover. |
| Blue control border | `#C5D7ED` | Selected and secondary control borders. |
| Text ink | `#17283F` | Main text; do not use action blue for all text. |
| Muted text | `#526278` | Supporting text with readable contrast. |
| Line | `#DCE4ED` | Shared neutral border token. |
| Orange accent | `#FF6420` | Logo dot and restrained attention/navigation accent. |

Pass 1 scope: wordmark colour; active main navigation; City/Intercity selection; city picker selection; Now/Plan selection; Add Delivery; shared primary/secondary buttons and switches; header Broadcasts text/hover; keyboard focus in the base controls. Existing control sizes, navigation positions, header spacing, map geometry and app layout are retained. Dispatch keeps its existing Inter typography; phone-specific 64–68px buttons and Arial sizing are not copied into an operator board.

White remains the dominant surface. Red, green and attention labels keep their operational meaning. Route/driver colours, map basemap, rain/traffic and selected-delivery card styling are not recoloured in this pass. Shared button classes adopt blue wherever reused; page-specific compositions wait for their scheduled pass. Disabled controls remain visibly unavailable. Keyboard focus uses blue for contrast on white instead of copying the driver's orange outline indiscriminately.

Brand passes 2 and 3 are implemented as described below, including map controls/timeline and Drivers/History/Settings page-specific treatments. These passes are visual consistency work, not new product features. They must not revive deferred modules or alter consent, custody or delivery rules. Original blue-grey component literals remain where outside pass 1; later passes should edit their owning styles rather than accumulate contradictory override layers.

Validation: colour-only source review, compiled CSS/JavaScript parsing, contrast calculation, and comparison against the Phase 36 markup/behaviour baseline. No actual browser/iPad rendering or live map/provider validation is claimed for this pass.

## 3B. Restrained colour application — pass 2 implemented

The user explicitly approved **very restrictive blue**: white and deep navy dominate; blue remains visible at selected controls and actions. This governs all remaining brand work and supersedes any interpretation that every panel should receive a pale-blue background.

Implemented in Phase 38:

- Selected Now/Plan delivery cards remain white with a thin blue-tinted border and a 3px blue inset edge. Hover is near-white. Recipient names remain deep navy; actionable next-step controls use blue. Existing issue/blocked text stays orange/brown.
- Delivery and Round detail metadata uses the shared readable muted text colour. Functional destination/back/edit links use blue; route avatars and ordinal colours retain their driver identity.
- Entrance inspection retains its existing white composition. The selected tab has a blue underline with navy text; the external Street View action uses blue. Confirmed and uncertain entrance states retain green and attention colours.
- Contextual driver Message uses the same primary blue as the app. Outgoing chat bubbles use a small pale-blue surface to distinguish direction; the chat panel stays white. Selected conversation-tray tabs use a blue border on white. Call state, unread and error semantics are retained.
- Delivery investigation entry, summary and linked-conversation context use white surfaces. Small action icons, active-tab underline and focus ring carry the identity. Evidence, proof, sources and warning colours are unchanged.
- Broadcast side panels remain white; active-tab underline and checked control use blue. Search waves, no-driver/exception states and accepted/completed indicators retain their existing meanings. Selection is not an operational alert.
- The paste/image entry stays compact and white with a small blue icon; manual Add Delivery stays primary and available.

There is no new panel, footer, extra header, behavioural change, timeline rearrangement or map-route recolouring. Sizes, spacing, font sizes, breakpoints, imagery and operational scripts are retained. These are edits in the owning stylesheets, using the shared Phase 37 tokens.

Validation for this colour pass: compiled CSS and JavaScript parsing; markup and behaviour comparison against Phase 37; review that changed style declarations are paint-only; retained 150 feature IDs and previous improvement log. This is not real browser/iPad visual verification or live provider testing. Remaining work remains as recorded in the feature register.

## 3C. Workspace colour alignment — pass 3 implemented

Phase 39 completes the planned three-pass brand application in the prototype. White surfaces and deep navy text remain dominant. Small selected borders, active underlines, action labels and focus states carry the shared blue. This is visual consistency, not completion of the operational or production backlog.

- Map controls: white Operations, camera and Inspect entrance controls; blue text/border on the active control; selected map style stays white with a blue check and border. Mapbox framing, basemap, marker coordinates, vehicle symbols, routes, traffic severity and rain presentation are preserved. No live provider integration is added.
- Timeline: shared navy lane headings and readable muted axis/metadata; blue Plan remaining, stop-edit controls, departure nudges and resize interaction. Existing lane/driver colours, selection tint within a route, travel lines, reload patterns, conflict/wait states and drag feasibility indicators are retained. Timing, return/reload, geometry and drag behaviour are unchanged.
- Drivers: selected driver row stays white with a slim blue edge. Active page tab gets a blue underline. Driver names and metadata use shared text tokens; driver identity avatars and availability/attention states retain their meaning.
- History: selected delivery row stays white with a slim blue edge; reporting tabs, range selections, record actions and focus rings use shared blue. Metrics use navy text; report surfaces stay white or neutral. Incident severity, delivery outcomes and chart encodings remain distinct.
- Settings: neutral navigation surface with a white selected item and slim blue edge. Selected working days, checkboxes, tracking-channel choices and commerce tabs use the shared blue. Saving, connection, unavailable and error states keep their existing semantics. The customer-facing tracking preview is not redesigned.

Implementation edits the owning stylesheets. No new panels, additional header/footer, font changes, layout changes, breakpoints, animations, marker redesign or workflow changes are introduced. Existing primary buttons already inherit the shared palette from pass 1.

Validation: compare compiled scripts and markup against Phase 38 (version/title only); parse all compiled CSS/JavaScript; compare stylesheet declarations to ensure changes are limited to colour/paint; preserve the 150 feature IDs and Appendix A. Actual browser/iPad visual validation and live-provider checks remain outstanding. Before specification sign-off, review these surfaces with real content in Chrome and iPad; this source check is not a substitute.

## 4. Feature register

Each ID is a traceable reference for the new specs and acceptance tests. Source filenames refer to `rounds-fresh/` unless stated otherwise. Required rows are intentionally retained even where the current HTML does not demonstrate them.

### 4.1 Workspace, identity and navigation

Source basis: `dispatch.html`, `dispatch.js`, `city-workspaces.js`, `workspace-review.js`, `tablet.css`; original visual/edge-state specs.

| ID | Feature and behavior to retain | Status / boundary |
| --- | --- | --- |
| WS-01 | Preserved wordmark shape with approved blue colour; business identity; Dispatch, Drivers, History and Settings navigation. | Prototype; authentication and role enforcement remain production work. |
| WS-02 | City selection with independent local orders, fleet, pickups, date, drafts and filters; suppress needless one-city choice. | Prototype; configured sample cities. |
| WS-03 | Optional City / Intercity board navigation; disabling Intercity preserves city operations and existing evidence. | Prototype. |
| WS-04 | Now / Plan operating modes, explicit service date and contextual counts. | Prototype; counts must follow the actual view/filter. |
| WS-05 | Dominant map, delivery rail, contextual detail, expandable timeline; no permanent prototype/footer field wasting board height. | Prototype; preserve full-height fix. |
| WS-06 | Business brands/offices/pickups, city membership, feature access and country configuration. | Partial; filtering/context exists, full creation/archive administration and permissions are required. |
| WS-07 | Keyboard access, visible focus, Escape/close, focus return, unsaved draft protection, reduced motion and readable touch controls. | Partial; full accessibility/browser/iPad closeout required. |
| WS-08 | Tenant isolation for all deliveries, media, history, chats, configuration and address knowledge. | Required server contract; some prototype context guards are present, not a security boundary. |

### 4.2 Delivery intake and AI

Source basis: `delivery-form.js`, `intake-core.js`, `intake-io.js`, `intake-view.js`, `intake-rules.js`; original bulk intake/actor model.

| ID | Feature and behavior to retain | Status / boundary |
| --- | --- | --- |
| IN-01 | Plus / Add Delivery immediately opens manual fields; optional paste/drop fills those same fields. | Prototype. |
| IN-02 | Recipient, contact, buyer where different, address, service date/window, pickup, items/quantities, handling, preparation and notes. | Prototype; full buyer/recipient/source mapping needs spec reconciliation. |
| IN-03 | Paste chat/order text, clipboard image and drag/drop screenshots; keep original source attached to the draft/delivery. | Prototype; no message is sent to the source chat. |
| IN-04 | Thai/English image text reading with processing progress, failure recovery and manual correction. | Partial; browser OCR dependency exists, real model integration and quality validation remain. |
| IN-05 | Optional authenticated AI extraction adapter; uncertain fields remain editable; preserve source, original and suggested address. | Partial; no connected production AI by default. |
| IN-06 | Multiple deliveries from a source; review/select/remove drafts; validate phone/date/window/cargo; duplicate warning and explicit resolution. | Prototype; server idempotency and production batch/partial failure rules required. |
| IN-07 | PDF and CSV import through the same intake/review contract. | Required legacy parity gap: current file reader accepts PNG/JPEG/WebP, not PDF/CSV. |
| IN-08 | Intake settings for city/pickup, windows, country/phone handling, preparation defaults and remembered addresses. | Partial; current parsing and coordinates contain Thailand-specific assumptions. |
| IN-09 | Commit reviewed orders into Ready/Unplanned or an explicit address/preparation hold without dispatching drivers. | Prototype; final dispatch eligibility must be enforced on server. |
| IN-10 | Preserve existing manual input when autofill arrives; retain incomplete source on read failure; prevent wrong-city draft contamination. | Prototype; concurrent/cloud draft recovery remains required. |
| IN-11 | Document upload/draft limits and timeouts as configurable operational limits. | Prototype examples: 5 images, 20 MB/image, 20 drafts, 24,000 text characters; not permanent global product limits. |

### 4.3 Address, entrances and site inspection

Source basis: `intake-address.js`, `address-review.js`, `map-inspection.js`, `street-inspection.js`; old Mapping spec.

| ID | Feature and behavior to retain | Status / boundary |
| --- | --- | --- |
| AD-01 | Address suggestions, business matches, manual map pin/coordinates and explicit location confirmation. | Prototype; geocoder match alone must not establish a verified entrance. |
| AD-02 | AI correction card: Original / Suggested, changed text, reason, source and review checkbox; confirm, edit or keep original. | Prototype; no real semantic Thai-address validator connected. |
| AD-03 | Pending correction blocks assignment, plan release, broadcast and intercity manifest eligibility; correcting text invalidates old pin. | Prototype; server enforcement required. |
| AD-04 | Preserve house/building, soi, district, province, postcode, floor and unit; show conflicts for review rather than inventing values. | Partial; formatting extraction exists, administrative validation remains required. |
| AD-05 | Entrance panel with recipient/location, verification state, access and handoff notes; edit pin and notes together where allowed. | Prototype; keep approved composition. |
| AD-06 | Dedicated Google Street View surface with same target, return, previous/next target, external fallback and connection settings. | Prototype layout; real key, coverage, provider agreement and browser validation required. |
| AD-07 | Street View loading, slow response, offline, retry, missing pin/key and stale-target protection. | Prototype; iframe load cannot verify coverage or valid imagery. |
| AD-08 | Remembered exact address matches scoped to business. | Partial; session address memory exists; do not equate this with the reusable entrance workflow below. |
| AD-09 | Reusable confirmed entrance record with access/parking/handoff notes, source, confirmer/date and revision; offer Use saved entrance / Review and edit. | Required next workflow, not built in Phase 36. |
| AD-10 | Correct or retire saved entrance information; preserve history and unit-specific delivery details; uncertain matches never silently auto-apply. | Required; no cross-business public learning by default. |
| AD-11 | Driver wrong-address evidence and successful delivery feedback inform reviewable entrance knowledge. | Required inherited driver contract; geocoder/Street View evidence is not driver verification. |
| AD-12 | Group several recipients at a building into one physical visit while preserving individual promises, manifests and proof. | Deferred research opportunity, not committed current functionality. |

### 4.4 Dispatch queue and own-fleet execution

Source basis: `dispatch.js`, `workflow.js`, `execution.js`, `consolidation.js`, `journeys.js`.

| ID | Feature and behavior to retain | Status / boundary |
| --- | --- | --- |
| DI-01 | Action, Ready, on-road/live and completed delivery views with search, window/brand filters, priority and honest counts. | Prototype; exact filter parity to reconcile against original. |
| DI-02 | Delivery detail shows items, promise, preparation, assignment, source, journey, issue, next action and evidence links. | Prototype. |
| DI-03 | Resolve missing pin, approval, preparation and recipient issues from their delivery context. | Prototype; no inferred customer consent. |
| DI-04 | Preparation/packing checklist before pickup; shared structured item lines and quantities. | Prototype; business-specific handling must remain configurable. |
| DI-05 | Release own-driver work; observe acknowledgement/decline; start, load, depart, progress, return and reload. | Prototype with sample driver responses; actual responses originate in driver app. |
| DI-06 | Current stop, next stop, arrival, promise risk, remaining route and driver free-after estimate. | Prototype estimates; no live GPS or measured driver speed established. |
| DI-07 | Failures, retry, reschedule, cancellation, return and receipt keep previous attempts and custody evidence. | Partial; flows exist, full cross-city/state matrix must be reconciled. |
| DI-08 | Own-driver live reassignment/transfer with feasibility, pending response, source preservation and explicit custody. | Prototype; production transactions and field handoff confirmation required. |
| DI-09 | Edit live destination/pin/window/instructions after pickup with impact review and driver acknowledgement. | Required legacy parity review; draft impact preview is not proof this entire live-change contract is rebuilt. |
| DI-10 | Protected collected manifests; no removal, cancellation or assignment change makes physical parcels disappear. | Required invariant across all execution flows; some prototype guards present. |
| DI-11 | Keep resolved/completed work and historical references when a plan, source, driver or optional feature changes. | Partial; production immutable snapshots required. |

### 4.5 Planning, timeline and route changes

Source basis: `planning*.js`, `route-impact.js`, `rolling.js`; original planning contract.

| ID | Feature and behavior to retain | Status / boundary |
| --- | --- | --- |
| PL-01 | Date-specific Unplanned pool, map and driver lanes with sequential Rounds, stop cards and selected-route detail. | Prototype. |
| PL-02 | Plan remaining / generate proposal; show coverage, unplanned work and constraints; operator reviews before release. | Prototype heuristic; do not promise globally optimal routes. |
| PL-03 | Create/edit a Round, departure, pickup, driver, vehicle, delivery window and service time. | Prototype; preserve stable order/stop identities. |
| PL-04 | Drag a whole Round between drivers/times; transfer a stop between Rounds; insert/reorder or return to Unplanned. | Prototype; keyboard/edit alternatives retained. |
| PL-05 | Timeline scale/zoom, stop tooltip/detail, fit Round, return/reload gaps and visible shift boundaries. | Prototype; full overnight and iPad gesture parity needs verification. |
| PL-06 | Vehicle max stops, cargo-class quantities, overall cargo, special handling, shift, overlap and pickup-transfer checks. | Prototype; one authoritative shared server validator required. |
| PL-07 | Capacity is per departure; repeat Rounds after travel back and reload; include that time in next availability. | Prototype; no equivalence between max stops and hourly throughput. |
| PL-08 | Route-improvement comparison and selected route geometry; apply only a chosen proposal. | Prototype; routing provider validation remains. |
| PL-09 | Before/after move review: affected drivers, loads, return/free times, arrival changes, late minutes and conflicts. | Prototype Phase 33; road estimates, not traffic-aware prediction. |
| PL-10 | Keep current / Recheck / Apply; unavailable routing blocks comparison apply; stale inputs invalidate proposal; apply atomically. | Prototype guards; server concurrency/versioning required. |
| PL-11 | Timing policy warns with explicit override or blocks; physical incompatibility remains blocking. | Prototype configurable rule; explain reason near affected work. |
| PL-12 | Save draft, explicit release review, uncovered-work acknowledgement, released snapshots and driver response state. | Prototype; authenticated notifications and durable release versions required. |
| PL-13 | Add later work through incremental releases while protecting already started/released Rounds. | Prototype; never silently rewrite work underway. |
| PL-14 | Full recurring schedules, date exceptions, special days and overnight operating-day model. | Partial; selected-date shifts/default weekdays exist; reconcile original dedicated schedule and special-day UX. |

### 4.6 Own drivers and vehicles

Source basis: `fleet.js`, `driver-management.js`, `planning-actions.js`; Specs 10 and 11.

| ID | Feature and behavior to retain | Status / boundary |
| --- | --- | --- |
| FL-01 | City fleet directory, search, driver details/contact, current/upcoming Rounds and date-scoped work. | Prototype. |
| FL-02 | Add/edit drivers, default weekdays/hours/vehicle, shift-specific edits, archive/restore with outstanding-work protection. | Prototype; business identity/permissions remain required. |
| FL-03 | Available, off shift, unavailable, loading, on Round, returning/reloading and projected free-after. | Prototype; distinguish presence, schedule and accepted workload. |
| FL-04 | Add/edit vehicles, profile, capacity overrides, in-service/unavailable and affected-work warnings. | Prototype. |
| FL-05 | Bike, car, van and tuk-tuk profiles; reusable cargo/handling and stop limits. | Prototype profiles; navigation legality and actual vehicle capabilities need field validation. |
| FL-06 | Additional vehicle types, including intercity trucks, without florist-specific assumptions. | Required configurable model; do not label every type/navigation mode fully supported. |
| FL-07 | Team assignment versus freelance open-for-work relationship; any legacy Partner category must not bypass freelancer consent. | Required terminology/relationship reconciliation. |
| FL-08 | Known/preferred freelancer directory, structured Ask availability and opt-in pre-job relationship contact. | Required legacy parity review; supply layer and accepted-job chat do not replace this full directory. |

### 4.7 Freelancer broadcast and supply

Source basis: `broadcast.js`, `broadcast-jobs.js`, `broadcast-delivery.js`, `broadcast-changes.js`, `network-supply.js`.

| ID | Feature and behavior to retain | Status / boundary |
| --- | --- | --- |
| BC-01 | Operator opens composer from delivery/Round or Broadcasts; explicitly starts search whenever needed, independent of own capacity. | Prototype; supersedes old own-capacity-first broadcast rule. |
| BC-02 | Single-delivery or multi-stop Round offer with pickup-ready time, city/date, scope, windows, vehicle, load and guaranteed total fare. | Prototype; fare sample is whole baht, international currency model required. |
| BC-03 | Nearest-first widening areas, configurable radii/response periods, visible wave and countdown. | Prototype examples 2/5/8 km and 45 seconds; not global defaults locked by this register. |
| BC-04 | Many independent city broadcasts; filter by city/status and return to each accepted job. | Prototype; transport offer marketplace is not implicitly included. |
| BC-05 | Stop, expand, no acceptance, restart or raise fare under operator control; preserve selected scope/version. | Prototype; production timers are server-owned, not paused because one browser disconnects. |
| BC-06 | Eligible open freelancers only; vehicle/load/city/availability checks; one acceptance winner, stale/race-loss/decline handling. | Prototype simulation; authenticated atomic acceptance required. |
| BC-07 | Before acceptance show approximate supply, aggregate/cluster at low zoom, no other merchant routes or exact GPS. | Prototype supply surface; production authorization and scalable map layers required. |
| BC-08 | After acceptance show assigned freelancer, relevant job tracking, direct contact, arrival at pickup and pickup issues. | Prototype; live location/communication services unconnected. |
| BC-09 | Itemized verified pickup changes custody; subsequent arrivals, handoff/POD, failed attempts, retry and completion. | Prototype sample workflow; driver app must be authority for driver evidence. |
| BC-10 | Freelancer return proposal/consent, return arrival, received quantities and receipt evidence. | Prototype; does not complete every post-pickup change scenario. |
| BC-11 | Before-pickup change proposal: add/remove/reorder stops, window/fare changes, reason, response deadline and history. | Prototype Phase 30; original agreement remains until valid acceptance. |
| BC-12 | Decline, withdrawal, expiry, changed sources, wrong actor and repeated response cannot partially overwrite accepted work. | Prototype; durable server version/transaction checks required. |
| BC-13 | Post-pickup additions, removals, destination changes, transfer and driver unable to continue. | Required extension: extra collection/custody, consent, impact and immutable completed stops. |
| BC-14 | Reputation-based ordering, richer preferred-driver ranking and on-route opportunity matching. | Deferred initial matching expansion; existing relationship/privacy requirements still retained. |
| BC-15 | Fares, settlement trigger, earnings, adjustments, dispute records and payout reconciliation. | Required driver/backend contract; no payment or payout implemented by board simulation. |

### 4.8 Intercity transport and destination delivery

Source basis: `network.js`, `network-map.js`, `network-detail.js`, `network-actions.js`, `network-operations.js`.

| ID | Feature and behavior to retain | Status / boundary |
| --- | --- | --- |
| IC-01 | National map of configured cities/hubs, active transport connections, selected trip and city drill-down. | Prototype; optional tenant feature. |
| IC-02 | Drivers/vehicles anchored geographically between cities during zoom/pan; progress, ETA and time remaining. | Prototype; sample position/time must not be presented as live telemetry. |
| IC-03 | Create/edit transport trip: origin/destination, departure/arrival, driver/vehicle, capacity, receiving contact and transfer point. | Prototype; recurring driver/carrier contracts and automated timetables not established. |
| IC-04 | Unbooked intercity orders and physical manifest; compatible city/date/route/capacity selection. | Prototype; production route and calendar validation required. |
| IC-05 | Departure, in-transit/arrival, destination receipt, discrepancy/hold, local assignment and final doorstep proof. | Prototype; explicit receipt connects linehaul to local custody. |
| IC-06 | Separate linehaul driver and destination/local driver conversations and responsibility. | Prototype; do not infer last-mile custody merely from arrival. |
| IC-07 | Trip activity, parcel counts, custody and destination History/investigation. | Prototype; durable evidence and signed actor records required. |
| IC-08 | Local city work remains independent; explicit handoffs entry and return preserve context. | Prototype Phase 32. |
| IC-09 | City-specific cutoff/service windows and next-day transport/last-mile promises. | Required service-policy specification; prototype schedules do not prove nationwide serviceability. |
| IC-10 | Cold holding at arrival, cooling hardware, sensor alerts and national cold-chain operation. | Deferred; preserve as a future module without blocking core dispatch. |
| IC-11 | Other-country networks such as Vietnam/China, currency/timezone/address/provider differences. | Deferred rollout; require country configuration, coverage and operating validation before launch. |

### 4.9 Map, traffic and operational context

Source basis: `map-workspace.js`, `journeys.js`, `planning-map.js`, `network-map.js`, `map-inspection.js`.

| ID | Feature and behavior to retain | Status / boundary |
| --- | --- | --- |
| MP-01 | Mapbox Operations basemap, Satellite and 3D site inspection where appropriate. | Prototype integration; provider/token/coverage validation separate. |
| MP-02 | Driver/vehicle markers, delivery pins and stop numbers, routes, selected driver/Round focus and full-extent fit. | Prototype; differentiate geographic truth from illustrative sample data. |
| MP-03 | Zoom, bearing/tilt, map focus/return, layers and style switch while retaining operational context. | Prototype; test camera/layer restoration in real browser. |
| MP-04 | Traffic layer with loading/error/retry and separate provenance from ETA calculation. | Partial; overlay exists, traffic-aware routing model not complete. |
| MP-05 | Rain visibility and route exposure when operationally relevant. | Partial: Bangkok sample rain only; live feed, time validity and impact rules required. |
| MP-06 | Planned route, active navigation leg and measured actual trail are distinct data. | Required shared mapping contract; basemap is not ETA authority. |
| MP-07 | Loading, invalid key/unavailable map, stale location and reconnect retain usable delivery list and honest status. | Partial; full real-service recovery validation required. |
| MP-08 | Vehicle-appropriate routing for bikes/cars/vans/tuk-tuks and country-specific restrictions. | Partial; avoid interpreting generic road routes as validated motorcycle/tuk-tuk navigation. |

### 4.10 Communication, tracking and notifications

Source basis: `communications.js`, `customer-tracking.js`, `delivery-investigation.js`; original shared communication contract.

| ID | Feature and behavior to retain | Status / boundary |
| --- | --- | --- |
| CM-01 | Map driver click/tap opens contextual actions; message/call/Open Round/center when relationship permits. | Prototype; right-click optional, never sole entry. |
| CM-02 | Persistent session conversations with context/unread state, header secondary access and return to the map/job. | Prototype; no large permanent chat placeholder below board. |
| CM-03 | Text, URLs, staged files/images, shared location and attachment handling; retain unsent drafts. | Prototype; live upload/delivery/security pipeline required. |
| CM-04 | Voice notes, call lifecycle, incoming call attention and shared contact ledger. | Partial/inherited: call simulation exists; full voice/media parity and real telephony require reconciliation. |
| CM-05 | Message/call/file history separate from operational status events; exact delivery reference where supplied. | Prototype; never guess delivery linkage from driver-wide messages. |
| CM-06 | Delivery context fixed for unsent draft and captured at call start; stale relationship blocks incorrect send. | Prototype Phase 36. |
| CM-07 | Buyer/sender and recipient tracking views; configurable event/channel routing and Surprise Protection. | Prototype settings/preview; public tracking and real sends unconnected. |
| CM-08 | Scheduled, out-for-delivery, material ETA change, action required, delivered, failed, retry and returned notification policy. | Partial preview; full provider-confirmed dispatch/delivery outcomes required. |
| CM-09 | Queued, uploading, sent, delivered, failed, retrying and disconnected states reflect actual evidence. | Required cross-service closeout; never infer recipient receipt from local success. |
| CM-10 | Notification failure never rolls back a delivery, accepted job, custody or POD. | Required invariant; retries idempotent and independently observable. |

### 4.11 History, evidence and investigation

Source basis: `history.js`, `history-reporting.js`, `delivery-investigation.js`; Specs 6 and 9.

| ID | Feature and behavior to retain | Status / boundary |
| --- | --- | --- |
| HI-01 | Overview / Deliveries / Drivers / Incidents; period/search/filter selection across fulfillment sources. | Prototype; check exact legacy filter and reporting parity in rewrite. |
| HI-02 | Volume, on-time, exceptions, cost and evidence/compliance summaries with explicit denominators and missing data. | Prototype sample reports; reliable production metrics need event definitions. |
| HI-03 | Delivery promise/actual, source, driver, item quantities, attempts, POD, return and resolution record. | Prototype; immutable source versions and media retention required. |
| HI-04 | Photo/signature, received-by, handoff/authorization notes, missing proof and evidence download. | Prototype; driver-origin upload/verification rules required. |
| HI-05 | Incident cause, impact, reviewer note and driver-performance treatment; non-driver causes do not automatically penalize driver. | Prototype; authenticated review and correction history required. |
| HI-06 | Freelancer availability/offline status is not negative performance evidence outside accepted commitments. | Required preserved principle. |
| HI-07 | Investigation summary separates assignment, recorded custody and next action; Activity / Proof & items / Communication / Address & source. | Prototype Phase 36, on demand; no permanent board space. |
| HI-08 | Linked communications only with exact delivery context; related full conversation separately accessible. | Prototype; tenant/city/date/order identity prevents cross-record mixing. |
| HI-09 | Activity CSV download and individual proof image access. | Prototype; full binary evidence-bundle export, retention/search policy and access logs required. |
| HI-10 | Historical lookup does not borrow current source/custody from a reused order number. | Prototype guards; durable historical snapshots required. |

### 4.12 Settings, commerce and platform

Source basis: `driver-management.js`, `intake-rules.js`, `planning-actions.js`, `commerce.js`, `customer-tracking.js`; old Settings/Integration/Edge-state specs.

| ID | Feature and behavior to retain | Status / boundary |
| --- | --- | --- |
| ST-01 | Operating posture and own-fleet assistance settings, service/wait timing, delivery/vehicle rules and protected decisions. | Partial; reconcile full original authority overview and detailed editors. |
| ST-02 | Named/custom delivery windows, brand/pickup defaults, cargo classes, product-to-vehicle rules and special days. | Partial; existing controls do not establish all legacy editors are present. |
| ST-03 | Freelancer broadcasts enabled state, expanding search configuration, privacy and accepted-work boundaries. | Prototype; remove old own-capacity-gated/automatic broadcast authority. |
| ST-04 | Boards/features: local cities independent of Intercity; temperature stays deferred. | Prototype settings; entitlement/city permission enforcement required. |
| ST-05 | Separate multi-store WooCommerce/WordPress, Shopify and Custom API source setups with city/pickup defaults. | Prototype configuration, not connected authorization. |
| ST-06 | Independent intake, fulfillment, tracking-reference and exception writeback permissions; optional paid-order hold. | Prototype configuration and scenario evaluation. |
| ST-07 | Preview missing windows, city mismatch, repeated/older events, dispatched-order edits and failed writeback. | Prototype isolated samples; preview creates no delivery or provider request. |
| ST-08 | Real authorization/revocation, source health, last received/sent, webhook intake, reconciliation and idempotent retries. | Required backend + recovery UX. |
| ST-09 | Disconnect or pause preserves existing operational records and evidence. | Required; saved setup is not successful authorization. |
| ST-10 | Settings immediate/structured save semantics, invalid input, unsaved drafts, version conflicts and material-change consequences. | Partial; full original Settings safety matrix to reconcile. |
| ST-11 | Authentication, tenant/city roles, audit actors, durable storage, realtime updates, secure media and service credentials. | Required production foundation; client checks are not authorization. |
| ST-12 | Business-local timezone/date, currency, phone/address locale and configured routing coverage. | Required international SaaS foundation; current HTML is Thailand-oriented. |
| ST-13 | Server-owned clocks, versioned commands, one-winner acceptance, concurrent operators and offline reconciliation. | Required; prototype browser timers/session snapshots cannot be copied as backend rules. |
| ST-14 | Subscription/entitlement administration, billing and tenant onboarding. | Required specification decision; not established by the board. Define minimal launch scope without inventing pricing. |

### 4.13 Driver app carryover

Source basis: Supplied driver Manifest v6, UX Behavior Master v3.1, UI Constitution v1.2 and localization Spec 14. The 47 HTML driver boards were not revalidated in this documentation pass.

| ID | Feature and behavior to retain | Status / boundary |
| --- | --- | --- |
| DR-01 | One localized app; Thai-first in Thailand, English selectable at first run and Profile. | Required retained driver contract; one behavior model, not separate products. |
| DR-02 | Phone/OTP, team invite or independent path, profile, vehicle, identity/live-face checks, payout setup and verification correction. | Required retained A01–A12 family; provider implementation separate. |
| DR-03 | Start/end shift, assigned team work, shift ending/overtime, verification pending and freelancer open/not-open home states. | Required retained B00–B03 families; team work and freelancer availability distinct. |
| DR-04 | Single/multi-stop offers, eligibility, scope/fare/deadline, accept/decline, expired offer and race loss. | Required retained C01/C03 and current operator broadcast corrections. |
| DR-05 | Pickup navigation, explicit arrival, item checklist, discrepancy hold and custody confirmation. | Required retained D01/D03/D04. |
| DR-06 | Active Round, current-stop navigation and live changes with acknowledgements/freelancer consent. | Required retained E screens; reconcile new Intercity and post-pickup contracts. |
| DR-07 | Handoff, adaptive proof/photo/signature and stop/Round completion. | Required retained F/I screens; evidence originates in driver app. |
| DR-08 | Recipient unavailable, address/entrance issue, parcel problem, cannot complete and emergency. | Required retained G screens; location evidence and safe escalation. |
| DR-09 | Operations chat/call/contact history, My Rounds, Team Hours/corrections, Network Earnings, Profile and Notifications. | Required retained H/J/K/L/M screens; no actual payroll/payout claimed. |
| DR-10 | Contextual permissions, offline/reconnecting, GPS unavailable and background-location boundaries. | Required retained N screens; one state model shared with dispatch. |
| DR-11 | Embedded navigation intent and motorcycle mode subject to provider/field gate; planned route vs navigation vs actual trail separate. | Required legacy engineering gate; revalidate vendor choice in implementation, not a new guarantee here. |
| DR-12 | Intercity arrival, parcel receipt, receiver/local driver handoff and consent parity with national board. | Required driver-spec extension; current 47-board manifest does not establish all new intercity screens. |

### 4.14 Deferred ideas and exclusions

Source basis: Latest user scope decisions and retained research roadmap.

| ID | Feature and behavior to retain | Status / boundary |
| --- | --- | --- |
| DF-01 | Lalamove/external provider booking, quotes, fare ceilings and provider fallback. | Deferred; remove active release requirements, keep generic historical source/evidence compatibility. |
| DF-02 | Temperature sensors on parcels, bike boxes, cars and transport trips; threshold alerts, stale/missing readings and intervention record. | Deferred; sample temperature module exists in source, not launch commitment. |
| DF-03 | Cooling boxes, ice packs, hub refrigeration and validated transport duration/holding windows. | Deferred operational programme; sensor readings alone do not prove product condition or fault. |
| DF-04 | Vietnam/China network rollout and other-country service coverage. | Deferred expansion; no guaranteed market size, revenue or supported coverage. |
| DF-05 | Building-level visit grouping and advanced ranking/on-route matching. | Deferred discovery; preserve separate delivery evidence if pursued. |
| DF-06 | Florist recipes, stock age, purchasing and waste-reduction WordPress plugin. | Separate UrbanFlowers/product workstream; not part of Rounds dispatch scope. |

## 5. Original-spec reconciliation that must not be skipped

These are known differences or unverified parity items, not claims that every listed original control should be copied visually.

| Legacy requirement | Current finding / decision | Rewrite action |
| --- | --- | --- |
| Own fleet → Network → external fallback; own-capacity Wave 0 | Conflicts with explicit operator choice. | Supersede in Specs 2, 3, 11, index and engineering scenarios. No own-capacity gate for broadcast. |
| Preferred-driver alternating search waves and reputation | Initial direction is nearest-first expansion; ranking later. | Separate eligibility/relationship privacy from ranking; do not reintroduce legacy priorities silently. |
| Lalamove required as first provider | Removed from current scope. | Mark Spec 7 deferred and remove current onboarding/booking dependencies across specs. Preserve historical source types. |
| Bulk PDF/CSV | Present in legacy, absent from current file reader. | Retain IN-07 and specify normalizers plus batch review; do not call implemented. |
| Schedule / recurring shift / special-day editors | Defaults and date-specific shifts exist; full old Schedule surface not confirmed. | Reconcile PL-14 and ST-02, including overnight dates and copy/edit exceptions. |
| Known/preferred freelancer directory and Ask availability | Supply map and accepted-job contact are not the entire relationship directory. | Reconcile FL-08 and driver opt-in/privacy behavior. |
| Live own-driver post-pickup destination edits | Legacy explicit update/acknowledgement contract is wider than draft route impact. | Specify DI-09 separately from PL-09 and freelancer proposals. |
| Voice notes, attachment lifecycle and multi-thread/tray behavior | Communications implemented in part; no end-to-end media provider validation. | Map each original interaction to CM IDs and test exact keyboard/touch/draft behavior. |
| Broad merchant authority and Settings overview | Current settings expose a subset/reorganized surface. | Retain valid policy controls; discard only superseded broadcast/provider authority. |
| Old index says responsive/UX closure complete | Applies to old artifact, not proof the rebuilt Phase 36 passes. | Require fresh browser/iPad check against approved layout and current workflows. |
| Driver app marked 47 boards complete | Manifest predates new multi-city/intercity and revised broadcaster decisions. | Reconcile both sides of every command/event before declaring parity. |
| Existing exact-address memory | Not equivalent to reviewable saved entrance/access revisions. | Keep AD-09/10 as Required; no silent claim of completion. |
| Temperature code remains in compiled prototype | User explicitly deferred the topic. | Exclude from core acceptance/release; decide disabled/default visibility during spec reconciliation. |
| Non-home cancellation and legacy shortcuts | Some paths still contain home-city checks. | Audit all city workflows, especially DI-07, before claiming uniform multi-city parity. |
| Thailand fixtures, browser timers, in-memory IDs and sample fares | Useful prototype examples, not global contracts. | Replace with tenant/city authorization, configured locale, server clocks and durable IDs. |

## 6. Remaining work to specify now

### 6.1 Reusable entrance knowledge

For a confirmed destination, record business/city, building or site identity, precise entrance coordinate, access/parking and handoff notes, supporting source, confirmer, confirmation time and revision. Separate shared building entrance information from a recipient's private unit/floor and instructions. A subsequent delivery gets an explicit saved-location suggestion with Use saved entrance or Review and edit. Uncertain/AI-changed addresses remain held for review. Applying a saved record stores its revision on that delivery; later edits do not rewrite old evidence. Define correction, retirement and conflicting entrances. Prototype memory alone is insufficient.

### 6.2 Connection, upload and notification confidence

Specify browser connectivity, service connection, driver telemetry freshness and channel delivery state separately. Preserve drafts and staged evidence; give retry/discard actions without duplicate commands. Show last confirmed update time and identify whether data is queued locally or accepted by the service. Real provider receipt is required for Delivered notification. Loss of connectivity must not erase custody or resume an obsolete assignment after reconnect. Existing Street View recovery is one covered subset, not completion of the whole requirement.

### 6.3 Changes after freelance pickup

Retain the current accepted agreement until a valid response where consent is required. Classify operational instruction change, physical destination change, new collection, stop removal, return and transfer. Calculate affected time/distance and promises where available, identify fare/commitment changes, preserve completed stops and collected manifest. Never remove a loaded item without a documented destination, return or custody handoff. Define original-agreement continuation, decline, expiry, source mutation and driver unable-to-continue outcomes. Customer agreement and freelancer consent stay distinct. Map the result to Driver E/G screens and History.

### 6.4 Closeout rather than redesign

Audit the original board and old specs against every feature ID. Verify desktop and iPad landscape/portrait for the header, delivery rail, timeline, map controls, modal fit, keyboard, touch move alternatives, focus return and text overflow. Verify geographic markers during zoom/pan, Street View return and failed-load recovery. Keep the approved visual design; make only concrete interaction corrections. Browser/device verification remains outstanding. Do not repeat a subjective “world class” claim as a substitute for acceptance evidence.

## 7. Specification rewrite map

Start with shared product/actor/state definitions and the canonical index, then reconcile workflows and both app surfaces. Keep existing spec numbers where useful. Batch 1 now supplies the product foundation, broadcast contract and revised scope ladder; other destinations below remain to be written in detail.

| Spec owner | Scope and register coverage | Required changes |
| --- | --- | --- |
| Canonical index + product master (Spec 2) | WS, DI, shared entities and release scope | Current UI reference (Phase 39 brand alignment over Phase 36 workflows), business/city roles, feature status, operator authority, sample/production boundary. |
| Driver + broadcast model (Spec 3) | BC, FL relationships, DR offers/consent | Remove own-capacity prerequisite; concurrent city jobs; freelancer-only audience; accepted scope/custody. |
| Mapping and address intelligence (Spec 4) | AD, MP | Thai source/correction review, entrance records, Street View surface, distinct route/telemetry truths. |
| Tracking/notifications/integrations (Spec 5) | IN source intake, CM tracking, ST commerce | Normalized delivery contract, audience privacy, provider state/recovery, webhook idempotency. |
| Dispatch/route editing/comms (Spec 6) | DI, PL, CM chat, live changes | Timeline moves/impact, rolling releases, protected work, contextual conversations and acknowledgement. |
| External couriers (Spec 7) | DF-01 | Explicitly deferred; no live release dependency. |
| Operations visual system (Spec 8) | WS, all surface contracts | Approved fresh layout/spacing, contextual panels, full board height, mobile operator scope. |
| History/operating memory (Spec 9) | HI | Exact entity keys, causal attribution, immutable evidence, investigation and export boundaries. |
| Drivers/availability/contact (Spec 10) | FL, supply/contact portions of BC | Own versus freelancer modes, projected availability, relationship permission and privacy. |
| Settings/control center (Spec 11) | ST, configurable rules | Tenant/city config, valid automation boundaries, delivery profiles, changed broadcast and deferred modules. |
| Network supply (Spec 12) | BC-07 | Approximate pre-acceptance visibility, stale states, no arbitrary unknown-driver chat. |
| Edge states (Spec 13) | WS-07, CM-09, recovery across all features | Conflict/offline/timeout/empty/loading/partial-success with preserved work and retry rules. |
| Driver localization (Spec 14) + manifest/behavior/constitution | DR | Preserve one localized app; reconcile new operator commands, Intercity and concise task UI. |
| New Intercity operating contract | IC | Trip/leg/manifest, destination receipt, transfer and local work; ETA provenance and permissions. |
| Future cold-chain module | DF-02/03 | Deferred module interface only; no hardware or product-safety promise in core build. |
| Engineering roadmap/build scope/field validation | All accepted release IDs | APIs/events, transactions, state versions, adapters, realtime, permissions, storage and release tests. |

For every rewritten feature, include: purpose; actors/permissions; entry point; displayed data/provenance; state transitions; commands and events; validation; failure/retry/cancel; audit/evidence; city/tenant scope; driver/operator counterpart; acceptance examples; implementation dependency; release inclusion. Specify exact service schemas in engineering documents after product behavior agrees.

### Reconciliation ledger format

Use one row per legacy requirement, not just per file:

| Old source + clause | Feature ID | Decision | New spec + section | Acceptance case | Status |
| --- | --- | --- | --- | --- | --- |
| Spec 3 §5 Own-capacity check before broadcast | BC-01 | Superseded by operator-started choice | Spec 3, operator authority (to write) | Operator with available own driver may still start eligible freelancer broadcast | Documented decision; rewrite pending |
| Spec 2 bulk intake / canonical index 1B2 | IN-07 | Retain; prototype gap | Spec 5 intake normalization (to write) | PDF/CSV drafts reviewed through same form without automatic dispatch | Requirement captured; build pending |
| Original learned-location + Spec 4 | AD-09 | Extend | Spec 4 entrance record (to write) | Previously confirmed entrance offered with revision and review | Requirement captured; build pending |

The full ledger must cover all files in the supplied archive, including build and engineering documents, not only these examples. Resolve contradictions explicitly. Do not automatically expand the active build release to include every retained feature.

### 7A. Specification rewrite — batch 1 written

Deliverable: `Rounds-Specification-Rewrite-Batch01.zip`, dated 7 September 2026. The approved Phase 39 HTML is unchanged in this batch.

Written documents inside the package:

- `README.md`: new index, source authority, owner map, next batch and completion conditions.
- `product/ROUNDS-SPEC-2-PRODUCT-FOUNDATION-v3.0-DRAFT.md`: SaaS/city/actor model; shared objects; operator authority; capacity, custody, address and evidence invariants; 16 acceptance examples. This is a foundation rewrite, not completion of every legacy Spec 2 addendum.
- `product/ROUNDS-SPEC-3-BROADCAST-AND-DRIVER-CONTRACT-v2.0-DRAFT.md`: explicit operator-started freelance broadcasts, nearest-first expansion, city isolation, scope reservation/one-winner acceptance, pickup/POD, proposal/consent, recovery and settlement truth; 40 acceptance examples.
- `engineering/ROUNDS-IMPLEMENTATION-SCOPE-LADDER-v2.0-DRAFT.md`: small own-team pilot retained; Lalamove stage removed from active sequence; optional Intercity milestone added without making it necessary for local SaaS.
- `reconciliation/ROUNDS-DRIVER-DISPATCH-CONTRACT-MATRIX.md`: matching driver/operator event surfaces and missing refreshed/Intercity screen coverage.
- `reconciliation/ROUNDS-RECONCILIATION-LEDGER.md`: 18 selected cross-document decisions; mapping of the 66 numbered legacy Spec 3 sections and eight addenda; full 41-file original inventory with explicit pending audit status.
- `reconciliation/ROUNDS-FEATURE-COVERAGE.md`: all 150 feature IDs with implementation boundary, rewrite owner and current documentation status.
- `reconciliation/SOURCE-MANIFEST.json`: byte counts/hashes for the bundled unchanged original specs and supplied reference HTML.

The archive also contains the 41 original specs, approved Phase 39 Dispatch, four refreshed driver examples in the two supplied HTML files, and this updated register. Original files are references, not permission to execute superseded capacity-first/preferred-wave/Lalamove requirements.

Batch 1 remains a **product review draft**. New conceptual state names and detailed concurrency/retry resolutions are proposed contract decisions, not production code or silent changes to the approved UI. Numeric search parameters, commercial terms and exact service schemas remain unapproved/unimplemented. The 56 acceptance examples are written requirements, not executed production tests.

Reviewed for this batch: full legacy Spec 3, Driver UX Behavior Master v3.1, Driver Manifest v6 and implementation scope ladder v1.0; selected product/commercial/actor/capacity/manifest/live-change sections of Spec 2. The ledger is a selected-rule and section-level reconciliation, **not a complete clause-by-clause audit of all 41 originals**. Complete refreshed driver files are still needed for final screen parity; their absence does not block writing Dispatch contracts.

Next batch: detailed Spec 4 Mapping/Address and Spec 6 Dispatch/Planning/Comms, using the approved HTML and retained original clauses. Continue with intake/integrations, settings/history/drivers and Intercity, then exact engineering/build contract reconciliation. Full specification sign-off and browser/device/provider validation remain outstanding.

## 8. Sources and verification boundary

Primary inputs reviewed for this register:

- Current `Rounds-Fresh-Phase36-Delivery-Investigation.html` build assembly and fresh source module inventory, with focused reads of intake, map, fleet, broadcast and workflow implementation.
- `upload/rounds-operations-current-v45(1).html`: original workflow entry points and feature families.
- Supplied `spec-review/specs/product/ROUNDS-CANONICAL-SPEC-INDEX-v43.md`, original product spec headings and relevant behavior contracts.
- Driver Manifest v6, Behavior Master v3.1, UI Constitution v1.2 and Spec 14 references in the supplied archive.
- Prior improvement MD, reproduced below in full, including previously recorded competitor evidence and focused DOM/state checks.
- Latest user decisions captured in section 3, overriding conflicting historical statements.

No new market research was performed in this documentation pass. Appendix A's research links and dates are preserved as prior evidence, not represented as freshly verified. No UI was changed or rebuilt. No live provider, actual iPad, full driver-board set, production permission system or complete old-spec clause parity was verified by generating this register.

## Appendix A — preserved improvement log through Phase 36

The following is the previous MD in full. Its historical phase sequencing and “next” labels are superseded by sections 1, 6 and 7 above. Detailed implemented behavior, test qualifications and references remain useful evidence. “Implemented” always refers to the prototype unless the text explicitly establishes a connected production service.

## Rounds — product improvements and delivery plan

Updated 7 September 2026. Companion to `Rounds-Fresh-Phase36-Delivery-Investigation.html`.

### Product decision

Keep the approved Rounds visual system, unchanged logo and current entrance-inspection composition. Improve existing workflows using evidence from the original board, supplied specs and competitor documentation. UrbanFlowers is a sample tenant; features must serve other businesses too.

The deliverables have different purposes:

- **HTML:** demonstrate the actual interaction, decisions and states.
- **This MD:** record the reason for each change, its status, limits, acceptance conditions and source evidence.
- **Full specs:** rewrite after the remaining board decisions and gaps are closed. This document does not replace that work.

### Implemented in Phase 30: accepted freelance Round proposals

#### Entry and composition

Open **Broadcasts → an accepted Round → Propose a change**. The action appears in the Round itself. The editor uses the existing Network layout, typography, spacing and controls.

The operator can propose:

- Adding eligible deliveries at the same pickup, city and service date.
- Removing deliveries while retaining at least one; whole-job cancellation remains a separate action.
- Reordering deliveries with explicit earlier/later controls suitable for touch and keyboard use.
- Changing delivery windows.
- Changing the total guaranteed driver fare.

The editor shows the existing agreement, proposed sequence and windows, total fare, a required reason and response period. The default response period is ten minutes and can be set from one to thirty minutes for that proposal. This is a prototype product default, not a researched market standard.

#### Consent and preservation

Sending a proposal does not overwrite the accepted Round. The current agreement continues while the freelancer decides. Pending changes are visible in the Round and its Network list status.

Explicit sample responses demonstrate acceptance or decline. There is no timer that invents acceptance. The operator may withdraw a pending proposal; otherwise it expires when its response period ends. Decline, withdrawal and expiry preserve the accepted work and fare.

Acceptance validates the scope again, then applies the stop sequence, windows and fare together. Previous accepted scope is retained with the proposal record. Removed deliveries return to Ready; added deliveries enter the accepted freelance assignment and leave any draft own-fleet plan. All affected work retains activity records. Proposal history remains available after pickup.

#### Operational boundaries

- This phase supports proposals **before verified pickup**, while the freelancer is heading to pickup or at pickup.
- Pickup issues must be resolved before sending or accepting a change. A pending proposal may remain during a pickup hold until it expires.
- Arrival at pickup does not itself invalidate a proposal.
- Verified pickup supersedes an unanswered proposal and locks the physical manifest under the current agreement. The operator is not forced to wait for a proposal response to continue the original work.
- Cancellation before pickup also supersedes an unanswered proposal.
- Vehicle, pickup, city and service date stay fixed. Changed load is checked against the assigned vehicle type's configured stop and cargo limits.
- Proposed additions are **not reserved**. They remain available until acceptance and are rechecked then. If another assignment or a source edit makes an addition unavailable, acceptance fails without partially changing the Round.
- Only the assigned freelancer may respond. Stale, repeated and offline responses cannot apply a change.
- Changing a delivery window in this prototype does not claim that the customer has approved it or received a notification. Production must record the operator's authority and any required customer agreement separately from freelancer consent.
- Editing addresses, changing vehicle/pickup, and changing a Round **after pickup** are not implemented by this phase. Post-pickup additions need explicit collection and custody steps; removals may require a return or transfer.

#### Timing and production limits

The proposal editor explicitly says that road timing needs review. It does not fabricate an ETA or a time-saving estimate. A subsequent route-preview phase must calculate timing from a routing service and show effects on other commitments.

All freelancer responses, fares and records in this HTML are session demonstrations. Production requires authenticated driver responses, server deadlines, transactions, tenant isolation, durable records and actual notifications. Sample acceptance does not take payment.

### Implemented in Phase 31: commerce setup and flow preview

Open **Settings → Commerce connections**. This adds a section inside the existing Settings layout; the board header, logo and approved entrance-inspection panel remain unchanged.

#### Setup experience

- Separate setups for Shopify, WooCommerce/WordPress and Custom API sources, including multiple stores per tenant.
- Each source has a name, HTTPS address, default city and pickup, and its own intake/writeback preferences.
- Intake, fulfillment progress, tracking references and delivery exceptions are independent controls. An optional paid-order requirement holds unpaid orders in the preview.
- Duplicate store setups are rejected within the tenant/provider scope. Shopify setup uses the canonical `.myshopify.com` store address; other sources may include a base path.
- Drafts survive navigation within the tenant and can be explicitly discarded. Saved revisions prevent an older editor from overwriting newer settings.
- Setup is distinct from authorization: saving preferences always leaves the source **Not connected**. Last received/sent timestamps remain empty instead of inventing health data.
- The original separated commerce order ownership from Rounds delivery operation. That boundary is retained. Customer notification permissions stay in Tracking & notifications.
- Manual delivery entry and optional text/image autofill remain available independently.

This intentionally permits preparing settings before authorization. The original disabled connection controls until connected; the rebuilt UI labels these as saved setup preferences and does not claim to activate them.

#### Preview flow

After saving a setup, select **Preview flow**, choose a scenario and load its sample. The preview evaluates the saved revision, not unsaved configuration edits. Operators can correct the sample recipient/address/window or payment state and check it again.

Scenarios demonstrate:

1. Complete order → ready for address/cargo intake review.
2. Missing delivery window → needs a confirmed promise; no invented slot.
3. Repeated event → keep the existing delivery.
4. Older event → preserve the newer state.
5. Change to a dispatched delivery → Operations review; preserve the current agreement.
6. Failed outbound update → check retry readiness against writeback permissions and handover evidence.

A city conflict needs review instead of silently switching city or pickup. Paused intake holds the event. Writeback permissions are checked independently. Delivered status requires recorded evidence in the scenario. Editing sample fields clears an obsolete result. Setup and preview activity stay scoped to that tenant/source.

The preview creates **no delivery**, changes **no live Round**, and sends **no provider request**. Retry readiness is not a successful retry or a delivery receipt. The sample versions represent the normalized Rounds contract, not a claim that all three providers supply identical version fields.

#### Production and UI work still required

This phase completes the setup and isolated preview surface, not the live connectors. Remaining work includes:

- Secure provider authorization, permissions and disconnect/reconnect states through the Rounds service.
- Provider-specific adapters, order/fulfillment identifiers, field mappings and monotonic event handling.
- Actual authenticated intake, address/cargo validation, durable retry and reconciliation.
- Live health and failure queues, provider-confirmed writeback receipts, and recovery from revoked access.
- A disconnect action that preserves existing delivery, custody and History records.
- Production authorization for changing source setup and operation across cities.

The preview uses example recipient/address fields and configured city/pickup defaults; it is not a complete import validator for all service dates, products, cargo, partial fulfillments or provider event formats.

Source basis: original board `openS4IntegrationDetail` / `renderIntegrationSettingsPanel`; supplied **Spec 11 §10 Commerce flow** and **Spec 5 Connector rules**. Earlier user decisions supersede the old specs where they describe automatic own-fleet-gated broadcasting or Lalamove.

### Implemented in Phase 32: independent local city workspaces

Local city operations no longer depend on enabling Intercity. The approved logo, header structure, delivery-card system, planning timeline and entrance-inspection panel remain in place.

#### Operator experience

| Task | Interaction and result |
| --- | --- |
| Change operating city | Click the city name and select Bangkok, Pattaya, Korat, Hua Hin or Phuket. The standard local board opens. A configuration with one city disables the unnecessary picker. |
| Work without Intercity | Turn off Settings → Boards & features → Intercity workspace. The city picker, local deliveries, intake, local planning and freelancer broadcasts remain available. The current city is retained. |
| Review transport handoffs | With Intercity enabled, use **Intercity handoffs** in the delivery panel. The national board’s city links still open its city handoff view. Return to local deliveries without changing city. |
| Add local deliveries | The existing + delivery form works in every configured city. Text and image entry continue to autofill the same form. Local pickup city is retained on the new delivery. |
| Return to unfinished work | Each city retains its service date, Now/Plan view, queue filters, delivery drafts, intake rules and delivery windows in this session. An in-progress import blocks switching until processing finishes. |
| Set up the local fleet | Drivers shows only that city’s fleet. Add a local vehicle, then its driver. New drivers start off shift on already-open dates; set the required shift explicitly. Other cities do not gain that driver. |
| Plan and release | The existing timeline operates on that city’s drivers, vehicles, pickup and deliveries. Empty fleets show a setup action. Planning retains capacity, return/reload, conflict and release checks. |
| Assign from a local delivery | Open the fleet timeline for the delivery’s date, or compose a freelancer broadcast. Composing an offer does not start its search. |
| Find an accepted freelancer | Show on map opens the job’s local city, even with Intercity disabled. Its accepted scope and conversation remain attached to the job. |

#### Data and behavior changes

- Local fleet lists and new planning shifts are scoped to the city; a Bangkok driver cannot be assigned to a Pattaya delivery.
- Draft intake state and window definitions are retained separately by city. Image-source references remain attached to their original city draft.
- Local pickup IDs and coordinates are used by planning and commerce configuration. New non-home workspaces use explicitly sample pickup locations; configure actual operational locations before production use.
- City map pins and map bounds follow local deliveries. Bangkok’s sample fleet positions and legacy routes are not copied into another city. Local own-driver execution uses the shared released-round engine.
- Intercity manifest, receipt, local custody, proof and destination History flows remain intact. Turning the module off hides the transport interface; it does not delete transport records or local releases.
- Corrected intake numbering so mixed numeric and alphanumeric sample order IDs cannot produce a new order with ID `NaN`.
- Vehicle-type profiles and dispatch-assistance policies remain business-level settings. Individual vehicles and driver shifts belong to their operating city. This phase does not introduce a cross-city vehicle-relocation workflow.

#### Try this phase

1. Disable Intercity in Settings and select **Phuket** from the city name.
2. Open **Drivers**. Add a vehicle and driver; no Bangkok drivers should appear.
3. In Plan, select **5 September 2026**, enable the driver’s shift and use **Plan remaining** with the sample local deliveries.
4. Save and review the release. Switch to Bangkok and back to confirm that the Phuket work remains separate.
5. Re-enable Intercity and open **Intercity handoffs** to inspect the Phuket transport work. The local fleet and delivery drafts are preserved.

#### Practical limits

This is still a standalone interaction prototype. Changes last until reload. Real tenant authentication, city permissions, durable storage, driver-app notifications, production routing and integration adapters are separate implementation work. The configured cities and local pickup coordinates are samples; there is no new city-creation, depot-geocoding or city-archiving administration screen in this phase.

Mapbox integration is retained, including geographic markers; this phase does not establish live vehicle telemetry or validate provider coverage. Existing Bangkok weather examples remain scoped to their sample context. Google Street View activation and provider-display requirements remain as documented below. No Lalamove or temperature expansion was added.

### Implemented in Phase 33: review the impact of a draft route change

This phase retains the approved board layout and the full-height correction from Phase 32a. The new surface is a contextual review dialog; it consumes no permanent board or map space.

#### Entry points and interaction

- Drag a whole draft Round to another driver or departure time.
- Move a delivery between draft Rounds, insert it before another stop, or return it to Unplanned.
- Reorder deliveries with the existing earlier/later controls.
- Use the existing move/round editor, departure nudges or timeline keyboard controls.

These UI entry points stage a proposed change. The current assignments remain intact until **Apply change**. An unchanged drop does nothing. **Keep current**, close or Escape cancels the proposal and aborts pending comparison requests. Creating a new Round, automatic Plan remaining and the existing route-optimization comparison retain their existing flows.

#### What the operator sees

| Information | Meaning |
| --- | --- |
| Proposed move | Stable delivery/Round identity, destination and operating city/date. |
| Capacity | Before/after cargo units, vehicle limit, stop count and receiving vehicle type. Removing an empty source Round is explicit. |
| Driver availability | Scheduled free time after the driver’s last planned Round, including return and reload. This is a plan comparison, not a new live availability prediction. |
| Return | Before/after return-to-pickup time for Rounds on the affected drivers. |
| Delivery arrivals | Expandable list with each recipient, order ID, promise, proposed Round/driver, before/after arrival and late minutes. Unplanned stops have no proposed arrival. |
| Conflicts | Physical restrictions block applying. Timing follows the existing business setting: warn with an explicit **Apply with warnings**, or block. |
| Basis | Road estimates; no traffic. Waiting for delivery windows and configured service time are included. Bike/tuk-tuk local access still requires checking. |

#### Calculation and consistency requirements for the later specs

1. Capture the proposal and the current city/date/tenant context before requesting routes. Do not mutate assignments as the dispatcher drags or while a comparison is loading.
2. Evaluate both the source and receiving drivers, including their other Rounds. Use the existing pickup-transfer, capacity, overlap, shift, return/reload and live-work safeguards.
3. Obtain Directions results for missing before/after route geometries, using the existing vehicle road exclusions. Reuse available route results; request at most three missing routes concurrently with a 12-second request timeout. Validate response status, leg count, nonnegative finite durations/distances and geometry presence.
4. Do not show a distance-only fallback as the timing comparison. If road calculation fails or locations are missing, keep the original plan and offer **Recheck** / **Keep current**. Applying is unavailable until the comparison succeeds.
5. Compare captured inputs again before applying. Changed assignments, promises, preparation/broadcast state, shifts, vehicles, rules, release/execution state, operating city/date or route results invalidate the review. A stale proposal must be recalculated.
6. Apply the intended draft changes together, increment the draft revision and keep other work intact. A second Apply cannot repeat the move. The standalone implementation has in-memory consistency guards; production requires a server-side transaction and version checks across dispatchers.
7. Applying a draft change does not send notifications, update a freelancer agreement, or silently publish a release. Before a live run starts, existing release review controls still manage subsequent draft changes. Once the run starts, released Rounds stay protected and use the established live reassignment workflow.
8. Broadcast-held deliveries cannot be taken by the draft move flow. Accepted freelancer changes continue through the explicit proposal/consent process from Phase 30. This phase does not extend its ETA comparison or enable post-pickup manifest edits.
9. Preserve stable stop IDs, explicit insertion position and the same final result for drag, keyboard and edit-form paths. Real iPad drag/touch quality remains a device-validation requirement; touch operators retain the edit controls.

#### Scope and remaining work

Implemented here: the UI preview for draft whole-Round moves, stop transfers and reordering, connected to the existing Mapbox Directions request pattern. The controlled tests use routing fixtures; no live provider result is claimed as verified in this environment.

Not implemented here: a traffic-aware future-departure model, live GPS-based rerouting, weather effects, embedded Street View activation, actual driver notifications, cross-dispatcher locking or production persistence. The current lowest-level prototype planning methods still exist for internal use; the operator UI uses the new review layer. Production assignment endpoints must enforce the same safeguards independently of the browser.

To try: open **Plan**, use **Plan remaining**, then drag a draft Round to another driver or open a delivery’s Move control. Review its before/after effects, then apply or keep the current plan. Internet access and an accepted Mapbox token are needed for uncached road comparisons.

### Evidence informing the roadmap

This is an initial scan of six products, not an exhaustive market study or a hands-on benchmark. Official documentation establishes advertised behavior. Customer feedback supplies problem signals; older reviews do not establish current product deficiencies.

| Product | Documented behavior | Implication for Rounds |
| --- | --- | --- |
| OptimoRoute | Exact drag-and-drop placement and best-fit placement on a map/timeline. | Preserve operator control and make the consequences of a move visible. [Dispatcher guide](https://help.optimoroute.com/hc/en-us/articles/35511474016404-Getting-started-for-new-OptimoRoute-dispatchers) |
| Onfleet | Routing considers schedules, capacity, service times and traffic history; dispatch surfaces exceptions. | Evaluate real constraints and make recovery actions accessible. [Routing setup](https://support.onfleet.com/hc/en-us/articles/360023910371-Route-Optimization-Setup), [Dispatch](https://onfleet.com/assignment-and-dispatching) |
| Spoke, formerly Circuit for Teams | Depots, delivery zones, driver permissions, live changes, proof and notifications. | Expose modules when needed and provide clear business-level controls. [Help center](https://help.getcircuit.com/en/collections/1889210-circuit-for-teams) |
| Bringg | Coordinates owned fleets and external providers through delivery terms. | Keep responsibility and eligibility clear across operators and cities. [Delivery Hub](https://help.bringg.com/docs/about-the-bringg-delivery-hub) |
| Tookan | Offers tasks in batches based on distance, timing and group size, with agent acceptance. | Supports the practicality of expanding searches; Rounds retains operator-started broadcasting to eligible freelancers. [Pooling and allocation](https://help.jungleworks.com/knowledge-base/pooling-task-feature-in-tookan/) |
| Routific | Reattempt and visit-first driver workflows with dispatcher-controlled permissions. | Give operators and drivers practical controls with explicit authority. [Driver workflow](https://help.routific.com/en/articles/16-using-the-routific-mobile-app) |

#### Customer-reported problem signals

| Signal | Evidence quality | Product response to explore |
| --- | --- | --- |
| Last-minute route changes create repeated manual updates. | Indexed first-person review excerpt; full review page was unavailable during research. [OptimoRoute reviews](https://www.softwareadvice.com/fleet-management/optimoroute-profile/reviews/) | Preserve unaffected work; show and apply only the intended change. |
| Large apartment buildings are difficult to organize. | Indexed customer review excerpt; review date not established. [OptimoRoute reviews](https://www.capterra.com/p/161579/OptimoRoute/reviews/) | Separate building, entrance and recipient; group visits without losing individual proof. |
| Short-notice arrival updates are not enough for recipients. | Dated May 2022 first-person review; historical evidence, not a claim about today's feature set. [Onfleet reviews](https://www.trustradius.com/products/onfleet/reviews) | Distinguish promised window, revised estimate and approaching-driver notification. |
| Driver signal loss causes synchronization trouble. | Indexed first-person review; current persistence of issue unverified. [Onfleet reviews](https://www.softwareadvice.com/fleet-management/onfleet-profile/reviews/) | Explicit last-update time, pending uploads and reliable reconnect behavior. |
| Historical search/report access is insufficient for investigations. | Customer review; reflects that reviewer's configuration and experience. [SoftwareReviews](https://www.infotech.com/software-reviews/products/onfleet?c_id=48) | Search across configured retention and connect records to original evidence. |

These findings justify testing the workflows with actual dispatchers. They do not prove market-wide demand, uniqueness or competitive superiority.

### Phase 34: address correction review and stronger delivery panels

Implemented after the operator’s 7 September screenshot and feedback. The requirements below guide the production specs; the implementation and remaining integration limits are distinguished below.

#### Address corrections must be reviewable

Orders imported from Thai storefronts, copied text and screenshots may have incomplete or inconsistent addresses. AI may propose normalization or a correction, supported by address lookup and previously confirmed tenant records. A plausible suggestion is not a verified delivery entrance.

- Keep the original submitted address verbatim, separately from the AI-extracted address, normalized address, proposed correction and operator-confirmed address. Preserve order/source identity and any screenshot or raw text. The current raw-source retention is useful but `originalAddress` alone can already contain an extracted draft value; it is not a sufficient provenance record.
- If the destination address changes, show **AI suggested a correction · Review needed** beside that address. Carry a concise **Address review** state into the delivery queue and details until resolved. Do not use “AI fixed” or “Verified” for an unconfirmed suggestion.
- The review surface shows **Original → Suggested**, highlights the changed components, explains the reason briefly, and shows the candidate location. Offer **Confirm address**, **Edit**, and **Keep original**. Keeping the original address does not automatically verify its pin.
- Preserve house/building number, unit, floor, recipient instructions and handoff notes. Do not invent missing house or unit numbers. Thai script and transliterated names should remain distinguishable; postcode/district conflicts and multiple matching locations should remain explicit unresolved cases.
- Separate text/address review from physical entrance confirmation. A building or area match is not an entrance. Formatting-only changes can have a lighter presentation, but must not silently change the destination or promote an approximate pin to confirmed.
- Unresolved material address changes must be resolved before release, assignment or inclusion in a broadcast. This is a delivery-data requirement, not an own-fleet-capacity prerequisite or permission to automatically start/withhold unrelated broadcasts. Operators may continue processing other valid deliveries.
- On confirmation record the operator, time, chosen address/pin, suggestion source and original value. Keep that history in the delivery record for investigation.
- Reuse only appropriately confirmed tenant-scoped address records. Label reuse as **Previously confirmed address** with provenance, not as a fresh AI verification. Learning here means reviewed address memory; do not claim automatic model retraining.
- Apply the same review behavior to manual autofill and future commerce imports. Keep the existing manual Add delivery form. Production AI/address adapters and commerce synchronization still require integration.

Current implementation: the prototype now has correction comparisons, pending review states, explicit decisions and session approval events in addition to local extraction, optional AI-adapter support, geocoding, raw-source retention and tenant-scoped address memory. Durable storage, authenticated reviewer identities and production AI/address validation remain integration work.

#### Left panel hierarchy and styling

The approved screenshot shows useful space for the delivery queue, but its controls and secondary text are too pale and similarly weighted. Preserve generous card spacing and the approved Rounds structure while making the active work more legible.

- Strengthen primary/secondary text contrast, active tabs and delivery identity. Reserve faint styling for truly tertiary information.
- Consolidate the oversized date row, duplicated calendar affordance, search and filters into a more compact, consistently aligned control area. Keep actual date selection accessible; do not replace it with a decorative date label.
- Make the selected delivery and the next required action clear. An address correction should be visible in the card and open directly into the contextual review.
- Reduce the visual dominance of Intercity handoffs and optional text/image intake relative to the current delivery task. Keep both available when relevant.
- Give the Unplanned/All deliveries controls a clear relationship to Now/Plan and the active filters. Honest counts and readable labels must remain.
- Do not fill the empty queue with decoration or invented deliveries. In this screenshot the Unplanned filter contains one delivery; the empty space below it is expected. Improve hierarchy and control density without globally enlarging cards or adding a permanent footer.
- Check Now and Plan together, including long Thai addresses, many deliveries, empty results, active selection, review states and iPad layouts. Preserve the full-height board fix and existing manual and autofill entry paths.

Delivery: `Rounds-Fresh-Phase34-Address-Review.html` and this companion MD. Carry these decisions into the final spec rewrite after board gaps are closed.

#### Implemented interaction and data contract

- The manual Add delivery form remains primary. Optional text, image and AI autofill use the same draft. The address field is multiline for long Thai addresses.
- An AI adapter may return `address`, `originalAddress`, `suggestedAddress` and `addressReason`. Rounds also sends an address policy requesting source preservation, no invented house/unit numbers and human review. This request is a contract, not a guarantee of model accuracy.
- `originalAddress` is accepted as verbatim only if it appears in the raw source; otherwise a labelled address or exact extracted substring is used. If no exact address is traceable, the original field is explicitly unavailable and Keep original is disabled. The full message/image remains accessible; no extracted value is falsely presented as the original.
- Drafts and created deliveries retain `submittedAddress`, `extractedAddress`, `normalizedAddress`, the raw source and `addressReview`. Normalized text is a search value; it does not replace the delivery text. Local parsing is not labelled AI.
- Any differing AI address (including formatting differences in this conservative prototype), or untraceable AI extraction, opens an Original / Suggested comparison. Changed character spans are highlighted without requiring spaces between Thai words. The operator can confirm, edit or keep the source text. Confirm and Save reviewed address require the operator to check that they compared the source or confirmed with the customer. Empty edited text is rejected.
- Review is available in the manual form and mapping intake panel. An unresolved delivery may be created explicitly **for address review**; its issue is visible in Now and Plan. Plan’s Review action opens the contextual review directly. Delivery details expose the same review.
- Pending corrections block own-driver assignment, planning placement, plan release, new freelancer broadcast inclusion and intercity manifest submission. The guard reads `addressReview.status`, so merely setting an entrance pin cannot bypass it. Other valid broadcasts remain operator controlled.
- Review decisions store tenant, prototype reviewer label, actual ISO timestamp, original/suggested/chosen text, source ID and the prior pin reference. Order activity records the decision. Repeated decisions cannot reapply. An open order review rejects changes if the city, tenant, address, coordinates, stage or assignment changed, or the delivery entered an active workflow.
- Text approval and physical entrance confirmation remain separate. Every address decision clears the old pin and requires entrance confirmation. Geocoder candidates can still be inspected via Check on map while text review is pending, but their location cannot be confirmed until the text is reviewed. Coordinates returned by an AI adapter are ignored.
- **A map label never overwrites the full written address at creation.** This fixes the previous risk of dropping unit/floor/house information when a building-level match was chosen. Delivery notes also remain separate.
- Address memory refuses pending corrections and stores only explicitly confirmed locations. Reused records display **Previously confirmed address**; the stored record includes confirmation time, prototype actor, tenant and source ID. This is session memory, not model training.
- Optional **Try a sample address review** appears inside the autofill disclosure. It uses a clearly labelled Thai postcode fixture, not a live AI result. It only replaces a wholly empty default draft; otherwise it adds a separate draft and retains entered details. Nothing is automatically dispatched.

#### Panel composition

The header, logo, map workspace, entrance inspection and timeline composition are retained. Changes are limited to the delivery rail and address review surfaces:

- Stronger name, secondary address and next-action contrast; clear selected-card border and left accent.
- Aligned compact date/search controls, one native calendar affordance, and actual editable delivery date.
- Consistent Now/Plan selection and subordinate Unplanned/All deliveries and brand filters; counts are unchanged.
- More restrained handoff link and optional autofill entry, leaving the queue dominant.
- Long addresses wrap; the queue scrolls independently. Coarse-pointer controls use a 44px minimum target. Existing responsive board breakpoints and explicit four-row app layout are retained, with no permanent prototype footer.

#### Production work still required

No model service is connected by default. The existing optional authenticated extraction adapter now feeds the review flow; WooCommerce/Shopify import remains a configuration preview. A real implementation must authenticate tenant and reviewer server-side, validate adapter outputs and source spans, detect house/unit omissions, postcode/district conflicts and ambiguous candidates, enforce holds on every write endpoint, retain durable audit history, and apply provider data retention/licensing requirements. The prototype requires manual review rather than claiming it has solved these semantic checks. Reviewed geocoder results and memory remain session-only.

After text review, normal geocoding/entrance selection determines the destination city; the UI does not infer city changes from a corrected string alone. The current review dialog protects new/held delivery intake; changes to released or accepted work must continue through the existing workflow and freelance consent rules.

#### Try this phase

1. Open the HTML in Chrome. Use Plan to inspect the revised queue controls, card contrast and spacing; compare with Now.
2. Click **+**, expand **Autofill from message or screenshot**, then **Try a sample address review**.
3. Compare the Thai source and suggested postcode. Try Keep original, or tick the source check and confirm/edit. An address decision does not confirm its entrance.
4. To inspect the queue hold, create the sample **for address review** before deciding. Click Review from its Plan card. Confirm its entrance separately after resolving the address.
5. Your normal manual delivery form and real pasted-text/image reader remain available throughout.

#### Phase 34 verification

18 bounded address-review checks passed, covering Thai source preservation, untraceable originals, local/AI distinction, required confirmation, edit/keep behavior, pin invalidation, escaped source content, queue holds, stale review, preservation of full written addresses, memory eligibility, sample isolation, the actual form checkbox interaction, date control and duplicate IDs. The existing route-impact checks (17), complete manual/autofill-to-History workflow (22), and accepted freelance-change checks (16) passed against Phase 34. These are DOM/state checks with controlled fixtures, not real AI/geocoder service validation or browser-rendered visual/iPad verification. Browser visual checks remain outstanding.

### Implemented in Phase 35: dedicated Street View inspection

#### Operator experience

The approved entrance panel remains the entry point: **Inspect entrance → Street View**. Its existing map tab, recipient hierarchy, access notes and edit action are preserved. Street View now opens a dedicated viewport rather than a small panorama over the operational map.

- The viewer has a clear **Entrance map** return action, delivery reference/name/address, verification state, vehicle access and handoff notes.
- When inspecting several deliveries, previous/next controls change only the inspected target. They never reorder the route or edit delivery records. Return keeps that inspected target and focuses its entrance on the map.
- **Edit entrance & access** returns to the existing map-based edit form. Switching from an unsaved edit to Street View is blocked until Save or Cancel, preserving typed notes.
- The panorama receives the main working area; delivery context occupies a narrow adjacent column on desktop and iPad landscape. On narrower widths the panorama and context stack vertically. The embed area remains at least 200 × 200 px; small screens can scroll the dedicated surface.
- The operational board is hidden while the dedicated viewer is open, and the modal has an opaque white backdrop. Closing it restores the approved board without reserving permanent space. Logo, dispatch header, city modes, queue styling, timeline and other map controls are unchanged.

#### Connection, loading and recovery

| State | What the operator sees | Behavior |
| --- | --- | --- |
| No Google key | A closer look at the entrance; Connect Street View | Existing session-only connection dialog; external Google Maps remains available for a known pin. |
| No valid delivery pin | Start with an entrance pin | Return to entrance map. Do not request a city-centre panorama or label it as this delivery. |
| Loading | Opening Google Street View | Fresh iframe for the target and key. |
| Iframe load | Google viewer opened; check imagery in the viewer | This confirms only the iframe event. Google may display imagery, no coverage, or a key/service error. |
| Slow load | Still waiting; Retry viewer | After 15 seconds, leave the frame available and offer retry/external recovery. Do not report a false confirmed failure. |
| Iframe error | Retry or open the same location in Google Maps | Browser error handling; this does not decode Google’s error response. |
| Offline | Connection needed; delivery selection kept | Unload iframe; reconnect retries the current target. |
| Target/key changes or close | New request or clean return | Clear timer, invalidate old callbacks and unload old iframe so stale events cannot change the current state. |

Google controls missing-coverage and provider-error content inside its iframe. Rounds cannot reliably inspect that cross-origin content, so it exposes a persistent recovery explanation after load and never marks an entrance verified merely because imagery was opened. No coverage availability is fabricated.

#### Integration and SaaS boundaries

- The existing Google browser-key setup is retained. It is separate from the Mapbox key, starts empty and is held only for the session. A tenant association prevents reusing the configured key after changing tenant identity. Cities within the same tenant can use that tenant’s configured connection.
- Only coordinates and the configured browser key are included in the embedded request; recipient names, phone numbers and instructions are not sent as address queries.
- A key-format check is not provider authentication. Domain restrictions may prevent a downloaded local HTML file from opening the embedded viewer. Production requires a correctly configured Maps Embed API project and an allowed deployed origin.
- Loading an image never creates entrance confirmation, changes address-review status, releases a delivery or sends a driver message. Existing assignment, custody and manual/AI intake boundaries remain unchanged.
- The new surface removes simultaneous visible Mapbox and Street View display. This is a layout improvement, not a legal conclusion that the full application satisfies all applicable Google terms. Production agreement and data-provenance review remain required.

#### Provider references checked for this phase

Google’s Embed API supports interactive Street View through an iframe, requires a key and documents a minimum 200 × 200 area. It recommends `strict-origin-when-cross-origin`, which this viewer now uses. The requested coordinate can resolve to a nearby panorama. [Embed documentation](https://developers.google.com/maps/documentation/embed/embedding-map)

Provider errors may be displayed by the embedded service. Treat a loaded frame separately from usable imagery and offer recovery. [Embed error documentation](https://developers.google.com/maps/documentation/embed/error-messages)

Google’s standard terms restrict simultaneous Street View/non-Google map display and contain broader restrictions on combined use. The applicable agreement must be assessed before production activation. [Google Maps Platform terms](https://cloud.google.com/maps-platform/terms)

#### Try and verify

1. Select a delivery with a pin, open **Inspect entrance**, then **Street View**.
2. Without a key, inspect the full-size connection state and destination context. Use the existing connection settings when a valid key is available.
3. Return to **Entrance map**, or choose **Edit entrance & access**. Selection and the existing edit workflow are retained.
4. Open inspection from a planned Round to step through several destinations. A missing pin stays an explicit entrance task.

15 bounded Street View checks passed: separate surface, context retention, request coordinates, non-verifying load events, timeout/retry, stale callbacks, target navigation, offline/reconnect, clean close, missing pins, unsaved edits, key removal, context changes and unique DOM identities. Address-review checks (18), complete manual/autofill-to-History workflow (22) and route-impact checks (17) also passed against Phase 35. These checks use a controlled DOM and iframe events; they do not establish live Google key validity, imagery coverage, actual browser rendering or physical iPad behavior. Those remain acceptance checks on the deployed integration.

The next phase agreed at the end of Phase 35 was delivery investigation, implemented in Phase 36 below.

### Implemented in Phase 36: delivery investigation

#### Purpose and entry points

The original board connects driver contact history to delivery references, and the communication specification explicitly calls for delivery/order reference, driver, duration, outcome and dispatcher actor in call records (original `ROUNDS-SPEC-6-DISPATCH-ROUTE-EDITING-COMMS-v1.11.md`, section 9.3). This phase restores that relationship in the fresh board while keeping existing chat, proof and resolution workflows.

Open **Delivery investigation** from delivery details, **Investigate** from a History record, or **Investigate delivery** from an incident. This is an on-demand contextual surface; it adds no permanent panel or footer to the dispatch board.

#### What the operator sees

A compact summary above four sections keeps assignment, recorded handover/custody and the next review task visible:

| Section | Evidence presented | Boundary |
| --- | --- | --- |
| Activity | Existing delivery/trip events, structured freelance failed attempts and address-review decisions | Preserve source ordering; do not fabricate timestamps, reconstruct GPS traces or count arbitrary event strings as attempts. |
| Proof & items | Recorded recipient, handoff, authorization, notes, photo/signature, return receipt and recorded item quantities | Missing evidence stays missing. Images can be opened/downloaded; invalid unsupported image values are not rendered as trusted proof. |
| Communication | Explicitly delivery-linked messages/calls, related full conversations and customer-notification connection state | Driver-wide or Round-wide conversation is not automatically treated as evidence about this delivery. No notification receipt is invented from a preview. |
| Address & source | Recorded address, original submitted text when available, entrance/access/handoff information, review status and original import message/image | Archived records do not silently borrow source/address fields from the same order ID on a different date. Pending corrections link back to the existing address review. |

- Assignment and custody are separate. A legacy own-driver assignment without pickup evidence says custody is not recorded. A verified freelance pickup identifies the freelance driver; handover or return uses the corresponding recorded evidence. An intercity journey distinguishes the linehaul driver from the destination receiver according to the trip state.
- **Open delivery record** goes to the existing History record and its resolution controls. Investigation does not itself retry, reschedule, reassign, mark delivered or alter custody.
- **Download activity CSV** uses the established History exporter. It exports activity/report rows, not a complete binary evidence bundle; proof images remain individually available in the proof section.
- Refresh reads the latest session state. Opening or refreshing does not mutate delivery data or mark driver messages read. Opening an actual conversation retains the established read/unread behavior.
- Desktop uses a single scrollable evidence area. Narrow displays keep the same sections with wrapping summary facts, stacked evidence rows and scrollable tabs; there are no nested side panels. Browser/device visual verification is still outstanding.

#### Explicit communication linkage

The record identity is `tenant | city | service date | delivery ID`.

- Opening a related current conversation from investigation supplies that delivery identity. New operator sample messages and sample call records retain it. The chat displays a visible delivery context and a return link to investigation.
- A call captures its delivery reference when started. Switching chats while the call runs cannot attach the result to another delivery.
- General map/header chat remains available. Opening generic chat clears an empty draft’s previous delivery context; it does not infer a stop from the selected driver or their Round.
- Unsent text, staged files and pending uploads keep their original context. Opening another context does not silently retag them; the operator sees an explanation. Sending is blocked if an existing explicit delivery context no longer matches the current relationship.
- Incoming messages have no implicit delivery association. The explicit sample-reply action can reference the active delivery; general received events remain unlinked unless they carry a valid reference.
- The existing hotel and pickup sample messages now have explicit fixture references matching their established deliveries. They remain marked sample events, not real historical communications.
- Related historical conversations are accessible separately. Missing explicit links are not filled by guessing from message contents, time or the driver’s name.
- Investigation filters foreign-tenant threads and uses full record keys, preventing same-ID evidence from being combined across cities or service dates. Production still requires server authorization and durable tenant-scoped thread storage throughout the communication subsystem.

#### Existing functionality retained

The approved dispatch header and logo, city/intercity modes, operator-started freelancer broadcasting, manual/AI intake, address holds, route impact review, direct map-driver chat, History reports and resolution actions remain in place. No customer message or real driver call is sent by this prototype. Temperature and Lalamove remain deferred.

#### Validation and remaining integration work

16 investigation state/DOM checks passed: read-only assembly, explicit linkage, exclusion of driver-wide messages, contextual sends, call reference retention, generic-context reset, unsent-draft protection, date/city and tenant separation, missing notification receipts, proof gaps, escaped sources, conservative custody, freelance attempts, intercity responsibility and keyboard tabs.

Regression checks passed against Phase 36: address review (18), communication (12), direct map-driver chat (8), History/reporting (12), and the manual/autofill-through-delivery-to-History workflow (22). The older map-chat test was updated to explicitly open Intercity handoffs after selecting a city, matching the approved independent-city behavior introduced in Phase 32. These checks do not constitute browser rendering or physical iPad verification.

Production follow-through remains: immutable event IDs and timestamps/timezones, historical custody and assignment references, authenticated reviewer/operator IDs, server-side permissions, persisted chat-to-delivery references, searchable attachment evidence, provider-confirmed customer notification outcomes, stable media access, and a complete evidence-bundle export. None is represented as connected or complete by this phase.

#### Remaining UI sequence

1. **Reusable entrance information:** save and reuse confirmed tenant entrance/access records with provenance, dates and explicit correction/review.
2. **Connection and notification confidence:** distinguish stale location, queued uploads, reconnect and real provider receipt states; preserve drafts and pending work.
3. **Post-pickup freelance changes:** extend the existing consent flow with collection, custody and return/transfer requirements while preserving completed stops.
4. **Final board closeout:** browser/iPad checks, an original-board/spec parity review, then the full specification rewrite with these companion decisions incorporated.

Live AI, commerce, maps, telephony/messaging, freelancer service, storage and permission integrations are separate production work. Completing the HTML phases does not mean those services have been deployed.

### Prioritized remaining work

| Priority | Improvement | Current position | Acceptance condition |
| --- | --- | --- | --- |
| Implemented in prototype | Address correction review + delivery-panel hierarchy | Phase 34 includes the review flow, delivery holds and revised rail styling. | Production follow-through: authenticated AI/address integration, semantic validation, durable provenance and approval events. |
| Production follow-through | Live commerce connection lifecycle | Setup and isolated preview implemented in Phase 31. Authorization and real synchronization remain unconnected. | Authenticate, reconcile, show live health/failures, retry safely, and disconnect without deleting delivery evidence. |
| Implemented in prototype | Independent city workspaces | Local navigation, intake, fleet, planning, releases and freelancer map access operate independently of Intercity in Phase 32. | Production follow-through: persistent city configuration, permissions, actual depots and city lifecycle administration. |
| Implemented for draft moves | Route-change impact preview | Phase 33 stages UI moves and compares affected Rounds with road results before applying. | Production follow-through: traffic-aware/live impact, cross-dispatcher versioning, provider validation and a separate extension to freelancer change proposals. |
| Implemented in prototype | Street View activation layout | Phase 35 adds a dedicated surface, retained delivery context and iframe lifecycle/recovery states. | Production follow-through: valid domain-restricted key, browser/coverage validation and applicable agreement review; iframe load is not imagery verification. |
| Following | Post-pickup freelance changes | Pre-pickup proposals now implemented; post-pickup consent/custody extension pending. | Explicit extra collection, immutable completed stops, fare consent and required return/transfer records. |
| Implemented in prototype | Delivery investigation | Phase 36 assembles existing activity, proof, attempts, custody context, explicit communication links and source/address evidence. | Production follow-through: immutable event references, complete evidence export, authenticated access, notification delivery receipts and durable records. |
| Next | Reusable entrance information | Per-delivery pins and access notes exist. | Tenant-scoped customer/driver-confirmed entrance data with provenance, verification date and correction; no silent reuse of uncertain locations. |
| Following | Connection and notification confidence | Prototype has stale-position and disconnected-channel states. | Real telemetry age, queued uploads, reconnect outcomes and provider-confirmed message delivery; never equate a send click with delivery. |
| Later | Building-level visits | Not included in this phase. | Several recipients can share one physical visit while keeping separate orders, windows, parcel counts and proof. |

Keep temperature and Lalamove deferred. Do not add reputation ranking or automatically decide when an operator should broadcast. The freelancer network remains distinct from own drivers.

### Street View decision

The approved screenshot shows a strong entrance-inspection hierarchy: selected recipient, location, verification state, map/Street View tabs, access notes and one edit action. Keep that visual design.

The current HTML supports an optional Google Embed key held for the session; its fallback opens Google Maps externally. A Mapbox token is not a Google key. Google's Embed API supports Street View and currently has no usage charge, though a valid Google Cloud project/key and billing setup are required. [Google quickstart](https://developers.google.com/maps/documentation/embed/quickstart)

Google's standard terms restrict showing Street View alongside non-Google maps. Before enabling the embedded viewer in production, confirm the applicable agreement and adjust the activated Street View state as needed—potentially a dedicated inspection surface with Mapbox hidden. Do not claim that simply hiding Mapbox proves contractual compliance. [Google terms](https://cloud.google.com/maps-platform/terms)

No Google key was added, no live embed was activated, and the approved entrance panel was not redesigned in Phase 30. Customer/driver-supplied access notes should remain distinct from Google imagery; do not scrape or build a stored image library from Street View.

### Phase 32a: reclaim board height

Removed the obsolete phase-number / “Map driver chat” prototype footer. Fixed app grid placement so the board always occupies the flexible final row, including desktop layouts where tablet controls are hidden. Removed the reserved footer row at desktop and tablet breakpoints. Map connection announcements remain in an offscreen accessibility status; existing visible map loading and error controls are retained.

### Verification

Phase 33 passed 17 focused checks using controlled road responses: staging without mutation, road-derived comparison, cancellation, atomic stop transfer, duplicate Apply prevention, stale promise rejection, recheck, physical capacity blocking, warning/strict timing policies, unavailable routing, recovery, city-context changes, request cancellation, stop reorder, editor staging, started-release protection, unique IDs and retention of the full-height board. Existing intake-to-delivery/rolling-release (22 checks) and freelancer consent (16 checks) regressions also passed. These are DOM/state and source checks, not real browser rendering or provider integration tests.

Phase 32 passed 17 focused DOM/state checks covering independent navigation, empty city fleets, draft/window preservation, busy-import switching protection, vehicle and driver scope, stale editor context, local planning and release, accepted-work preservation, foreign-driver rejection, freelancer map navigation, handoff return paths, numeric intake IDs, one-city navigation, local map marker scope and the two assignment choices. Regression suites also passed for commerce setup (17 checks), intake-to-delivery and rolling release (22), freelance change proposals (16), and intercity manifest/custody/proof/map flows (12). The legacy Intercity-disable test was updated to expect the current city to remain selected.

Phase 31 passed 17 focused checks for configuration, draft preservation, duplicates, version conflicts, city/pickup mapping, sample correction, repeated/older events, released-delivery protection, permissions, tenant isolation and manual entry. Regression checks passed for accepted-Round changes, the intake-to-delivery workflow, and customer tracking preferences.

Phase 30 checks passed for proposal composition, scope preservation, wrong-driver rejection, decline, expiry, withdrawal, invalid windows/fares, capacity, atomic additions/removals, changed-source rejection, arrival, verified-pickup locking and repeated responses. Regression checks passed for broadcast search, freelance delivery/return and History.

Verification used DOM/state execution with a simulated map object. It does not establish browser rendering, live Mapbox/Google behavior, real iPad touch quality or a working backend. Visual browser and real-device verification remain pending from Phase 29.
