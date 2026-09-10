# Refresh 17 — Shift ending soon + Overtime

32 of 47 original HTML files refreshed; 15 remain original. Only B01D and B01E change in this pair. All earlier app screens, review pages, the guide and tokens are preserved. The last offer-map correction and Refresh 16 Start shift / Network home remain unchanged.

## What improves

The original screens were readable at the reference size but compressed Anantara Siam into a one-line destination beside the ETA, with ellipsis on overflow. They also used 11.5–13px labels, 38–40px icon controls and a largely black/orange palette. The new pair follows the approved blue wordmark, restrained blue/orange surfaces, 44px timing, a full-width 28px destination allowed to wrap, clear 36px arrival / 32px timing-impact figures, 14–16px operational labels, 60px labelled contact buttons and a pinned 68px Return to delivery action.

The shift-time block and delivery estimates are visually separate. Ending soon uses the existing pale blue; overtime uses the existing pale orange and care text. No new color tokens or ornamental badges. “Scheduled end · 17:00” replaces the original overtime wording “Shift ended 17:00,” which could imply the driver had clocked out despite active work.

Both remain shift status screens. Their main task is to explain shift timing and return the driver to the accepted delivery. The delivery destination spans the available width rather than competing with an ETA column. Contact actions stay reachable at the bottom of the scrollable content; the primary action and navigation remain pinned. Flex flow, minimum heights, safe areas and independent scrolling preserve text/control size on short phones.

## Preserved example data

| Field | B01D / Ending soon | B01E / Overtime |
|---|---|---|
| Current example time | 16:45 | 17:14 |
| Scheduled shift end | 17:00 | 17:00 |
| Shift headline | 15 min left | +14 min |
| Destination | Anantara Siam | Anantara Siam |
| Area | Ratchadamri | Ratchadamri |
| Delivery scope | Last delivery · 8 of 8 | Last delivery · 8 of 8 |
| Estimated arrival | 17:18 | 17:22 |
| Secondary estimate | +18 min past scheduled end | 8 min remaining |
| Dispatch | UrbanFlowers | UrbanFlowers |

Timing differences are derived from one local fixture per screen. Shift time and ETA have different meanings: the expected arrival can be after the scheduled end before overtime has actually begun. The Later ETA review state uses an explicit additional sample of 17:30: +30 minutes past scheduled end in B01D; 16 minutes remaining in B01E. It does not modify the original examples or define a new delivery promise.

No overtime rate, paid amount, clock-out event, arrival, delivery completion or custody release is claimed. Reaching scheduled shift end cannot terminate active work. End-shift confirmation and completed-shift states remain separate B01F/B01C screens for a later pair.

## Correct delivery context

The original Return to delivery links pointed to E02's fixed Stop 1 / Emporio fixture, despite these screens showing Anantara Siam as delivery 8 of 8. The new action opens a full-height local destination view with the correct Anantara Siam / Ratchadamri / delivery 8-of-8 context and the same arrival estimate. It does not change the previously approved E02.

The destination view contains a real saved Mapbox streets-v12 area map at 393×420 @2x. The existing approximate Anantara Siam fixture coordinate [100.5414, 13.7405] is reused. Pin 8 identifies the current displayed delivery; the established provider pin style is retained. No live driver dot, road route, turn instructions, verified entrance or navigation ETA is fabricated. This is a destination-area preview, not embedded turn-by-turn navigation. The map image was inspected; provider logos/attribution remain visible, and contain fitting prevents cropping.

Open in Maps in the standalone review is intercepted and explained outside the phone. Opening an individual screen directly allows an explicit tap to search Google Maps for “Anantara Siam Bangkok Ratchadamri.” It does not navigate to the approximate map coordinate or claim a verified delivery entrance. Production must open the actual assigned stop's verified navigation context. The HTML review does not launch navigation automatically.

Dispatch Message / Call opens a clearly labelled preview for UrbanFlowers and this delivery, instead of routing into H01's unrelated Stop 1 conversation. It makes no outbound call or message. Production contact must use the correct authorized Team/current-delivery conversation.

## Review states and interaction

Current, Later ETA, No ETA, Offline and Delivery view are available outside each phone. No prototype mode controls are added to the production layout.

When ETA is unavailable, both arrival and the derived remaining/overrun estimate become unavailable; the UI does not preserve misleading precision. Offline marks the shift timing as last known, removes current ETA and keeps accepted delivery context accessible. Reconnection does not silently make cached ETA fresh. The review selector supplies a new sample; production needs an authoritative update.

No backend, shift write, proof write, GPS, tracking, storage, call or message request occurs. The plain screen displays Preview · Sample shift; the standalone review labels examples outside the phones. Local preview functions are not service acknowledgements.

Modal views use native buttons/links, accessible names, focus movement, inert backgrounds, Tab trapping, Escape and return focus. Map failure retains the named destination, ETA state and Maps action. Successful image loading can restore the map.

## Validation and limits

Checks cover original values and time arithmetic, script syntax, duplicate IDs, referenced IDs, local links and Team context, modal focus, correct delivery/contact context, no automatic external Maps launch, no shift-ending mutation, ETA loss/offline/reconnect behavior, image fallback/recovery, and trusted review messages. Key text widths and two-column metrics are checked at 320/360/393px with font metrics. All non-target app files, existing guide/tokens and previous review pages are byte-compared. The ZIP is checked against the current 47-screen folder.

Browser/phone visual QA remains unavailable under the earlier security restriction. CSS allocations and font metrics are not browser measurements. Actual device layouts, Thai wrapping, sunlight/gloves, native navigation and authoritative shift/ETA lifecycle still need validation. No 10/10 or production-readiness claim.

Sources: original B01D/B01E v3 HTML; current v42 Driver UX Behavior Master v3.0 B00–B03 and embedded-navigation intent; Driver Canonical Manifest v6; Spec 10 Drivers Live Availability & Contact v1.4 Team/accepted-work semantics; approved style guide v1. Map snapshot saved 7 September 2026.
