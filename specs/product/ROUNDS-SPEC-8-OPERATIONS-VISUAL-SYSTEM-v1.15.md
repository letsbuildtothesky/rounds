# Rounds · Operations Visual System

**Version:** 1.15
**Status:** Canonical — Operations visual system + History H1–H4 + Drivers V5 + Settings S1–S5 + Network Supply + External Courier Finish + Responsive workstation + edge-state lock
**Canonical UX checkpoint:** `rounds-edge-states-v45.html`

## 1. Purpose

This specification locks the shared visual grammar for the Rounds Operations product before screen-by-screen refinement. It does not change product behavior, information architecture, routing logic, planning logic, custody rules or communication contracts.

Rounds should feel like premium operational software: calm, spatially generous, highly legible, precise and fast. Density is allowed where the work requires it, but the interface must never feel cramped, decorative, toy-like or visually noisy.

## 2. Core visual principles

- Preserve the light Operations environment; no dark application shell.
- Use whitespace as structure. Major surfaces receive deliberate margins instead of edge-to-edge compression.
- Prefer hierarchy over boxes. Do not wrap every section in a card.
- Use color primarily for state, selection, risk and action—not decoration.
- Orange remains the Rounds accent; navy remains the primary action/operational anchor.
- Avoid pill-shaped controls. Controls use a restrained small radius only.
- Avoid excessive heavy/bold text. Premium hierarchy comes from size, spacing and contrast before font weight.
- Floating controls may use a restrained shadow; ordinary content rows and sections should remain flat.
- Icons must be visually consistent: simple line icons, rounded caps/joins, approximately 18px in standard controls, with consistent optical weight.

## 3. Color tokens

```text
Canvas          #F6F7F8
Paper           #FFFFFF
Ink             #172238
Secondary ink   #3D4A5D
Muted           #748094
Line            #E1E6EA
Strong line     #CBD4DC
Navy            #172238
Orange          #FF6420
Green           #168B50
Amber           #AA701D
Red             #BF4A4A
Blue            #3269B7
```

Soft state backgrounds must remain very light and should never overpower the operational content.

## 4. Spacing system

Use a deliberate spacing rhythm based on approximately:

```text
4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 px
```

Canonical desktop spacing guidance:

- Top bar horizontal padding: ~24px.
- Dispatch rail header: ~22–24px.
- Contextual drawer header/body: ~24px.
- Business surface outer padding: ~32–34px.
- Major drawer section separation: ~24–26px.
- Standard operational row height: ~56–60px.
- Primary action group top margin: ~24px.

Do not use thin 8–12px outer margins for primary surfaces merely to fit more information.

## 5. Typography

- Normal operational text: 13–14px.
- Secondary text: 12.5–13px.
- 12px is reserved for true metadata, timestamps, compact labels and dense timeline notation.
- Avoid sub-12px text in normal product UX.
- Major screen titles: ~30–31px.
- Drawer titles: ~25–26px.
- Decision headlines: ~21–22px.
- Use weight ~700–820 for most hierarchy.
- Reserve very heavy weight for compact numeric/identity emphasis only; do not make every label 900+.
- Uppercase kickers are small, spaced and restrained.

## 6. Controls

- Standard icon/utility controls: ~40–42px.
- Form controls: ~44px minimum.
- Primary drawer actions: ~48px.
- Control radius: approximately 5px; never a pill.
- Primary action: navy fill, white text.
- Secondary action: white fill, strong neutral border.
- Destructive action: white or restrained red treatment; do not use red fill unless urgency requires it.
- Hover states should be subtle. Active/pressed state may shift by ~1px.
- Focus-visible treatment must be clear and accessible.

## 7. Icons

- Use one coherent icon family/language across the Operations product.
- Standard visual size: ~18px inside 40–42px controls.
- Stroke width around 1.8–2px with rounded line caps and joins.
- Avoid novelty icons, badges used as decoration, inconsistent filled/outlined mixing, or emoji as permanent product iconography.
- Status dots are semantic and small (~7px).

## 8. Drawers

Drawers are editorial decision surfaces, not dense tables.

Preferred rhythm:

1. Context / kicker.
2. Strong title.
3. Short explanatory line where needed.
4. Primary decision/facts.
5. Main action.
6. Supporting details/evidence.

- Desktop drawer width is approximately 430px where space permits.
- Drawer header/body padding is approximately 24px.
- Use restrained left shadow only while open to separate the drawer from the map.
- Avoid equal visual weight for every section.

## 9. Selection and state

- Selected work should become unmistakably dominant across linked surfaces.
- Non-selected items may quiet slightly, but important risk/action state must never disappear.
- Green = confirmed/safe/success.
- Amber = attention/review.
- Red = blocked/danger/failure.
- Blue = informational/live system state.
- Orange = Rounds accent, planning emphasis, selected/proposed actions.

## 10. Shadows and surfaces

- Ordinary rows, tables and sections remain flat.
- Shadows are reserved for floating controls, menus, communication windows and open drawers.
- Avoid stacked card shadows or decorative elevation.

## 11. Responsive behavior

The premium spacing system compresses deliberately rather than collapsing into cramped legacy values.

- Wide desktop: full spacing.
- Standard laptop: moderate horizontal compression.
- iPad/tablet: maintain touch targets and hierarchy; reduce optional metadata before reducing primary control size.
- Do not solve narrow layouts by shrinking text below the readable floor.

## 12. Phase V1 implementation lock

The canonical Operations UX now applies this foundation globally to:

- top shell and shared controls;
- Dispatch rail;
- map header/shared map controls;
- contextual drawers;
- business surfaces;
- forms;
- primary/secondary/destructive buttons;
- shared status/data readouts;
- communication window chrome.

Subsequent visual phases refine individual surfaces using this system. They should not reintroduce cramped margins, pill controls, excessive bold weight or inconsistent icon treatment.


## 13. Visual Phase V2 · Dispatch Live

Visual Phase V2 refines the primary Operations workstation without changing routing, planning, custody, communication or automation behavior.

### 13.1 Top shell

- Dispatch Live uses a slightly more generous desktop shell with approximately 26px horizontal padding and a 76px top-bar height where space permits.
- Navigation weight is calm; the active section uses a restrained 2px orange underline rather than heavy filled navigation.
- Workspace identity remains visually secondary to the Rounds wordmark and active product navigation.
- Network state and utility controls use quiet, consistent 44px controls with coherent line icons and no decorative badges beyond semantic status/unread indicators.

### 13.2 Dispatch rail

- Wide desktop Dispatch rail may expand to approximately 350px; standard laptop widths compress deliberately.
- Rail header receives approximately 24px horizontal and 28px top padding.
- `Live / Plan` remains a segmented operational switch, but its selected state is calm and premium rather than visually heavy.
- Action / Ready / Live / Done remain one scanable four-column status strip with a restrained active underline.
- Search is a full 48px operational control with visible focus treatment.
- Delivery rows remain a flat work list, not independent floating cards.
- Selected work uses a restrained orange-tinted wash plus the semantic left state line. Unselected rows remain readable rather than disappearing.
- Recipient identity, reference, physical context, timing and operational state use clear typographic hierarchy rather than many equally bold labels.

### 13.3 Live map chrome

- Live map header owns map context only: city/mode, current scope, Rounds/Automation controls, health and decision-changing impact.
- Header height is approximately 64px on wide desktop and compresses on smaller screens.
- `Rounds` and `Automatic` are compact bordered controls rather than underlined text links.
- Map mode, camera, focus and zoom controls share the same restrained border, shadow, radius and icon language.
- Map legends and weather/traffic chips remain secondary to routes, Stops and current decisions.

### 13.4 Linked selection

Selecting a delivery must create one coherent visual state across rail, map and drawer.

- The selected delivery row becomes visibly dominant in the work rail.
- If the delivery belongs to an active Round, that Round is emphasized and unrelated routes/markers quiet down.
- The selected Stop receives an additional orange focus ring/scale treatment.
- Unassigned work uses the existing selected-order marker treatment.
- Closing the drawer or changing the active queue tab clears the linked focus state.

### 13.5 Live drawer

- Wide desktop contextual drawer may expand to approximately 448px where space permits.
- Header and body use approximately 28px padding on wide desktop.
- Drawer hierarchy is editorial: context → title → decision → impact → supporting sections → actions.
- Decision headlines use size/spacing before extreme weight.
- Impact facts may use one restrained neutral fact strip; ordinary supporting sections remain flat.
- Standard detail rows are approximately 62px with more breathing room and lighter typography.
- Primary, secondary and destructive drawer actions use consistent approximately 50px height and 6px radius.
- The drawer shadow is reserved for separation from the map while open.

### 13.6 Scope lock

Visual Phase V2 does **not** redesign Plan mode. Plan mode continues to inherit the V1 foundation until its dedicated visual phase. V2 also does not alter Dispatch workflow, driver state, route logic, automation, communication contracts, manifest/POD behavior or post-pickup change authority.


## 14. Visual Phase V2A · Dispatch Card Optimization

- Delivery cards use the available rail width deliberately rather than stacking all information on the left.
- Reference, recipient/location and operational state share one top scan line where width allows.
- The operational state is a compact semantic tag at the upper right; status color remains meaningful and is not used as decorative alternating card fill.
- Product/handling evidence remains central; manifest state remains visible; the footer is reserved for time and assignment/route context.
- Strong orange alternating rows are not canonical. Very light group/selection tints may be used, but state colors retain semantic meaning.

## 15. Visual Phase V3 · Plan Mode

Visual Phase V3 refines Plan mode without altering planning logic, capacity validation, approval, mutation or date behavior.

- Planning keeps its canonical layout: unplanned/action rail, dominant map, resizable fleet timeline, contextual drawer.
- Plan rail uses the same premium spacing and control language as Live while remaining visually distinct as a planning state.
- Date controls, input count and Generate Plan form one composed planning control area rather than a stack of unrelated controls.
- Proposed-plan header owns plan status, operating horizon, coverage summary and approval actions.
- Timeline summary metrics may use restrained neutral metric cells because they are a compact planning instrument; ordinary content remains flat.
- Fleet lanes receive stronger rhythm, clearer driver/vehicle/shift hierarchy, quieter off-shift space and more legible time gridlines.
- Round blocks use restrained depth and small radius. Selected Round/lane receives dominant emphasis; non-selected Rounds quiet but remain readable.
- Return/reload moments are visually distinct but secondary to Rounds and Stops.
- Plan drawer inherits the shared premium drawer system and uses wider margins, clearer capacity hierarchy and calmer detail rows.

## 16. Visual Phase V4 · Premium Drawer System + Interaction Integrity

### 16.1 Drawer hierarchy

All Operations contextual drawers use one editorial hierarchy:

1. context kicker;
2. strong title + short context line;
3. primary decision/state;
4. compact impact facts when relevant;
5. supporting evidence/details;
6. clear primary/secondary/destructive actions.

- Wide desktop drawers may use approximately 448–452px where available.
- Header/body padding is approximately 28px on wide desktop and compresses deliberately.
- Drawer header may remain sticky while the body scrolls.
- Close uses the shared line-icon language rather than a raw text glyph.
- Detail rows align labels and values in a two-column grid where width allows; narrow layouts stack them.
- Impact metrics may use small neutral cells; do not wrap every supporting section in a card.
- Action buttons use consistent hierarchy, touch size, focus state and disabled state.

### 16.2 No ghost-control rule

Visible controls are product promises. A control may not be left as decorative chrome.

- Every visible button must either invoke a meaningful prototype/product action, navigate to the intended surface, or be removed/disabled with an explicit reason.
- Prototype-only role switching or fake application previews are prohibited.
- Shell utility icons follow the same rule as drawer actions.
- In the canonical prototype, operational alerts open a real alerts drawer and the profile/settings control opens the real Settings surface.
- Map zoom controls, drawer close actions, planner actions and dynamically rendered drawer buttons remain wired to executable handlers.
- Static QA must check for unresolved inline action functions, unbound button controls and duplicate static DOM IDs before a visual checkpoint is promoted to canonical.


## 17. Visual Phase V3A · Plan finishing lock

This pass finishes the Plan workstation without changing planning behavior.

### 17.1 Shell continuity

- Live and Plan use the same top-bar height, rail width, rail title geometry and map-header height at the same breakpoint.
- Switching `Live / Plan` must not visibly jump or reflow the application shell. Only mode-specific content changes.
- Breakpoint compression must also stay mode-consistent.

### 17.2 Live / Plan mode control

- The mode control is a flat operational tab switch, not a button nested inside a filled track.
- Active mode uses dark text plus a restrained orange underline.
- Plan count is small orange text, not a separate filled badge.
- The control occupies identical geometry in Live and Plan.

### 17.3 Fleet timeline flexibility

- The entire top resize edge of the fleet timeline is draggable; the center grip is only a visual affordance.
- Double-click toggles normal / expanded height; keyboard Arrow Up / Down and Enter / Space remain supported.
- Chosen timeline height is remembered for the browser session.
- The timeline keeps sensible minimum/maximum heights so map context cannot be accidentally eliminated.
- The timeline remains vertically scrollable for fleet scale and horizontally scrollable for long / overnight operating horizons.
- A small internal right and bottom finishing gutter prevents the final lane/time content from feeling jammed against the browser edge while the workstation remains docked.

### 17.4 Plan header

- Plan map header is intentionally compact: `Bangkok · Plan`, planning date + coverage context, Plan summary, proposal state, Round/reload summary.
- Do not repeat long planning sentences across both header and timeline workstation.

### 17.5 Linked Round focus

- Selecting a proposed Round creates one dominant state across timeline and map.
- Selected Round remains full strength with stronger outline/depth; other Round blocks quiet substantially.
- Other driver labels/tracks quiet but remain legible.
- Planning map routes already dim through the route renderer; non-selected Round markers and uncovered markers also quiet while selection is active.
- Clearing/changing mode clears this focus state.


## 18. Visual Phase V4A · Smooth modes + communications / verification polish

### 18.1 Live / Plan mode control

- `Live / Plan` is one segmented control with one moving selected surface.
- The selected segment uses a white active surface over a restrained neutral track; the mode is communicated by position, typography and selected surface rather than an underline.
- Segment geometry, rail width, top bar and map-header geometry remain constant between modes.
- Plan count remains compact semantic text and may use the Rounds orange accent while Plan is active.
- Button state uses `aria-selected` so visual and accessibility state remain synchronized.

### 18.2 Smooth mode choreography

- Mode changes should feel continuous rather than instant/reflow-heavy.
- The Plan controls expand/collapse with restrained opacity/height motion.
- Live status tabs and optional delivery-scope context collapse as Plan controls appear.
- The fleet timeline remains mounted and slides into/out of view; map bottom inset animates with it.
- Queue/map content may use a short opacity transition during the exchange, but no decorative motion is added.
- Mapbox resize is performed during and after the transition so the map remains geometrically correct.

### 18.3 Communications visual lock

- The Operations communication window remains a floating operational tool, not a second drawer.
- Chrome, title hierarchy, presence, controls, thread spacing, message bubbles, attachments and composer use the same restrained radius/border/icon grammar as the Operations shell.
- Driver and Operations messages remain visually distinct without excessive color or bubble styling.
- Attachments, staged files, drag/drop and the composer remain fully functional; visual polish must not change the canonical shared-thread behavior.
- Contact History remains a chronological audit ledger, visually distinct from chat.

### 18.4 Physical manifest / verification / POD visual lock

- Physical manifest, pickup verification, handoff verification and POD share one custody-evidence visual language.
- Manifest and verification surfaces use contained, restrained bordered sections with clear header/status/progress/list hierarchy.
- Verification state may use compact semantic state surfaces: neutral waiting, orange active checking/attention, green verified.
- Item rows remain highly legible with quantity and physical verification evidence visible at a glance.
- Custody lock remains visually explicit but not alarmist.
- POD photo, handoff fields and audit facts inherit the shared Operations form and evidence styling.
- Delivery success feedback remains short, restrained and map-local; no confetti or game-like decoration is introduced.

### 18.5 Interaction integrity

- Visual refinement must preserve every existing functional control and the no-ghost-control rule from Visual Phase V4.
- A styling change must not replace a working interaction with a decorative control.


## 19. History Phase H1 · Operating-memory overview

- History is an operating-memory surface, not a generic analytics dashboard.
- Primary navigation is Overview / Deliveries / Drivers / Incidents.
- H1 Overview uses one strong operating readout, an evidence-backed Needs attention section, explicit exception attribution and a chronological evidence ledger.
- Use whitespace and editorial hierarchy before adding cards. The H1 page deliberately avoids a dense wall of independent KPI cards.
- Driver-attributed causes use the Rounds accent; excluded/non-driver causes use restrained neutrals so color communicates accountability rather than decoration.
- Management signals must state evidence and open a real record/driver/evidence surface.
- History period selection is a proper compact segmented control with a real state change.
- History export is functional.
- H2/H3/H4 must inherit this visual language rather than returning to dense generic tables.


## 20. Visual Phase V5 · Drivers command surface

- `Drivers` keeps one stable page title while Own team / Network / Schedule behave as sub-surfaces.
- The live command view uses editorial hierarchy and flat operational rows rather than a dense generic table or floating-card wall.
- Own-driver rows prioritize live state, next availability, vehicle/shift and current work. Durable performance evidence remains compact and secondary.
- Network rows use the same scan rhythm but visually distinguish independent Network identity and protect exact pre-job location.
- Availability states use restrained semantic surfaces; they are not decorative score colors.
- Row actions remain small, real and permission-aware; no ghost Message/Call/Offer controls.
- Driver detail drawers lead with current live state and actionable contact/work controls, followed by operating context and an evidence snapshot.
- Schedule uses the same premium spacing system, a clearly marked current day, restrained cells and real editable shift controls.
- Avoid over-rounding: small control radii remain canonical; the Drivers screen must not drift toward a consumer card UI.


## 21. Settings S1 · Premium Overview

- Settings Overview is an operating-control readout, not a six-card SaaS launcher.
- Lead with one strong **operating posture** surface that states automatic vs approval mode and explains the human-control boundary.
- Pair the posture with a compact **Authority at a glance** readout for own-fleet insertion, exceptions, Network and external courier authority.
- Use setup-attention rows only for configuration gaps that materially limit the operating model; use restrained amber/warm treatment rather than alarm styling.
- Configuration navigation uses flat, evidence-rich rows grouped into **Execution** and **Connections & customer**. Rows include a coherent line icon, title, short explanation, current state, meaningful boundary/context and a real navigation action.
- Do not return to a generic wall of equal-weight floating settings cards.
- Status color remains semantic: green connected/active, amber setup/review, neutral configured context.
- The Overview may summarize protected-decision rules but never becomes the editor for those rules.
- Detailed Dispatch, Delivery, Network, External, Integrations and Tracking pages are intentionally unchanged in S1.
- S1 inherits the no-ghost-control rule: every visible action must navigate or execute a real prototype behavior.

## 22. Network Supply map layer

- The layer is opt-in and visually secondary to the merchant's operational truth.
- A compact `Network supply` control may live in the Live map header and is mirrored in map-layer controls where useful.
- Do not display the supply layer in own-fleet Plan mode by default.
- Open capacity uses small hollow orange points; busy capacity uses smaller neutral points with lower opacity.
- At low zoom, points cluster into restrained orange-outline counts rather than producing a dense field of markers.
- When active, a compact explanatory notice must state that pre-acceptance locations are generalized.
- Clicking supply may open a contextual drawer explaining availability and privacy boundaries; it must never reveal another merchant's route or Stops.
- Supply dots are not status decorations: orange continues to mean selectable/available Network capacity, not generic map decoration.


## 23. Settings S2 · Dispatch + Delivery Rules

- Dispatch settings lead with one strong authority posture surface, a real Automatic / Approval control and an at-a-glance boundary readout.
- Editable automation rules use flat rows with either a semantic switch or a focused numeric boundary control; do not use passive values that look editable.
- Numeric boundary editing uses the business drawer and shows current → new consequence framing before save.
- Protected decisions are grouped separately from merchant-editable authority to avoid implying that custody, exception or consent guarantees can be casually disabled.
- Delivery Rules lead with one delivery-model surface and a compact summary of timing, orders, shortfall, vehicle profiles, cargo classes and special days.
- Delivery-slot, special-day, vehicle-profile, product-rule and cargo-class collections use flat premium rows with generous spacing and clear scan columns.
- Avoid decorative settings cards, oversized pills and excessive tinting. State color is semantic only.
- Slot duplication is a real mutation. All visible Settings S2 actions must execute or navigate to a real editable surface.
- At laptop/tablet widths, optional columns collapse before typography or touch targets shrink below the canonical readable floor.


## 24. Settings S3 · Network + External capacity

- Network and External use the same Settings visual grammar but must remain conceptually distinct.
- Lead with a compact three-step capacity ladder: Own fleet → Rounds Network → External courier.
- Highlight the active settings layer without turning the ladder into decorative progress UI.
- Network hero pairs merchant authority with live capacity context; live counts remain secondary operational evidence.
- Matching settings should visualize progression across relationship radius, open-Network radius and hard maximum expansion.
- Network privacy is an explicit evidence surface, not hidden legal copy. Generalized pre-acceptance location and other-merchant confidentiality must be easy to understand.
- External provider page leads with connection/authority state, then fallback contract and spend authority.
- Ask vs Automatic is a real two-choice authority control; it must not look like an unrelated dropdown buried in a table.
- External connection state, webhook/health and billing relationship use restrained readouts rather than oversized provider branding.
- Avoid making Network and Lalamove equal top-level products. External remains visually subordinate to the Rounds capacity ladder.
- Every editable fare/radius boundary must visibly behave as an editable control and use the focused business drawer for numeric editing.
- Provider/privacy boundary surfaces are flat and editorial; do not create a wall of floating settings cards.


## 25. Settings S4 · Integrations + Customer Tracking

- Integrations must read as an operational data-flow surface, not an app marketplace.
- Lead with connection health and current commerce-flow posture, then provider choices, data permissions and system boundary.
- Provider choices may use restrained bordered modules, but do not turn the page into a colorful logo-card marketplace.
- Connected state uses semantic green evidence; unconfigured state remains calm amber/neutral rather than alarm-red.
- Customer Tracking leads with the merchant-owned tracking posture and visually separates Sender, Recipient and Surprise Protection.
- Channels and event routing use flat rows with deliberate vertical rhythm; do not compress them into tiny checkbox grids.
- Sender/Recipient event controls remain compact square/rounded-small controls rather than pills.
- Tracking previews use the business drawer and demonstrate privacy without becoming a fake phone/device mockup.
- Commerce integration and customer-notification settings retain the global no-ghost-control requirement.
- At narrower widths, provider/audience modules collapse before typography and touch targets shrink.


## 26. Settings S5 · Interaction safety visual lock

- Immediate-save controls expose a restrained persistence acknowledgement rather than relying only on transient toast copy.
- Draft editors show a compact amber **Unsaved changes** state in the drawer header after the first edit.
- Unsaved-discard confirmation uses one focused overlay inside the current drawer so the user retains visual context.
- High-impact Settings confirmation is editorial: short consequence statement, preserved-state evidence, one explicit confirm action and one Cancel action.
- Validation is inline, calm and precise; it uses a restrained red evidence banner and focuses the invalid field without turning the whole Settings page into an error state.
- Quiet/unconfigured states remain neutral/amber; red is reserved for invalid/destructive evidence.
- Settings confirmation and validation surfaces inherit the small-radius, flat, premium Operations grammar and must not become generic modal-card UI.
- S5 completes the Settings visual phase; later work should not add another styling layer unless a concrete issue is found in responsive/browser QA.

## 27. External courier live visual lock

- External courier execution remains visually subordinate to Rounds; do not introduce a provider-branded application shell.
- The live external marker uses the shared Rounds map-control language with a small distinct vehicle glyph and provider label such as `Lalamove`.
- Avoid a large provider logo on the map.
- External live drawers use the same editorial hierarchy as Own/Network work: provider/context → current state → lifecycle → operational facts → event evidence → actions.
- A compact six-step lifecycle may show Booking / Driver / Pickup / En route / Delivered / POD. It is status evidence, not decorative progress UI.
- Quote-expired and external-custody-exception states use restrained amber/orange evidence surfaces; red remains reserved for genuine failure/danger.
- Provider cancellation is a destructive action only before pickup. After pickup, the surface must explain custody rather than showing a misleading cancel/reassign action.


## 28. Responsive workstation lock · v44

Rounds Operations targets laptop and iPad-class work surfaces. Responsive behavior must preserve the workstation model rather than collapse Dispatch into a phone-style stacked interface.

### 28.1 Tested viewport classes

The v44 responsive checkpoint was explicitly exercised at:

- 1366 × 768 — standard/short laptop;
- 1180 × 820 — iPad-class landscape / compact laptop;
- 1024 × 768 — compact landscape;
- 820 × 1180 — iPad-class portrait;
- 768 × 1024 — narrow iPad-class portrait.

Rendered QA also exercised generated Plan mode, an open contextual Dispatch drawer and Settings Overview in portrait.

### 28.2 Laptop

- Keep the full top shell and direct primary navigation.
- Compress rail/drawer widths and horizontal gaps before shrinking readable typography.
- Decision-changing weather remains visible; secondary map-health copy may collapse when header width is constrained.
- Map identity/title may not wrap merely to preserve optional metadata.
- On short displays, Plan begins with a shallower but usable timeline; the operator may still resize it.

### 28.3 iPad landscape

- Preserve the left work rail + dominant map + overlay drawer model.
- Primary navigation remains directly visible; old breakpoints must not hide Dispatch / Drivers / History / Settings.
- The rail deliberately compresses to roughly 280–295px while the map remains dominant.
- Optional map-header controls move into the existing map-layer/menu surface before primary controls are removed.
- Network Supply remains reachable from the map menu if its direct header control is hidden.
- Drawers overlay the map; they do not squeeze the map/rail into unreadable columns.
- Plan timeline keeps a sticky driver/vehicle/shift column and horizontal timeline scrolling.

### 28.4 iPad portrait

- Do not convert Dispatch into a vertical mobile dashboard. Keep rail + map spatial continuity.
- Global navigation becomes a compact dedicated second header row so all four primary destinations remain directly accessible.
- The top identity row keeps Rounds, current workspace and utility actions.
- Map context progressively collapses; Rounds, Automation and the map-mode control remain accessible while secondary health/supply/weather detail moves to existing controls.
- Focus map remains available to temporarily reclaim the rail width.
- The right drawer stays an overlay and leaves a visible strip of map context rather than becoming a full-screen replacement.
- Plan timeline uses a narrower sticky driver label column and horizontal scrolling; critical actions remain visible.
- Business surfaces remain document-like and scroll vertically; subnavigation may scroll horizontally instead of wrapping into multiple rows.

### 28.5 Touch and rotation

- Critical touch controls remain approximately 40px+; form controls retain the existing ~44px minimum.
- Plan departure-time drag handles receive a larger coarse-pointer hit area without visually becoming heavier.
- The Plan resize edge remains touch-operable.
- Queue, drawer, business-surface and timeline scrolling use touch momentum and contained overscroll.
- Viewport/orientation changes trigger map geometry reconciliation so Mapbox does not retain stale dimensions after iPad rotation.
- Floating communication geometry is recalculated after resize/orientation changes.

### 28.6 Responsive integrity rules

- Never hide a primary product destination solely because the viewport is 1024px wide.
- Never solve density by dropping normal operational copy below the readable typography floor.
- Hide or consolidate optional metadata before hiding executable actions.
- There must be no document-level horizontal overflow at the locked viewport classes; intentional horizontal scrolling is limited to dense local surfaces such as Plan timeline, Schedule, wide evidence tables and Settings subnavigation.
- Responsive CSS must not disable existing interactions, drawer actions, Plan resizing, touch Stop moves or map controls.

## 29. Operations edge-state visual lock · v45

Edge states are part of the premium Operations system, not generic error pages.

### 29.1 Global state strip

- Browser-offline, recovering and materially degraded live-service states use one compact strip directly beneath global chrome.
- The strip must explain **what is unavailable and what remains trustworthy**.
- Amber = connectivity/action constraint; orange = degraded dependency; green may appear briefly after confirmed recovery.
- The strip may expose one real recovery action such as `Retry`; no decorative retry controls.
- Do not stack multiple global banners for the same underlying problem.

### 29.2 Empty vs no-match vs loading

- Quiet business states use generous whitespace, one short eyebrow, one clear statement and supporting copy.
- Positive quiet states may use restrained green; they must not look celebratory.
- Filter/search no-match exposes a functional clear/reset action when useful.
- Loading must use a visible progress treatment; never render `0`, `No records` or `All clear` before the data source is known.
- Disabled actions must look unmistakably disabled and must not retain primary-action visual weight.

### 29.3 Map degraded state

- Map failure is localized to the map area plus one global degraded signal.
- Keep rail/business navigation usable.
- The map area presents a flat editorial recovery card: dependency/state → what still works → Retry.
- Do not replace Mapbox failure with a decorative fake map.

### 29.4 Offline communication state

- Keep draft text and staged attachments visible.
- Place a small amber sending-status note adjacent to the composer.
- Block send/call without appending a fake sent/call event.
- Replace live-presence certainty with `Live status paused`/last-known semantics; never infer driver offline from operator-browser connectivity.

### 29.5 Device lock

- Full Operations remains a laptop/iPad workstation.
- Do not introduce a phone breakpoint that pretends to preserve full Dispatch/Plan by serializing every surface into a stack.
- A future phone companion, if built, is a separate narrow-scope approval/alert/lookup surface.
