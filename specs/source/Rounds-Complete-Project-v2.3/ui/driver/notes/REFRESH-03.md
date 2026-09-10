# Rounds — Refresh 03

## Scope and comparison
Read the existing E01 and E02 before changing them. This cumulative pack contains 47 screen HTML files, six refreshed in total. This iteration updates E01 and E02 and aligns B01/B01B to the approved Refresh 02 blue. D01 and D03/D04 are copied without changes from Refresh 02; the other 41 screens still match the original upload. The previous versioned packs remain snapshots of their delivery date. Pair 01's standalone HTML and pack are updated in place.

## Color roles
Blue #1754a6: primary navigation, route, active tabs and information. Pale blue #edf4fd: supporting information. Orange #ff6420: brand accents, the current destination, and pickup emphasis. Green: collected/ready states. Red: problems. Dark ink remains for readable body text. Color is accompanied by labels, numbers and icons.

## Earlier pair
B01 retains its waiting-state layout and large shift timer, with a pale-blue shift panel, blue figures and progress track, blue active tab and blue contact icons. B01B gets a pale-blue pickup summary, a 64px blue primary action, blue route and orange pickup marker on both the saved map and interactive map. The assigned-round summary now uses the same sample route total and six-package count as E01, instead of inconsistent legacy totals.

## Active round, E01
A full-width blue summary shows four stops, six packages and remaining distance. The real map highlights the first leg in stronger blue and uses numbered delivery markers; the current stop is orange. The bottom panel prioritizes the destination building and street, with recipient and fragile handling directly beneath. The primary navigation action is 64px; All 4 stops is 56px and opens the complete manifest. The list includes all four recipients, package counts, consistent first-order orchid and glass vase, and per-leg drive estimates. These are travel estimates; handling time is excluded. The legacy route-update state (?update=1) and Review destination remain available. Dynamic content is in flex layout, replacing fixed-height docking that could crowd its contents.

## Delivery navigation, E02
Carries forward the D01 layout with a full-width blue direction panel, 36px distance, 20px instruction, large map, 52px map/header controls and a 64px primary action. Recipient context is in the header; destination building and street remain in the bottom panel. A labeled Call control goes to the existing contact screen rather than dialing an invented number. External navigation uses the same sample destination. Near Stop 1 shows the final 200m of the actual captured geometry and the green arrival action; it links to the existing F01/F02 handoff screen. On-the-way and near-arrival are manually selected preview states, not live location detection.

## Map data and limitations
Mapbox streets-v12 imagery and road geometry, saved into the HTML for a useful offline review. Internet can enable pan, pinch, zoom and route recentering. Attribution retained. New routes use the corrected Taka Town pickup from Refresh 02 as their start and the original E01 delivery coordinates as sample stops. E02 previously used a conflicting coordinate for the same recipient; it now shares E01's sample location. Delivery pins and exact entrances have NOT been independently verified; no unverified Tower A entrance label is presented. Stops 2 and 3 are sample recipient locations inherited from the supplied files. The maps are real, the job and current location are prototypes. Driving profile only; no live GPS, traffic updates or motorcycle routing.

## Validation
JavaScript syntax, offline and near-arrival states, dialog open/close and focus handling, route-update selection, matching route totals, local link targets, unchanged-screen scope and ZIP integrity checked. Saved real-map assets inspected. Full HTML browser rendering could not be completed in this environment; browser/device layout and outdoor/glove usability still require visual validation. This is not a 10/10 or production-readiness claim.

## Sources
- Original uploaded E01/E02 and approved Refresh 01/02 HTML for demo job records.
- [Published pickup location](https://www.urbanflowers.co.th/en/contact-us/)
- [Mapbox driving directions](https://docs.mapbox.com/api/navigation/directions/)
- [Mapbox static maps](https://docs.mapbox.com/api/maps/static-images/)
- [Mapbox GL JS](https://docs.mapbox.com/mapbox-gl-js/api/map/)

## Next pair
F01/F02 dropoff handoff and F03/F04 proof of delivery. Compare their original content and behavior before editing.

Captured route: 14.8 km; 51.8 driving minutes. First leg: 2.9 km; 13 min.
