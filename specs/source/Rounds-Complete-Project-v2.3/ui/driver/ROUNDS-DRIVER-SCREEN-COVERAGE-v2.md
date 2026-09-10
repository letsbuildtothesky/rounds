# Rounds Driver — Current coverage and finishing checklist

Checked 8 September 2026 against the Refresh 26 cumulative pack and the uploaded originals. This is the current progress tracker. The included v1 coverage document records the historical Refresh 10 audit and must not be used for current completion counts.

## Current position

**45 of 47 canonical HTML files are visually refreshed. All 47 are already included in the ZIP.** The approved blue/orange system continues across the refreshed files. The vehicle icon polish and face-check motion are retained.

A file can contain several screens or variants, so the original “47 screens” label understates the number of visible states. Review boards are presentation files and do not increase the canonical app count. No additional screen IDs have been created by this sweep.

## Remaining original designs

| File group | Screens and variants still using the original design | Review order |
|---|---|---|
| A02–A05 · Driver entry | Phone number; verification code; Team/Independent driver choice; Team invitation, including the manual invite-code sheet. Existing English and Thai copy must remain supported. | A02 + A03 first, then A04 + A05. |
| E04–E06 · Live Round change | Entrance change; destination change; stop-order change; delivery-window change; added Network stop with accept/decline. | Review the standard update and scope-consent layouts, then all variants and recovery states. |

The remaining entry file still uses the old wordmark and reduces typography and controls on narrow/short screens. The live-change file also retains its old map/panel layout and small comparison copy. These are concrete remaining refresh tasks, not previously approved screens to redesign again.

The live-change refresh must preserve a useful map surface and make the changed instruction, impact and driver decision clear. Its current local acknowledgement/acceptance behavior still needs the pending, retry and superseded-change treatment identified in COV-07. Map-marker redesign remains deferred as requested.

## Coverage follow-up after the visual refresh

The eight items below retain the existing audit references. They do not automatically require eight new pages. Reuse an existing screen or sheet where the task fits; give a distinct task its own space when necessary. Status here is design coverage, not a claim that services or native behavior are implemented.

| Ref | Current position | Remaining work |
|---|---|---|
| COV-01 · Offer outcomes | Addressed in the Refresh 15 HTML: accepted, another driver, expired, withdrawn and uncertain-result states. | Validate the real claim/retry/lifecycle implementation later. |
| COV-02 · Incoming Operations call | Still on the design backlog. H02/H03 cover outgoing contact and history. | Incoming, missed and declined-call treatment with the correct caller/Round context. |
| COV-03 · Proof upload/recovery | Partly addressed in Refresh 14 N02: local save failure, pending, uploading, partial, failed and confirmed-receipt states. | Complete the proof → next-stop → recovery journey and durable evidence contract across F03/F04, F08 and N02. |
| COV-04 · Pickup not ready | Still on the design backlog. | Structured merchant-delay/waiting treatment in the pickup issue flow. |
| COV-05 · Cancellation and return | Offer withdrawal is now covered by Refresh 15; the full post-acceptance/post-pickup continuation is still on the backlog. | Cancellation disposition, return navigation and custody handback after the existing return instruction. |
| COV-06 · Pre-job merchant conversation | Still conditional. Profile contact permission and availability requests already have homes. | If enabled for V1, distinguish a permitted merchant conversation from an active delivery thread. |
| COV-07 · Current change/acknowledgement | Notifications received loading, resolution, retry, expired and offline UI in Refresh 12. E04–E06 remains original. | Pending/retry acknowledgement, newer-change handling and explicit Network scope consent without losing the original accepted work. |
| COV-08 · Optional location observation | Still conditional; marker refinement remains deferred. | Decide from field use whether a brief post-handoff observation is useful. Do not add it to required completion steps. |

Carry forward the historical manifest question for D03/D04: distinct physical manifest lines can have separate verification controls; one line with quantity two must follow the controlling line/quantity contract. Resolve that when consolidating the specs rather than silently changing the data model in a styling pass.

## Sweep completed on this pack

- All 47 canonical filenames match the uploaded original set; exactly the two groups above remain byte-identical to their originals.
- The source contains the approved blue in all 45 refreshed files. This is a source-presence check, not a rendered color/contrast audit.
- All 46 inline script blocks pass JavaScript syntax checks. No duplicate static IDs or unresolved static label/ARIA references were found in the 47 app files.
- All 227 checked relative file references resolve. This verifies file existence, not every parameterized journey, live URL or runtime outcome.
- The previous vehicle SVGs and other assets remain unchanged. The archive passes its integrity check and matches its working folder.
- The progress documentation is brought up to date here. The app HTML, tokens, guide and approved review boards are unchanged by this sweep.

## Before the final design handoff

Finish the remaining entry and live-change designs, then sweep the complete set for consistent wordmark, palette, typography, spacing, control sizes, concise copy and map priority. Walk the normal Team and Network journeys and the meaningful error/recovery variants. Reconcile the design backlog and current specs before deciding whether additional boards are necessary.

Browser/device visual QA remains unavailable under the earlier security restriction. This sweep used source, file and syntax checks; it does not establish real phone rendering. The final visual review still needs small-screen and enlarged-text checks, Thai shaping and copy review, map/action visibility, and real touch/daylight use. This pack is a design review set, not a production sign-off.

Sources: the current canonical HTML and uploaded originals; Refresh 09, 12, 14, 15, 25 and 26 notes; the retained v1 specification coverage audit and its v42 source key. No new specification revision was assumed.

## Current canonical inventory

“Refreshed” describes the visual refresh. It does not mean every recovery state or native integration is complete.

| ID | Board | Refresh status |
|---|---|---|
| A01 | Splash | Refreshed |
| A01B | Choose Language | Refreshed |
| A02–A05 | Phone / OTP / Driver path / Team invite | Original |
| A06 | Team About You | Refreshed |
| A06B | Independent About You | Refreshed |
| A07 | Your Vehicle | Refreshed |
| A08 | Verify Identity | Refreshed |
| A09 | Live Face Check | Refreshed |
| A10 | Get Paid | Refreshed |
| A11 | Verification Submitted | Refreshed |
| A12 | Verification Needs Attention | Refreshed |
| B00 | Start Shift | Refreshed |
| B01 | Team Driver Home | Refreshed |
| B01B | Team Home · Round Assigned | Refreshed |
| B01C | Shift Ended · Switch to Network | Refreshed |
| B01D | Shift Ending Soon | Refreshed |
| B01E | Shift Overtime | Refreshed |
| B01F | End Shift Confirmation | Refreshed |
| B02 | Verification Pending Home | Refreshed |
| B03 | Network Home / all availability states | Refreshed |
| C01 | Single Delivery Offer | Refreshed |
| C03 | Multistop Offer | Refreshed |
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
| K01 | Network Earnings | Refreshed |
| L01 | Driver Profile + Language setting | Refreshed |
| M01 | Notifications | Refreshed |
| N01 | Permissions | Refreshed |
| N02 | Offline / Reconnecting | Refreshed |
| N03 | GPS Unavailable | Refreshed |
