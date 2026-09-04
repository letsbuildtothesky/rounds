# Rounds Driver App — Canonical Screen Manifest v6

**Date:** 2026-09-01  
**Status:** Canonical Driver App V1 board set after Operations parity refinement  
**Canonical English UX source:** `ux/driver/en/screens/`
**Canonical Thai UX source:** `ux/driver/th/`
**HTML board files:** 47

## 1. Production localization rule

The production Driver product is **one localized app**. English and Thai are not separate products or separate codebases.

First run:

`A01 Splash → A01B Choose Language → A02–A05 Entry Flow`

Later change:

`L01 Profile → Language → ไทย / English`

Locked behavior:

- Thailand is Thai-first (`th-TH` primary product locale).
- English remains first-class and selectable.
- The language choice is app-level and is not repeated in individual onboarding headers.
- Thai and English use the same screen IDs, state machine, commands, evidence requirements, permissions and role rules.
- Thai boards are translation/layout-QA artifacts; they do not create a second canonical behavior set.
- Production uses localization keys and a single implementation.
- Thai QA checks natural line height/wrapping, hierarchy, touch targets, date/time formatting and 320 px behavior.

## 2. Locked shell / visual rules

- App icon: navy R tile + orange dot; phone/app icon only.
- In-app branding: `Rounds.` wordmark where branding is useful; road/task screens prioritize functional navigation chrome.
- One obvious job per screen.
- Driving surfaces are road instruments, not dashboards.
- Critical text/actions remain 13 px+; metadata alone may go smaller.
- Navy/orange semantic system remains restrained; orange is action/attention, not decoration.
- No decorative prototype state switchers in production.
- Camera/microphone permissions are contextual; initial setup requests only what is needed to become operational.

## 3. Canonical boards

| ID | Screen | File |
|---|---|---|
| A01 | Splash | `ROUNDS-A01-SPLASH-LIGHT-v5.html` |
| A01B | Choose Language | `ROUNDS-A01B-CHOOSE-LANGUAGE-v1-10OF10.html` |
| A02–A05 | Phone / OTP / Driver path / Team invite | `ROUNDS-A02-A05-DRIVER-ENTRY-FLOW-v6-10OF10.html` |
| A06 | Team About You | `ROUNDS-A06-ABOUT-YOU-v3-10OF10.html` |
| A06B | Independent About You | `ROUNDS-A06B-INDEPENDENT-ABOUT-YOU-v3-10OF10.html` |
| A07 | Your Vehicle | `ROUNDS-A07-YOUR-VEHICLE-v4-10OF10.html` |
| A08 | Verify Identity | `ROUNDS-A08-VERIFY-IDENTITY-v3-10OF10.html` |
| A09 | Live Face Check | `ROUNDS-A09-LIVE-FACE-CHECK-v5-10OF10.html` |
| A10 | Get Paid | `ROUNDS-A10-GET-PAID-v4-10OF10.html` |
| A11 | Verification Submitted | `ROUNDS-A11-VERIFICATION-SUBMITTED-v4-10OF10.html` |
| A12 | Verification Needs Attention | `ROUNDS-A12-VERIFICATION-NEEDS-ATTENTION-v1-10OF10.html` |
| B00 | Start Shift | `ROUNDS-B00-START-SHIFT-v1-10OF10.html` |
| B01 | Team Driver Home | `ROUNDS-B01-TEAM-DRIVER-HOME-v4-10OF10.html` |
| B01B | Team Home · Round Assigned | `ROUNDS-B01B-TEAM-HOME-ROUND-ASSIGNED-v3-10OF10.html` |
| B01C | Shift Ended · Switch to Network | `ROUNDS-B01C-SHIFT-ENDED-SWITCH-TO-NETWORK-v2-10OF10.html` |
| B01D | Shift Ending Soon | `ROUNDS-B01D-SHIFT-ENDING-SOON-v3-10OF10.html` |
| B01E | Shift Overtime | `ROUNDS-B01E-SHIFT-OVERTIME-v3-10OF10.html` |
| B01F | End Shift Confirmation | `ROUNDS-B01F-END-SHIFT-CONFIRM-v2-10OF10.html` |
| B02 | Verification Pending Home | `ROUNDS-B02-HOME-VERIFICATION-PENDING-v5-10OF10.html` |
| B03 | Network Home / all availability states | `ROUNDS-B03-HOME-NETWORK-AVAILABLE-v8-10OF10.html` |
| C01 | Single Delivery Offer | `ROUNDS-C01-SINGLE-DELIVERY-OFFER-v4-10OF10.html` |
| C03 | Multistop Offer | `ROUNDS-C03-MULTISTOP-OFFER-v5-10OF10.html` |
| D01 | Navigate to Pickup | `ROUNDS-D01-NAVIGATE-TO-PICKUP-v5-10OF10.html` |
| D03/D04 | Pickup Confirmation | `ROUNDS-D03-D04-PICKUP-CONFIRM-v6-10OF10.html` |
| E01 | Active Round Overview | `ROUNDS-E01-ACTIVE-ROUND-OVERVIEW-v5-10OF10.html` |
| E02 | Navigate to Current Stop | `ROUNDS-E02-NAVIGATE-TO-CURRENT-STOP-v2-10OF10.html` |
| E04/E05/E06 | Live Round Change | `ROUNDS-E04-E05-E06-LIVE-ROUND-CHANGE-v3-10OF10.html` |
| F01/F02 | Dropoff Handoff | `ROUNDS-F01-F02-DROPOFF-HANDOFF-v3-10OF10.html` |
| F03/F04 | Proof of Delivery | `ROUNDS-F03-F04-PROOF-OF-DELIVERY-v6-10OF10.html` |
| F08 | Stop Complete / Next Stop | `ROUNDS-F08-STOP-COMPLETE-NEXT-STOP-v4-10OF10.html` |
| G01 | Recipient Unavailable | `ROUNDS-G01-RECIPIENT-UNAVAILABLE-v2-10OF10.html` |
| G02 | Address / Pin / Entrance Problem | `ROUNDS-G02-ADDRESS-PROBLEM-v2-10OF10.html` |
| G03 | Package Problem | `ROUNDS-G03-PACKAGE-PROBLEM-v3-10OF10.html` |
| G04 | Cannot Complete Delivery | `ROUNDS-G04-CANNOT-COMPLETE-DELIVERY-v2-10OF10.html` |
| G05 | Driver Emergency | `ROUNDS-G05-DRIVER-EMERGENCY-v2-10OF10.html` |
| H01 | Operations Chat | `ROUNDS-H01-OPERATOR-CHAT-v4-10OF10.html` |
| H02 | Call / Contact | `ROUNDS-H02-CALL-CONTACT-v2-10OF10.html` |
| H03 | Contact History | `ROUNDS-H03-CONTACT-HISTORY-v2-10OF10.html` |
| I01 | Round Complete | `ROUNDS-I01-ROUND-COMPLETE-v3-10OF10.html` |
| J01 | My Rounds | `ROUNDS-J01-MY-ROUNDS-v7-10OF10.html` |
| K00 | Team Hours + missed clock-out correction | `ROUNDS-K00-TEAM-HOURS-v5-10OF10.html` |
| K01 | Network Earnings | `ROUNDS-K01-EARNINGS-v3-10OF10.html` |
| L01 | Driver Profile + Language setting | `ROUNDS-L01-DRIVER-PROFILE-v3-10OF10.html` |
| M01 | Notifications | `ROUNDS-M01-NOTIFICATIONS-v2-10OF10.html` |
| N01 | Permissions | `ROUNDS-N01-PERMISSIONS-v3-10OF10.html` |
| N02 | Offline / Reconnecting | `ROUNDS-N02-OFFLINE-RECONNECTING-v1-10OF10.html` |
| N03 | GPS Unavailable | `ROUNDS-N03-GPS-UNAVAILABLE-v3-10OF10.html` |

## 4. Final product closure

The 47-screen set closes the Driver App V1 product-design library. New screens should be driven by implementation/field findings, not speculative completeness.

The final returned board set adds/locks the previously missing product states:

- first-run language selection;
- verification correction;
- start shift, ending soon, overtime and end-shift confirmation;
- Network availability states;
- Team Hours / missed clock-out correction;
- offline/reconnecting;
- GPS unavailable;
- final physical manifest pickup/handoff/POD parity;
- rich Operations communication/contact history;
- live delivery/Round change acknowledgement and Network add-stop consent.

## 5. Navigation implementation boundary

D01 and E02 are the canonical **product UX intent**, not the final map/navigation vendor implementation. Production navigation follows Engineering Architecture v1.1 and the Phase 0 field gate:

- embedded Google Navigation SDK is selected for Driver V1 subject to field validation;
- `TWO_WHEELER` is the selected Thailand motorcycle mode subject to field validation;
- Rounds chrome must coexist with Google safety/navigation UI;
- planned route, active navigation leg and actual trail are separate truths;
- if the Flutter plugin is the blocker but the native SDK works, keep Flutter and use a thin Swift/Kotlin bridge.

## 6. Canonical source precedence

When sources conflict:

1. newest product/business specs;
2. this v6 Driver Manifest + Driver UX Behavior Master v3.0 + Driver UI Constitution v1.1;
3. current 47-screen English board set for layout/interaction demonstration;
4. Thai board set mirrors the same behavior one-to-one;
5. older Driver boards/spec versions are historical only.
