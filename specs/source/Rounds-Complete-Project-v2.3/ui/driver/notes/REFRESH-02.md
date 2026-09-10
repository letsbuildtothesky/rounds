# Rounds driver — Refresh 02

## Product rule
Clarity for drivers comes first: generous touch targets, readable instructions outside, large useful map surfaces, concise copy, no decorative content that reduces task space. Compare each pair to its current predecessor before changing it. Preserve or improve useful behavior; do not equate a new appearance with an improvement. Blue is for navigation/actions, orange for destination/handling emphasis, green for completed/ready states, red for problems. Validate on phones before claiming suitability with gloves.

## This pair
- D01 Navigate to pickup: full-width blue instruction panel replaces the narrow instruction column between controls. Direction text increases from 13.5px to 20px, distance from 30px to 36px. Back/menu/map controls are 52px; footer actions are 64px. Map expands into remaining height.
- Uses the corrected published Taka Town location from Refresh 01.2. Real Mapbox driving route, two saved map images and optional interactive pan/zoom/recenter. Orange pickup marker and blue route/driver. Logo and attribution retained.
- On-the-way preview shows 130m to the next right turn, derived from the captured first leg (132.322m before the next right maneuver). Route is 2894.348m, about 13 minutes. Near-pickup state uses the final 163.371m step; it shows Pickup ahead and the large arrival action. The state is selected in the review controls or with ?state=near. No live positioning or automatic arrival is simulated.
- Open navigation launches external Google Maps. Call pickup uses the public business number from UrbanFlowers' contact page. Operations chat and problem actions remain available in a large action sheet.
- D03/D04 Pickup confirmation: six individually selectable physical packages replace five product rows. Two arrangements are labeled 1 of 2 and 2 of 2, preserving the same order and six-package manifest. Count now runs 0 of 6 to 6 of 6.
- Package rows are at least 88–92px, entire rows are tappable, selection indicators 34px, item titles 17px, order/recipient labels 14px, handling labels 13px. Collected rows turn pale blue; a green 68px confirmation becomes enabled only at six collected packages.
- Header and confirmation stay visible while package list scrolls. Native buttons support keyboard activation; modal sheets trap focus and return it on close. Selection is kept in sessionStorage across prototype navigation when storage is available, then cleared on confirmation. Nothing is submitted to a live service.
- Pickup problem choices keep the legacy G03 destination; that older screen still owns its issue selection flow.

## Cumulative scope
Current pack includes 47 screens. Four differ from the original upload: B01, B01B, D01, D03/D04. The previous home and assigned-round HTML files are copied unchanged from Refresh 01.2. The other 43 HTML screens remain unchanged. index.html shows this pair; pair-01.html shows the earlier pair.

## Validation
Script syntax, counter gating and toggle behavior, local file destinations, cumulative scope, and archive integrity are checked. Both real-map assets were retrieved from Mapbox. Full browser rendering, touch behavior on devices, sun/glove use, native back behavior and long Thai content still need validation; no 10/10 claim is made.

## Next pair
Suggested next: E01 active round overview and E02 navigate to current stop, carrying this map/instruction/control system forward.

## Sources
- Published UrbanFlowers location and contact: https://www.urbanflowers.co.th/en/contact-us/
- Real driving geometry and step instructions: https://docs.mapbox.com/api/navigation/directions/
- Saved maps: https://docs.mapbox.com/api/maps/static-images/
- Live map interface: https://docs.mapbox.com/mapbox-gl-js/api/map/
