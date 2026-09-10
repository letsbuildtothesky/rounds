# P10 — Maps Navigation and Location Knowledge

Rounds specification set · Consolidated V2.3 · 8 September 2026

Feature scope: MP-01–08; AD-09–12; DR-11. Database ownership: entrances, entrance_revisions, location_observations, route_estimates, navigation_intents.

Authority: this document defines the product workflow. Machine contracts in contracts/ define exact payloads, states and transitions; decisions/ records deliberate defaults and exclusions. All mutations use authenticated scoped authority, required versions, idempotency and an audit trail. Approved current screens remain the visual reference; sample data is not a tenant default.

## Four map truths

Operations basemap renders; server plan/routing service owns planned sequence and estimate; Driver navigation SDK guides the current leg; Rounds-owned telemetry records actual observation/trail. A basemap or congestion color does not confer route authority. Do not force different provider geometries to match or copy restricted provider content into another map.

Preserve Operations, satellite/site/3D and Street View task surfaces where supported, selected driver/Round/stop focus, fit/zoom/orientation, supply layer and contextual actions. Default map is quiet and prioritizes routes/current issues. Clusters generalize at low zoom, selected work remains visible, and obsolete marker listeners/coordinates are removed. Maintain geography-derived positions on every camera update. Empty/loading/provider error retains board controls and explicit retry/fallback; no endless loading panel taking the board.

## Routing contract

Request has permitted points/source, actual profile/capabilities, departure instant, requested traffic mode and revision/hash. Result has distance, duration, permitted geometry, provider/profile, calculated_at/expiry, restrictions/warnings and explicit traffic awareness. Store/display only content allowed by provider policy. Planner feasibility uses conservative configured handling time and flags unknown estimates. No unrestricted truck/tuk-tuk/motorcycle support inferred from displaying its icon.

Driver destination intent key = driver + stop + destination version + provider. Screen remount/retry reuses intent where provider permits; actual SDK requests are measured separately. Real pin/destination change increments version and safely updates navigation with required acknowledgement/consent. Contact and exception access stay available without covering vendor safety controls. Primary embedded navigation intent is retained; Flutter/native integration must pass combined field gate. External maps is explicit recovery, not a claim that embedded SDK is implemented.

## Entrance inspection and knowledge

Keep the approved contextual entrance panel: selected delivery identity, verification state, entrance map and Street View tabs, access/handoff notes, edit/confirm action and close return. Embedded Google Street View requires configured allowed key/context and actual coverage; external link remains an explicit alternative. Loaded iframe alone does not prove correct/verified imagery. Error/no imagery preserves map/notes and lets operator retry or continue legitimate address work.

Knowledge stores stable site/entrance identity, reviewed revision, point, supported vehicle access, parking/loading/handoff notes, author/time and permitted provenance. Recipient unit/private instructions stay delivery-private. Driver candidate observation includes source/time/accuracy; report without GPS is allowed. Approval promotes a reviewed revision, not an entire raw AI/provider payload. Applying saved entrance snapshots revision on delivery; later corrections never rewrite completed evidence. Retire an invalid entrance without deleting its historical use.

## Traffic, rain and freshness

Traffic overlay and traffic-aware ETA are separately labelled capabilities. Weather has provider, observation/forecast time, coverage and expiry. Rain can contextualize affected work and prompt operational review; it is not automatically a cause of a delay or safe driving instruction. Driver view offers concise relevant warnings without a distracting general weather feed. Missing/stale forecasts remain unavailable/stale, not clear weather.

Exact telemetry carries observed_at, received_at, accuracy/source and authorized work entitlement. Older delayed batches may contribute to history but cannot move the current marker backward in time. Interpolation is labelled estimated and stops at defined freshness limits. No decorative continuous motion when observations are absent. Before acceptance only minimized approximate Network supply is exposed; one tenant cannot inspect other tenants' routes.

## Weather decision contract

Weather layer has Auto / On / Off. Auto surfaces only decision-relevant rain/severe conditions and keeps routes dominant. Traffic overlay and traffic-aware ETA remain different capabilities. Do not add generic rain minutes to traffic that already includes current congestion.

An independent weather buffer needs a stored reason: forecast not yet reflected in traffic, extra protection/loading/handling, approved motorcycle safety constraint or exposed handoff access. Record provider, observation/forecast interval, freshness, independent buffer and affected rule. Apply configured limits. A vehicle rule may propose/require safer eligible capacity or create operator attention; it never initiates freelance broadcast automatically.

## Reusable entrance learning

Parse contact, room/floor and private delivery instructions separately from geographic address. Search reviewed merchant/site knowledge before the configured external provider; compare Thai/English aliases and prior successful access evidence. Preserve original text and provenance.

Successful arrival/handoff creates a location observation with accuracy/time. Repeated consistent evidence can support confidence/last-confirmed metadata under reviewed rules. Conflicting coordinates trigger review, not blind averaging. Wrong gate, closed entrance and security refusal are distinct from recipient unavailable, traffic-only delay or driver error. Only supported reusable access knowledge may be promoted; customer unit/private notes remain delivery-private.

## Vendor integration gate

Retain Mapbox Operations and selected embedded Google navigation subject to the original provider-coherence field gate. Current Google Routes policies restrict displaying Routes results on non-Google maps; implementations must resolve each service's permitted storage/display before selecting server routing/geocoding. The reviewed provider references and implications are in E10. A credentials field or screenshot is not proof of valid coverage, terms or mobile behavior.

### QA-AD-05

Actor: Authorized actor for ConfirmEntrance; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ConfirmEntrance under the condition in expected outcome; query affected records and compare committed events..

Then: Edit entrance point and handoff notes together: one revision is created and both fields return from GetEntrance..

Status: written requirement; application execution pending.

### QA-AD-09

Actor: Authorized actor for ConfirmEntrance,ApplyEntrance; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ConfirmEntrance,ApplyEntrance under the condition in expected outcome; query affected records and compare committed events..

Then: Confirm entrance revision2 then apply to D2: D2 references revision2 and preserves its own floor/unit and delivery instructions..

Status: written requirement; application execution pending.

### QA-AD-10

Actor: Authorized actor for RetireEntrance; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute RetireEntrance under the condition in expected outcome; query affected records and compare committed events..

Then: Retire a saved entrance: it is excluded from new suggestions while historical delivery references still resolve the old revision..

Status: written requirement; application execution pending.

### QA-AD-11

Actor: Authorized actor for ReportLocationObservation; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ReportLocationObservation under the condition in expected outcome; query affected records and compare committed events..

Then: Driver reports wrong entrance: observation is proposed and original confirmed entrance remains current until authorized review..

Status: written requirement; application execution pending.

### QA-MP-01

Actor: Authorized actor for UI; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute UI under the condition in expected outcome; query affected records and compare committed events..

Then: Switch Operations/Satellite/3D and back: selected driver/stop remains selected and attribution remains visible..

Status: written requirement; application execution pending.

### QA-MP-02

Actor: Authorized actor for UI; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute UI under the condition in expected outcome; query affected records and compare committed events..

Then: Driver, vehicle and numbered delivery pins match returned IDs; selecting a stop highlights only its route..

Status: written requirement; application execution pending.

### QA-MP-03

Actor: Authorized actor for UI; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute UI under the condition in expected outcome; query affected records and compare committed events..

Then: Fit selected route, rotate and restore map: board context and delivery rail selection are preserved..

Status: written requirement; application execution pending.

### QA-MP-04

Actor: Authorized actor for GetRouteEstimate; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetRouteEstimate under the condition in expected outcome; query affected records and compare committed events..

Then: Traffic unavailable gives traffic_state unavailable; a drawn traffic layer alone does not change ETA provenance..

Status: written requirement; application execution pending.

### QA-MP-05

Actor: Authorized actor for UI; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute UI under the condition in expected outcome; query affected records and compare committed events..

Then: Rain provider unavailable shows layer unavailable/retry; no random sample rain is labelled live..

Status: written requirement; application execution pending.

### QA-MP-06

Actor: Authorized actor for GetRouteEstimate; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetRouteEstimate under the condition in expected outcome; query affected records and compare committed events..

Then: Planned Mapbox geometry, Google navigation intent and measured trail have distinct source/type identifiers..

Status: written requirement; application execution pending.

### QA-MP-07

Actor: Authorized actor for UI; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute UI under the condition in expected outcome; query affected records and compare committed events..

Then: Invalid map key leaves searchable delivery list and plan actions usable; error shows retry and never hides all work behind indefinite loading..

Status: written requirement; application execution pending.

### QA-MP-08

Actor: Authorized actor for CreateNavigationIntent; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute CreateNavigationIntent under the condition in expected outcome; query affected records and compare committed events..

Then: Unverified vehicle/profile returns UNSUPPORTED_PROFILE; Mapbox cycling is never labelled Thai motorcycle navigation..

Status: written requirement; application execution pending.

### QA-DR-11

Actor: Authorized actor for CreateNavigationIntent; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute CreateNavigationIntent under the condition in expected outcome; query affected records and compare committed events..

Then: Background/device field gate measures actual GPS continuity, Thai guidance and selected vehicle behavior; no declared production pass without device evidence..

Status: written requirement; application execution pending.

### QA-V21-WEATHER-DOUBLECOUNT

Actor: Route estimation service.

Given: Current traffic already includes rain congestion; no independent handling effect.

When: Calculate ETA; then add approved120s waterproofing rule.

Then: First adds no rain-only duplicate delay; second adds120s with stored rule reason.

Status: written requirement; application execution pending.

### QA-V21-ENTRANCE-CAUSE

Actor: Address reviewer.

Given: Verified entrance EN1; failed D1 reason recipient unavailable.

When: Record failure; compare entrance confidence; record conflicting gate observation.

Then: Recipient failure alone does not lower entrance confidence; conflicting gate requires review.

Status: written requirement; application execution pending.
