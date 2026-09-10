# Refresh 23 — Live face check and payout setup

40 of 47 original app files refreshed; 7 remain original. This pair refreshes A09 and A10. A12 receives only the face-check return wiring described below. The other 44 app files, previous review pages, style guide and shared tokens are unchanged. The complete 47-file app set remains in the ZIP.

## Design decisions

A09 keeps a 465px camera area at every viewport height, matching the original full-size capture area. Short screens scroll rather than shrink it. The live feed is mirrored for positioning; the captured image shows the full frame with contain-fit so the review does not crop the face. The capture guide stays static during camera positioning. On request, the separate motion preview shows a thin orange line within the oval for a 5.2-second down-and-back pass, then a green completion state. This demonstrates the checking/result design; it is not a liveness result. Capture stays explicit. Clear camera-off, permission, unavailable and captured states explain the immediate action. Start / Take photo / Use photo remains a pinned 68px primary; Retake becomes a separate 60px full-width control. The original 44px heading remains; camera instructions and status are 17px rather than tiny overlay text.

A10 gives each payout method a 92px selection row, 20px name, 14px supporting text and a clear blue radio indicator. Phone/ID and bank-account fields are 60px tall with 17px labels and 18px input text. The QR entry control is 76px tall; its image preview is 252px with contain-fit. Original methods and all six bank choices are retained. A saved method has a clear masked summary and a large Edit payout method action. The footer is a pinned 68px action. No task controls or text shrink on short screens.

Both use the approved blue wordmark, orange square, established blue primary action, restrained orange accent and generous white space. Back and modal close targets remain 52px. Headers retain the original sample clocks: A09 18:03 and A10 18:18. These are separate design examples, not a connected verified activity timeline. The orange scanning line is the user-approved motion polish added after Refresh 23; the existing color tokens, layout dimensions and style guide file remain unchanged.

## Face interactions and correction handoff

Camera permission is requested only after the driver presses Start face check. The preview uses the device camera when permitted by its browser, context and iframe policy. No gallery fallback is allowed for the live-face step. Taking a photo requires a ready video frame and explicit action. Retake opens the camera again. Camera streams stop after capture, when leaving, when the page is hidden, or when the track ends. A permission response or capture callback that arrives after leaving cannot restart or replace the current state. Local captured image URLs are released on replacement and non-cached page exit.

This HTML only captures a local photo; it does not implement liveness or face verification. Use photo opens a labelled Capture preview, with Preview scanning motion and Continue sample actions. The review board also has Scan motion and Complete states. The motion preview uses an explicitly labelled sample timer; production must start/stop the animation from the actual check lifecycle and return its authoritative result. No success timer runs during ordinary camera positioning or capture. Leaving/backgrounding the preview cancels the demonstration and stops its completion callback. Reduced-motion users see a static orange line with the same checking/result labels. No selected bytes cross into another page and no evidence is uploaded.

A12 Start face check now opens A09 with `?return=A12`. A09 Back returns to A12’s face correction; its accepted design handoff returns to `A12?issue=face&sample=face-captured`, where the already-approved correction design shows Sample capture added and enables the existing sample resubmission flow. The explicit sample flag never stands for real evidence or a liveness result. The obsolete local face-completion chooser is removed from A12. Its license and ID paths and visual design remain unchanged. Normal A09 onboarding continues to A10.

Production needs a native/service-backed live-face flow that securely returns the actual requested evidence reference to A12. It must not use a query flag as evidence. Existing A08, A09, A10 and A11 page navigation remains navigation between independent design samples, not a production evidence/submission pipeline.

## Payout interactions

The method selector supports pointer, keyboard arrows, Home and End. Inputs have real disabled-save behavior until the selected method has numeric content (and a bank selection where needed). Local checks only distinguish missing/nonnumeric content; they do not validate account length, identifier type, ownership, checksum, bank availability or payment eligibility. The prototype adds no invented financial acceptance rules.

A QR image must decode before Use QR image becomes available. It is an image preview, not a parsed/validated PromptPay QR. A cancelled or invalid replacement retains the previous QR. Pending callbacks cannot overwrite a newer selection or a closed dialog. QR URLs are local memory only; no payout details or images are sent or stored.

Save opens an explicitly labelled sample-outcome chooser. Accepted and saved, Not saved and Unconfirmed can be reviewed without pretending to call a provider. A decoded image or filled input alone never produces Saved. Failure retains the details for correction. Unconfirmed hides editing and offers Check status, with no automatic retry, timer-based success or automatic continuation. Cancel leaves the current state intact. Offline blocks save/status/continue; reconnection does not save or resolve anything by itself. A saved sample continues to the existing A11 submission example. Back warns before leaving unsaved/uncertain local work; page reload and cross-page return require fresh authoritative reconciliation in production.

The QR path still needs actual QR parsing, supported-format checking, recipient confirmation and authoritative payout verification. Bank/PromptPay identifiers require authoritative validation before production save. Unknown save results must be reconciled before a duplicate mutation, including after re-entry. The sample result selectors are design-review controls, not production dialogs.

## Validation and limits

DOM interaction checks cover scan replay, completion, cancellation, backgrounding, no automatic scan during capture, explicit camera permission/capture, denied/unavailable access, zero-frame gating, stream cleanup, delayed permission/capture races, correction return routes, numeric presence gates, method selection, QR decoding/cancellation/replacement, masked summaries, failed/unknown/offline states, modal focus and review navigation. Static checks cover IDs, scripts, linked filenames, the 47-file manifest, exact changed-file scope, unchanged previous files/tokens, original clocks, control dimensions, key text widths and ZIP integrity.

Browser visual/device QA remains unavailable under the earlier security restriction. DOM/source/font checks do not establish phone rendering, camera hardware, secure-context permission, Thai text, daylight or glove usability. No 10/10 or production-readiness claim.

Sources: original A09 v5 and A10 v4; approved A08/A12 Refresh 22 and A11 Refresh 21; canonical v42 Driver UX Behavior Master v3.0 and Driver UI Constitution v1.1; unchanged style guide v1.

Remaining original files: A01, A01B, combined A02–A05, A06, A06B, A07 and combined E04–E06. Suggested next pair: A06 Team details and A06B Independent details.
