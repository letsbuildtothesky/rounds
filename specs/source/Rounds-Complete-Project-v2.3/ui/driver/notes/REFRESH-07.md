# Rounds driver — Refresh 07

## Scope
Continue with G03 Package problem and G04 Cannot complete delivery after reading both originals and the fixed style guide. All 45 other screen files, all map imagery and markers, the style guide and design tokens are byte-identical to Refresh 06. The cumulative pack contains 47 screens, including 14 refreshed screens and 33 untouched originals. Earlier review pairs and notes are preserved.

The shared marker refinement is deferred at the user's request. Do not implement it while continuing these pairs.

## Visual consistency
Use the approved blue/orange palette and contextual header. Keep 52px header controls, 64px primary actions, 60px contacts, 68px sheet rows, 88px problem choices and the 212px evidence-photo area. Important text is 16–20px; main headings 30px (28px on narrow widths). Scroll content independently of the footer. Sheets scroll and support focus, Escape and an inert background. No new brand colors, typography, generated images, card decoration or map redesign.

## G03 — Package problem
- Preserve all three cases: damaged, missing and wrong package.
- Expected package remains Midnight Orchid + glass vase, #8421, one fragile package. Avoid claiming a missing package is still physically with the driver or displaying an unconditional green custody check.
- Damage requires a damage photo; wrong package requires a label photo. Missing package needs no photo. Details are optional. The Request instructions action stays disabled until required evidence is actually decoded and available.
- The photo surface launches the native chooser/camera only when tapped. Validate image type and successful decoding. Cancellation or a failed retake preserves the existing good photo. Release obsolete object URLs. Discard stale decoding callbacks when the issue changes.
- Evidence photos are real user-selected files; no fabricated sample image or fake `photo=1` readiness. The outer Waiting review tab uses the missing-package example so it does not imply an unseen evidence photo.
- Request instructions models an Operations request. Waiting retains contact actions and report review. No timer auto-approves, and no backend request or upload occurs.
- Explicit decision fixture: damaged/wrong packages are not delivered and are returned after the remaining stops. A missing package is arranged by Operations while the driver keeps the other packages. Stop 1 remains incomplete in every decision case.

## G04 — Cannot complete delivery
- Preserve no access, refused delivery, closed location and other reason. Require a short explanation for Other so it is usable; details for named reasons remain optional.
- No access and location closed offer Call recipient first, with a reachable Request instructions alternative. Refused/other go directly to Request instructions. Contacts remain available through the footer or More menu.
- Calling and recording the outcome are distinct actions. The contact sheet links to H02 with the correct `contact=recipient` parameter. Explicit outcomes preserve Issue resolved, Reached/still blocked and No answer. Merely opening the contact link does not record a call.
- Call outcomes use the actual local timestamp. Unresolved outcomes promote the Operations request. Issue resolved exposes Continue to handoff without timed navigation or marking anything delivered.
- Retain reason, note and contact history in the waiting report. Operations and recipient contact remain available while waiting. A return decision is an explicit review state rather than automatic success.
- Return this package: continue the round, then return #8421 to UrbanFlowers after remaining stops. The stop is explicitly incomplete.

## Next-stop action
The original Continue Round link opened E01, which is a fixed Stop 1 sample and does not apply a skipped-stop update. These two screens instead open a small next-delivery sheet: Stop 1 remains incomplete, Stop 2 is James T. at The Sukhothai Residences/Sathorn with one Signature hamper, and the return obligation is retained where relevant. Navigate to Stop 2 uses the same Google Maps destination already verified against the supplied sample in Refresh 05 (`13.7204,100.5332`). No new map, route estimate or marker is introduced. Production route mutation and adding a formal return stop remain integration work.

## Local drafts and offline behavior
Drafts use browser IndexedDB, including the selected photo Blob for G03 and the reason/note/call ledger for G04. Writes are queued in order and acknowledged only when the transaction completes. Existing drafts restore on regular screen pages; review states use separate storage keys and reset their own display. Read errors do not block the screen; write failures show a direct keep-screen-open message.

Offline submission does not claim to send. It shows a saved draft only after a successful local write, or otherwise tells the driver to keep the screen open. Retry is explicit. There is no automatic transmission, reconnection approval, background sync, delivery completion or package-custody backend mutation. Browser-local storage is a prototype aid, not the production offline queue.

## Review and navigation
Standalone HTML contains both screens and local interactions. Tabs cover Start / Photo or Reason / Waiting / Decision. The ZIP's local screen pages additionally support `?offline=1`, `?state=offline`, `?issue=missing`, `?issue=wrong`, and the original resolved-state alias. The standalone page intercepts links to companion HTML and directs the reviewer outside the phone to open the ZIP for that flow. External Google Maps navigation stays a normal user-opened link. Calls and Operations chat use the legacy H02/H01 prototypes; nothing is sent via a tool.

## Validation
Source and logic checks cover photo requirements, decode failure/cancellation/retakes, missing-package handling, reason branches, Other validation, explicit call outcomes, waiting contacts, decision states, offline/storage failure behavior, draft records, modal focus, review switches and navigation targets. HTML IDs and script syntax, earlier-screen identity, the 47-screen inventory and ZIP integrity are verified. Full browser/device rendering remains unavailable after the earlier browser security block. Phone layout, text scaling, camera permissions and storage behavior on target devices still require device review.

## Next pair
G05 Driver emergency and H01 Operations chat. Compare originals first; retain the fixed visual system and leave map markers deferred.
