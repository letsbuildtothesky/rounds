# Rounds driver — Refresh 04

## Scope
Two screens: F01/F02 delivery handoff and F03/F04 proof of delivery. Both original files were read before editing. This cumulative pack contains all 47 screens: eight refreshed screens, 39 unchanged originals. The previous six refreshed screen files are preserved byte-for-byte from Refresh 03. index.html opens this pair, and pair-01/02/03.html open the previous pairs. Earlier design notes are included in PREVIOUS-DESIGN-NOTES.md.

## Fixed visual system
Blue #1754a6 for navigation, actions and information; pale blue #edf4fd for supporting surfaces; orange #ff6420 for brand and destination accents. Green for ready/complete states, red for problems. Ink #17283f, muted #526278, Arial/Helvetica. These screens retain the approved typography, 52px header controls, compact borders and generous interaction surfaces. No new brand color or generated mockup asset.

## Handoff
- Preserve all three original paths: recipient, someone else, and left at location. Keep “Only when instructed” attached to the unattended option.
- Pale-blue heading, clear location, same orchid/glass-vase package and order #8421. Package title 17px, metadata/handling 14px.
- Full-width choices 104px (96px on shorter displays), titles 20px, supporting labels 15px. Large simple icons and visible arrows.
- Call recipient and Message Ops remain in a pinned footer with 60px controls, with a 52px recipient-unavailable link.
- Call uses the existing contact screen instead of the original hard-coded sample phone number. No call is made automatically.
- The left-location sheet preserves Reception, Lobby / entrance, At the door, and Other approved place. The selected value carries into proof.

## Proof
- Preserve the original required evidence rules: recipient = package + photo + signature (3); someone else = those three + receiver category (4); left at location = package + photo (2). Completion remains disabled until all required evidence is present.
- Keep progress and the 68px completion action visible; evidence content scrolls. A labeled 64×68px Problem control links to the original G03 package-problem flow.
- Package row is at least 100px with a 34px checkbox, 17px title and 14px metadata. The entire row toggles. Confirmed state is pale blue with an explicit check.
- Delivery photo opens the browser/device file or camera chooser only when tapped. Capture surface is at least 196–212px. After a successful image decode, show the user's image with a 52px Retake control. No stock or generated proof is used.
- A cancelled retake keeps the previous photo. An unsupported image shows an inline error and keeps the previous photo. Replaced object URLs are released. Images stay in page memory; this prototype uploads nothing.
- Signature moves from the original cramped inline canvas to a dedicated 220–360px signing pad. Clear and Use signature are 64px controls. No signature is counted until a visible stroke is explicitly accepted. Tapping without drawing does not count.
- Strokes are kept as normalized vectors and redrawn after resizing, preserving visible ink. Opening an accepted signature makes an editable draft; closing/cancelling retains the accepted signature. Use signature commits a thumbnail and updates progress.
- For someone else, selecting a receiver is required before opening the signing pad. Changing the receiver invalidates the prior signature so it cannot be attributed to a new person.
- Existing receiver categories retained. No new ID/name requirement invented.
- Remove the original unsupported “GPS + time: Automatic” and “Proof saved” claims: this prototype does not collect GPS or save a backend delivery record.
- All modal sheets move focus inside, trap Tab navigation, support Escape/backdrop close, and restore focus to the initiating control.

## Review files and actual flow
Standalone HTML shows the two boards together. Choosing a handoff on the left updates proof on the right, including its required evidence count; the three proof tabs also expose these states. Changing a review state resets that proof page and its local evidence. This is a deliberate review control outside the driver UI.

Standalone completion shows a clearly labeled prototype completion state. The ZIP review also offers the link to the existing F08 next-stop screen. Opening the screen files directly uses the normal F01/F02 → F03/F04 → F08 flow, preserving query parameters and existing destinations. The legacy F08 and issue/contact screens have not been redesigned in this batch.

## Validation and limits
JavaScript syntax, three evidence gates, handoff query propagation, cancelled/error photo replacement, accepted-signature handling, resize redraw, receiver/signature dependency, modal behavior, relative links, unchanged-screen scope and ZIP integrity are checked using source/logic tests. Full HTML browser rendering is still blocked in this environment. Real phone camera behavior, touchscreen signing, outdoor contrast, glove use and long Thai strings remain to be visually/device tested. No production readiness or 10/10 claim.

## Next pair
F08 stop complete / next stop and I01 round complete, to finish the main delivery journey before returning to exception and shift states.
