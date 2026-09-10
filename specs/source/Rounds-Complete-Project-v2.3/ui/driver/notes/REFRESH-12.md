# Rounds Driver — Refresh 12

7 September 2026 · M01 Notifications.

## Progress

47 app HTML files: **23 refreshed, 24 still original**. The user requested the next single screen, so this refresh changes only M01. All earlier screens, maps, tokens, style guide and review pages are preserved. `pair-11.html` opens Earnings / Profile. The included coverage audit remains the dated Refresh 10 baseline; this note supplies the latest progress count.

## Design

- Approved blue wordmark, orange accent, white surfaces, Arial type and restrained radii.
- 30px page title; 19–20px notification titles, 16px descriptions and 14px timestamps. The time sits above the title instead of squeezing a separate right-hand column. Earlier events use 18px titles / 15px descriptions.
- Entire event rows are large targets: minimum 154px for attention items, 126px for earlier events. Rows grow with text; they are not compressed on a short screen. Mark all read is at least 52px high. Availability responses are 64px / 60px controls.
- Needs attention stays separate from read status. Mark all read does not acknowledge a change, accept an assignment, accept an offer or submit availability. Read messages move to Earlier; unresolved operational decisions stay visible. Known-expired items move to Earlier.
- Unread status has both an orange edge and a textual New label. Completion/payment icons use green with explicit labels. Blank state offers a direct Home action.

## Content alignment

The original notification samples disagreed with their destinations. This refresh aligns them without editing the destination screens:

| Notification | Original | Refreshed, matching linked board |
|---|---|---|
| Assigned Round | 3 stops | 4 stops, matching B01B |
| Single offer | ฿240; 1.2 km pickup | ฿185; 1.4 km pickup; Sukhumvit 39 → Thonglor, matching C01 |
| Entrance change | Gate A → Gate B | Tower A lobby → Gate B; +2 min, matching E04–E06 |
| Payout | ฿1,920 | ฿2,480 on 28 Aug 2025; PromptPay •••• 4821; 12 jobs, matching K01 |

Preserves the Operations message about reception handoff and required proof, the 6-package pickup event and the completed 4-stop UrbanFlowers record. Times are dated fixture examples from the companion boards, not live events.

## Interactions

- Normal job/update/message notifications resolve the current fixture state before navigating directly to the existing flow. There is no added confirmation page for a current notification.
- Availability and payout open their own detail sheet. Payout details are fixed historical records; viewing them does not alter earnings.
- Availability identifies merchant, time and area, and explicitly means availability only. Responses save locally and are labelled Not sent. Changing a response does not accept work, reserve the driver, alter Network availability, change custody or notify the merchant.
- Read states and response drafts persist locally in `rounds12-notifications-v1`; review uses `rounds12-notifications-v1-review`. Cancel/Close does not invent a response. Failed writes retain the previous state and expose retry through the original action.
- Team and combined Team/Network context keep Team obligations primary and suppress the new Network offer/request examples. Network context carries Earnings navigation and the Network Profile context.
- Offline or failed lookups block acting on the update and offer Try again. Expired offers/requests have a clear ended state. Reconnection does not fabricate a sent response or automatic acknowledgement.
- Closing a sheet invalidates an outstanding lookup. A late response cannot reopen it or navigate to an old notification. Modals trap focus, make the background inert and return focus on close.

## Specification coverage

This addresses the notification UI portion of COV-07: opening/resolving, loading, retry, expired and offline states. The resolver here is deliberately a local fixture adapter (`window.rounds12Lookup`); production must replace it with an authenticated authoritative domain lookup. No backend push, server fetch, availability transmission or acknowledgement service is implemented. Do not mark the broader COV-07 requirement fully closed.

Offer acceptance/expiry inside C01/C03 and full versioned acknowledgement handling inside E04–E06 remain separate backlog items. Existing companion screens still use fixed sample routes/records and do not provide a general job-ID router. English remains the board language; Thai parity is still pending.

## Verification

Checked JavaScript syntax, unique IDs, local links, original-vs-current file counts and ZIP integrity. Node VM checks cover unread counts, read/action distinction, role filters, direct navigation, availability save/reload/failure, lookup failure/retry, expiration, offline gating, stale lookup cancellation, modal focus and trusted review routing.

Layout was checked in source for the established dimensions, narrow-width wrapping and flexible scroll structure. Browser and physical-phone visual verification remain pending; no 10/10 or production-readiness claim is made.
