# Refresh 21 — Verification submitted

36 of 47 original HTML files refreshed; 11 remain original. This refresh changes A11 only. All 46 other app files, previous review pages, the style guide and shared tokens are preserved. The cumulative pack contains all 47 app files.

## Design

The original confirmation already had the right sequence: submission confirmation, two status facts, one Go to Home action. The refresh preserves it and the original 18:26 example.

The wordmark uses the approved blue with the orange square. Network context grows from 11.5px to 14px. The 44px headline stays large at narrow and short viewport sizes, with a more readable 1.1 line height and approved font weights. The repeated Submitted eyebrow is removed. A restrained green receipt symbol identifies successful submission; it does not mean Network approval.

The two status rows grow from 66px to 88px. Labels grow from 14px to 18px; Received is 20px and the Network access value is 18px. They share the established pale-blue surface and orange rule. Received remains green; In review uses the readable care color rather than bright orange text. The supporting copy is a concise 17px: We’ll notify you of the result. It covers correction requests as well as approval.

Go to Home grows from 60px to 68px and uses the established blue. It is the only resting-state action. Content scrolls independently above the pinned action, with safe-area padding. Short viewports keep text and controls large. No map, bottom navigation or extra task competes with this onboarding confirmation.

## Review states

- Received: Application received / Network access in review. Go to Home opens the approved B02 pending example.
- Offline after receipt: the confirmed submission remains received. A short offline notice appears and the review status requires checking. Go to Home remains usable and opens B02’s offline example.
- Unconfirmed submission: the screen says Check submission, not Verification submitted. Application is Not confirmed and Network access is Not available. Check status opens explicit local result choices; it cannot route into B02’s four-received-check example without a receipt.
- Recheck failed: Couldn’t check keeps the submission unconfirmed and allows another status check.

Reconnection never turns an uncertain submission into a confirmed receipt or a confirmed receipt into approval. After a received example reconnects, Home opens B02’s status-check example rather than asserting a fresh review state. The original received event remains valid. An interrupted status check closes its dialog and moves focus to the visible heading.

## Prototype boundary and navigation

All result choices are labelled sample results. Nothing is uploaded, submitted, stored, approved or published to Network. No timer generates success or changes availability. Production must enter the received view only from a confirmed application receipt and reconcile uncertain submissions before displaying success. No new resubmission action is introduced here.

The review uses the established single-screen wrapper and allowlisted companion navigation from its own iframe. Modal sample choices have labelled dialogs, background inertness, Tab trapping, Escape and return focus.

B02 remains byte-for-byte unchanged. A11’s original 18:26 and B02’s separate 16:03 sample times remain independent design examples; production navigation must carry the real application identity and current state. The connection/status query is preserved when opening B02.

## Validation

Checks cover receipt vs approval wording, correct B02 state routing, offline receipt retention, uncertain submission gating, explicit result choices, failed/interrupted checks, reconnect behavior, modal focus and safe companion routes. Source checks cover original time/status facts, IDs, scripts, links and key text widths at 320/360/393px. All non-target screens and earlier guide/tokens/reviews are byte-compared. The ZIP is checked against the output folder.

Browser/phone visual QA remains unavailable under the earlier security restriction. Font metrics and CSS dimensions are not rendered layout measurements. Phone, Thai, sunlight, glove and native lifecycle validation remain pending. No 10/10 claim.

Sources: original A11 v4 HTML; approved Refresh 20 B02; canonical v42 Driver UX Behavior Master v3.0 (entry/verification and Network availability), Driver Canonical Manifest v6; approved style guide v1.

Next: A12 Verification needs attention, keeping the correction focused on the specific failed evidence.
