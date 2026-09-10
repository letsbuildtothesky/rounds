# Rounds Driver — Refresh 13

7 September 2026 · N01 Permissions.

## Progress

47 app HTML files: **24 refreshed, 23 still original**. Only N01 changes. Earlier screens, maps, review pages, tokens and the approved style guide remain unchanged. `pair-12.html` opens Notifications. The included coverage audit is still the dated Refresh 10 baseline; these notes provide the latest progress count.

## Visual changes

The approved blue wordmark, orange accent, white surface and Arial type continue. Permission explanations have a 40px heading (36px below 350px), 18px supporting copy, one 16px scope note and a clear SVG symbol. The primary action is 64px high; Not now is 60px. Controls are pinned below an independent content scroller and keep their size on short screens. There are no early green checkmarks suggesting access has already been granted.

## Flow and timing

The original N01 contained three explanations but advanced on a timer regardless of the permission result. It also claimed a background permission request without a native implementation.

This refresh preserves all three capability explanations inside N01 and separates when they are used:

- Initial setup: Location → Work alerts → permission review.
- Background location: a separate just-in-time entry in the same board, for when work tracking needs it. Use `?permission=background`; the legacy `?step=2` also opens it. `?step=3` / `?permission=notifications` opens Work alerts.
- A native background request requires foreground location first. If missing, the board returns to the location step before continuing background setup.
- Camera and microphone remain contextual to their features; this board does not request them.

This timing follows the current Manifest v6 / UX Master v3.0 instruction to request only necessary initial permissions, and the phase permission-flow guidance to stage background access after foreground access at the appropriate work moment. The older phase text’s automatic pickup/delivery confirmation is superseded by the current explicit-arrival and evidence rules; none is introduced here.

## Honest permission outcomes

Allow advances only after an observed granted result. Denial stays on the permission screen with Open settings and Not now. Dismissing a prompt leaves access unconfirmed. Error and unavailable states have a retry or continue-for-now path. Choosing Not now records a deferred setup choice for this page session; it does not enable access.

The final review distinguishes Enabled, Not enabled, Not now, Not checked and Set up in the app. Rows reopen the relevant explanation. The primary action continues to the existing verification-pending screen, as in the original. `from=profile` returns to Profile with context; `from=home`, or a background-work entry, returns to the corresponding Team/Network Home. There is no generic work-ready claim after skipped permissions.

## Preview and implementation boundary

The standalone review HTML and pack index run in review mode. Clicking Allow opens a clearly labelled **Permission preview** sheet with sample Allow / Don’t allow results. These are review controls, not an imitation of OS chrome, and they do not request device access. Settings preview similarly lets reviewers inspect enabled/denied outcomes.

The individual N01 HTML outside review mode:

- Uses the browser’s location or notification permission mechanism only after the user presses the corresponding action.
- Reads available permission status without requesting a new grant on page load. It does not persist permission grants in local storage.
- Discards any position obtained while requesting location access; it does not store or transmit coordinates. A permission grant does not imply a fresh/accurate GPS fix or verified arrival.
- Does not fake background access. Native integration can supply `window.RoundsPermissionBridge` with `getStatus`, `request` and `openSettings`; without it, background access explains that setup is required in the Rounds app.
- Does not infer that opening settings enabled access. Check again reads the current result. Native settings launch failures retain an explanatory recovery surface.

That bridge is an integration interface, not a completed Flutter plugin. Production permission prompts, platform-specific timing, precise/reduced location, background lifecycle and push delivery need native implementation and device validation. Granting notification permission does not register an FCM/APNs token in this prototype.

Closing or skipping invalidates pending work, so a late callback cannot advance a different permission screen. Modal focus is contained; closing returns focus. A granted location result is not confused with an enabled tracking session.

## Verification

JavaScript syntax, unique IDs, local destinations, exact single-screen change, inventory and ZIP integrity are checked. Node VM scenarios cover preview grant/deny/cancel, skip/review, real-adapter granted/denied/error/unavailable outcomes, settings checks, foreground prerequisites, late callback handling and trusted review routing.

Layout was inspected in source for the fixed palette, type sizes, touch targets, flexible scrolling and safe areas. Browser and physical-phone visual checks remain pending, including native prompts and Thai wrapping. These English HTML boards are design and interaction references, not a production permission implementation.
