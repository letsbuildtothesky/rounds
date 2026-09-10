# Refresh 25 — Your vehicle: Team and Network

43 of 47 original app files refreshed; 4 remain original. This review shows the two role variants of A07, so it refreshes one additional canonical app file. N01 receives one targeted Team onboarding destination fix; its visual design is unchanged. All other 45 app files, earlier review pages, the shared tokens and style guide remain unchanged. The ZIP contains the complete 47-file app set, including the approved face-check motion.

## Design

All five original choices and their descriptions remain: Motorbike + box / Standard delivery setup; Tuk-tuk / City cargo and medium loads; Car / Sedan or SUV; Pickup / Open-bed cargo capacity; Van / Large deliveries. The choices are visible in a vertical list rather than hidden behind a new picker. Rows increase from 70px to at least 92px, titles from 17px to 20px, supporting descriptions from 12.5px to 14px and icon artwork uses a consistent 40px viewport (36px on narrow rows). Text wraps and rows grow when needed.

The vehicle icons were refined after the initial Refresh 25: all five now face right in side view, share a 32-unit grid and 1.75-unit stroke, and have consistent wheel proportions. The bike has its box over the rear wheel, the tuk-tuk has an open canopy, Car has a lower roof, Pickup an open bed, and Van a taller continuous body. The symbols use crisp inline SVG with no new decorative badges. Reusable SVGs are included in `assets/vehicle-icons/`. The selection-row geometry, copy and behavior stay as approved.

Selection uses the established pale-blue surface, a narrow orange edge and a blue radio indicator. The entire row is a target. The 44px heading and role/merchant context match the recent onboarding pages. The plate field grows from 61px to 72px, with an 18px label and 26px entry text. Continue is a pinned 68px action and Back is 52px.

The original short-height styles shrank rows to 56px and descriptions to 11.2px. This refresh keeps the large controls and text, with content scrolling to the plate field as needed. It adds no repeated instructions or extra form sections. The original 17:46 example clock remains in both role variants.

## Behavior

One vehicle can be selected. The selector exposes native button radio semantics and supports arrows, Home and End with a single tab stop. Switching vehicle type preserves the entered plate so a classification correction does not erase it. No type is preselected in the actual entry state. The Network review board initially shows a clearly labelled Ready design sample; its Start control opens the empty state.

Continue requires a selected vehicle, at least three trimmed plate characters (the original rule) and a connection. The original 12-character maximum remains. Plate input accepts Thai and Latin characters, uses uppercase presentation and does not rewrite text during composition. These local checks do not validate registration or plate ownership. Short input receives an inline error after leaving the field. Enter during composition does not advance the form.

Offline preserves the selected type and entered plate. Reconnection enables the next action when appropriate but never navigates automatically. Back warns before discarding an edited local sample and returns to A06 for Team or A06B for Network. No saved toast or timer-based save claim is shown. Vehicle and registration details remain in this page’s memory; production must retain and validate the actual onboarding draft.

Team continues to N01 with `context=team&from=onboarding`; Network continues to A08 identity documents. N01 previously sent its default entry to the Network verification-pending screen even for Team setup. The explicit Team onboarding entry now finishes at B00, before a shift begins. Existing N01 Profile, Home, background-permission and Network/default return routes keep their prior behavior. No shift is automatically started and no Network availability is enabled.

## Catalogue follow-up

The canonical September 1 A07 English board has the five choices preserved here. The older `MASTER-v1.6-LIVE-CHANGE-ACK.md` has a seven-value vehicle enum (separate motorbike, sedan/SUV and box truck, with no Tuk-tuk). This mismatch needs reconciliation when the specs are consolidated. This design refresh follows the later canonical board and does not silently remove Tuk-tuk, split Car or add an unsupported eligibility promise.

## Validation

Interaction checks cover all choices, single selection, keyboard movement, plate gating, composition, retained input, offline/reconnect, leave confirmation and role-specific onward/back navigation. The N01 target expression is checked for Team onboarding and unchanged existing entry contexts. Static checks cover all five original labels/descriptions, valid consistent replacement SVGs, IDs, scripts, links, text/control sizes, 320/360/393px key label widths, original clock, changed-file scope, unchanged prior designs, all 47 filenames and ZIP integrity.

The isolated vector icons were rasterized and visually inspected at actual and enlarged sizes; this is not browser or phone UI validation. Browser/device visual QA remains unavailable under the earlier security restriction. Source/DOM/font checks do not establish actual phone rendering, Thai line wrapping, keyboard viewport behavior, touch accuracy or glove/daylight performance.

Sources: original A07 v4; approved Refresh 23/24 onboarding; N01 permissions and B00 shift-entry flow; canonical v42 Driver UX Behavior Master v3.0 and Driver Canonical Manifest v6; unchanged style guide v1.

Remaining original files: A01 Splash, A01B Choose language, combined A02–A05 entry flow and combined E04–E06 live Round changes. Suggested next pair: A01 and A01B.
