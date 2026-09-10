# Rounds driver — Refresh 06

## Scope
Read the original G01 recipient-unavailable and G02 address-problem screens, the approved previous pair and the fixed style guide before refreshing these two exception screens. The cumulative pack contains all 47 screens: 12 visually refreshed and 35 originals. The style guide and design-tokens.css are unchanged. Earlier pair notes and review pages are included.

Two earlier refreshed screens (E02 navigation and F01 handoff) also receive a one-parameter wiring correction: H02 expects `contact=recipient`, while those links used `target=recipient` and opened Operations instead. Only that query parameter changes; their layout and copy are preserved. Archived pair review HTML in this new pack receives the same correction. Previous delivered files remain unchanged.

## Fixed visual system
Same #1754a6 blue, #ff6420 orange, pale-blue headings, ink text and operational red/green. No new palette. Blue 64px primary actions, 60px contact actions, 52px header controls, 68px sheet rows, 88px location choices. Titles 30px, recipient 17px, address 16px, problem options 19px, details 15–16px. Scrollable content and sheets; pinned footer; safe-area padding. Main heading retains the orange left rule from handoff and pickup.

## G01 — Recipient unavailable
- Preserve the two-call escalation, call outcomes, Operations contact, waiting and approved handoff states.
- Main action starts with Call recipient; opens a call sheet with the recipient contact link and explicit post-call outcomes. Opening a contact screen never records a call by itself.
- One unsuccessful outcome prompts another call. Two unsuccessful outcomes promote Contact Operations. Recipient answered makes Continue to handoff available without timed navigation.
- Attempts show actual local time when manually recorded, rather than hardcoded times. Waiting/approved review fixtures use explicit sample times.
- Request instructions models the waiting state. No timed approval. Message Operations and recipient contact stay available while waiting; the driver is not left with a disabled-only footer.
- Approved fixture: Leave with reception / Photo required. Continue to handoff opens F01 so receipt/proof must still be captured.
- Correct package is Midnight Orchid + glass vase, #8421, one fragile package. No unsupported Tower A lobby instruction or inconsistent bouquet label.
- More menu retains address problem, Operations chat/call, recipient call, navigation, and a working link to cannot-complete delivery.

## G02 — Location problem
- Keep all four categories: wrong pin, entrance/access, wrong address and cannot find location.
- Preserve wrong entrance, access closed, better driveway, different building, written address wrong and recipient-provided address subchoices.
- Select a problem, optionally add an entrance/address/landmark, then request review. Reports can be made without a known correction or location fix.
- Optional Add my location invokes browser geolocation only on an explicit click. Captured coordinates and browser-reported accuracy appear only after success. Denied/unavailable/invalid locations retain a path to report without location. Removing a location removes it from the draft. Pending capture disables submission until the result resolves.
- No decorative street map, automatic GPS attachment, invented ±8m accuracy, or fabricated distance/time impact. Route estimates and a selectable corrected pin require the future map/backend integration. The existing large maps on navigation screens remain available through Return to navigation.
- Waiting recap shows the actual chosen issue, submitted details and optional measured coordinate. Editing starts from the report; cancel does not overwrite the submitted recap. Operations chat and recipient call remain reachable.
- Offline report data is genuinely written to sessionStorage when available. Draft saved appears only after a successful write; storage failure is explicit. This is tab/session scope, not a durable offline queue or background synchronization. Retry is user-initiated and never auto-approves.
- Approved review fixture uses Gate B, matching the linked legacy entrance-change screen, and does not invent an ETA here. The original E04 change screen is still a sample fixture and requires its own future refresh/integration.

## Prototype and review behavior
Standalone HTML contains both full screens and local interactions. It intercepts companion-file navigation and explains outside the phone that the ZIP is required. The ZIP's index.html and screens support real local links to the original companion prototypes. The H02 and H01 prototypes remain the existing contact demos; this refresh neither places calls nor sends messages via a tool.

Outer review tabs show initial, waiting and approved states (plus offline for G02). Approvals are explicit review fixtures. Requests are simulated; no backend submission or Operations approval occurs. There are no automatic success timers. On regular screen pages, attempts and reports persist in sessionStorage. Review tabs reset their own display; preview writes use separate storage keys. Optional geolocation uses the browser API; no location is uploaded by these screens.

## Validation
JavaScript syntax and local logic checks cover call escalation, reached/waiting/approved states, category/subcategory routing, optional location success/failure/removal, submitted recap, offline storage failure and retry, modal focus, review switches and link targets. HTML IDs, stylesheet token reuse, 47-screen inventory, exact changed-file scope and ZIP integrity are checked. These are source/logic checks. Full browser rendering remains unavailable after the earlier browser security block. Phone layout, text scaling, sunlight/glove use and real contact/map integration still need device validation.

## Next pair
G03 package problem and G04 cannot complete delivery. Compare originals first and retain the fixed style guide.
