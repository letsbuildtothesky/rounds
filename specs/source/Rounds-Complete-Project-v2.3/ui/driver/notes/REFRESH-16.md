# Refresh 16 — Start shift + Network home

30 of 47 original HTML files refreshed; 17 remain original. This pair changes B00 and B03 only. The corrected Refresh 15 offers, all previous screens/review pages, style guide and tokens remain unchanged. All 47 original screen filenames are retained.

## Original comparison

B00 previously used a 39px shift time, 11.5–13.5px supporting labels, 40px notification control and 44px icon-only dispatch actions. Its Start shift link immediately opened a later Team-home fixture without representing a start outcome. The new screen uses the approved blue wordmark, pale blue schedule with orange rule, 44px time, 16px shift details, 52px header control, labelled 60px contacts and a pinned 68px Start shift action. The 08:00–17:00 / 9h schedule, UrbanFlowers dispatch and 07:52 / starts in 8 minutes context are preserved. Space between the schedule and dispatch is intentional, matching the approved Team home.

B03 previously used a schematic street map, a fabricated driver dot, a 60×36 switch, 34–40px map/header controls and 10.5–13px area details. The new version uses a real saved map as its central surface, 30px availability heading, 22px selected-area name, 16px job/distance figures and a full-width 64px availability action. The map sits directly below the compact status header; a short area row and action remain below it. The explicit Pause offers / Open for jobs buttons replace the small switch while keeping its driver-controlled on/off behavior.

Blue/orange branding and operational green remain restrained. No new palette or marker system. Inactive work state and connection state have different labels and actions. Footer/content use flex flow and independent scrolling; controls are not shrunk to fit shorter screens.

## Maps and preserved data

Real Mapbox streets-v12 snapshots, 393×420 @2x. All variants have the same camera and numbered area positions. Orange identifies the selected area; blue identifies the other areas, using the existing provider pin style. The base map omits demand pins. No driver location, route, traffic, recenter animation or live-map claim is fabricated. All area coordinates are approximate demo areas. Provider logos/attribution are retained; contain fitting prevents clipping. The map opens an enlarged view and large area-selection rows.

| Area | Original count | Original distance |
|---|---:|---|
| Thonglor | 5 jobs | 1.8 km |
| Ekkamai | 3 jobs | 2.4 km |
| Sukhumvit 39 | 2 jobs | 0.9 km |

The original Last 20 min period, counts and distance labels are retained as sample data, not live demand. Distances are legacy examples; without a driver-origin fixture they are not calculated from these area coordinates. Real demand needs an authoritative source and expiry. Area metadata is included in notes/NETWORK-16-MAP-FIXTURES.json.

Paused, busy, stale and unconfirmed states use the unmarked saved map and suppress recent-demand counts. The no-demand state is an explicit additional empty-state example. It does not mutate the original area's sample counts. No area selection accepts work or opens a merchant conversation.

## Behavior covered in the HTML review

B00: Before shift, Ready, Started, Unavailable, Unconfirmed and Offline. The normal Start shift action immediately advances the clearly labelled local demonstration. A real connection loss prevents starting; reconnection changes to an unconfirmed status, never automatically starts a shift. Status-result choices are explicitly labelled as preview controls. The ready example uses 08:00, while the original before-shift example uses 07:52. No new early-clock-in policy is invented.

Dispatch actions open a Team-dispatch preview for UrbanFlowers. They do not route off-shift chat into H01's unrelated Stop 1 conversation or send messages/calls. Production must open the authorized employer conversation/voice context. The existing H01/H02 screens are unchanged.

B03 retains the five canonical states:

- Open for jobs: eligible to be considered for compatible offers; Pause offers changes only future availability in the demo.
- Offers paused: Open for jobs is the explicit next action; identity and reliability are unchanged.
- Open after current work: Round 27, Stop 2 of 3; ~14:05 is explicitly projected. Pause future offers keeps the current Round.
- On a Round: accepted work remains; Open after this Round changes only future availability.
- Offline / stale: last synced 8 minutes ago, unmarked saved map and no fresh availability claim. Reconnection requires a status check; it never turns availability on automatically.

Current work remains accessible through offline/unknown transitions if it was already present. Round 27 opens its own local summary with the known Stop 2-of-3 scope. It does not open E01's incompatible fixed Round 18 route or invent Round 27 recipient addresses. Production must open the actual accepted assignment route.

Area selection changes the selected pin emphasis and footer; it does not accept an offer. Visibility explains internal matching, protection of exact pre-acceptance GPS and the fact that pausing future offers does not end accepted work or penalize Network reliability. All sheets have focus management, inert backgrounds, Escape and return focus.

## Integration boundary

These two files are interactive design prototypes, not shift-clock or availability-service implementations. They deliberately make no backend, GPS, matching, message or call requests. The standalone review labels samples outside the phone; opening a screen directly shows Preview · Sample state. No global bridge or operational service is invoked by these preview controls. Production must replace the fixture transition functions with authoritative outcomes.

Required implementation work includes authenticated driver/employer context, shift policy and durable start receipts, idempotent requests/reconciliation, freshness/eligibility gates, device lifecycle, permitted Team vs Network availability, accepted-work preservation, projected availability, aggregate-demand expiry and actual assignment/contact navigation. An unconfirmed write must remain unconfirmed; do not copy the demo transition as a service acknowledgement. Network availability must never serve as an accepted-work cancellation control.

No new screen IDs or product-wide timing/freshness thresholds were invented. Start shift / future availability remain separate operations. No real data is persisted or published by the review.

## Validation

Compared both predecessors and controlling local v42 specs. Checks cover script syntax, duplicate IDs, local navigation targets and Team/Network context; sample start/availability states, active-work preservation, offline/reconnect behavior, area selection, map fallback, modal focus and trusted review navigation; key row font metrics at 320/360/393px; unchanged prior screens/tokens/guide; embedded map assets and ZIP integrity.

Map images were visually inspected. Browser/phone visual QA is still unavailable under the earlier security restriction. Font calculations and CSS dimensions are estimates, not rendered measurements. Thai, actual devices, sunlight/gloves and backend integration remain unvalidated. No 10/10 or production-ready claim.

Sources: original B00 v1 and B03 v8 HTML; current v42 Driver Canonical Manifest v6; Driver UX Behavior Master v3.0 B00–B03 and Network availability addendum; Spec 10 Drivers Live Availability & Contact v1.4 §§2–4, 8–10, 12–15 and 19; approved Driver style guide v1. Map snapshots saved 7 September 2026.
