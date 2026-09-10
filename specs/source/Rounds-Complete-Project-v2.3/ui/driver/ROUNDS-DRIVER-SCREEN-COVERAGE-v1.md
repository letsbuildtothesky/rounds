# Rounds Driver — Screen coverage and follow-up backlog

**Checked:** 7 September 2026  
**Design baseline:** Refresh 10 cumulative pack  
**Specification baseline:** `ROUNDS-ALL-SPECS-COMPLETE-2026-09-01-v42.zip`  
**Status:** Review findings and proposed design work; no new screen IDs approved or added.

## Where we are

The current pack contains **47 app HTML files: 20 refreshed and 27 still original**. All 47 filenames match Canonical Driver Manifest v6. Pair review pages, the index and the style guide are supporting files, not additional app screens.

The specifications already recognize this same 47-board set as the V1 baseline. Manifest v6 recommends adding screens when implementation or field evidence establishes a need. The older working screen library has different IDs and more individual steps; its absent IDs are not automatically gaps in the current app.

**47 files does not mean 47 visible states.** For example, A02–A05 contains several onboarding steps, and E04–E06 contains delivery updates and Network scope-change consent. We can expand state coverage without adding a new page or another tap to the normal delivery flow.

Recommendation: retain the 47-board baseline, continue the refresh two boards at a time, and track the findings below against their existing flow. Add a separate board only when the driver has a distinct task that needs its own space. The eventual number may exceed 47; the evidence does not yet support a specific final count.

## Follow-up backlog

“Missing” below means the relevant state or continuation was not found in the inspected HTML. It does not mean the product specification omitted the requirement. These are proposed treatments, not changes to the controlling specs.

| Ref | Finding in current HTML | Proposed design treatment | Source / priority |
|---|---|---|---|
| COV-01 | C01/C03 show the offer and accept/decline actions, but do not demonstrate an acceptance result, another driver winning, expiry or merchant withdrawal. | Add accepting, accepted, already taken, expired and withdrawn states to C01/C03. An unavailable offer must close clearly and leave the driver available; successful acceptance leads to pickup. No mandatory offer-detail page. | S4 §§11, 37. Close when refreshing offers. |
| COV-02 | H02 demonstrates outgoing calls and manually recorded outcomes. Incoming Operations calls are absent. | Extend H02 with an incoming-call state: clear caller and Round context, large Answer/Decline actions, then the existing active-call layout. Retain missed/declined outcomes in H03. Native call behavior needs implementation validation. | S3, Weather + Dispatcher Communication addendum. Follow-up to refreshed H02/H03. |
| COV-03 | F03/F04 demonstrates evidence capture and prototype completion. N02 has offline/reconnecting/synced fixtures, but its retry path changes to “synced” after a timer when the browser reports online. There is no demonstrated proof-upload failure/retry path tied to confirmed storage. | Show proof saved on device, upload pending, upload failed/retry and server-confirmed completion across F03/F04, F08 and N02. Keep the driver’s next task prominent. A connection returning must not itself mean proof was received. | S3, Handoff/POD and System states sections: `delivered_pending_evidence` until required bytes are durable. Required before implementation handoff. |
| COV-04 | D03/D04’s Pickup problem sheet offers missing/wrong/damaged package and Operations contact. It lacks a structured pickup-not-ready / merchant-delay state. | Add “Pickup not ready” to the existing pickup issue path, with a clear waiting status and an Operations-directed next step. Do not force the driver to invent the situation in chat or confirm custody early. | S4 §31. Follow-up to refreshed pickup board. |
| COV-05 | G04 already shows an Operations instruction to return a package after the remaining stops, and a next-stop sheet. It does not demonstrate the later return leg and package return completion. Merchant cancellation is also not demonstrated as a distinct state in the inspected offer/live-change paths. | Map cancellation before acceptance, after acceptance and after pickup to the appropriate existing flow. Design the continuation from a return instruction through navigation and custody handback. Reuse navigation and verification patterns; a dedicated return/transfer board is a candidate if the full task needs space. Policy must determine the approved disposition and evidence. | S4 §§32, 34–38. Complete the exception journey before adding a new ID. |
| COV-06 | L01 includes known-merchant contact opt-in; M01 includes an availability request with a response sheet. H01 is a job-linked Operations thread. A separate pre-job merchant conversation is not demonstrated. | Availability requests already have a home in M01. If enabled for V1, add the permitted merchant conversation as a clearly separate H01 context and a suitable entry point. Preserve the distinction from a delivery thread. Unknown merchants do not gain casual chat access. | S3, Network contact addendum; S5 §§5–7. Conditional conversation variant; not an automatic new inbox. |
| COV-07 | E04–E06 already shows the material entrance change and accept/decline of an added Network stop. Its local acknowledgement does not demonstrate delivery pending, retry or a newer change superseding the one being reviewed. M01 routes sample notifications directly to their target board. | Add acknowledgement pending/retry and current-version handling to E04–E06. Notification opening must resolve the current job/change before enabling actions. Keep explicit scope consent and preserve the original accepted work when an addition is declined. | S3, Live Route / Destination Updates addendum; S6 §8. Extend existing states; do not add an acknowledgement checklist to every stop. |
| COV-08 | F08 prioritizes the next delivery; no post-POD vehicle-stop / entrance / handoff observation is demonstrated. | Where operationally useful, offer a brief, optional observation sheet after handoff. Save it as an observation for review, not an automatic permanent pin correction. Decide timing and necessity from field use. | S3, Confirmation after success; S7, location knowledge. Conditional follow-up; map-marker redesign remains deferred. |

### One existing interaction also needs a manifest check

D03/D04 currently gives the two floral arrangements separate “1 of 2” and “2 of 2” verification controls. S3 says one manifest line with expected quantity two is one verification decision. If these are two separately identified physical manifest lines, separate controls can be appropriate. If the source is one line with quantity two, show that quantity and verify the line once. Confirm the data model before adjusting the existing screen; this requires no new board.

## Already represented — preserve and refine

| Requirement | Current home | Coverage note |
|---|---|---|
| Language before onboarding and later in Profile | A01B, L01 | Both entry points exist. Thai translation and layout QA are additional coverage, not another product or new screen IDs. |
| Verification correction | A12, B02 | Dedicated boards already exist. |
| Start/end shift, ending soon and overtime | B00, B01C–B01F | Existing boards cover these distinct shift situations. |
| Network availability | B03 | Existing state-based board; keep availability separate from identity and accepted work. |
| Availability requests | M01 | Merchant, time window and available/not-available response sheet already exist. Response delivery still needs real implementation. |
| Merchant contact preferences | L01 | Opt-in controls already exist; they do not prove the separate conversation flow is complete. |
| Delivery update and consent to additional paid scope | E04–E06 | Both primary decisions exist; reliability states remain on the backlog. |
| Missed clock-out correction | K00 | Refreshed sheet and local correction behavior already exist. Server submission/review is a separate implementation task. |
| Rich Operations chat and communication history | H01–H03 | Core layouts exist. Incoming calls and permitted pre-job context remain distinct follow-ups. |
| Offline, GPS loss and permissions | N01–N03 | Existing boards should be refined and connected to real state; no duplicate “system status” section is needed. |

## Design rules for the additional states

Keep the approved blue/orange style guide, large type, generous spacing and large controls. Preserve the map and immediate next action on road screens. Use a sheet for a short decision; use a full task view when instructions, evidence or recovery need more room. Do not shrink content to avoid adding a justified screen.

Review new states alongside their parent board. Avoid introducing another confirmation step between arrival and pickup verification. Keep optional location feedback out of the required delivery completion path. Thai layouts may reflow, but must preserve readable type, touch targets and the same behavior.

## Evidence and limits

The inventory was checked against all 47 Manifest v6 filenames, and the current files were compared with the uploaded originals to determine refresh status. The focused interaction review inspected offers, pickup, delivery exceptions, communications, POD, live updates, Profile, Notifications and connection states in the HTML source.

This is a design-coverage review, not a complete audit of every specification in the archive or an end-to-end app acceptance test. It does not certify backend integration, device behavior, Thai rendering or production readiness. The v42 parity acceptance establishes the canonical baseline; it does not replace testing the refreshed prototype against these requirements.

### Source key

All sources below are from the v42 archive’s `00-CURRENT-CANONICAL/` folder.

| Key | Controlling document |
|---|---|
| S1 | `ROUNDS-DRIVER-CANONICAL-MANIFEST-v6.md` — board inventory, source precedence and expansion rule |
| S2 | `ROUNDS-DRIVER-PARITY-SYNC-AUDIT-v1.0.md` and `README-CHECKPOINT-v42.md` — accepted baseline and audit scope |
| S3 | `ROUNDS-DRIVER-UX-BEHAVIOR-MASTER-v3.0.md` — Driver behavior and later addenda |
| S4 | `ROUNDS-SPEC-3-DRIVER-BROADCAST-OPERATING-MODEL-v1.8.md` — offers, exceptions, cancellation and custody |
| S5 | `ROUNDS-SPEC-10-DRIVERS-LIVE-AVAILABILITY-CONTACT-v1.4.md` — availability and permission-based contact |
| S6 | `ROUNDS-SPEC-14-DRIVER-LOCALIZATION-LANGUAGE-v1.0.md` — Thai/English parity and authoritative notification opening |
| S7 | `ROUNDS-SPEC-4-MAPPING-ADDRESS-INTELLIGENCE-v1.7.md` — location observations and knowledge |

The older `02-DRIVER-SPECS/ROUNDS-DRIVER-APP-UX-SCREEN-LIBRARY.md` is historical context, not the current counting baseline.

## Current 47-board inventory

“Refreshed” records design progress only; it does not mean every production state has been implemented. “Original” means the file is unchanged from the upload.

| ID | Board | Refresh status |
|---|---|---|
| A01 | Splash | Original |
| A01B | Choose Language | Original |
| A02–A05 | Phone / OTP / Driver path / Team invite | Original |
| A06 | Team About You | Original |
| A06B | Independent About You | Original |
| A07 | Your Vehicle | Original |
| A08 | Verify Identity | Original |
| A09 | Live Face Check | Original |
| A10 | Get Paid | Original |
| A11 | Verification Submitted | Original |
| A12 | Verification Needs Attention | Original |
| B00 | Start Shift | Original |
| B01 | Team Driver Home | Refreshed |
| B01B | Team Home · Round Assigned | Refreshed |
| B01C | Shift Ended · Switch to Network | Original |
| B01D | Shift Ending Soon | Original |
| B01E | Shift Overtime | Original |
| B01F | End Shift Confirmation | Original |
| B02 | Verification Pending Home | Original |
| B03 | Network Home / all availability states | Original |
| C01 | Single Delivery Offer | Original |
| C03 | Multistop Offer | Original |
| D01 | Navigate to Pickup | Refreshed |
| D03/D04 | Pickup Confirmation | Refreshed |
| E01 | Active Round Overview | Refreshed |
| E02 | Navigate to Current Stop | Refreshed |
| E04/E05/E06 | Live Round Change | Original |
| F01/F02 | Dropoff Handoff | Refreshed |
| F03/F04 | Proof of Delivery | Refreshed |
| F08 | Stop Complete / Next Stop | Refreshed |
| G01 | Recipient Unavailable | Refreshed |
| G02 | Address / Pin / Entrance Problem | Refreshed |
| G03 | Package Problem | Refreshed |
| G04 | Cannot Complete Delivery | Refreshed |
| G05 | Driver Emergency | Refreshed |
| H01 | Operations Chat | Refreshed |
| H02 | Call / Contact | Refreshed |
| H03 | Contact History | Refreshed |
| I01 | Round Complete | Refreshed |
| J01 | My Rounds | Refreshed |
| K00 | Team Hours + missed clock-out correction | Refreshed |
| K01 | Network Earnings | Original |
| L01 | Driver Profile + Language setting | Original |
| M01 | Notifications | Original |
| N01 | Permissions | Original |
| N02 | Offline / Reconnecting | Original |
| N03 | GPS Unavailable | Original |
