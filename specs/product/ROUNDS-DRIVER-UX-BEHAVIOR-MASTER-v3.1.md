# Rounds Driver App — UX Behavior Master

> **Implementation scope note:** The 47-board Driver set is the product-design library, not the scope of the first deploy. Pilot/Slice 1 implements only the Team-driver execution path promoted by `ROUNDS-IMPLEMENTATION-SCOPE-LADDER-v1.0.md`; Network/KYC/Get Paid/earnings boards remain canonical future behavior but are not Slice 1 dependencies.


**Version:** 3.1

**Status:** Canonical V1 behavior master after final 47-screen board sync  
**Purpose:** Defines the final interaction behavior of Driver App screens as UX is approved.  
**Relationship to other specs:** This document sits between the product/operating specs and the eventual technical build specification. The final HTML prototypes demonstrate these behaviors visually.

## Changelog

- **v3.1 — 2026-09-04:** Consolidated the historical append-only behavior
  blocks into named sections of this master and removed addendum precedence
  language. Driver behavior is unchanged.

## Working rule

A screen is added here only when its UX behavior is sufficiently agreed to be used as a build reference.

Visual styling is controlled by the canonical Driver boards and Driver UI Constitution. Changes should now be driven by implementation/field evidence, not speculative redesign. The behavioral rules below must not be changed by an engineer without product review.

---

# D01 — Navigate to Pickup

**Status:** Behavior locked  
**Prototype:** `ROUNDS-D01-NAVIGATE-TO-PICKUP-v5-10OF10.html`

## Purpose

Get the driver from their current position to the pickup with the lowest possible cognitive load.

D01 is a **road instrument**, not a delivery-detail screen.

## Entry

D01 opens after:

- a Team assignment becomes active; or
- a network driver accepts a delivery/Round.

The driver is now committed to the pickup.

## Default road state — En route

The screen prioritizes only:

1. next navigation instruction;
2. map / route;
3. pickup merchant;
4. ETA and distance to pickup.

### Visible

- Large next-turn distance.
- Large next-turn instruction.
- Route map.
- Driver position.
- Pickup position.
- Pickup merchant name.
- ETA + distance in the bottom pickup dock.
- Back/navigation utility.
- One secondary menu/contact entry point.

### Not visible while driving

- Round earnings.
- Full Round statistics.
- Fragile-item details.
- Item checklist.
- Customer details unrelated to reaching pickup.
- Persistent Chat and Call buttons competing with navigation.
- A permanent Arrived button while the driver is still far away.

## Secondary actions

A single secondary menu/contact entry point may expose:

- Call pickup merchant.
- Message pickup merchant.
- Report an issue.
- Open external maps.

These actions remain secondary to navigation.

## Proximity state — Near pickup

When the driver enters the configured pickup-proximity zone, D01 changes state.

Example prototype state:

- Navigation changes from normal turn guidance to an arrival-oriented instruction such as `UrbanFlowers entrance ahead`.
- Pickup dock changes from `Pickup` to `Almost there`.
- More useful entrance/location context may replace generic distance text.
- The explicit **I'm at the pickup** action becomes available.

The system should not automatically declare arrival solely from GPS proximity.

The driver explicitly confirms physical arrival.

## Arrival action

The arrival action is hidden until proximity makes it relevant.

Driver taps:

**I'm at the pickup**

Rounds then:

1. records the arrival event;
2. records/validates current location where available;
3. accepts a reasonable GPS tolerance for dense Bangkok environments;
4. transitions directly to Pickup Confirmation.

## No redundant confirmation step

There is **no** intermediate screen saying:

`Pickup reached → Continue`

The driver's explicit arrival action is the confirmation.

After it succeeds, the next functional screen begins immediately.

## GPS edge case

If GPS says the driver is unusually far from the pickup:

- warn the driver;
- show the measured discrepancy;
- allow an explicit override where operationally appropriate;
- log the anomaly.

GPS should assist verification, not trap a driver because of high-rise/urban location error.

## Transition out

Successful arrival → **D03/D04 Pickup Confirmation**.

Which pickup-confirmation variant appears depends on the merchant/order data and pickup policy.

## Prototype behavior

The HTML prototype includes demonstration states for:

- En route;
- Near pickup;
- Arrived / transition into pickup confirmation.

The demonstration controls are prototype-only and are not part of the production Driver App.

---

# Final board-set closure

The final 47-screen Driver board set dated 2026-09-01 is now behaviorally closed for V1. B03, C03 and D03/D04 are no longer “being designed”; their final board versions are canonical.

- B03 Network Home is map/context-led and separates published availability from verification/identity and from accepted-work state.
- C01/C03 offers expose guaranteed economic scope before acceptance.
- D03/D04 uses the structured manifest and blocks ordinary custody confirmation until required physical lines are verified or a Pickup Problem path is entered.
- Team/Network/shift/offline/system states are represented by dedicated screens rather than prototype mode switches.

---

# Location-aware Driver Behavior

**Canonical detailed spec:** `ROUNDS-SPEC-4-MAPPING-ADDRESS-INTELLIGENCE-v1.8.md`

## D01 / Navigation

The route target is the best confirmed **vehicle access point** when one exists.

Near arrival, road navigation may transition to an arrival instruction:

- `South driveway ahead`;
- `Enter via Tower B lobby`;
- `Loading bay on left`.

Building/entrance context is secondary while driving and becomes more visible only near arrival.

## Issue: Address wrong / Can't find

Driver may report:

- written address wrong;
- pin wrong;
- entrance wrong;
- access closed;
- better driveway;
- different building.

Driver can submit candidate coordinates and evidence.

The app must not silently update future merchant knowledge from a single driver action.

## Confirmation after success

After POD, where appropriate, the driver can confirm:

- vehicle stop;
- entrance;
- handoff.

This confirmation is written as an observation and contributes to merchant-level location knowledge.

---

# Traffic, ETA & Arrival Context

**Canonical mapping rules:** `ROUNDS-SPEC-4-MAPPING-ADDRESS-INTELLIGENCE-v1.8.md`

- Traffic-aware ETA may update continuously while driver is on duty.
- Do not ask driver to interpret congestion colors while driving.
- If delay materially changes the Round, dispatch/automation receives the decision first.
- Driver UI can show concise facts: `ETA 12:16 · traffic +12m`.
- Near arrival, use learned vehicle-access and entrance instructions.
- Successful handoff/location confirmation contributes to Rounds location knowledge after sync.

---

# Weather + Dispatcher Communication

- Driver chat remains reachable from in-flight delivery context.
- Dispatcher messages arrive realtime and may contain text, voice, file or location context.
- Dispatcher may initiate in-app VoIP; incoming-call UI retains order/Round context.
- Weather warnings are concise and action-oriented, never a general weather feed.
- Weather guidance must never distract while driving; use voice/navigation-safe presentation where appropriate.

---

# Realtime Dispatcher Contact & Route Updates

**Controlling cross-surface spec:** `ROUNDS-SPEC-6-DISPATCH-ROUTE-EDITING-COMMS-v1.11.md`

Driver app behavior:

- receives dispatcher text/voice messages realtime;
- unread state visible without obstructing navigation;
- incoming dispatcher VoIP follows existing safe call UI;
- route sequence updates arrive as system state, not as informal chat instructions only;
- while actively navigating, route mutation must update navigation safely and preserve the current Stop/custody state;
- driver may acknowledge updated route through message/voice without leaving operational flow.

# Physical Manifest Verification & Shared Rich Communications

## D03/D04 — Pickup Confirmation is now behavior-locked

Itemized pickup uses the structured delivery manifest supplied by the merchant/Operations pipeline.

For each manifest line the driver sees label + expected quantity and confirms the physical line. Quantity `2` is one verification decision for expected quantity two, not two arbitrary taps.

Pickup completion is blocked until required lines are verified or a structured Pickup Problem is opened.

`Confirm pickup` creates the custody transition. After confirmation, the previously verified manifest becomes custody evidence and must not silently change.

## F01–F08 — Handoff verification

At dropoff, the same manifest is exposed again before final completion when merchant policy requires item verification.

The driver confirms the physical package handed over, captures required POD evidence, then completes the Stop.

Normal completion requires all required evidence:

- handoff manifest verified;
- delivery photo when required;
- handoff/received-by fields when required;
- signature/note when policy requires them.

A manifest mismatch routes to the existing issue flow rather than allowing a false Delivered state.

## POD origin

The delivery photo originates in the Driver App at the destination. Operations may review/share it but does not retroactively manufacture the driver's POD event.

## Shared conversation content

Driver and Operations share the same order/Round thread.

Driver can send:

- text;
- voice note;
- Camera photo;
- existing photo;
- file/document;
- location.

Links are typed/pasted as ordinary message text and auto-detected; no separate Link action is required.

The app can stage attachments before Send so text and media can be sent together. Copy is available for human messages/attachment references where supported by the platform.

On tablet/desktop-class driver environments, drag/drop may accelerate file/link attachment. Mobile Camera/Photo/File/Location actions remain primary.

## Route/system communication

Physical-verification events and route changes appear as system events in the same delivery history without being represented as if a human typed them.

# Live Route / Destination Updates After Pickup

**Status:** Behavior locked

The Driver App and Dispatcher web app are separate role-specific surfaces. The Driver App is never embedded as a preview inside the Operations board, and the Driver App never embeds the Dispatcher UI.

After pickup, Operations may change the live destination, operational pin, promised window or handoff instruction without changing the pickup-confirmed manifest.

When a versioned live change arrives, the Driver App must:

1. stop relying on stale route/destination state;
2. persist the new change version locally/offline-first;
3. surface an unmistakable `Delivery updated` / `Route updated` state at the next safe interaction point;
4. show the material difference relevant to the driver (destination, entrance, time, instruction);
5. update navigation to the new operational point;
6. require explicit acknowledgement;
7. send acknowledgement back to Rounds;
8. retain the system event in the delivery conversation/history.

The driver must not re-confirm pickup or alter the manifest because of a destination change. The verified package remains the same physical custody object.

If the driver cannot safely comply with the change, the acknowledgement surface must provide a path to contact Operations / report an issue rather than silently accepting.

---

# Network Availability + Merchant Contact Permissions

**Controlling cross-surface spec:** `ROUNDS-SPEC-10-DRIVERS-LIVE-AVAILABILITY-CONTACT-v1.4.md`

## B03 — Home · Network Available is now behavior-locked

The Network driver controls whether they are currently open to new Rounds work.

Canonical availability states:

- **Open for jobs** — eligible for compatible new Network Offers now;
- **Open for jobs · available after current work** — future Offers may be considered using a projected next-available time;
- **On a Round** — accepted work is active;
- **Not accepting jobs** — Network Offers paused without changing the driver's identity or historical reputation;
- **Offline / stale** — device/presence is not fresh enough to represent live availability.

The availability control is operational state, not a permanent driver category.

Turning `Open for jobs` off must not create a negative performance event.

## Team relationship interaction

When a driver is actively working a team shift, team work has priority. Open-network availability is normally suppressed unless employer policy and the driver's settings explicitly allow outside Network work.

The Driver App must never imply that switching off Network work ends an active accepted Round or abandons team obligations.

## Preferred / known merchant availability requests

A driver with a preferred/known merchant relationship may receive a structured **availability request** when the driver has allowed that merchant relationship to contact them.

The request must identify:

- merchant;
- why the merchant is contacting them (`Ask availability` / possible work);
- whether a specific job/rough time window is attached;
- a clear respond/decline path.

An availability request is not an Offer acceptance and does not reserve the driver.

## Direct merchant messages before a job

Direct relationship messaging is opt-in for Network drivers.

- Known/preferred merchant + direct-contact permission → relationship-level message may be available.
- Unknown merchant → no casual chat; work arrives through the normal Offer/Broadcast path.

Once work is accepted, the job-linked delivery/Round thread becomes canonical for that work.

## Presence/privacy

The Driver App may publish availability and location needed for matching, but pre-acceptance merchant UI should not expose unrestricted exact live GPS to unknown merchants.

The driver should be able to understand that `Open for jobs` makes them discoverable for operational matching, not available for arbitrary social contact.

## Availability history and performance

The app/history may record availability changes for operational reconstruction, but:

- `Not accepting jobs` is not a strike;
- offline time outside a committed team shift is not a strike;
- declined Offers are not equivalent to accepted-job failure;
- reliability evidence becomes materially stronger after acceptance or during a scheduled team obligation.


# Final 47-Screen Driver Contract

This section completes the behavior contract for the canonical 47-screen
Driver library.

## A01 / A01B — Splash and language

- First-run path is `A01 → A01B → A02–A05`.
- Thailand is Thai-first; English remains selectable.
- Language is an app-level preference, not a per-screen mode toggle.
- The preference is available before authentication and later syncs to the authenticated driver profile.
- `L01 Profile → Language` is the normal post-onboarding change point.
- Language changes never mutate operational state, permissions, role, assignment, outbox or evidence.

## A02–A12 — Entry and verification

- Phone/OTP identifies the driver account before role path selection.
- Team drivers join through a merchant invite relationship; independent drivers enter Network verification.
- Team and independent About You flows stay distinct where required by verification/employment context.
- Vehicle selection is structured rather than free text.
- Identity verification and live-face verification are separate evidence steps.
- Payout setup belongs to independent/Network earnings, not Team payroll.
- `A12` is a focused correction loop: only the failed/insufficient evidence is replaced and verification is resubmitted.

## B00–B03 — Work-mode home states

- Team work has explicit shift lifecycle: start, waiting, assignment, ending soon, overtime, end confirmation and completed shift.
- Shift ending never silently abandons accepted custody/work.
- After team obligations are complete, a Network-eligible driver may choose Network availability only where employer/driver policy permits it.
- `B03` availability is driver-controlled. `Open for jobs`, available-later, busy/accepted work, not accepting and stale/offline are distinct states.
- Open availability does not expose unrestricted exact GPS or arbitrary merchant chat.

## C01 / C03 — Offers

- Guaranteed fare is visible before acceptance for Network work.
- Single and multi-stop offers show sufficient pickup/route/scope context to understand the commitment.
- Multi-stop acceptance is one Round commitment, not a sequence of hidden jobs.
- Material accepted-scope changes follow the explicit consent contract.

## D01 / E02 — Embedded navigation intent

- Navigation is first-class inside Rounds V1, subject to Engineering Architecture / Phase 0 field validation.
- Product chrome keeps the current Stop/pickup identity, ETA/distance, contact/exception access and explicit arrival transition reachable without obscuring vendor safety UI.
- The app never declares physical arrival solely from GPS; driver confirmation remains explicit.
- Navigation state and operational telemetry must carry freshness and survive lifecycle interruption according to the offline/location contract.

## D03/D04 — Pickup / custody

- Driver verifies the structured physical manifest before custody confirmation when merchant policy requires it.
- Missing/wrong/damaged item paths interrupt ordinary confirmation and create an explicit problem record.
- Pickup-confirmed manifest becomes immutable custody evidence.
- After custody confirmation, later address/window/instruction changes do not rewrite the physical manifest.

## E01 / E04–E06 — Active Round and live changes

- E01 is the current Round overview; it does not become a dense analytics dashboard.
- Route/destination/instruction changes after pickup are versioned and require acknowledgement where the contract requires it.
- A Network add-Stop that materially expands accepted scope requires explicit accept/decline and compensation display where applicable.
- Contact Operations remains available when the driver cannot safely accept/understand a change.

## F01–F08 — Handoff / POD / completion

- Handoff records who/where received the delivery using constrained choices before free text.
- The same pickup manifest may be re-exposed at handoff according to merchant policy.
- Required POD evidence may include photo, receiver, signature/note, GPS/geofence and manifest verification.
- Required evidence blocks final committed completion.
- Offline capture is allowed; server truth distinguishes `delivered_pending_evidence` until required bytes are durably stored.
- Stop complete transitions directly to the next operational Stop or Round completion without celebratory clutter.

## G01–G05 — Exceptions / emergency

- Recipient unavailable, address/access, package, cannot-complete and emergency are distinct typed flows.
- The driver should choose structured reasons/actions before writing free text.
- Exceptions preserve custody truth and never “solve” a package by silently reassigning it.
- Emergency flow prioritizes personal safety and immediate device/Operations contact over delivery workflow.

## H01–H03 — Communications

- Driver and Operations share the canonical order/Round thread.
- Driver supports text, voice, camera/photo, file and location context; web links are normal message content, not a separate attachment type.
- Attachments stage before send and remain recoverable as drafts while offline.
- Calls and call outcomes become part of Contact History where relevant.
- Contact History is chronological evidence, not a second chat product.

## I01 / J01 — Round history

- I01 confirms Round completion and returns the driver to the appropriate work-mode home.
- J01 separates active/current work from completed historical Rounds and keeps POD/evidence status visible.

## K00 / K01 — Team Hours and Network Earnings

- Team Hours records shift attendance, not Network earnings.
- Missed clock-out has a correction flow and audit; correction does not silently overwrite attendance history.
- Network Earnings shows guaranteed/settled Network work and payout method; it must not imply Team payroll is processed by Rounds.

## L01 / M01 — Profile and notifications

- Profile owns vehicle/profile/payout/verification/network-contact preferences and Language.
- Notifications are actionable operational events and availability requests, not a social feed.
- Tapping a notification causes an authoritative state fetch; push delivery itself is never treated as state truth.

## N01–N03 — Permissions / offline / GPS

- Initial permissions are only what is operationally necessary; camera/microphone are contextual.
- Browser/mobile connectivity loss and GPS loss are separate states.
- Offline does not fabricate command success. Drafts/evidence/outbox remain locally safe until sync.
- GPS unavailable exposes cached-route/recovery behavior where safe and labels location freshness honestly.

# Localization invariants

- Production is one localized app.
- `th-TH` is the primary Thailand locale; `en` is secondary.
- All canonical screen IDs and workflows are language-neutral.
- Thai translations may expand/reflow layouts but may not remove information or change operational semantics.
- Do not translate merchant/recipient free text silently unless a future explicit translation feature is introduced.
- Thai UI QA is required at 320 px and on low-cost Android before pilot.

*End of Rounds Driver App — UX Behavior Master*
