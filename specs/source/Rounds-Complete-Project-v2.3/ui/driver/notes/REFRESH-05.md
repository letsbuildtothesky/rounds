# Rounds driver — Refresh 05

## Scope
Adds a fixed style guide and shared CSS token file. Refreshes F08 stop complete/next stop and I01 round complete after reading both originals. All eight earlier refreshed screens remain byte-identical to Refresh 04. The 47-screen pack now contains 10 refreshed screens and 37 unchanged originals. Previous pair notes are in notes/; the current style guide is ROUNDS-DRIVER-STYLE-GUIDE.md.

## Stop complete / next stop
- Clear green completion check and 23px completion title, 15px recipient/time and 22px delivered counter replace smaller 10.5–16.5px status text.
- Large real map fills remaining space. Captured road geometry uses the same source as Refresh 03; completed Stop 1 is green, next Stop 2 orange, Stops 3 and 4 blue. Next leg is a strong blue line, later legs a quieter blue. Map controls are 52px with saved image fallback and provider attribution.
- Location-first next-task panel: The Sukhothai Residences / Sathorn, with James T. and Signature hamper beneath. This remains the original sample destination label and original sample coordinate, not a newly verified entrance.
- One 64px navigation action and a 56px remaining-stop action. The remaining list now includes the next stop, making its count explicit: three stops / five packages remain.
- Travel figures all come from the captured route: next leg 5.3km / about 20min; all remaining legs 12.0km. Per-leg estimates exclude handing-over time.
- Fix the old Navigate to Stop 2 destination: the earlier E02 HTML is still a fixed Stop 1 prototype and ignores ?stop=2. This button now opens external Google Maps for the actual sample Stop 2 coordinate. No silent trip to Stop 1. Earlier screens are preserved. A fully parameterized in-app journey for every recipient remains implementation work.

## Round complete
- Blue Rounds wordmark with the approved orange square; clear 42px delivered total; existing four-stop, six-package round information.
- Team mode: pale-blue shift panel consistent with Home; 44px remaining time; blue progress with a numerical accessibility value. At 15:08, an 08:00–17:00 shift has 428 minutes elapsed and 112 minutes left (7h08m worked / 1h52m left), 79.26% complete. The Continue shift action returns to the existing team Home.
- Network mode: preserve the original guaranteed ฿420 fare and Open for jobs action to Network Home. Hide team-only hours and the original team-only on-time line. Do not relabel the fare as paid or available balance.
- View delivered stops opens a large readable list of all four recipients and their package counts. No unprovided delivery times or performance metrics are invented.
- Main content can scroll while the 68px next action stays at the bottom.

## Review states
index.html and standalone review show this pair. Team and network tabs change I01 only. The map is a fixed sample, not live GPS. Saved geometry and all job labels are fixture data. No delivery or payment record is submitted.

## Validation
Embedded JavaScript syntax, team/network switching and home targets, shift arithmetic, remaining-stop counts and destination URL, modal behavior, local file links, guide/token consistency, unchanged-screen scope and ZIP integrity checked. New saved real map inspected. Full browser rendering remains unavailable after the earlier browser security block. Phone layout, sunlight/glove interaction, device map behavior and Thai wrapping still need visual/device validation.

## Sources
- Original supplied F08/I01 and approved Refresh 01–04 HTML for demo job records and behavior.
- Captured Mapbox driving response already used by Refresh 03.
- https://docs.mapbox.com/api/navigation/directions/
- https://docs.mapbox.com/api/maps/static-images/

## Next pair
G01 recipient unavailable and G02 address problem. Keep the style guide fixed and compare all existing exception actions before updating.
