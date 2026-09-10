# Rounds driver — Refresh 01.2

Only B01 Team driver home and B01B Round assigned are redesigned. The other 45 HTML screens retain their uploaded contents. Existing filenames are retained for internal links.

## Changes
- Home shift panel is pale slate with a narrow orange edge. Remaining time is 44px (was 51px), with tighter spacing and a 6px elapsed bar. Waiting-for-assignment leads the screen.
- Assigned screen uses real Mapbox Streets cartography with a road-following sample route, not drawn streets. A map image and route response are embedded so the file opens with a real map even without internet. An online Mapbox GL layer adds pan, pinch zoom and recentering when available.
- The original pickup coordinate was near Samitivej and did not match UrbanFlowers at Taka Town. It is corrected to the GeoCoordinates published on the UrbanFlowers contact page: longitude 100.572624, latitude 13.745653. Treat it as the published shop location; the precise driver entrance is not independently verified.
- Driver origin remains sample longitude 100.5664, latitude 13.7317. No geolocation or live tracking is requested.
- Mapbox Directions driving response fetched 2026-09-07: 2894.348 meters, 766.000 seconds; displayed as 2.9 km and 13 min. Line and metrics use the exact same captured response. This is a saved sample car route, not traffic-aware or motorbike-specific navigation.
- Saved map marker D means sample driver, P means pickup. Attribution and Mapbox logo are retained. The interactive layer uses You/Pickup labels. `?offline=1` keeps the saved view and suppresses all external map requests.
- Public Mapbox token and SDK version are reused from the original prototype. No new map account or credentials were added.
- Existing round totals remain original sample data: four stops, 18.6km, about 58 minutes. They are separate from the pickup route.

## Shared design
White header, 48px contact controls, 76px bottom navigation and navy main action. Body text 14–17px; secondary labels 12–13px. Arial has no external font dependency. Scrollable main content, stable header/navigation and safe-area padding are retained.

## Validation and limits
- Mapbox returned a successful Directions response and a valid real-map PNG; map geography and route placement were visually inspected from that image.
- Script syntax, screen IDs, relative destinations, changed-file scope and ZIP integrity are checked. Fixed route response and displayed numbers agree.
- Full HTML rendering and interactive browser/device testing remain unverified because browser preview access is blocked. Small phone rendering and long Thai text still require visual review before design sign-off.
- Downstream screens are unchanged: the old D01 navigation screen still has its original sample coordinates. Its migration to this route belongs to the next screen pair; linked files resolve but the full journey is not yet visually/geographically unified.

## Files
Open index.html in the ZIP for linked screens. The separate two-screen HTML is self-contained for layout review. Saved imagery and captured geometry are embedded in the assigned HTML.

## Sources
- UrbanFlowers published shop address and structured GeoCoordinates: https://www.urbanflowers.co.th/en/contact-us/
- Mapbox Directions: https://docs.mapbox.com/api/navigation/directions/
- Mapbox Static Images: https://docs.mapbox.com/api/maps/static-images/
- Mapbox GL JS: https://docs.mapbox.com/mapbox-gl-js/api/map/

## Refresh 01.3 — shared blue palette
Home and assigned-round now use the blue/soft-blue palette, blue route, orange pickup marker, and 64px assigned primary action. Layout and flow retained. Assigned round summary uses the current four-stop sample route total and six packages. See Refresh 03 for the cumulative design notes.
