# Refresh 22 — Verification correction and identity documents

38 of 47 original app files refreshed; 9 remain original. This pair updates A12 and A08. All 45 other app files, earlier review pages, style guide and shared tokens remain unchanged. The ZIP contains the complete 47-file app set.

## Design

A12 preserves a focused correction: Driver’s license, Thai ID or live face check. The large headline names the action and the requested evidence stays prominent. The separate 68px warning ornament is replaced by the established orange-edged, pale-orange heading surface, giving the correction more room. The replacement photo area increases from 176px to 224px, document name from 13.5px to 22px, and Replace photo from 42px to 60px. Resubmit verification is 68px. Other details stay saved remains visible until submission.

A08 keeps Thai ID and Driver’s license as two separate required documents. The heading retains 44px, labels increase from 17px to 22px, capture areas from 158px to 176px, and photo actions become 18px. Replace photo is a separate 60px full-width control, replacing the 34px overlay. Continue is genuinely disabled until both photos decode successfully and the connection is available. A 16px count shows progress.

Both carry the agreed blue wordmark/orange square, 14px Network context, 17px supporting copy, spacious insets and pinned 68px primary action. Short screens scroll content without shrinking text or photo targets. All photo previews use contain-fit; none crop document edges. A large photo-review dialog allows closer inspection. There are no real identity images in the deliverables: review examples are labelled Sample photo / No document data.

## Photo interactions

Native photo selection is explicit. Selected images remain only in the page’s memory. Image decoding must succeed before a photo counts as Added. A cancelled or invalid replacement retains the previous image. Late decode callbacks cannot replace a newer selection. Object URLs are released on replacement and page exit. Unsupported/non-image inputs produce an inline error. No image is uploaded, stored or verified by this prototype.

The image area opens photo review after a photo is added. Replace photo remains separate and large. A08’s Back action asks before leaving selected photos; Continue opens the existing A09 sample after both photos are ready. The next page is a separate fixture; this prototype does not transfer the selected bytes across pages. Production must retain evidence securely through the actual onboarding flow.

## Correction behavior

A12 retains `?issue=license`, `?issue=id` and `?issue=face`. Only the requested evidence is replaced. A valid replacement enables resubmission. The labelled Submission preview lets reviewers choose Received, Not sent or Unconfirmed without pretending to submit personal documents.

Received shows Correction submitted with Network access In review; Home opens B02 pending. Not sent preserves the new photo for another attempt. An uncertain outcome locks editing and requires a status check before resubmission. Reconnection never automatically submits or confirms a correction. Offline capture remains possible but submission is disabled. After an acknowledged correction reconnects, Home opens B02’s status-check state; offline Home opens its offline state.

The existing A09 ignores its old `return=A12` query and continues to payout. A12’s face correction therefore uses a clearly labelled local Face check preview and returns to correction resubmission, avoiding that incorrect handoff. It does not open a gallery, claim liveness verification or capture a real face. A09 is still the original file and is recommended next; production needs the real live-capture return contract. The original license/ID correction paths are functional local photo previews.

No service, GPS, message, call, storage or approval operation occurs. Production needs authoritative correction outcomes, safe evidence handling, liveness validation for face checks and reconciliation after uncertain submission results. The sample choices are review controls, not a production confirmation sequence.

## Validation

Checks cover both required documents, successful decoding, cancellation and invalid replacements, late-image callbacks, URL cleanup, exact correction scope, submission/unknown/offline states, preserved photos on retry, correct B02 state routes, explicit face preview, modal focus and review route allowlisting. Source checks cover IDs, scripts, local routes, original labels/times, type/touch sizes, unchanged prior files and ZIP integrity. Font metrics check key labels at 320/360/393px.

Browser/device visual QA remains unavailable under the earlier security restriction. Source and font checks do not establish phone, camera, Thai, daylight or glove performance. No 10/10 or production-readiness claim.

Sources: original A12 v1 and A08 v3; A09 v5 return behavior; approved Refresh 20 B02 and Refresh 21 A11; canonical v42 Driver UX Behavior Master v3.0 entry/verification rules and Driver UI Constitution v1.1; unchanged style guide v1.

Next pair: A09 Live face check and A10 Get paid.
