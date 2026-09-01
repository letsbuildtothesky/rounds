# Rounds · Settings Control Center

**Version:** 1.5
**Status:** Canonical — Settings S1–S5 complete + edge-state lock
**Canonical UX checkpoint:** `rounds-edge-states-v45.html`

## 1. Product role

Settings is the business control center for the rules and connections that determine how Rounds operates. It is separate from live Dispatch even when a setting changes Dispatch behavior.

Canonical Settings information architecture:

1. Overview
2. Dispatch
3. Delivery rules
4. Rounds Network
5. External couriers
6. Integrations
7. Tracking & notifications

## 2. S1 Overview contract

The Overview answers:

- What may Rounds execute automatically?
- Which capacity sources/systems are available?
- What setup gaps limit the current operating model?

It is a readout + navigation surface. It does not silently edit detailed rules.

### 2.1 Operating posture

Show the current automatic/approval posture as the primary statement. Supporting authority facts include:

- own-fleet auto insertion and its configured time/Stop limits;
- exception treatment;
- Network enabled state plus relevant configured boundaries;
- external courier connection/booking authority.

### 2.2 Setup attention

Only show setup gaps that materially limit Rounds. A setup gap is not automatically an operational incident. Current examples:

- commerce integration not connected;
- external courier provider not connected.

The row explains the consequence and links to the owning Settings page.

### 2.3 Configuration map

Group settings as:

**Execution**
- Dispatch
- Delivery rules
- Rounds Network

**Connections & customer**
- External couriers
- Integrations
- Tracking & notifications

Each row exposes a concise state + relevant boundary/context. Every row navigates to a real detailed settings page.

### 2.4 Protected decisions

The Overview may remind the user of protections that remain system-wide, including:

- physical custody cannot be silently mutated after verification;
- delivery exceptions return to a person according to configured policy;
- accepted Network scope changes preserve driver consent;
- surprise-protection settings suppress recipient communication where required.

These are explanatory reminders, not inline editors.

## 3. Visual contract

- Premium light Operations language from `ROUNDS-SPEC-8-OPERATIONS-VISUAL-SYSTEM`.
- Whitespace and editorial hierarchy before card count.
- One primary posture surface, restrained setup-attention list, then flat configuration rows.
- Avoid giant color blocks, pills and a generic SaaS tile wall.
- Small consistent line icons only.
- Normal operational text remains within the canonical readable floor.
- All visible buttons/actions are functional.

## 4. S2 Dispatch authority contract

The Dispatch settings page is the canonical editor for what Rounds may execute without Operations approval. It must expose the current operating posture first, then the explicit boundaries.

### 4.1 Operating mode

- `Automatic`: Rounds may execute routine work only when all configured boundaries pass.
- `Approval required`: Rounds may recommend but execution waits for a person.
- Changing mode is a real settings mutation and immediately changes the operating posture readout.

### 4.2 Own-fleet boundaries

The page must expose and edit at minimum:

- automatic safe Stop insertion;
- maximum added route minutes;
- maximum delivery Stops per Round;
- merchant-protected VIP / fragile approval rule.

These are real prototype settings, not descriptive labels. Numeric limits edit through a focused drawer and save back to the same authority state used by Dispatch.

### 4.3 Network boundaries

The page must expose and edit at minimum:

- automatic Network start when own-fleet fit is unsafe;
- preferred / known radius;
- maximum automatic radius;
- maximum guaranteed Network fare;
- safe add-Stop proposal permission;
- maximum added minutes for accepted-work proposals.

Accepted Network work still preserves driver acknowledgement / consent. Direct settings authority must not bypass that contract.

### 4.4 Protected decisions

The Dispatch settings page must explicitly distinguish editable automation boundaries from protected system rules:

- delivery exceptions return to Action / human review under the current policy;
- pickup-confirmed physical manifest remains custody evidence;
- material accepted-work changes preserve driver acknowledgement / consent;
- external courier booking authority is configured separately.

## 5. S2 Delivery Rules contract

Delivery Rules is the canonical editor for the customer timing + physical-capacity model used by Dispatch, Plan, Network eligibility and fallback decisions.

### 5.1 Delivery timing

- The merchant may use named delivery slots or direct promised start/end windows.
- Turning named slots on/off is a real settings change.
- Flexible windows remain fully compatible with Automatic Dispatch.

### 5.2 Named slots

Each slot exposes and edits:

- name;
- promised start/end;
- applicable days;
- order cutoff;
- release time;
- maximum orders;
- vehicle policy;
- own-capacity shortfall treatment.

Slot duplication must create a real editable copy; decorative `Duplicate` actions are prohibited.

### 5.3 Special-day overrides

A date-specific override may change or close one recurring slot without mutating the recurring rule. Add, edit and delete actions must be real.

### 5.4 Vehicle profiles and Round patterns

Vehicle profiles own the physical rules reused by planning and live assignment:

- vehicle/profile identity;
- departure / return-reload pattern;
- maximum Stops per departure;
- planning throughput assumption;
- pickup/reload turnaround;
- mixed-load guidance;
- cargo-class limits.

### 5.5 Product handling rules

Merchant product/handling classes map to Allowed / Preferred / Required vehicle rules. These rules must be visible and editable from Delivery Rules rather than existing as unreachable configuration.

### 5.6 Cargo classes

Reusable cargo classes remain explicit. A quantity of zero means the cargo class is prohibited for that vehicle profile.

### 5.7 Planning contract

The UI must explain the shared chain without creating a second algorithm:

`items → cargo classes → vehicle profile → Stops/departure → return/reload pattern → shift & promise fit → capacity source`

## 6. S2 visual / interaction contract

- Lead Dispatch with one authority hero and Delivery Rules with one delivery-model hero.
- Use flat rule rows and deliberate whitespace; do not return to a generic tile wall.
- Settings toggles and numeric editors are clearly interactive and have real state changes.
- Product/vehicle/cargo rows remain flat evidence rows, not consumer-style floating cards.
- Current configuration, effect and protected boundaries are visually separated.
- Every visible action is functional; no ghost controls.

## 7. Phase sequence note

S2 established Dispatch + Delivery Rules. S3 and S4 below are now completed canonical phases; only S5 remains pending.


## 8. Settings S3 · Network + External Capacity

S3 makes the fulfillment ladder explicit without collapsing Network and third-party providers into one concept.

Canonical capacity order:

```text
Own fleet
→ Rounds Network
→ External courier
```

### 8.1 Rounds Network settings

The Network page must expose:

- Network enabled / disabled state;
- Preferred / Known relationship radius;
- Open Network radius;
- maximum automatic expansion radius;
- maximum Network fare that may be committed automatically;
- automatic Network-start authority;
- safe add-Stop proposal authority;
- maximum added time for an accepted-work proposal;
- accepted-work consent boundary;
- relationship-message permission boundary;
- privacy-safe Network Supply behavior.

Network is a Rounds-native capacity layer. Offer/Broadcast, acceptance, consent, settlement, tracking and history remain inside Rounds.

Disabling Network removes it from the active capacity ladder and also hides the optional Network Supply map layer.

### 8.2 Matching progression

Settings must explain matching as a progression rather than unrelated numeric fields:

```text
Preferred / Known
→ Open Network
→ Maximum expansion
→ Action if still unresolved
```

Automatic expansion may never exceed the configured maximum radius or guaranteed-fare authority.

### 8.3 Network privacy and contact

The settings page must make the pre-acceptance privacy boundary understandable:

- open/busy availability may be visible;
- area/distance is generalized before acceptance;
- another merchant's identity/customer/route/Stops remain hidden;
- exact GPS begins only after accepted job-linked work;
- unknown open drivers are reached through Offer/Broadcast;
- Known/Preferred relationship messaging is visible only where driver opt-in/permission exists.

Availability/offline state is not a Network performance penalty.

### 8.4 External courier settings

External courier settings must be visually and conceptually separate from Rounds Network.

The page must expose:

- provider connection state;
- merchant-owned provider account;
- provider/webhook health;
- Ask before booking vs Automatic inside limit;
- maximum automatic provider fare;
- billing relationship;
- fallback trigger;
- failure behavior.

External capacity is considered only after the preceding capacity layers have been evaluated under merchant policy. Provider failure returns work to Action; it never creates a false assigned/delivered state.

### 8.5 External spend authority

Two canonical modes:

```text
Ask before booking
Automatic inside limit
```

Automatic provider booking requires all of:

- provider connected;
- merchant authority = automatic;
- quote promise-safe;
- quote inside merchant fare ceiling;
- work eligible for external execution.

The fare ceiling is a true numeric setting, not a demo toggle between preset values.

### 8.6 Interaction quality

- Enable/disable Network is a real state change.
- Matching/fare boundaries use focused numeric editors with validation.
- Provider connection/disconnection is functional in the prototype.
- Provider health test updates visible health state.
- External booking authority is a real segmented choice.
- Visible actions may not be decorative/ghost controls.

## 9. Phase sequence note

S1–S5 are now complete canonical Settings work. The remaining product-wide work is edge-state and responsive QA, not another Settings information-architecture phase.


## 10. Settings S4 · Integrations + Tracking / Notifications

S4 turns the architecture from Spec 5 into a merchant control surface while preserving the separation between commerce order ownership, Rounds fulfillment, and customer communication.

### 10.1 Commerce flow

The Integrations page answers:

1. What system is feeding Rounds?
2. Is the connection healthy?
3. What data may flow in?
4. What fulfillment state may flow back out?

The page must show active source, health/reconciliation state, inbound-order authority and fulfillment/tracking writeback state.

### 10.2 Connection choices

Canonical first-party UX:

- Shopify;
- WooCommerce;
- Custom API / webhook.

The merchant's manual/batch intake remains available independently of connection state.

### 10.3 Connector data permissions

Real Settings controls may enable/disable:

- automatic order intake;
- fulfillment-state writeback;
- tracking-reference writeback;
- delivery-exception writeback.

Disabled/unconnected controls must look disabled rather than pretending to save changes.

### 10.4 Tracking and notification posture

The Tracking page leads with the customer-experience posture rather than a generic toggle list.

It must expose:

- branded tracking page on/off;
- Sender/Buyer audience on/off;
- Recipient audience on/off;
- surprise protection;
- active customer channels.

### 10.5 Audience separation

Sender and Recipient remain separate roles. Their information and event routing may differ. Buyer = Recipient is deduplicated automatically.

Recipient-facing information remains intentionally more discreet where merchant policy or surprise protection requires it.

### 10.6 Channel controls

Current merchant channel controls:

- Email;
- SMS;
- LINE.

Internal Operations↔Driver communications remain a different system and are never routed through these settings by default.

### 10.7 Event routing

The merchant can toggle Sender / Recipient routing independently for canonical delivery events. Event routing consumes committed Rounds events; it never creates or reverses operational truth.

### 10.8 Preview / privacy

Sender and Recipient preview actions are real. They must visually demonstrate the privacy boundary without exposing private driver phone, other Round Stops, private merchant notes or protected gift details.

### 10.9 Interaction quality

- Test + reconcile is functional.
- Connect/disconnect is functional in the prototype.
- Connector data-flow switches are real state changes.
- Tracking audience/channel/event controls are real state changes.
- No ghost controls.

## 11. Settings S5 · Final interaction safety and completion

S5 completes the Settings control center without changing the underlying Dispatch, Network, custody, integration or notification algorithms.

### 11.1 Persistence model

- Simple switches and authority choices save immediately and visibly acknowledge persistence.
- Structured editors (slot, vehicle profile, special day, cargo/rule, numeric authority) are draft-based until Save.
- Draft-based editors must show an **Unsaved changes** state after the first edit.
- Closing the drawer, pressing Escape, switching Settings sections, or leaving Settings while a draft is dirty must offer **Keep editing / Discard changes**.
- New draft entities such as a new delivery slot must not survive if the user discards the draft.

### 11.2 Validation

Settings must reject invalid values before mutation rather than silently clamping or committing malformed rules. Canonical examples include:

- valid slot/start/end/cutoff/release times;
- end after start for the current same-day slot model;
- release after cutoff and no later than the slot start;
- positive order limits;
- unique date + slot special-day override;
- vehicle/throughput/turnaround values inside explicit ranges;
- cargo quantities inside configured numeric range;
- non-empty vehicle/cargo/product labels;
- Network and external-fare boundaries inside their defined limits.

Validation appears inline in the Settings drawer, focuses the relevant field, and does not mutate the committed setting until Save succeeds.

### 11.3 High-impact confirmation

The following changes require explicit consequence confirmation:

- disabling Rounds Network;
- switching from named delivery slots to flexible windows;
- disconnecting the active commerce integration;
- disconnecting Lalamove / external fallback;
- deleting a special-day override;
- turning the customer tracking page off;
- turning Surprise Protection off.

Confirmations must explain what stops, what remains preserved, and what will resume if the feature is re-enabled.

### 11.4 Quiet / unavailable Settings states

- Unconnected integrations remain calm setup states, not errors.
- Disabled Network / unavailable External courier pages remain usable explanation surfaces.
- When no outbound customer-notification channel is enabled, Tracking shows an explicit non-blocking warning while keeping operational delivery truth separate.
- Existing delivery, History, custody and provider records are preserved when a connection or capacity source is disabled.

### 11.5 No-ghost-control completion

Every visible Settings control must either:

1. mutate the current prototype state;
2. open a real editor/preview/evidence surface; or
3. be visibly disabled with an explanation.

A decorative control that appears actionable is prohibited.

## 12. Remaining product-wide finish

Settings S1–S5 is complete. Still pending outside Settings:

- final product-wide quiet / error / loading state pass;
- final laptop/iPad responsive QA;
- Driver App parity verification against the updated mobile-screen implementation.

Any future Settings behavior change must update this controlling spec in the same work cycle.

## S5B · Connection/loading/degraded-state lock

Settings connection surfaces must expose truthful transitional states.

- `Test connection`, reconciliation and similar remote checks visibly enter `Checking…`/loading before success or failure.
- An operator-browser offline state blocks a remote connection test; it does not write a fake healthy result.
- Disconnect/unconfigured is a stable setup state, not a red system failure.
- A remote-provider/API failure must distinguish provider health from merchant configuration and from browser connectivity.
- Existing saved settings remain readable while a remote dependency is degraded.
- Recovery should refresh current connection health before the page claims `Healthy`.
