# Rounds · Implementation Coverage and Gap Control

**Version:** 1.0  
**Date:** 2026-09-05
**Status:** Active implementation-control specification  
**Applies to:** English own-fleet Pilot / Slice 1 closure and Slice 2 execution

## Changelog

- **2026-09-05 · Checkpoint 41:** Replaces generic signed-media links with the
  canonical v45 and H01 media cards. Dispatch now renders its real photo inline,
  plays and pauses the real voice asset without a polling refresh interruption,
  and opens file bytes through a temporary browser object URL. Driver H01 now
  uses the supplied 118 px photo preview, 38 px file/photo row and 34 px
  nine-bar voice control. Browser playback, automated board geometry, all 150
  Driver tests and a fresh Samsung install pass. Physical Operations-originated
  media acceptance, queued recovery, realtime, call events and GAP-009 remain
  open; capability scores are unchanged.
- **2026-09-05 · Checkpoint 40:** Adds durable per-person communication read
  cursors and one shared Operations unread projection across the canonical
  v45 top bar, Driver map markers, conversation tray and compact conversation
  window. Incoming messages do not open or focus a minimized conversation.
  Driver H01 renders the supplied `1 UNREAD` boundary at the first unread
  Operations message and marks visible messages read without inventing
  delivery receipts. Migration `202609050001` is applied; all application
  tests pass. Secure push/realtime delivery, call events, the full contact
  ledger and remaining physical media acceptance stay open.
- **2026-09-05 · Checkpoint 39:** Physically proves Samsung Driver-to-Dispatch
  current location, photo, file and voice commits plus signed private-media
  projection, and proves Dispatch map-context delivery to Samsung. The open
  Driver H01 thread now refreshes every five seconds and on app resume; a live
  Operations reply appeared without leaving or reopening the screen. Desktop
  Photo/File/current-Location/voice sends, playback/download, unread/read and
  call events remain explicitly open.
- **2026-09-04 · Checkpoint 38:** Re-audits the running Operations workspace
  against the final v45 board and corrects the shared shell, Live/Plan rail,
  planning controls, Drivers command surface, terminal History ledger and
  manual-delivery drawer to that canonical visual hierarchy. Connected
  own-team data and commands are retained; unsupported automatic-dispatch,
  on-time, Weather, Network and history-projection claims are not fabricated.
  All 169 repository tests, the Operations typecheck and its production build
  pass.
- **2026-09-04 · Checkpoint 37:** Aligns the Dispatch shell and embedded
  Communications window to the canonical final v45 override measurements,
  including the 438 × 650 px desktop conversation surface, flat Live/Plan
  tabs, responsive rail/drawer geometry, marker language and map controls.
  The operating map now uses Mapbox Standard with the specified faded
  Operations presentation, Standard Satellite for real aerial imagery, real
  building-level 3D and deterministic zoom/rotation/north/pitch/focus
  controls. Street mode hands the selected saved coordinate to Google Street
  View with Mapillary stated as fallback. Weather and network-supply layers
  remain visibly unavailable until their real data sources exist; no fake
  operational layer is rendered.
- **2026-09-04 · Checkpoint 36:** Removes the non-canonical standalone
  Communications workspace from desktop and responsive navigation. Real
  Operations messaging now opens inside the v45 Dispatch map as the specified
  compact 438 px conversation window, coexists beside the contextual drawer
  at wide desktop widths, becomes the dominant overlay at constrained widths,
  and minimizes into a persistent bottom conversation tray. The original
  message/media backend and offline draft behavior are retained rather than
  replaced by prototype-only interactions.
- **2026-09-04 · Checkpoint 35:** Replaces the Dispatch text-only composer
  with the canonical v45 Photo, File, Location and Map context menu, visible
  microphone, staged-review area, image paste, file drop and ordinary-text URL
  handling. Text plus staged blobs survive browser refresh locally; offline
  Send is blocked without losing the draft. Operations-authored media now uses
  the existing private resumable Storage boundary, exact server SHA-256/length
  verification and atomic shared-thread commit. The remote migration is
  applied and the localhost menu/map-context refresh path is browser-verified;
  the wider floating/tray/unread/call/history behavior remains open.
- **2026-09-04 · Checkpoint 34:** Completes the real Driver H01 rich-message
  path for Camera, Photo, File and Voice. Media drafts survive restart,
  uploads resume through private Supabase Storage, server verification checks
  exact SHA-256 and byte length, and a message commits its verified assets
  atomically. Driver and Operations render signed private media; H03 records
  truthful attachment evidence. The canonical bottom drawer and microphone
  passed physical Samsung inspection. Final committed-media expiry remains
  explicitly controlled by GAP-009 rather than guessed.
- **2026-09-04 · Checkpoint 33:** Adds the first real H01 structured
  attachment: current device location. It is staged before Send, retained per
  Stop across restart, queued through the existing offline command outbox,
  validated and stored as structured server thread data, rendered in Driver
  and Operations, opens in an external map and enters H03 evidence. The remote
  migration is applied; media and voice controls remain gated.
- **2026-09-04 · Checkpoint 32:** Adds the canonical H01 ordinary-text URL
  behavior and long-press Copy action without adding a Link pseudo-attachment.
  Only HTTP(S)/`www` content becomes actionable; punctuation remains part of
  the message and links open through an explicit external handoff.
- **2026-09-04 · Checkpoint 31:** Rebuilds the active English H01 Operations
  chat shell from the supplied board's generated measurements, adds honest
  sender/system-event states and persists unsent text drafts per Stop across
  process restart. Real text delivery and the existing offline outbox remain
  unchanged; attachments and voice remain unavailable until their durable
  evidence pipeline exists.
- **2026-09-04 · Checkpoint 30:** Localizes the real N01 location-permission
  state machine and its location/camera recovery drawers from both supplied
  boards, adds generated Thai and 320 px geometry, and propagates the active
  Driver locale from every production entry path. N01 remains `PARTIAL` while
  background-location policy, a real notification channel and full physical
  permission acceptance remain open.
- **2026-09-04 · Checkpoint 29:** Localizes the active L01 Team Driver Profile
  and its language/sign-out drawers from both supplied boards, adds generated
  Thai and 320 px geometry, and makes the selected locale rerender L01
  immediately. Functional status remains `IMPLEMENTED`; physical visual
  acceptance remains open.
- **2026-09-04 · Checkpoint 28:** Adds authenticated, versioned and
  conflict-safe Driver language preference synchronization while preserving
  the immediate local/offline choice. A01B remains `PARTIAL` until complete
  active-flow translation coverage and physical bilingual acceptance pass.
- **2026-09-04 · Checkpoint 27:** Completes the canonical English/Thai G03
  package-problem subtype surface, exact generated geometry, durable category
  handling and database/API acceptance rules. Functional status remains
  `VERIFIED`; physical visual and live multi-subtype acceptance remain open.
- **2026-09-04 · Checkpoint 26:** Records canonical English/Thai D03/D04
  localization, responsive Thai verification and the remaining unlocked-device
  acceptance boundary. Coverage scores are unchanged because functional status
  remains `VERIFIED`.

## 1. Purpose

This document prevents design drift and false completion claims by connecting the canonical product/UX sources to code, verification evidence, known gaps and the next build sequence.

It does **not** replace product behavior, architecture or the canonical UX. If this document conflicts with a newer authoritative source, stop and report the exact conflict rather than resolving it by interpretation.

Authority remains:

1. `specs/product/` for behavior;
2. canonical Driver and Operations HTML boards for visual/interaction intent;
3. `specs/engineering/ROUNDS-ENGINEERING-ARCHITECTURE-v1.1.md` for architecture;
4. `specs/build/` for implementation mechanics;
5. `CODEX-BUILD-ORDER.md` and the scope ladder for promotion order.

## 2. Non-negotiable coverage rules

- A control drawn in an HTML board is **specified**, not implemented.
- Demo-only, preview-only or in-memory behavior is not counted as server-backed product behavior.
- A screen is not complete because it renders. Its consequential actions must use the canonical, authorized domain command and show honest pending, conflict, failure and committed states.
- Visual parity and functional completion are tracked separately.
- A future-slice board may remain `DEFERRED`; it is not a Pilot defect unless the scope ladder requires it now.
- No fake button, fake map marker, fake route, fake provider response or invented committed state may be used to make a surface appear complete.
- Test fixtures must be visibly and technically isolated from production behavior.
- Thai and English remain one localized application. The complete English and Thai UX board sets are binding visual/interaction references. English-reference-first construction does not change the Thai-first production requirement.

## 3. Status vocabulary and completion formula

Each capability has one functional status:

| Status | Score | Meaning |
|---|---:|---|
| `ACCEPTED` | 1.00 | Tested through the real UI and real backing service/provider on the intended device or environment. |
| `VERIFIED` | 0.85 | Implemented and covered by automated tests plus a live integration or database check. |
| `IMPLEMENTED` | 0.65 | Product code exists, but the required integration/device acceptance is incomplete. |
| `PARTIAL` | 0.35 | Only part of the canonical behavior exists. |
| `SPECIFIED` | 0.00 | Canonical behavior exists in specs/UX but product code is absent. |
| `BLOCKED-DECISION` | 0.00 | A material product/policy input is required before safe production behavior can be completed. |
| `DEFERRED` | excluded | Explicitly belongs to a later slice and is excluded from the current-slice denominator. |

Priority weight is `P0 = 3`, `P1 = 2`, `P2 = 1`.

Each non-deferred matrix row is one scoring unit. A grouped board range represents one connected capability and is scored once; it must be split into separate rows if its states stop sharing one implementation outcome.

```text
functional coverage %
= 100 × sum(priority weight × status score)
       / sum(priority weight for all in-scope capabilities)
```

Visual parity is scored independently:

- `0`: not built;
- `0.5`: canonical structure/tokens implemented but not visually accepted;
- `1`: golden/reference-viewport comparison plus physical-device or target-browser acceptance passed.

Production readiness is a gate, not an average. It remains **not ready** until every applicable BS-17 release gate, field gate, localization gate and security gate passes, regardless of the functional percentage.

## 4. Current completion baseline

These are evidence-based planning estimates, not release claims. Recalculate them only from the matrices in this document.

| Surface | Weighted functional coverage | Production readiness | Full roadmap context |
|---|---:|---:|---:|
| Driver · English Pilot business path only | 72.8% (`37.15 / 51`) | gate incomplete | not comparable to the complete board set |
| Driver · all currently authorized own-fleet depth | 62.2% (`47.90 / 77`) | gate incomplete | approximately 30% of the complete Driver V1 board set; roadmap estimate only |
| Operations · currently authorized own-fleet depth | 72.8% (`40.75 / 56`) | gate incomplete | approximately 35% of the complete Operations vision; roadmap estimate only |
| Combined authorized English own-fleet work | 66.7% (`88.65 / 133`) | **not release-ready** | approximately 20–25% of Slices 1–7; roadmap estimate only |

The Driver percentage is higher for the narrow delivery loop than for the complete 47-board product because Network onboarding, offers, earnings and marketplace behavior are deliberately outside the current own-fleet slice.

The Driver Pilot-only numerator/denominator uses these rows: A01, A01B, A02–A05, B01/B01B, D01, D03/D04, E01, E02, F01/F02, F03/F04, F08, G03, H01, H02, I01, L01, N01, N02 and N03. The broader Driver and Operations figures use every non-deferred row in their respective matrices.

## 5. Driver canonical board coverage

Canonical inventory: `specs/product/ROUNDS-DRIVER-CANONICAL-MANIFEST-v6.md` and `ux/driver/en/screens/`.

| Board | Current scope | Status | Evidence now | Required closure |
|---|---|---|---|---|
| A01 Splash | Pilot P2 | `IMPLEMENTED` | The shared canonical A01 now renders from generated board measurements, runs the specified word/dot entrance and advances after 1.25 seconds or an explicit full-screen tap. Session restoration still starts independently at process boot, so the visual launch state does not defer recovery work. Timing, centered geometry and returning-Driver routing have automated coverage. | Complete physical-device visual/timing acceptance on the supported Android/iOS matrix. |
| A01B Choose Language | Pilot P0 | `PARTIAL` | The original generic selector is replaced by one Thai-first localized Flutter surface generated from both canonical EN/TH board measurements. Thai is the first-run default, English is first-class, selection changes the complete screen presentation, and the local pre-auth preference survives relaunch/offline. Authenticated sessions now adopt the profile only when no explicit device choice exists; explicit local choices synchronize through a tenant-authorized, expected-version, idempotent profile command with one stale-version refresh/retry and non-blocking offline behavior. Reference-width geometry, 320 px Thai layout, conflict and offline behavior have automated coverage, and migration `202609040003` is applied remotely. | Complete localization-key coverage for every active flow, physically accept Thai/English layout and run a signed-in cross-device preference acceptance. |
| A02–A05 Entry / Team invite | Pilot P0 | `PARTIAL` | Protected Team email login and pilot one-tap login exist. | Replace pilot shortcut for release; implement canonical phone/OTP/invite path or record an approved product amendment. |
| A06 Team About You | Later onboarding depth | `DEFERRED` | No production onboarding form. | Promote with self-service Team onboarding. |
| A06B–A12 Independent identity/payment | Network | `DEFERRED` | Intentionally absent. | Build only with Network promotion and trust/payment policies. |
| B00 Start Shift | Slice 2 P1 | `PARTIAL` | The authenticated Driver session now projects today's effective recurring/date-exception shift and any real attendance. The canonical measured English/Thai B00 surface commits one explicit server-timed, versioned and idempotent shift start; the database snapshots schedule source/window and emits audit/domain evidence without changing assignment or custody. Automated contract/API/widget/golden coverage passes, migration `202609030017` is applied, and the real configured Samsung transition from B00 to the assigned-Round home passed. Unsupported notification/Hours actions remain inactive rather than fabricated. | Run the pgTAP behavior suite in a Docker-capable environment and define a real shift-level Operations contact identity/thread when no Round-scoped contact exists. Resolve GAP-013 late-start presentation. Ending/overtime remain B01D–B01F work. |
| B01 / B01B Team Home + assigned Round | Pilot P0 | `IMPLEMENTED` | The authenticated root lifecycle now renders the supplied measured B01 waiting state while an attendance is open with no Round, the supplied B01B assigned state for approved/loading work, D01 only after the explicit Navigate action, and E01 only after the Round is active. Both English and Thai layouts use generated measurements from their four canonical boards. Shift progress, pickup, manifest handling and route-plan context use real session truth; unknown driver-to-pickup distance/ETA remain visibly unavailable instead of copying prototype values. English goldens, compact Thai layout and lifecycle routing tests pass. The live assigned B01B map and B01B→D01 transition passed on the connected Samsung. | Physically accept the unassigned B01 state, connect authoritative driver-to-pickup preview distance/ETA, define a real shift-level Operations contact when no Round exists, and complete refresh/background visual acceptance. |
| B01C Switch to Network | Network | `DEFERRED` | Intentionally absent. | Slice 5+ only. |
| B01D–B01F Shift ending/overtime/end | Slice 2 P1 | `IMPLEMENTED` | The authenticated Driver app now derives the ending-soon, overtime and ready-to-end states from the immutable attendance snapshot, current assigned-Round truth and real stored route-plan timing. English and Thai surfaces use measurements extracted from all six supplied canonical boards. One typed offline-capable end command is authenticated, server-timed, versioned and idempotent; the database rejects an early end or any end while assigned work/custody remains, then records audit and domain-event evidence. Automated contract/API/widget/golden coverage passes and migration `202609040001` is applied. Overtime is factual elapsed time only, with no invented pay claim. | Run the pgTAP suite in a Docker-capable environment and complete physical near-end/overtime/end acceptance. B01F's post-end Network switch target remains deferred; Team Drivers return to the existing own-fleet home without fabricated Network availability. |
| B02 / B03 Verification + Network home | Network | `DEFERRED` | Intentionally absent. | Slice 5+ only. |
| C01 / C03 Delivery offers | Network | `DEFERRED` | Team work is assigned, not offered. | Slice 5+ only. |
| D01 Navigate to pickup | Pilot P0 | `VERIFIED` | An approved assigned Round now routes through the canonical D01 state using the authoritative pickup coordinate, live Google maneuver/ETA/distance events, measured D01 geometry, the canonical bottom action drawer and the D01→D03/D04 arrival transition. Automated/golden checks and a live Samsung provider check pass. | Physically approach the pickup to accept the 100 m/native-arrival reveal, then finish degraded-network/background road gates. |
| D03 / D04 Pickup confirmation | Pilot P0 | `VERIFIED` | Exact manifest checklist, offline command outbox, version/idempotency checks and server custody commit exist. English and Thai now use the canonical D03/D04 copy through the shared locale layer, including manifest handling labels, problem reporting and honest pending/failure states. English geometry/golden coverage and a Thai 393 px no-overflow interaction test pass; the configured APK is installed on the connected Samsung. | Complete final physical multi-item English/Thai acceptance and visual comparison with the phone unlocked. |
| E01 Active Round overview | Pilot P0 | `VERIFIED` | Real Round data, map, measured UI metrics and golden geometry tests exist. | Final physical-device visual acceptance for supported widths. |
| E02 Navigate to current Stop | Pilot P0 | `ACCEPTED` | Embedded Google navigation, TWO_WHEELER route, arrival command and physical Samsung bench operation have been exercised. | Motorcycle road, degraded-network, background and battery field gates remain open. |
| E04–E06 Live Round change | Slice 2 P0 | `IMPLEMENTED` | The supplied measured Driver surface now renders server-authored before/after truth and route impact, supports Operations contact, and durably acknowledges one assigned versioned update. Operations previews real route/promise/shift consequences, atomically changes only authorized destination/window/sequence truth, preserves locked custody, exposes awaiting/acknowledged state, and blocks stale versions. Automated API/widget coverage, remote migration application and Android build/launch pass. | Exercise the complete Operations apply → physical Driver acknowledge → Operations observed transition against a live active multi-Stop Round, add canonical map-based pin selection, and finish device visual/road acceptance. Network paid add-Stop consent remains deferred. |
| F01 / F02 Drop-off handoff | Pilot P0 | `VERIFIED` | Arrival now enters the separate measured English/Thai handoff surface before POD. Recipient, someone-else and left-at-location choices use real Stop/manifest truth; the latter opens the canonical four-choice bottom drawer. Contact actions reuse the real call, chat and recipient-unavailable flows. Handoff selection is passed into the existing atomic POD command instead of being committed early. English golden, compact Thai and routing/drawer tests pass; the English surface and drawer passed physical Samsung visual acceptance. | Exercise each choice through a live arrived Stop and committed POD, then complete physical Thai acceptance. |
| F03 / F04 Proof of delivery | Pilot P0 | `ACCEPTED` | Real camera photo, retained draft, resumable upload, server hash/size verification and commit survived Android bench relaunch. The generic form is now replaced by the measured English/Thai canonical structure: explicit delivery-side manifest checks, handoff-derived copy, structured received-by drawer plus the real receiver name required by the server contract, retained-photo preview/retake, honest server-time evidence and a fixed completion action. Only driver-confirmed line numbers enter the POD outbox. Reference geometry, golden parity, compact Thai, receiver-drawer and completion-gate tests pass. | Complete physical English/Thai visual acceptance and road/degraded-network recovery. GAP-014 must project the actual order-class POD policy before conditional signature or GPS/geofence UI is enabled. |
| F08 Stop complete / next Stop | Pilot P0 | `VERIFIED` | Multi-stop continuation and golden geometry coverage exist. | Physical multi-stop acceptance with real server data. |
| G01 Recipient unavailable | Slice 2 P0 | `PARTIAL` | The measured canonical G01 opens from the delivery issue drawer, launches the real native dialer, retains an authenticated/audited call-attempt ledger, changes to a second-call action after one failed attempt and exposes the real Operations contact channel after two. It never invents a waiting or approved decision. | Define GAP-006 custody outcomes, then add a typed recipient-unavailable hold, real Operations decision and recovery state. |
| G02 Address/pin/entrance problem | Slice 2 P0 | `PARTIAL` | Canonical measured G02 opens from pickup navigation and the delivery issue flow, captures optional real device-location evidence and survives restart/offline through the durable command outbox. A typed versioned/idempotent server command snapshots the authoritative expected location, preserves destination/manifest truth, opens an audited Operations hold and projects the comparison into v45. The separate authorized E04–E06 live-change command now versions destination changes and Driver acknowledgement without weakening the hold. | Define the remaining GAP-006 exception-resolution outcome, then connect an explicit Operations correction decision to the live-change boundary before releasing the hold. Pickup-location mutation authority remains undefined and is not inferred. |
| G03 Package problem | Pilot/Slice 2 P0 | `VERIFIED` | The English and Thai canonical initial, evidence and waiting states now use generated board measurements, the supplied bottom action drawer and real Stop/manifest truth. Damaged, missing and wrong-package categories are typed end to end; damaged/wrong require retained, verified photo evidence while missing explicitly submits without fabricating a photo. Category/photo drafts survive restart, all three open the existing audited Operations hold, and migration `202609040002` is applied remotely. Automated geometry, localization, contract, API and outbox coverage passes. An English Samsung debug-preview pass covered initial, damage-evidence and action-drawer composition and exposed the now-fixed photo-width defect. | Complete Thai and waiting-state physical visual acceptance plus live damaged/missing/wrong submissions against an arrived Stop. The only defined terminal reconciliation remains the existing physical damaged-item return; no missing/wrong Operations outcome is invented before GAP-006 is closed. |
| G04 Cannot complete | Slice 2 P0 | `PARTIAL` | The supplied measured G04 now opens from the delivery issue drawer with the canonical no-access/refused/closed/other reasons, real recipient dialing, durable Driver-selected contact evidence and a durable structured Operations message. Its waiting state truthfully preserves Driver custody and never invents a return, continuation or approved decision. | Define GAP-006 custody outcomes, then add a typed cannot-complete hold, real Operations disposition and recovery state. |
| G05 Emergency | Slice 2 P0 | `PARTIAL` | The canonical measured G05 opens from the issue drawer, requires one explicit safe/urgent status before dismissal, captures optional real position without blocking safety reporting, survives offline through the command outbox and commits an immutable emergency event plus protected priority Operations hold/thread. Urgent help exposes explicit 1669/191 dialer handoffs, while Driver and Operations surfaces never invent acknowledgement, reassignment or release. | GAP-006 must define Operations acknowledgement, escalation ownership, reassignment and audited hold release before the flow can become verified; physical-device and real Driver-to-Operations acceptance remain open. |
| H01 Operations chat | Pilot P1 | `VERIFIED` | The persistent Team Driver ↔ Operations thread works through the server and offline outboxes. Its English shell uses generated measurements from the supplied H01 board, projects truthful sender/system-event states, keeps queued messages visibly local and restores unsent text and attachments per Stop. HTTP(S)/`www` URLs are actionable ordinary text and human messages support long-press Copy. Location is structured thread data. Camera, Photo, File and Voice stage before Send, retain private local drafts, use resumable private Storage uploads, require server SHA-256/size verification and commit atomically with the message. Voice follows record → stop → preview → explicit send and never auto-sends. Signed private media renders in Driver and Operations and enters H03 evidence. Samsung acceptance now covers live Driver current-location, gallery-photo, file and voice sends through Operations receipt and signed private-media projection. Operations map context and new text also reach the already-open H01 thread through five-second foreground and resume refresh. A durable per-Driver read cursor now projects the supplied `1 UNREAD` boundary at the first unread Operations message and advances when the visible thread is read, without claiming delivery. The committed-media renderer now follows the exact H01 card variants: 118 px inline photo, 38 px photo/file row and 34 px nine-bar voice play/pause control, with signed-source stability across polling. | Complete physical Samsung Operations-originated Photo/File/current-Location/voice acceptance including playback/open behavior, plus queued rich-message network-loss/process-death recovery. GAP-009 still blocks a production retention claim. |
| H02 Call/contact | Pilot P1 | `IMPLEMENTED` | Canonical recipient/Operations contact presentation opens the native phone app and records authenticated, tenant-scoped, versioned and idempotent Driver-selected outcomes. Attempts survive offline in the Driver outbox, project into the Stop and Operations thread, and do not pretend to be carrier proof or mutate custody. | Complete physical-device visual acceptance and, if required later, integrate a real masked-call provider with provider-owned connection evidence. |
| H03 Contact history | Slice 2 P1 | `IMPLEMENTED` | The measured canonical Driver ledger combines real Driver/Operations/system messages with typed recipient/Operations call attempts, removes duplicate call projections, preserves chronological evidence, labels locally saved/offline history and opens the existing H01 thread. Durable location, photo, file and voice attachments enter the ledger with truthful labels and useful references. It never renders the illustrative prototype events without persisted evidence. | Complete physical-device visual acceptance and verify rich-media evidence after live sends. |
| I01 Round complete | Pilot P0 | `VERIFIED` | Server-complete Round state and canonical completion screen/golden exist. | Final physical multi-stop and offline-completion acceptance. |
| J01 My Rounds | Slice 2 P1 | `IMPLEMENTED` | The canonical measured Driver workspace shows the real current Round and up to 30 tenant-scoped completed Team Rounds from the authenticated session. Completed rows use authoritative terminal Stop/POD/return evidence; saved route distance/duration are explicitly labelled planned. Completed detail opens in the canonical bottom sheet. Network jobs, fares and actual-route claims are absent. | Complete physical-device visual acceptance and add actual duration/distance only when durable execution telemetry defines those metrics. |
| K00 Team Hours | Slice 2 P1 | `SPECIFIED` | Recurring schedules/date exceptions exist only in Operations. | Driver clock/shift history and correction request policy. |
| K01 Network earnings | Network | `DEFERRED` | Intentionally absent. | Slice 5+ payment/settlement scope. |
| L01 Profile + Language | Pilot/Slice 2 P1 | `IMPLEMENTED` | The measured canonical Team subset shows authenticated Driver identity, active merchant relationship and vehicle truth. Every visible L01 label, the language drawer, sign-out drawer and bottom navigation now use the supplied English/Thai copy; locale changes rerender the open profile immediately. Generated metrics reference both supplied boards and include their distinct Thai and 320 px composition rules. Support opens the existing Round-scoped H01 thread; sign-out requires explicit confirmation. Unsupported verification, identity editing, Network, payout and notification controls remain absent, and the former unsupported `Assigned` vehicle claim is removed. | Complete physical English/Thai visual acceptance. Localize and accept the child H01 surface separately; add account mutation or verification states only after authoritative workflows define them. |
| M01 Notifications | Slice 2 P2 | `SPECIFIED` | No notification preference surface. | Define channel authority and implement preferences when notifications are promoted. |
| N01 Permissions | Pilot P1 | `PARTIAL` | The measured canonical Team permission surface reads the real location-service and app-permission state, requests only in-use location, distinguishes denied/permanently blocked/service-disabled states and opens the correct OS settings. English and Thai now use their supplied board copy and generated geometry, including 320 px Thai overrides, across profile/navigation/location recovery and contextual camera-denial paths. Navigation no longer spins indefinitely when location is blocked, and no evidence is claimed on camera denial. The protected APK installs and launches on the connected Samsung; automated English/Thai and recovery coverage passes. | Validate background-navigation permission policy on Android/iOS before requesting it. Add notification permission only with a real promoted push channel, then complete physical denied/permanently-blocked/settings-return and visual acceptance. |
| N02 Offline/reconnecting | Pilot P0 | `VERIFIED` | The measured canonical N02 surface uses real Android connectivity transitions plus authenticated API reachability, an encrypted assigned-Round cache and live counts from the command, message, proof/media and telemetry outboxes. Startup renders the cached Round without waiting for the network. `Back online` appears only after the API responds and every measured retryable queue is empty. Offline and reconnecting states were exercised on the Samsung device with Wi-Fi and mobile data disabled, then restored. | Complete a physical queued-message/photo/status recovery run, background/process-death recovery and degraded-network road acceptance; iOS device acceptance remains open. |
| N03 GPS unavailable | Pilot P0 | `PARTIAL` | The measured canonical N03 surface is wired to the real operational position stream. A 30-second sample gap or stream error pauses live position/ETA, disabled service or permission is classified separately, and Retry GPS requires a real fix and restarts the stream. Cached-route continuation is shown only when Google guidance was already active. The Android access-off branch is physically verified on Samsung. | Complete true signal-loss field acceptance with location service still enabled, degraded/background recovery, and iOS device acceptance. The Google Navigation SDK may show its own Android location warning before the Rounds recovery surface when global location is switched off during active guidance. |

## 6. Operations v45 capability coverage

Canonical visual source: `ux/operations/rounds-operations-current-v45.html`. The HTML contains many interactive demonstrations. Only behavior connected to the React application and authoritative services counts below.

| Capability | Current scope | Status | Evidence now | Required closure |
|---|---|---|---|---|
| Authentication, tenant and role projection | Pilot P0 | `VERIFIED` | Supabase session, tenant membership, dispatcher/viewer roles and read-only enforcement exist. | Production account lifecycle, recovery and session security. |
| v45 workstation shell and navigation | Pilot P1 | `IMPLEMENTED` | React shell follows the canonical Dispatch/Deliveries/Drivers/Communications/History structure. | Full visual comparison and narrow/iPad responsive pass. |
| Real Operations map | Pilot/Slice 2 P0 | `VERIFIED` | Real Mapbox renderer, Operations/Satellite styles, zoom, north, rotation, pitch, truthful error state, server positions and server route geometry exist. | Complete canonical layer policy, marker semantics, live route/trail distinction and browser/device acceptance. |
| Live Dispatch / Action queue | Pilot P0 | `VERIFIED` | Server-backed Rounds, exceptions, live positions and freshness states exist. | Remaining edge states, filtering and realtime/polling production policy. |
| Single delivery intake | Pilot P0 | `VERIFIED` | Canonical internal delivery command, idempotency and drawer UI exist. | Address validation depth and final v45 visual acceptance. |
| Batch/manual import | Slice 2 P1 | `SPECIFIED` | No batch ingestion UI. | Define file template, row validation, partial failure and reconciliation UX. |
| Deliveries workspace | Pilot P1 | `VERIFIED` | Server-backed delivery list/details and operational states exist. | Complete filters, edit boundaries and remaining v45 record states. |
| Manual plan construction | Slice 2 P0 | `VERIFIED` | Date, ordered Stop selection, own driver, shared multidimensional capacity check, real route/window preview and explicit approval exist. | Configure production cargo values and add service dwell after the responsible business decisions. |
| Automatic plan generation | Slice 2 P1 | `SPECIFIED` | Intentionally not simulated in React. | Explainable heuristic, proposed plan persistence, uncovered-work truth and tests. |
| Plan adjustment before approval | Slice 2 P0 | `ACCEPTED` | Canonical Stop-order/departure controls and existing-Round Stop movement use fresh server route/window/shift/cargo previews. Moving a Stop recalculates only source/target Rounds, shows both consequences and commits through one dual-version atomic database command. Signed-in live acceptance passed with two approved, explicitly configured demo Rounds. | Production-approved cargo values and service dwell remain before full operating approval. |
| Round approval/assignment | Pilot/Slice 2 P0 | `ACCEPTED` | Server recalculates route, validates window/shift/cargo, database independently recalculates multidimensional capacity, requires fitting snapshots, then atomically assigns. Live cargo-configured approval passed with explicit demo values. | Production cargo taxonomy and service dwell remain before declaring full BS-09 approval. |
| Round execution detail | Pilot P0 | `VERIFIED` | Server-backed Stop/custody/exception state and communication links exist. | Remaining v45 Round actions and realtime projection depth. |
| Post-pickup live delivery change | Slice 2 P0 | `IMPLEMENTED` | The v45 Round detail opens a custody-locked live-change drawer, accepts only the authorized own-team fields, calls a real consequence preview, applies one versioned/idempotent database command and projects pending or acknowledged Driver state. Route order, destination version, audit, system ledger and Driver notification state commit atomically. | Complete signed-in browser/device acceptance with an active multi-Stop Round and connect the canonical map-based pin selector plus risk-override acknowledgement when that authority is configured. |
| Pickup exception resolution | Pilot P0 | `VERIFIED` | Audited correction returns Stop to assigned and requires manifest recheck. | Broader pickup outcomes/evidence views. |
| Delivery exception resolution | Pilot/Slice 2 P0 | `PARTIAL` | Damaged-item hold, return confirmation and reconciliation exist. Typed G02 location holds show authoritative-versus-observed coordinates in v45, while both UI and database deliberately block generic resolution. Post-pickup destination-change authority and Driver acknowledgement now exist as a separate versioned flow. | Approve and implement the recipient/address/cannot-complete/emergency exception outcomes and connect approved address corrections through the live-change boundary. |
| Communications | Pilot/Slice 2 P1 | `PARTIAL` | Persistent two-way shared threads support Driver and Operations text, location, photo, file and voice. The standalone invented board has been removed: the real composer now lives in the canonical v45 compact map window, coexists with the Round drawer on wide desktop, minimizes to the bottom conversation tray, and becomes an overlay at constrained widths. Selected blobs/text persist locally across refresh, offline Send preserves the draft, private media is integrity-verified, and message/media commit atomically. Localhost browser verification covers open, minimize and tray reopen. Physical acceptance covers all four Driver attachment classes reaching Dispatch, signed private-media projection, Dispatch map context reaching Samsung and Operations text appearing in an already-open H01 thread. Durable per-person read cursors now drive one shared unread state across the v45 top bar, map markers, conversation tray and compact window; unread voice is distinct and incoming messages never steal focus. The v45 window now renders real inline photos, canonical file cards and a working voice play/pause card; signed-source rotation does not interrupt playback, and file bytes open through a temporary browser object URL instead of a visible Supabase token URL. Migrations `202609040006` and `202609050001` are applied. | Complete physical browser Photo/File/current-Location/voice sends to Samsung, Driver playback/open and browser file-open acceptance, secure push/realtime delivery, call events and the full filtered contact-history ledger. |
| Own Drivers capacity view | Slice 2 P0 | `VERIFIED` | Own-team availability, live/stale/unknown presence, current Round and effective shift projection exist. | Route-completion availability estimate and complete vehicle/cargo truth. |
| Recurring schedules/date exceptions | Slice 2 P0 | `VERIFIED` | Versioned/idempotent drawers and server commands exist. | Driver-side shift lifecycle and overnight/date-policy acceptance. |
| Vehicle profiles and cargo limits | Slice 2 P0 | `VERIFIED` | Versioned cargo classes/limits are projected and enforced with max Stops/departure pattern by the common planner validator and database approval guard; unknown cargo is `review_required`. | UrbanFlowers must approve production taxonomy/limits; connect the canonical Settings controls for managed edits. |
| History and POD evidence | Pilot P0 | `VERIFIED` | Completed/returned deliveries, committed evidence metadata and audit-backed history exist. | Rich incident/contact filters, retention behavior and authorized evidence retrieval. |
| Settings control center | Slice 2 P2 / BS-16 | `SPECIFIED` | Settings is not connected. | Promote only settings required by the active pilot; keep unsaved/version/audit rules. |
| Customer tracking | Optional Slice 2 | `DEFERRED` | Not promoted. | Requires explicit promotion and BS-11 acceptance criteria. |
| Network supply/dispatch | Slice 5+ | `DEFERRED` | UI explicitly says it is not connected; no capacity is simulated. | Build only after own-fleet gates and Network promotion. |
| External courier/Lalamove | Slice 4 | `DEFERRED` | Intentionally absent. | Build only after Slice 4 promotion. |
| Commerce/SaaS integrations | Slices 3 and 7 | `DEFERRED` | Internal canonical delivery contract exists; production adapters do not. | UrbanFlowers first, then later connectors after their gates. |

## 7. Specification gap register

Not every unfinished feature is a missing specification. This table contains only inputs that are incomplete, ambiguous or require a deliberate production decision.

| ID | Gap | Type | Temporary engineering rule | Closure owner / gate |
|---|---|---|---|---|
| GAP-001 · **CLOSED 2026-09-03** | The Thai source inventory was mistakenly incomplete in Git, although the user-provided build pack contained the finished boards. | Source synchronization | The repository now contains 46 Thai-specific boards plus the shared language-neutral A01 Splash, matching the 47-board English screen inventory. | Closed by synchronizing the build-pack boards. Flutter implementation and Thai layout QA remain delivery work, not a specification gap. |
| GAP-002 | Cargo taxonomy, dimensions, quantities and vehicle compatibility limits are not production-approved. | Business operations | Use explicit `unclassified`/`review_required`; test fixtures may use clearly labelled non-production values. Never silently treat unknown cargo as fitting. | UrbanFlowers operations decision before full BS-09 approval. |
| GAP-003 | Destination handoff/service dwell and some pickup/reload turnaround defaults are not locked. | Business operations | Route preview must disclose excluded dwell. No hidden zero-time assumption may be described as full feasibility. | UrbanFlowers operations decision before promise-safe planning claim. |
| GAP-004 | Final production routing provider, call metering, cache duration and fallback policy are not locked. | Technical/commercial | Keep provider-neutral server interface and preserve provider provenance; Mapbox remains the current development provider. | Engineering + commercial decision before production load test. |
| GAP-005 | Canonical phone/OTP/team-invite onboarding versus pilot email login needs a release decision. | Product/security | Pilot one-tap login stays development-only; no credential is embedded in a release build. | Product decision before external beta. |
| GAP-006 | Recipient-unavailable, address, cannot-complete and emergency resolution policies are not complete enough for implementation. | Business/safety | Preserve custody, open an explicit Operations hold and never auto-complete or auto-return. | Operations policy workshop before those flows can become `VERIFIED`. |
| GAP-007 · **CLOSED 2026-09-03** | Which post-pickup fields Operations may change and when Driver acknowledgement is mandatory needs final policy. | Business operations | The controlling addendum in `ROUNDS-SPEC-6-DISPATCH-ROUTE-EDITING-COMMS-v1.11.md` limits change authority to destination/pin, promise, handoff/entrance instruction and future own-Round sequence; it requires locked custody, real consequence preview, atomic versioning and explicit Driver acknowledgement. | Closed by the Post-Pickup Live Change Control addendum. Network material-scope consent remains a later-slice authority. |
| GAP-008 | Batch intake file contract and partial-failure policy are not locked. | Product/integration | Continue single canonical intake; do not invent a production spreadsheet format. | Product + UrbanFlowers data owner before batch intake. |
| GAP-009 | Production retention periods for GPS, POD, exception media, messages and audit evidence are not locked. | Legal/privacy | Keep data private and access-controlled; do not claim compliant expiry. | Business/legal decision during BS-17 hardening. |
| GAP-010 | Notification channels, templates, retry rules and recipient consent are not locked. | Product/legal | No fake notification success. Store only canonical events until notifications are promoted. | Product decision before M01/BS-11 notification work. |
| GAP-011 | Supported Android/iOS versions and final release/device matrix are not locked. | Product/engineering | Current Samsung/API 36 is evidence, not the supported-device declaration. | Engineering/product before store submission. |
| GAP-012 | Field evidence is incomplete for motorcycle route quality, OEM background behavior, battery and degraded networks. | External evidence | Bench acceptance cannot be promoted to field acceptance. | Phase 0 field run before Pilot release. |
| GAP-013 | B00 defines only a pre-shift countdown; it does not define what an unstarted Driver sees after the scheduled start time. | Driver UX/operations | Keep the Start Shift action available and clamp the supplied countdown at zero. Do not claim the Driver started, was late or was excused from client time alone. | Product/UX decision before B00 can leave `PARTIAL`. |
| GAP-014 | The canonical POD boards illustrate a signature and automatic GPS, while product authority makes photo, signature, name and geofence evidence conditional by order class; the Driver session and POD command currently project no effective POD policy and persist no signature asset. | Product/operations + data contract | Keep the real required manifest, handoff, receiver-name and photo evidence. Record delivery time on the server. Do not draw a fake signature requirement or claim GPS/geofence evidence until an effective policy projection, signature-media contract and location-evidence fields are authorized end to end. | Product/UrbanFlowers operations must define Pilot order-class rules; Engineering then adds the policy projection, immutable signature asset and optional location evidence before those controls ship. |

## 8. Gap-handling protocol

For every newly discovered gap:

1. Add it to the register with a stable ID.
2. Classify it as product/business, safety/legal, technical/commercial or external evidence.
3. Continue unrelated work when the gap can be isolated safely.
4. If test behavior is needed, use an explicitly labelled test fixture/configuration that cannot be mistaken for a production default.
5. Stop only the affected production capability when a decision changes customer promise, custody, money, safety, privacy or external authority.
6. Record the decision in the relevant canonical product/build spec, then mark the gap closed here with the authoritative reference.

## 9. Locked remaining English own-fleet sequence

This sequence does not promote later slices; it orders the already authorized English own-fleet work.

### Checkpoint A — common cargo/capacity truth · **COMPLETED 2026-09-03**

- Versioned cargo-class and vehicle-limit contracts exist without invented production values.
- `unclassified` and `review_required` are explicit blocking truth.
- Planning preview uses one common application validator; approval independently recalculates the same dimensions in the database guard.
- Automated tests prove cargo and max-Stop bottlenecks independently, including aggregation and disallowed cargo.

### Checkpoint B — canonical Round management · **COMPLETED 2026-09-03**

- Connect server-backed Round overview/detail actions required by v45.
- **Completed B1 2026-09-03:** pre-approval Stop reorder and departure adjustment recalculate route/window/shift/cargo truth and commit the matching departure through the versioned approval boundary.
- **Completed B2 2026-09-03:** future pre-custody Stops move between existing approved own-team Rounds through source/target version checks, affected-Round-only route/capacity/promise recalculation and one atomic audited command.
- The canonical destination picker and consequence preview are connected in Round detail. Signed-in browser acceptance moved one Stop between two approved live test Rounds, verified both resulting orders and versions, and confirmed the audit/idempotency/outbox records.
- Keep automatic plan generation absent until its real heuristic and persistence exist.

### Checkpoint C — remaining own-driver operational states

- **Completed C1 2026-09-03:** D01 pickup navigation uses the server pickup pin and live embedded Google guidance, renders the canonical measured instruction/dock states and enters D03/D04 only after the explicit pickup-arrival action.
- **C2 typed hold implemented 2026-09-03:** canonical G02 captures optional real GPS evidence and durably sends a typed versioned/idempotent command. The server snapshots expected truth, preserves the locked manifest and destination version, opens an audited Operations hold/thread, and projects the comparison into v45. Generic resolution remains blocked until GAP-006 defines the exact exception outcome. The separate C6 command now supplies destination versioning, route consequences and Driver acknowledgement, but it is not allowed to silently clear the hold, so G02 stays `PARTIAL`.
- **C3 contact evidence implemented 2026-09-03:** canonical H02 and the safe portion of G01 now use the native phone app and a typed durable contact-attempt command. Driver-selected outcomes are visible to Driver and Operations, repeat attempts do not advance Stop versions or custody, and the G01 escalation stops at the real contact channel rather than fabricating an Operations decision. G01 stays `PARTIAL` until GAP-006 defines its hold and resolution outcomes.
- **C4 contact history implemented 2026-09-03:** canonical H03 is a read-only Driver ledger composed from the real Operations thread and typed contact-attempt evidence. It deduplicates the system projection of typed calls, makes pending/offline evidence explicit and returns to the originating Round. Prototype-only pickup, handoff and POD examples are not fabricated.
- **C5 Round history implemented 2026-09-03:** canonical J01 projects the authenticated Team driver's current Round and completed Round history from server truth. POD and formally closed work remain distinct, route figures are labelled planned, and Network fares/sample jobs are not copied from the prototype.
- **C6 live Round change implemented 2026-09-03:** the authorized own-team destination, entrance, promise and future-sequence changes now run through real server consequence preview, an atomic versioned database command, the supplied E04–E06 Driver acknowledgement surface and an observable Operations acknowledgement state. Locked pickup custody and the physical manifest cannot be mutated by the command.
- **C7 cannot-complete evidence implemented 2026-09-03:** the safe, supplied G04 path now captures one canonical structured reason, uses the real recipient dialer where the board requires contact, records Driver-selected contact outcomes and sends the complete Round/Stop/reason/custody context through the durable Operations thread/outbox. It stops at an explicit waiting-for-decision boundary because GAP-006 does not authorize a return or continued delivery.
- **C8 emergency safety hold implemented 2026-09-03:** the supplied G05 screen now records one typed safe/urgent status, optional real location, a durable emergency event and a protected priority Operations hold/thread. Explicit emergency-number handoffs remain Driver-controlled; acknowledgement and hold resolution are blocked on GAP-006 rather than inferred from the prototype.
- Implement the remaining typed holds and Operations outcomes for G01/G02/G04/G05 after GAP-006 defines custody disposition; G05 also requires its dedicated safety escalation policy.
- Complete the E04–E06 signed-in live multi-Stop acceptance and canonical Operations map-pin interaction.
- Complete physical-device visual acceptance for H02/H03 and add richer contact evidence only with a real durable source.

### Checkpoint D — offline, field and visual closure

- **D1 launch/language surface implemented 2026-09-03:** canonical A01 timing/animation and Thai-first A01B English/Thai geometry now use generated board measurements. Local pre-auth locale persistence, returning-Driver bypass and 320 px Thai layout are covered automatically.
- **D4 POD canonical parity implemented 2026-09-04:** F03/F04 now uses generated measurements from the supplied English/Thai boards, transmits only explicitly confirmed delivery-manifest lines and preserves the already accepted retained/resumable photo and atomic completion path. Unsupported conditional signature/GPS claims remain isolated under GAP-014. The next authorized closure is physical F03/F04 English/Thai and degraded-network acceptance, followed by the remaining active-screen localization pass.
- **D5 D03/D04 localization completed 2026-09-04:** pickup confirmation, manifest handling, problem reporting and sync/error states now resolve through one English/Thai copy authority based on the supplied boards. A Thai reference-width interaction test exposed and closed two real narrow-layout overflows. All 123 Driver tests, Flutter analysis and the Android build pass; the APK is installed on the connected Samsung, with unlocked physical comparison still open.
- **D6 G03 subtype parity completed 2026-09-04:** G03 now implements the
  supplied English/Thai initial, evidence and waiting compositions from one
  generated metrics contract. Damaged, missing and wrong-package commands are
  typed through Flutter, API contracts and PostgreSQL; photo evidence is
  required only where the boards require it. The remote database migration,
  automated geometry/localization tests and Android install pass. Physical
  screen comparison and live arrived-Stop acceptance remain open, and no
  unsupported GAP-006 decision state is exposed.
- **D7 authenticated locale persistence completed 2026-09-04:** the explicit
  local language remains immediate and offline-safe while authenticated profile
  synchronization is tenant-authorized, versioned and idempotent. A stale
  profile version refreshes and retries once without reverting a newer local
  choice or blocking active operational state. Migration `202609040003`, API,
  contract and Flutter regression coverage pass. Signed-in cross-device and
  full active-screen bilingual acceptance remain open.
- **D8 L01 bilingual parity completed 2026-09-04:** the active Team profile,
  language drawer, sign-out drawer and navigation labels resolve from one
  English/Thai copy authority. Generated measurements reference both supplied
  L01 boards, including the Thai composition lock and 320 px overrides. All
  133 Driver tests and Flutter analysis pass. Physical comparison remains
  open; N01 and H01 are tracked by their later checkpoints.
- **D9 English H01 canonical text/draft pass completed 2026-09-04:** the active
  Driver Operations thread now follows the supplied H01 top bar, Stop context,
  connection banner, message-bubble and composer measurements. Unsent text is
  durable per Stop, failed sends retain it, and queued sends remain labelled as
  local rather than sent. Automated geometry and restart-persistence coverage
  passes. Rich media, voice, unread/read state and physical Samsung comparison
  remain explicit closure work rather than simulated controls.
- **D10 English H01 URL/Copy behavior completed 2026-09-04:** ordinary
  HTTP(S) and `www` content inside a human message now renders as an actionable
  link, with surrounding punctuation preserved. Long-press copies the original
  complete message. There is deliberately no Link item in an attachment menu.
  Media/voice remains blocked from exposure until its real durable pipeline and
  GAP-009 retention boundary are implemented.
- **D11 English H01 current-location attachment completed 2026-09-04:** the
  Driver captures an authorized high-accuracy position, stages it in the
  canonical composer, persists the draft per Stop and sends it with optional
  text through the same offline-capable message command. The shared contract,
  database, Driver projection, Operations projection and H03 ledger preserve
  it as typed location data. Migration `202609040004` is applied remotely.
  Camera/Photo/File and voice remain unavailable until their durable bytes,
  resumable upload and GAP-009 retention behavior are complete.
- **D12 English H01 rich attachments completed 2026-09-04:** Camera, Photo,
  File and Voice are exposed through the supplied H01 drawer/mic behavior only
  after implementing retained local drafts, a resumable upload outbox, private
  per-thread Storage paths, server-side hash/size verification, atomic message
  commit and short-lived signed reads for Driver and Operations. Voice requires
  an explicit stop, preview and send. Migration `202609040005` is applied
  remotely; all automated suites pass and the real Samsung shows the canonical
  controls. GAP-009 remains open for the final committed-media expiry period,
  so this checkpoint does not claim production retention compliance.
- **D13 shared communications unread/read completed 2026-09-05:** one private,
  per-person, monotonic database cursor now defines unread state. Operations
  consumes one projection for the v45 top bar, map markers, tray and compact
  window; a minimized conversation remains minimized when new messages arrive.
  Driver H01 renders the exact supplied unread divider at the authoritative
  boundary and advances its cursor when the visible thread is read. Migration
  `202609050001` is applied remotely; API, web and all 149 Driver tests pass.
  The existing five-second refresh remains the honest transport until secure
  push/realtime delivery is implemented.
- **D14 canonical communication-media presentation completed 2026-09-05:**
  real signed photo, file and voice data now renders inside the supplied v45
  and H01 card variants instead of generic signed links. Dispatch browser voice
  playback is accepted without polling interruption; H01 photo/voice geometry
  is locked by automated tests and the updated build is installed on Samsung.
  Physical Operations-originated media and Driver playback/open acceptance
  remain open, as do queued recovery, realtime delivery and GAP-009 retention.
- Complete assigned-Round offline read cache and consolidated sync truth.
- Finish N01/N02/N03 recovery states.
- Run golden/reference-viewport comparisons for every in-scope board.
- Run physical multi-stop, degraded-network, background, battery and motorcycle road acceptance.
- Complete physical English/Thai G03 comparison and live subtype acceptance;
  do not promote unsupported exception outcomes.

### Checkpoint E — Thai implementation and production gates

- Implement the approved Thai boards and complete one-to-one layout QA in the same Flutter application.
- Close BS-17 security/privacy/recovery requirements.
- Remove or compile out all development shortcuts and fixtures.
- Run Android/iOS release, monitoring, backup/restore and incident gates.
- Stop for the human Pilot/Slice gate with tests, unresolved gaps and real-device/provider evidence.

## 10. Required checkpoint update

Every future checkpoint must update this document in the same commit by:

- changing affected status cells;
- citing the new checkpoint/test/device evidence;
- adding or closing gap IDs;
- recalculating any published completion percentage;
- naming the next authorized capability.

No future progress report may use an unqualified percentage that mixes the current own-fleet slice with the full Slices 1–7 roadmap.
