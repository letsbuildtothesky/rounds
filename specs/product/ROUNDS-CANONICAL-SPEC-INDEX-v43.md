# Rounds · Canonical Specification Index

**Version:** 43  
**Canonical Operations UX artifact:** `rounds-edge-states-v45.html`  
**Canonical Driver UX artifact:** `ROUNDS-DRIVER-APP-ENGLISH-BOARDS-2026-09-01/` (47 boards; Thai mirrors behavior)

Older versioned specifications are preserved.  
Where a newer version conflicts with an older one, the newest listed version controls.

## Business product

1. `ROUNDS-SPEC-2-BUSINESS-PRODUCT-MASTER-v2.26.md`
2. `ROUNDS-SPEC-3-DRIVER-BROADCAST-OPERATING-MODEL-v1.9.md`
3. `ROUNDS-SPEC-4-MAPPING-ADDRESS-INTELLIGENCE-v1.8.md`
4. `ROUNDS-SPEC-5-TRACKING-NOTIFICATIONS-INTEGRATIONS-v1.6.md`
5. `ROUNDS-SPEC-6-DISPATCH-ROUTE-EDITING-COMMS-v1.11.md`
6. `ROUNDS-SPEC-7-EXTERNAL-COURIERS-v1.4.md`
7. `ROUNDS-SPEC-8-OPERATIONS-VISUAL-SYSTEM-v1.15.md`
8. `ROUNDS-SPEC-9-HISTORY-OPERATING-MEMORY-v1.5.md`
9. `ROUNDS-SPEC-10-DRIVERS-LIVE-AVAILABILITY-CONTACT-v1.4.md`
10. `ROUNDS-SPEC-11-SETTINGS-CONTROL-CENTER-v1.5.md`
11. `ROUNDS-SPEC-12-NETWORK-SUPPLY-MAP-LAYER-v1.1.md`
12. `ROUNDS-SPEC-13-OPERATIONS-EDGE-STATES-v1.0.md`

## Driver product

13. `ROUNDS-DRIVER-CANONICAL-MANIFEST-v6.md`
14. `ROUNDS-DRIVER-UX-BEHAVIOR-MASTER-v3.1.md`
15. `ROUNDS-DRIVER-UI-CONSTITUTION-v1.2.md`
16. `ROUNDS-SPEC-14-DRIVER-LOCALIZATION-LANGUAGE-v1.0.md`

Legacy `MASTER-*` / `PHASE-*` Driver documents and parity/sync audits are preserved in historical archives but are **not implementation authority**. Current Driver behavior is controlled by the four sources above plus the canonical 47-board UX library.

## Implementation boundary

This index defines **current product truth**, not the scope of a single release.

- Product-complete V1 is broader than Pilot/Slice 1.
- Active build scope is controlled by `ROUNDS-IMPLEMENTATION-SCOPE-LADDER-v1.0.md` in the implementation baseline.
- The 47 Driver boards are a product-design library; only screens required by the active slice are implemented.
- Historical specifications are not implementation sources. If current sources conflict, implementation must stop and report the conflict rather than searching old versions.

### Mapping / navigation control

- Operations V1 renderer: Mapbox GL JS.
- Driver active navigation: embedded Google Navigation SDK / `TWO_WHEELER`, subject to Phase 0 validation.
- Server planning/routing and address/geocoding providers remain abstracted and vendor-term constrained.
- Planned route, active navigation leg and actual Rounds-owned trail are separate truths.
- The basemap never becomes authoritative route/ETA logic.

## Current locked business-surface decisions

### Intelligent New Delivery
- screenshot / image / PDF / clipboard / manual entry are first-class intake sources;
- AI creates a structured delivery draft, never dispatches automatically;
- uncertain fields remain visible for human review;
- Address Intelligence resolves destination/access separately from raw source;
- original source is preserved as evidence/reference;
- reviewed structured fields create the operational delivery.

### Dispatch
- Work rail + dominant Operations map (Mapbox GL JS V1 renderer) + contextual right drawer.
- Action means a human/business decision is required.
- Own fleet → Rounds Network → External courier when merchant policy permits.
- Map explains decisions.
- Traffic/weather only surface when decision-changing.
- Optional Network Supply layer can reveal nearby open/busy shared capacity without exposing exact pre-acceptance GPS or other merchants' work.
- External courier fallback is a complete live lifecycle: expiring quote → booking → driver assignment → pickup → en route → delivered → provider POD.
- External booking may be cancelled before pickup; after pickup, provider failure/cancellation becomes a custody exception and cannot silently reassign the package.
- Lalamove may appear as a small provider label on the distinct external map marker; provider branding remains subordinate to Rounds.
- Responsive workstation contract is locked for laptop and iPad-class landscape/portrait: primary navigation stays reachable, Dispatch remains rail + map + overlay drawer, and Plan preserves a horizontally scrollable fleet timeline with touch-safe controls.
- Full Operations is not a phone-sized Dispatch/Plan product; phone may later be a separate narrow alert/approval/lookup companion.
- Browser-offline state never implies the backend, provider or driver is offline; live claims become paused/last-known and blocked live actions do not mutate state.
- Quiet, loading, no-match, degraded and recovery states follow `ROUNDS-SPEC-13-OPERATIONS-EDGE-STATES-v1.0.md`.

### Driver contact
- click/tap driver → action popover;
- right-click = optional shortcut;
- Center on driver ≠ Show full Round;
- multiple conversations persist in bottom tray;
- one expanded conversation at a time;
- map/tray/top-bar communication state remains synchronized.

### Drivers
- Own drivers;
- Network drivers;
- Schedule;
- live presence and work availability are separate states;
- own-driver rows must show current work/shift plus next available where calculable;
- Network drivers may publish `Open for jobs` or `Not accepting jobs` without changing identity/verification;
- known/preferred Network drivers may expose `Ask availability` and, only where opted in, relationship messaging;
- unknown open-network drivers are reached through Offer/Broadcast, not arbitrary chat;
- exact pre-acceptance Network GPS is protected; merchant UI uses approximate distance/area until an accepted-work tracking relationship exists;
- availability/offline state is not itself a Network performance penalty.

### History
- Primary information architecture: Overview / Deliveries / Drivers / Incidents.
- Own / Network / External remain unified fulfillment scopes inside relevant records, not primary tabs.
- History is the operating memory: delivery evidence, POD, waiting, traffic/weather, exceptions, communications, cost, driver execution and causal attribution.
- Driver performance only includes driver-attributed operational events; recipient, traffic/weather, Operations/provider and unresolved causes remain visible but are not automatically counted against the driver.
- One opaque driver score is not canonical.
- History H3 Driver record separates **live context** from durable performance evidence.
- Own-team history may include shift reliability, driver-attributed execution, acknowledgement, workload and custody/POD evidence.
- Network history evaluates accepted commitments; open/offline/not-accepting state remains non-penalizing context.
- H3 exposes only the contact action permitted by current relationship/state and protects exact pre-acceptance Network GPS.

### Settings
- Overview is the operating-control readout: authority posture, setup gaps, configuration map and protected-decision reminders;
- Dispatch is the direct editor for Automatic / Approval posture plus own-fleet and Network authority boundaries;
- Delivery rules directly edit named/flexible timing, slots, special days, vehicle profiles, Round patterns, product/vehicle rules and cargo classes;
- Rounds Network directly exposes enabled state, matching progression, fare/radius authority, accepted-work consent and Network Supply privacy;
- External couriers explicitly sit beneath Own fleet → Network, with provider connection, health, spend authority, fare ceiling, fallback trigger and failure behavior;
- Integrations;
- Tracking & notifications;
- Overview never silently edits detailed rules; it links to the owning page;
- visible Settings actions must be functional; no decorative/ghost controls.

### External couriers
- First provider: Lalamove;
- merchant connects own provider account;
- default Ask before booking;
- optional automatic authority inside merchant fare limit;
- external delivery remains inside Rounds Dispatch/History.

*End of index.*


## New Delivery interaction correction

- `New Delivery` is one continuous intake surface.
- Drop/paste is a compact optional accelerator at the top.
- Manual delivery fields are visible immediately underneath.
- No AI/manual mode-selection click is required.
- AI fills the same fields the dispatcher can type into directly.


## Actor model lock

- Merchant/pickup comes from the business/location profile.
- Recipient is the required delivery person.
- Buyer defaults according to merchant configuration.
- Buyer may be `Same as recipient` without duplicate data entry.
- For gifts, buyer may be a different person and is the commerce/gift sender.
- Courier-provider pickup contact is the merchant pickup contact, never implicitly the buyer.
- Product UI avoids ambiguous `Sender` terminology.


## Phase 1B1 · Vehicle / Cargo / Round Rules

- Vehicle profiles own reusable physical delivery constraints.
- Max Stops per departure is separate from planning throughput.
- Departure patterns support multi-stop and return/reload operating models.
- Cargo classes and per-profile quantity limits are first-class.
- Drivers/shifts reference vehicle profiles.
- One common load validator must be reusable by Dispatch, Network and the future bulk planner.


## Phase 1B2 · Bulk Delivery Intake

- `+ Deliveries` is the single intake entry point.
- One or many screenshots/images, PDF, CSV and pasted rows are supported sources.
- Multi-delivery sources produce a batch review.
- Batch states: Ready / Needs review / Missing data.
- Only validated ready drafts can be committed in bulk.
- Committed deliveries enter the planner contract as `planning_state = unplanned`.
- Separate legacy CSV import UX is removed in favor of the same normalized intake pipeline.


## Phase 1B3A · Planning Workspace

- Planning is a Dispatch operating mode, not a new room.
- Layout: unplanned pool / dominant map / bottom driver timeline / contextual right drawer.
- Planner outputs sequential physical Rounds per driver.
- Return/reload gaps remain visible.
- Plan summary exposes coverage and uncovered work.
- Explainability is required.
- Generated plan is proposed until the later approval/adjustment phase.


## Phase 1B3B · Plan Adjustment & Approval

- Delivery Stops, not drivers, are moved.
- Desktop drag and iPad/touch Move actions call the same planning mutation.
- Every move is previewed against vehicle, cargo, Stop, promise and shift rules.
- Invalid moves are blocked and explained.
- Affected driver lanes recalculate after valid changes.
- Empty proposed Rounds are removed.
- Approval is explicit and converts valid proposed Rounds into upcoming work.
- Uncovered deliveries may remain after approval but must stay explicit.


## Phase 1B3B implementation reconciliation

- Generated plans reject promise-window placements the same way manual moves do.
- Planned Stop drag begins from an explicit handle.
- Touch/iPad Move uses the same mutation engine.
- Approval creates semantic `Upcoming` work; current demo may internally reuse legacy `planned` status.
- Uncovered deliveries require acknowledgement and remain Action/unplanned after own-fleet approval.


## Phase 1B3C · Planning Precision

- Planning date is explicit and controls deliveries/shifts/plan output.
- Timeline horizon is calculated from actual shifts and promised work.
- Timeline is not fixed to 08:00–18:00.
- Round capacity is multidimensional, not one generic load percentage.
- Move previews expose Stops/cargo usage and the constraining dimension.
- Approved Upcoming Rounds inherit the selected planning date.


## Phase 1B3C implementation reconciliation

- Selected-date driver availability uses date exceptions before recurring schedule.
- Date-specific vehicle-profile assignments feed planning.
- Zero-work dates cannot generate an empty proposal.
- Overnight operating days may display next-day times such as `01:00 +1`.
- New Delivery/bulk drafts carry an explicit service date.
- Planning capacity bottleneck is the maximum active physical dimension, not Stop count alone.


## Phase 1C1 · Physical Manifest + Pickup Verification

- Every delivery normalizes to a structured physical manifest with item lines and quantities.
- Commerce/import/manual sources feed the same manifest.
- Driver confirms the physical manifest at pickup before custody changes.
- Dispatch mirrors the checklist/progress state.
- Pickup-confirmed manifest becomes custody evidence and is not silently editable.

## Phase 1C2 · Handoff Verification + POD

- The same manifest is verified at handoff when policy requires it.
- POD photo originates in the Driver App.
- POD record can include photo, GPS/geofence, handoff, received-by, signature/note and both manifest-verification stages.
- A short restrained map success acknowledgement may follow committed completion and then settle to normal completed state.

## Phase 1C3 / 3B · Rich Shared Communications

- Operations and Driver App use one persistent delivery/Round thread.
- Human content: text, voice, photo, file, location/map context and auto-detected web URLs.
- Operations desktop accepts visible drag/drop for files/URLs and clipboard image paste.
- Attachments stage before Send; multiple attachments plus optional text are supported.
- `Link` is removed from the attachment menu; pasted/typed URLs are message content.
- Contact History is moved out of `+` and rebuilt as a chronological ledger with All / Messages / Calls / Files & media filters.
- Copy works on both Operations and Driver App.

## Spec synchronization lock

Phases 1C1–1C3 above are canonical product decisions, not prototype-only behavior. Future UX changes affecting physical manifest, pickup/handoff verification, POD or communications must update the controlling specifications and this index in the same work cycle.


## Phase 1C4 · Post-Pickup Live Change Control

- Operations and Driver App are separate role-specific surfaces; neither embeds a preview of the other.
- Pickup-confirmed manifest remains immutable custody evidence.
- After pickup, Operations may change destination/address, operational pin, promised window and handoff instruction.
- A physical destination change uses a confirmed new pin and reroutes the current live Stop.
- Future Stops remain editable through the normal own-fleet Round editor.
- Before Apply, Rounds exposes route time/distance, ETA, downstream, promise and shift consequences where relevant.
- Apply creates a versioned `live_delivery_changed` event and pushes the update to the assigned Driver App.
- Driver acknowledgement originates from the Driver App/realtime contract; Operations only observes the acknowledgement state.
- The applied change and acknowledgement remain in Contact History/audit.


## Visual Phase V1 · Premium Foundation

- Operations uses a canonical global visual system before section-by-section refinement.
- Major surfaces use deliberate 22–34px margins/padding rather than thin edge spacing.
- Normal operational text is 13–14px; 12px is reserved for true metadata.
- Font weight is reduced across common hierarchy; spacing and scale do more of the visual work.
- Primary controls use navy, restrained small radii and consistent 40–48px control heights; pills are not canonical.
- Shared icons use one simple line language at approximately 18px with rounded caps/joins.
- Drawers are wider and use editorial spacing instead of dense equal-weight rows.
- Shadows are reserved for floating surfaces/drawers, not ordinary content cards.
- Responsive compression preserves readable type and touch targets.
- Later visual phases must inherit the latest canonical Operations Visual System, currently `ROUNDS-SPEC-8-OPERATIONS-VISUAL-SYSTEM-v1.15.md`.


## Visual Phase V2 · Dispatch Live

- Dispatch Live receives the first section-level premium visual refinement; product behavior is unchanged.
- Top shell uses calmer navigation, coherent 44px utility controls and more deliberate spacing.
- Wide desktop Dispatch rail may expand to ~350px with ~24px internal margins; laptop widths compress deliberately.
- `Live / Plan`, status tabs, search, group headers and delivery rows use one coherent operational hierarchy rather than many equal-weight boxes.
- Selected work links rail → active Round/Stop → drawer; unrelated map content quiets without hiding risk/action state.
- Live map header is a ~64px map-context surface with compact bordered Rounds/Automation controls and unified map chrome.
- Wide desktop contextual drawer may expand to ~448px and uses editorial decision rhythm, stronger spacing and consistent ~50px actions.
- Plan mode is explicitly outside V2 and remains structurally/stylistically unchanged until its own visual phase.


## Visual Phase V2A · Dispatch card optimization

- Live delivery rows use the full rail width: reference + recipient/location + semantic state tag form the primary scan line.
- Product/handling and manifest evidence remain visible without forcing state into a crowded footer.
- Footer is simplified to time + assignment/route context.
- Strong alternating orange card fills are not canonical; semantic color must retain meaning.

## Visual Phase V3 · Plan mode premium refinement

- Plan architecture is unchanged and remains inside Dispatch.
- Plan rail, date controls, proposed-plan header, summary metrics, fleet lanes, Round blocks, reload moments and planning drawer inherit the premium Operations grammar.
- Selected Round/lane dominates; unrelated planning work quiets but remains legible.
- Timeline remains resizable and all existing planning mutation/approval behavior remains canonical.

## Visual Phase V4 · Drawer system + interaction integrity

- Operations uses one premium contextual drawer language across Live and Plan: sticky editorial header, wider deliberate margins, aligned detail rows, compact impact facts and consistent actions.
- Raw text close glyphs are replaced by the shared line-icon language.
- Visible controls may not be decorative. They must work, navigate to a real surface, be explicitly disabled, or be removed.
- Bell/alerts now opens the current operational-alert ledger; profile opens Settings.
- Canonical static QA checks unresolved inline action functions, unbound button controls and duplicate static DOM IDs before promotion.


## Visual Phase V3A · Plan finishing lock

- Live and Plan share locked shell geometry at each breakpoint; mode switching must not jump/reflow the frame.
- `Live / Plan` is a proper segmented two-mode control with a sliding selected surface; no underline treatment. Plan count remains compact text.
- The full fleet-timeline top edge is draggable, double-clickable, keyboard-resizable and remembers height for the browser session.
- Timeline retains right/bottom finishing gutters while remaining docked and scalable.
- Plan map header is compact and avoids duplicate planning copy.
- Selected proposed Round dominates across timeline + map; unrelated planning work quiets substantially but remains legible.


## Visual Phase V4A · Smooth mode switch + communications / verification polish

- Live / Plan uses one sliding two-segment control; no active underline is canonical.
- Live ↔ Plan exchanges content with restrained motion while shell geometry stays fixed.
- Plan controls and timeline transition in/out rather than appearing as abrupt layout jumps.
- Communications chrome, thread, attachments, staged files and composer use the premium Operations visual grammar without changing shared-thread behavior.
- Contact History remains an audit ledger rather than a chat duplicate.
- Physical manifest, pickup verification, handoff verification and POD now share one premium custody/evidence visual system.
- Existing functional controls and the no-ghost-control rule remain mandatory.


## History Phase H1 · Operating Memory Overview

- History opens to Overview by default.
- Overview answers: how are we operating, what needs attention, and why did it happen.
- Default management period is 30 days; 7 / 30 / 90 day period controls are functional in the prototype.
- Top readout includes delivery volume, on-time rate, exceptions, driver-attributed exceptions, blended delivery cost and POD compliance.
- Needs attention contains only evidence-backed signals and links to a real driver/delivery/evidence surface.
- Exception attribution separates driver / recipient / traffic-weather / operations-provider causes.
- Non-driver causes remain in History but are excluded from driver performance where attribution supports that treatment.
- Recent operational record exposes cause, impact and performance treatment and opens an evidence drawer.
- History export creates a real CSV file.
- History H1–H4 is complete: Overview / Deliveries / Drivers / Incidents.


## History Phase H2 lock
- Deliveries is a unified evidence workspace with source/result/exception filtering and search.
- POD, exception, promise/actual, fulfillment source, driver, cost and performance treatment stay attached to the delivery record.
- Evidence export must perform a real download in the prototype.
- H2 delivery evidence remains canonical; H3 Drivers and H4 Incidents are now also complete.

## Drivers availability/contact behavior lock · H3 + pre-V5

- `ROUNDS-SPEC-10-DRIVERS-LIVE-AVAILABILITY-CONTACT-v1.4.md` controls live availability and pre-job contact behavior.
- Canonical live language includes `On shift · available`, `On Round`, `Available after HH:MM`, `Open for jobs`, `Not accepting jobs`, and `Offline / stale` as appropriate to relationship.
- `Available after HH:MM` is a projection derived from accepted work and can change; it is not a reservation.
- A preferred/known Network relationship may use a structured `Ask availability` request. Direct relationship messaging requires driver opt-in.
- An unknown Network driver who is merely open for jobs must not expose casual Message/Call controls before acceptance.
- Once Network work is accepted, normal job-linked Message / Call / Voice note becomes available.
- Own-driver scheduled shift attendance may affect reliability history; Network offline/not-open time outside accepted commitments does not.
- Current live state belongs primarily to Drivers; History owns durable evidence/trends and must not confuse presence with performance.
- These rules are implemented in History H3 and the dedicated top-level Drivers V5 command surface.



## History H4 · Incidents
- Incidents is now a canonical evidence workspace with causal attribution, impact, performance treatment, filters and evidence trail.


## Drivers V5 · Premium Command Surface

- `Drivers` uses one stable page identity with Own team / Network / Schedule sub-surfaces.
- Own team answers who is working, current work, vehicle/shift and projected next availability, with real Message / Call / Open Round actions only when valid.
- Network answers who is open now or soon, approximate location context, relationship and accepted-work evidence while enforcing contact permission and location privacy.
- `Ask availability` is functional; Message requires direct-contact permission; Offer work is shown for compatible open Network capacity.
- `Not accepting jobs` / offline availability never becomes negative performance evidence.
- Schedule remains own-fleet only and highlights the actual current day; capacity summaries use current-date shifts and exceptions rather than a hard-coded first schedule column.
- Full durable reliability evidence remains in History, preventing Drivers from becoming a duplicated analytics screen.


## Settings S1 · Premium Overview

- Canonical Settings surfaces are inherited by the current UX checkpoint, `rounds-edge-states-v45.html`.
- Operating posture leads the page and states automatic vs approval mode plus human-control boundaries.
- Authority at a glance summarizes own-fleet insertion, exception treatment, Network and external courier authority.
- Setup attention is reserved for configuration gaps that materially limit the operating model.
- Configuration is grouped into Execution and Connections & customer rather than a generic equal-weight card wall.
- Detailed settings pages remain unchanged until S2–S5.

## Network Supply Map Layer · v1

- Live Dispatch may expose an optional `Network supply` layer; default is off.
- Open capacity appears as restrained hollow orange points; busy capacity is smaller and neutral.
- Low zoom clusters capacity; normal operational zoom resolves small individual points.
- Before acceptance, Network location is generalized and other-merchant identity/routes/Stops remain hidden.
- Unknown open supply is reached through Offer/Broadcast, not arbitrary chat.
- Known/preferred identity/contact remains subject to the Drivers Availability & Contact contract.
- Accepted work transitions to the normal exact job-linked tracking/communication contract.
- Production rendering uses native Mapbox GeoJSON/vector layers, clustering and viewport/radius filtering rather than high-frequency DOM markers.



## Settings S2 implementation lock

- Dispatch authority controls mutate the same `automationSettings` used by Dispatch.
- Numeric authority boundaries edit through a focused Settings drawer and save immediately.
- Protected custody / exception / accepted-work consent rules are visually separated from editable merchant authority.
- Delivery Rules exposes the shared physical planning contract rather than creating a second planning model.
- Named slot duplication creates a real editable slot copy.
- Product-to-vehicle handling rules are now reachable from Settings.
- Settings S2 inherits the global no-ghost-control rule.


## Settings S4 implementation lock

- Integrations is a commerce-flow control surface: source, health, inbound delivery intake and normalized writeback are visible together.
- Shopify, WooCommerce and Custom API/webhook are canonical connector choices in the current UX.
- Manual / screenshot / PDF / CSV / clipboard intake remains available without a connector.
- Connector permissions independently control order intake, fulfillment writeback, tracking-link writeback and exception writeback.
- Tracking & notifications separates Sender/Buyer, Recipient and Surprise Protection.
- Customer channels are configured separately from Operations↔Driver communication.
- Sender / Recipient routing is configurable for scheduled, out-for-delivery, material ETA change, recipient-action-required, delivered, failed, retry and returned events.
- Notification failure never rolls back Dispatch/custody/POD state.
- Sender and Recipient tracking previews preserve customer/privacy boundaries.
- Settings S4 visible actions are functional under the no-ghost-control rule.


## Settings S5 · Completion lock

- Settings S1–S5 remains complete in the current UX checkpoint, `rounds-edge-states-v45.html`.
- Immediate switches save immediately and expose persistence feedback.
- Structured Settings editors use explicit Save and protect unsaved drafts on close/navigation/Escape.
- Invalid structured rules are blocked before mutation with focused inline validation.
- High-impact changes require consequence confirmation: Network disable, timing-model switch, commerce/provider disconnect, special-day delete, tracking-page disable and Surprise Protection disable.
- Disabling a source preserves existing delivery, History and custody/provider evidence.
- No visible Settings control may be decorative or ghost-functional.

## Product / UX closure checkpoint

- Operations quiet/loading/error/degraded states and laptop/iPad responsive QA are complete in v45/v41.
- The returned 47-screen Driver English board set is now synchronized into product specs.
- Driver is Thai-first (`th-TH`) with English secondary; first-run language selection and Profile language change are canonical.
- Thai boards are localization/layout-QA artifacts and must preserve identical behavior one-to-one.
- Product/UX specification work is now ready to transition into Engineering Build Specs and Phase 0 implementation.

## Driver localization + commerce integration lock

- Production Driver App is one localized app, not separate EN/TH implementations.
- `A01 → A01B Choose Language → onboarding`; later language change lives in `L01 Profile`.
- Thailand is Thai-first, English remains first-class.
- Shopify App, WooCommerce extension and Public Rounds API all normalize through one canonical server-side Rounds delivery contract.
- Plugins/connectors do not write Rounds database tables directly.
- Exact API/OpenAPI/webhook schemas move to Engineering Build Specs.

## External courier finish checkpoint

- Quote freshness/scope is validated before booking.
- Requote is explicit.
- Provider lifecycle is normalized into Rounds states and audit.
- External map identity is `Lalamove` using a restrained provider label rather than a large logo.
- Pre-pickup cancellation returns work to Action.
- Post-pickup external custody is protected.
- External POD is normalized into the delivery record/History where provider proof is available.
- Production provider truth must come from the server-side Lalamove integration; the canonical HTML lifecycle is a UX simulation only.
