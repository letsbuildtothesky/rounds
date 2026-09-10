# Refresh 19 — Shift complete / Network availability

34 of 47 original HTML files refreshed; 13 remain original. This refresh updates B01C only. All other app screens, earlier review pages, the style guide and shared tokens are unchanged. The ZIP contains all 47 app files.

## Design

The original page mixed an “Open for jobs” heading with a “Not accepting jobs” status and a 76 × 44 switch. The new resting state says Offers paused and provides a full-width 68px Open for jobs action. The completed Team shift remains visually separate from optional Network availability.

The approved blue wordmark, orange square and restrained blue/orange palette carry forward. Completion uses green. The main heading increases from 35px to 40px. The scheduled time increases from 26px to 36px inside a pale-blue, orange-edged hours link; its entire surface is tappable. Dispatch’s icon-only 40px controls become labelled 60px Message and Call buttons. The Network status is 28px; the primary action is 68px and Pause offers is 60px. The header control is 52px.

Original example values remain: 17:04, UrbanFlowers and 08:00–17:00. The range is explicitly labelled Scheduled shift. It is not treated as nine payable hours, an actual clock-out receipt or an attendance total. View hours and the Hours navigation open the existing Team Hours sample.

The content area scrolls independently above Network controls and primary navigation. Short viewports preserve text and touch-target sizes. No map is inserted into this completed-shift screen. Once availability is open, View Network map leads to the previously approved, larger-map B03 screen. The deferred map-marker work is unchanged.

## Review states and behavior

- Paused: completed Team shift, offers paused, explicit Open for jobs action.
- Open for jobs: local sample availability is open. View Network map opens B03’s open example. Pause offers returns this example to paused.
- Not eligible: Network unavailable, with a short account reason and disabled opening action. Completion and Team hours remain accessible.
- Offline: Network availability is not presented as confirmed. Opening and pausing cannot publish a change. Cached Team completion remains visible.
- Unconfirmed: Check status opens explicit sample result choices. Reconnection always requires this check; it never automatically reopens availability.

Opening availability does not accept a job or create a reservation. Ending a Team shift does not enable Network availability. No timed redirect, automatic shift change, location request, storage write, message or call occurs.

Team-dispatch buttons open clearly labelled local previews for UrbanFlowers. They do not enter H01’s unrelated Stop 1 recipient context or call an invented number. Modal views use labelled dialogs, background inertness, focus trapping, Escape and return focus. Review navigation accepts only known local screen names and messages from its own iframe.

## Prototype and flow boundaries

These are HTML design fixtures, identified in the review and on the individual page. They are not a connected availability service. Production must refresh eligibility, employer policy, relationship permissions, accepted obligations, presence freshness and authoritative availability separately. Uncertain write outcomes require reconciliation before confidently showing Open. No pending Team obligation or custody may be abandoned through this transition.

Earlier B01F remains unchanged and retains its separate 17:22 / 8h 22m end-shift example. This B01C retains its original 17:04 example. B03 and Team Hours also remain independent sample pages. This refresh does not silently join incompatible sample times into one authoritative trip or attendance record. Production routing must carry the actual shift identity and acknowledged end result.

## Validation

Checks cover paused/open/pause transitions, disabled eligibility and offline actions, reconnect-to-status-check behavior, interrupted status checks, contact previews, modal focus, safe local routing, script syntax, IDs and local destinations. Font metrics check key labels at 320/360/393px. All 46 non-target screens and prior reviews, guide and tokens are byte-compared, and ZIP content is checked against the output folder.

Browser/phone visual QA remains unavailable under the earlier security restriction. Font metrics and CSS dimensions are not rendered layout measurements. Device, Thai, daylight, glove and native lifecycle validation remain pending. No 10/10 or production-readiness claim.

Sources: original B01C v2 HTML; approved Refresh 16 B03 and Refresh 18 B01F; canonical v42 Driver UX Behavior Master v3.0, Driver Canonical Manifest v6, and Spec 10 Drivers Live Availability & Contact v1.4; approved style guide v1.

Suggested next screen: B02 Home / verification pending, retaining the distinction between account eligibility and live availability.
