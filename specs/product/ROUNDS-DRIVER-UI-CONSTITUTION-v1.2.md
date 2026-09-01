# Rounds Driver App — UI Constitution v1.2

Status: LOCKED BASELINE  
Purpose: Prevent visual and UX drift during implementation of the canonical 47-board Driver product library.

This guide is derived from the strongest existing Rounds driver anchors:
- C03 Multi-stop Offer
- B03 Home / Network Available
- D01 Navigate to Pickup
- D03/D04 Pickup Confirmation
- E01 Active Round Overview
- E02 Navigate to Current Stop

The goal is not to make every screen look identical. The goal is to make every screen feel like the same premium driver product.

---

## 1. Product feeling

Rounds Driver should feel:

- calm
- premium
- extremely easy to understand
- operational rather than administrative
- built for one-hand use
- usable outdoors and on a mounted phone
- visually confident without decorative clutter

Rounds is **not** a generic SaaS dashboard squeezed onto a phone.
Rounds is **not** a form system.
Rounds is **not** a collection of cards.

The product should usually answer one question:

> What does the driver need to do right now?

---

## 2. Core screen rule — one obvious job

Every screen gets one dominant job.

Examples:

- Home: where is demand?
- Offer: should I accept this Round?
- Navigate: where do I turn?
- Pickup: do I physically have every package?
- Round overview: where does this Round go?
- Dropoff: how was it handed over?
- Proof: what proof is still required?

If a screen has two equally strong jobs, split the state or hide secondary information.

---

## 3. Explain less

Do not add instructional prose when the interface already communicates the action.

BAD:
> Tick every package as it is handed to you. Leave only when the complete Round is physically with you.

GOOD:
> Collect every package  
> 0 / 6  
> [checkboxes]

Rules:
- avoid explanatory paragraphs on normal operational screens
- short exception explanations are allowed when something unusual must be understood
- do not repeat the same idea in the title, subtitle, section heading and button
- prefer visible state over prose

---

## 4. Text entry is a last resort

A driver should almost never need to type during a normal stop.

Prefer, in order:

1. tap
2. checkbox
3. scan
4. photo
5. signature
6. quick structured choice
7. voice / system-captured data
8. text entry only if no better input exists

Do not make a driver type a receiver name simply because a database field exists.

If a merchant requires receiver identity, prefer:
- Reception
- Security
- Family
- Staff / colleague
- Other

Only reveal a text field if the merchant specifically requires a name and it cannot be inferred.

---

## 5. Typography

Font:
- Inter
- system fallback allowed

Operational minimums:
- primary task headline: 29–31 px, heavy
- navigation distance: 27 px, heavy
- important name / destination: 18–20 px
- primary action: 17–18 px
- main item / package: 15–16 px
- ordinary operational copy: 14–15 px
- secondary metadata: 13–14 px
- tiny support text: avoid; absolute floor approximately 12.5 px
- never place critical information below 13 px

Do not create visual sophistication by making text small.

---

## 6. Color system

Core:
- Ink / Navy: `#162033`
- Orange: `#ff6a21`
- Green: `#18a957`
- Muted text: `#687587`
- Border: `#dce4eb`
- Surface: `#ffffff`
- Light neutral: `#f5f7f9`

Soft states:
- Orange soft: `#fff0e7`
- Green soft: `#eaf8ef`

Semantic usage:
- navy = main action / navigation / core structure
- orange = Rounds identity / attention / current stop / pickup
- green = available / complete / verified / success
- red = actual problem or issue only

Do not decorate screens with extra colors merely to make them look richer.

---

## 7. Shape language

Phone reference: 393 × 852.

Typical radii:
- phone frame: 34 px prototype only
- primary surfaces: 16–18 px
- controls: 12–15 px
- small tags: 8–10 px

Rules:
- rounded, but not bubbly
- do not create a page made of floating cards
- use borders and spacing before shadows
- shadows should be light and functional
- no pill-heavy interface

---

## 8. Controls and tap targets

- fixed primary action height: about 64 px
- road utility controls: 42–48 px
- standard operational row: at least 50–58 px
- important action rows: 62–88 px
- checkbox: approximately 31 px
- controls must be easy to hit with one thumb

On 393 px phones, avoid splitting important actions into cramped two-column cards.

Use full-width action rows when an action deserves attention.

---

## 9. Screen archetypes

### A. Road screen
Examples: D01, E02

Hierarchy:
1. turn instruction
2. large map
3. current destination + ETA
4. arrival action only when proximity makes it relevant

Do not show:
- Round statistics
- earnings
- package detail
- route list
- unnecessary instructions

The UI changes with reality:
- en route
- near
- arrived

### B. Overview / planning screen
Example: E01

Hierarchy:
1. large route preview
2. current/next stop
3. primary navigation action
4. remaining stops hidden behind expansion

Use the map to communicate the Round faster than a list.

### C. Stationary task screen
Examples: Pickup, Dropoff, POD

Hierarchy:
1. task
2. visible objects/actions required to finish it
3. fixed primary completion action
4. secondary issue/contact controls

Do not turn task screens into dashboards or forms.

---

## 10. Information density

More visible content is not automatically better.

Default screen should contain only what matters now.

Hide or defer:
- history
- future stops
- policy explanations
- system logs
- earnings
- secondary detail

Use:
- bottom sheets
- expandable areas
- next screens
- operator dashboard

rather than crowding the resting state.

---

## 11. Driver vs operator information

Driver:
- next action
- customer contact
- business/operator contact
- required proof
- exception path
- immediate route / package information

Operator / business record:
- call/contact attempts
- timestamps
- approvals
- authority changes
- proof records
- escalation history

The driver may see a compact state such as:
> Called 11:42

but does not need a full audit log on the road.

---

## 12. Merchant-configurable rules

Rounds does not hardcode one proof workflow for every merchant.

Merchant policy can define:
- signature required
- photo required
- left-at-location allowed
- operator approval required
- receiver identity required
- customer instruction required
- return / wait rules

The driver should only see the requirements that apply to this delivery.

---

## 13. Proof of Delivery rules

POD must not look like a form.

Use large full-width proof actions.

Example:
- Photo — REQUIRED
- Signature — REQUIRED
- Complete Stop

For someone else:
- Receiver type
- Photo
- Signature

For left at location:
- Photo
- GPS/time automatically recorded

Typing is not a default proof action.

---

## 14. Navigation continuity

The app should feel continuous:

Home
→ Offer
→ Pickup navigation
→ Pickup confirmation
→ Round preview
→ Stop navigation
→ Handoff
→ Proof
→ Stop complete
→ Next stop

Avoid artificial confirmation screens between states.

A successful action should normally transition directly into the next real task.

---

## 15. Drift test

Before accepting any new screen, ask:

1. Can the driver understand the job in one glance?
2. Is there one obvious primary action?
3. Did we add text that the interface already explains?
4. Did we introduce tiny text?
5. Did we create cards because we did not know how to structure the screen?
6. Are important actions cramped into columns?
7. Are we asking the driver to type unnecessarily?
8. Is system/audit data cluttering the driver experience?
9. Does the screen use the same navy / orange / green visual language?
10. Does it feel as simple and confident as D01, E01 and E02?

If the answer to any of 3–8 is yes, reconsider the design before proceeding.

---

## 16. Current anchor screens

Use these as the visual reference set:

- `ROUNDS-C03-MULTISTOP-OFFER-v5-10OF10.html`
- `ROUNDS-B03-HOME-NETWORK-AVAILABLE-v8-10OF10.html`
- `ROUNDS-D01-NAVIGATE-TO-PICKUP-v5-10OF10.html`
- `ROUNDS-D03-D04-PICKUP-CONFIRM-v6-10OF10.html`
- `ROUNDS-E01-ACTIVE-ROUND-OVERVIEW-v5-10OF10.html`
- `ROUNDS-E02-NAVIGATE-TO-CURRENT-STOP-v2-10OF10.html`

When a later screen conflicts with this constitution, the constitution wins unless we intentionally update the system.


---

## 17. Localization constitution — Thai first, one app

- Production is one localized Driver app, not EN and TH binaries/codebases.
- First run uses `A01 → A01B Choose Language`; later change is `L01 → Language`.
- Thailand is designed Thai-first. English is a first-class alternative.
- Thai copy must be written for natural driver comprehension, not literal word-for-word translation.
- Translation may increase vertical height; preserve hierarchy and tap targets instead of shrinking critical type.
- Test every field-critical component at 320 px and on lower-cost Android devices.
- Use locale-aware date/time/number formatting; operational IDs and state enums remain language-neutral.
- Names, addresses and merchant/recipient notes render exactly as entered unless a future explicit translation action exists.
- Language switching cannot interrupt an active Round, erase drafts/outbox, or reset navigation/assignment state.

## 18. Embedded navigation constitution

D01/E02 prototypes communicate product hierarchy. Production map/navigation chrome must respect the Navigation SDK safety/attribution region.

The Rounds-owned elements that must remain reachable are:

1. current pickup/Stop identity;
2. operational arrival action when appropriate;
3. exception/contact entry;
4. transition from arrival into handoff/POD;
5. honest location/connectivity freshness.

Do not cover vendor maneuver/lane/current-location safety UI simply to reproduce an HTML mockup pixel-for-pixel. Product semantics outrank prototype geometry where Navigation SDK policy/lifecycle requires adaptation.

## 19. Current anchor board set

The 2026-09-01 47-screen English board package is the current canonical visual/interaction reference. Thai design boards mirror those IDs one-to-one for localization/layout QA.
