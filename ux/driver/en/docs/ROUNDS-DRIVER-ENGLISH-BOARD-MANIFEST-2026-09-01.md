# Rounds Driver App · English Board Manifest

**Date:** 2026-09-01  
**Status:** English board set frozen before Thai board pass  
**HTML board files:** 47

## Language architecture

- `A01` Splash hands first-run users to `A01B` Choose Language.
- `A01B` offers **English** and **ไทย** as the app-level language choice.
- The choice is stored as `rounds.language` and is inherited by onboarding rather than repeated as a per-screen toggle.
- `L01` Profile keeps the real **Language** setting so the preference can be changed later.
- `A02–A05` no longer shows the old EN/ไทย switch in each onboarding header.
- This package is the **English board set**. The Thai board pass must preserve the same screen IDs, behavior, actions, and operational truth one-to-one.

## Canonical boards

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
