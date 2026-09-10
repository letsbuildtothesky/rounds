# Refresh 15 — Single Delivery Offer + Multi-stop Offer

28 of 47 original HTML files refreshed; 19 remain original. Includes the polished N02 from Refresh 14. The guide/tokens, GPS screen and all other previous app screens are unchanged. The ZIP retains all previous review pages; pair-14.html includes the offline copy polish.

## Original comparison and design

Original C01/C03 had 11.5–14.5px material text, schematic maps, 42px decline controls, fixed content boxes and Accept links that immediately navigated to a shared pickup fixture.

The corrected layout gives the map the central surface. A 52px brand row, 84px fare block and 72px pickup row sit above it. The fare stays 52px, scope 20px, pickup name 22px and pickup distance 23px. The 24px trip estimate and 20px ending area sit in a short strip immediately below the map. Handling, vehicle and deadline stay visible in a concise two-line footer above the decisions. Accept and Decline are side by side in the available-offer state, both at least 68px high; the primary button remains dominant. Other states keep the established full-width action layout. Map enlargement remains 52px. The blue/orange palette, wordmark and confirmed-acceptance green are unchanged.

Both maps are real Mapbox street imagery with the same pin style used previously. P identifies pickup; 1–4 identify stop areas. No marker redesign. No fake road geometry or invented live driver dot. These are area overviews, not exact recipient locations or navigation routes. Mapbox/OpenStreetMap logos and attribution remain visible. Delivery-area coordinates are approximate fixtures; pickup uses the previously verified public UrbanFlowers location.

Original fares, pickup estimates, route estimates and final areas are preserved:

| Offer | Guaranteed fare | Pickup | Total estimate | Stop areas |
|---|---:|---|---|---|
| C01 | ฿185 | 1.4 km / ~5 min | 4.8 km / ~17 min | Thonglor |
| C03 | ฿420 | 1.2 km / ~4 min | 18.6 km / ~58 min | Thonglor → Asoke → Lumphini → Sathorn |

Map area coordinates do not determine the legacy offer estimates. No precise road route is drawn or claimed. The production offer/map estimates must come from one authoritative scoped offer.

The current canonical spec also requires vehicle and time constraints before acceptance. The review explicitly uses example fields: Motorbike + box; pickup now; deliver by 18:00 for the 17:21 single offer, and by 12:30 for the 10:42 multi-stop offer. These are newly added demonstration values, not customer promises or new business-wide rules. Original handling is retained: fragile bouquet; flowers + cake kept upright. No unknown package counts, recipient identities, exact delivery addresses or COD terms were invented.

## Review and acceptance behavior

State buttons: Available, Accepted, Another driver, Expired, Withdrawn, Checking, Offline. Press Accept to choose a clearly labelled sample result. The review never calls an adapter, claims work or starts navigation. The individual HTML without an adapter shows “Preview · Sample offer”.

- Accept is one commitment for the displayed offer/version. No multi-stop per-delivery acceptance.
- Confirmed acceptance shows the guaranteed fare, accepted scope and pickup action immediately.
- Another driver winning has its own clear state, separate from a technical failure.
- Expired/withdrawn offers close and return to availability.
- Decline has no questionnaire or extra confirmation. A real service result is required before reporting its success.
- Offline acceptance is blocked and never queued.
- Unconfirmed acceptance becomes Check acceptance; it does not navigate or report a win.
- Duplicate clicks are blocked while a request is pending.
- Reconnection reads status only, never sends an acceptance.
- The correct accepted offer opens a local pickup sheet. It does not jump to the existing D01 fixed four-stop/six-package fixture, which would misrepresent the single offer and the original C03 stop sequence.
- Review navigation is intercepted. The plain demo may open Google Maps to the public pickup after a separate explicit navigation click. Real adapters must route the confirmed assignment through native pickup/navigation.

## Optional adapter boundary

window.RoundsOfferBridge is an integration interface, not a backend implementation.

Methods:

- getOffer({offerId, version, requestId}): authoritative read, including reconciliation of a previous command ID.
- accept({offerId, version, requestId}): atomic, idempotent claim of exactly the displayed scope.
- decline({offerId, version, requestId}): idempotent decline.
- openPickup({assignmentId, offerId, version}): open the correct assigned pickup flow.

Results identify offerId, version and status. Status values include available, accepted, taken, expired, withdrawn, declined, changed, unknown, error and offline.

An available result includes finite serverNow and expiresAt timestamps in milliseconds. The UI converts their difference to a local monotonic deadline. It does not invent a product-wide offer duration. The demo has no ticking expiry; explicit review state buttons show closure. The native service remains authoritative at a claim boundary.

An accepted result requires claim {offerId, version, assignmentId, acceptedBySelf:true}, matching the displayed offer. A bare accepted status, another driver's claim, a mismatched ID or a different version cannot unlock pickup. A new version shows Offer changed and requires reopening current offer data; the prototype does not apply unseen changed terms.

Requests have a 12-second UI timeout. Timeout/failure leaves acceptance unconfirmed. A page exit or offline transition invalidates late callbacks. Native services own authentication, durable request IDs across lifecycle, canonical offer terms, linearizable reconciliation, atomic winner selection, server-clock integrity, expiry, eligibility, availability and actual navigation. A correctly shaped JS object is not proof of a trustworthy server.

No account, assignment or availability data is persisted by this HTML. Production must not use the fixed fixtures as operational input.

## N02 final copy polish

Removed the normal-state lead and repeated bottom sync explanation. Rows show one short state. Essential unsaved-work instructions and errors remain. Sent-item details no longer restate the receipt. No receipt validation, retry or GPS behavior changed.

## Validation and remaining work

Checks cover scripts, IDs, local targets, unchanged tokens/prior screens, embedded maps and ZIP contents; demo states, accept/decline, claim/version/expiry guards, race loss, no offline acceptance, duplicate clicks, timeout/reconnect reconciliation, late callbacks, modal focus and trusted review navigation.

The two saved map images were inspected. Browser visual QA remains unavailable under the earlier security restriction; actual phone layout, long Thai copy, sunlight/gloves and native backend/navigation behavior still need device validation. No 10/10 or production-readiness claim.

COV01 now has HTML states and an adapter contract for atomic claim outcomes. The real backend race/replay/lifecycle tests remain open. Original estimate semantics and production cargo/time/window data must be bound to the canonical offer model before implementation.

Sources: current v42 ROUNDS-DRIVER-UX-BEHAVIOR-MASTER-v3.0.md C01/C03 section; ROUNDS-SPEC-3-DRIVER-BROADCAST-OPERATING-MODEL-v1.8.md §§9–12; original C01/C03 HTML. Map assets: Mapbox Static Images, streets-v12, saved 7 September 2026. No live traffic or GPS claim.

## Map layout correction after review

The previous layout put a long stack of terms above the map. This correction moves the map directly after pickup, puts route estimates below it and consolidates requirements beside the actions. It does not hide vehicle, handling or deadline information in a drawer.

The map receives the remaining content height, designed for about 400px at the 393×852 reference size (roughly 47% of the full screen). This is a CSS allocation estimate, not a browser measurement. The minimum map basis adapts to viewport height, with a 220px floor for very short screens. Independent scrolling handles insufficient height without reducing text or action sizes. The normal fare remains 52px; the existing narrow-width 48px value remains.

New 393×400 @2x provider snapshots use the exact same pickup/area coordinates, pin labels and colours as the earlier 393×300 maps. They are taller real maps, not stretched versions of the previous bitmaps. Images use contain fitting so no stop or provider attribution is cropped. The legend overlays unused upper map space; enlargement opens the complete map and scope. The map images themselves were inspected.

The available action label is now Accept · fare for both offers; the visible four-stop scope still defines one Round commitment. Beyond the button copy and a presentation class, the JavaScript is unchanged. Offer values, scope, timing fixtures, receipt/version/expiry checks and navigation behavior remain the same.

Validation for this correction: source hierarchy, type/control sizes, font-width calculations for key rows at 320/360/393px, preserved offer data, offer interaction suite, unchanged non-offer screens and ZIP integrity. Actual browser/phone visual QA remains pending.
