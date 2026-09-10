# Decisions and minimal UI additions

Version 1.3 · 2026-09-10 · Active reconciliation decision register.

## Changelog

- 1.3 (2026-09-10): record the bounded manual-form draft-only status/retry reuse for review. Its compiled React fixture is not approval of interim UX or final Create activation.
- 1.2 (2026-09-10): record the user's approval of the bounded own-team wait/escalate drawer reuse. This does not approve a new board, the separate Driver waiting variant or a source-browser policy bypass.
- 1.1 (2026-09-10): record the unapproved own-team pickup reply and pre-custody waiting proposals; transport implementation does not approve new artwork or source-browser policy bypass.
- 1.0 (2026-09-08): initial reconciliation decisions and component-based proposals.

## Genuine decisions (not a blocker for all engineering)

| ID | Choice / recommendation | Affected scope | Current disposition |
| --- | --- | --- | --- |
| DEC-01 | Initially let the Rounds team approve/provision workspaces; add self-service later if wanted. User asked to choose. | CreateTenant only | BLOCKED_BY_DECISION. Existing tenant workflow is ready to implement. |
| DEC-02 | Use tenant-approved proof/receiver/GPS-outage matrix; do not invent one globally. | Live delivery completion for a tenant lacking configuration | Configuration UI/validation ready; launch actions fail POLICY_NOT_CONFIGURED until saved. Existing approved fixture policy may be used for isolated tests. |
| DEC-03 | Select country/vendor identity/liveness, voice and customer channels with account rights. | Real external sends, VoIP, verification and unsupported routing | Adapters remain disabled until selected/verified. Text/media/voice notes and ordinary maps do not depend on VoIP. |
| DEC-04 | Owner chooses commercial tariffs/compensation and approved retention by purpose/country. | Freelance charging, irreversible purge, real collection of gated sensitive history | Schema/validation can be built. No invented fees, payment execution or arbitrary retention. |
| UI-01 | Use existing wordmark assets for their current surface; choose one only if unifying square/dot variants is desired. | New logo changes only | Do not redraw branding while implementing existing references. |

No response to a question is not approval. Only ask about a decision when it materially affects the next scope; don't request all provider/account details now.

## Small missing-state proposals and approval scope

These preserve the current screen layout/components and require reference capture plus review before visual acceptance. No new standalone board is proposed.

| State | Existing reference and component | Proposed minimum addition and real binding |
| --- | --- | --- |
| Own-team pickup reply | Phase39 issue/review drawer, existing fields/buttons | APPROVED_TO_IMPLEMENT10 September: user replied “yes sure” to the proposed Ask driver to wait / Escalate form with exact driver instructions and a separate internal reason, then confirmed “ok move on.” Bind ADR-Q05 and ResolveIssue; no goods release/arrival/physical completion. Approval is limited to this component-based addition. Source rendering, actual drawer implementation, visual comparison and browser acceptance are still open; source-browser restrictions are not waived. |
| Pre-pickup waiting for Operations | G03 waiting layout, excluding post-custody copy | Waiting for Operations, actual instructions, Refresh and Message Operations. Do not say keep the package/continue round before collection. Previously proposed, not yet explicitly approved. |
| Manual draft-only save/recovery | Phase39 addDialog/addForm, existing add-autofill-message and form-error areas | REVIEW_PENDING: show Saving draft / Draft saved, retain source Create delivery disabled with its unconnected reason, and reuse a text retry action for checking an uncertain original save. Close/Cancel retains edits; no new board or final-order success. Implemented in the staged default-off connection and labelled synthetic fixture for review; not final UI acceptance or shared activation. Source/address/window/commit gaps remain explicit. |
| Pickup waiting | D03 confirmation; `pickup_confirmation_screen.dart`, `rounds_action_drawer.dart` | Keep manifest and primary CTA. Existing notice style states which complete order is awaiting goods/preparation; disable Confirm for a blocked selected batch; existing Pickup problem drawer records issue. Refresh re-queries, never simulates receipt. Back/dismiss stays available. |
| Changed assignment with offline photo | N02 reconnecting plus existing evidence preview/drawer | “Saved on this phone · Operations review needed”, view preserved photo and contact Operations. Bind retained_for_review/incident ID; no retry button that silently changes assignment authority and no “Delivered” badge. |
| Return receipt awaiting confirmation | Existing issue/return drawer and delivery detail | Show actual received and outstanding quantities with receiver and time; receiver-only confirmation of positive increment. Sender cannot mark receipt. Close/back retains draft and historical evidence. |
| Incoming/missed call | H02 call plus existing action drawer; Phase39 contact tray | Caller/job context, Answer/Decline or missed outcome from verified provider state. No sample call timer. Keep disabled until provider and this state are approved. |
| Driver must acknowledge changed work | E04–E06 existing combined source; `live_delivery_change_screen.dart` | Preserve before/after and exact amendment version. Pending/expired/revoked responses use existing notice and actions. Team acknowledgment and freelancer consent remain different commands. |

Recheck source state coverage immediately before implementing: if the HTML already supplies the needed variant, use it instead of adding the proposal. All 47 HTML files remain byte-identical to the supplied ZIP in this checkpoint.

## Intentionally disabled / deferred

No partial-pickup approval in any launch mode; no setting can enable it. Lalamove, temperature, wallet, COD and bank execution remain deferred. `cmReply`, `cmIncoming`, sample send/call and `planReleaseConfirm` sample success logic are reference-only. Production controls must bind to real commands or remain absent/disabled; successful mock state is never a fallback. Preserve normal messaging/media functions and the approved surrounding geometry.
