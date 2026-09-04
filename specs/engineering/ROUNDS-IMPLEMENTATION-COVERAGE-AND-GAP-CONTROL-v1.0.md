# Rounds · Implementation Coverage and Gap Control

**Version:** 1.0  
**Date:** 2026-09-04
**Status:** Active implementation-control specification  
**Applies to:** English own-fleet Pilot / Slice 1 closure and Slice 2 execution

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
| Driver · English Pilot business path only | 69.9% (`35.65 / 51`) | gate incomplete | not comparable to the complete board set |
| Driver · all currently authorized own-fleet depth | 60.3% (`46.40 / 77`) | gate incomplete | approximately 30% of the complete Driver V1 board set; roadmap estimate only |
| Operations · currently authorized own-fleet depth | 72.8% (`40.75 / 56`) | gate incomplete | approximately 35% of the complete Operations vision; roadmap estimate only |
| Combined authorized English own-fleet work | 65.5% (`87.15 / 133`) | **not release-ready** | approximately 20–25% of Slices 1–7; roadmap estimate only |

The Driver percentage is higher for the narrow delivery loop than for the complete 47-board product because Network onboarding, offers, earnings and marketplace behavior are deliberately outside the current own-fleet slice.

The Driver Pilot-only numerator/denominator uses these rows: A01, A01B, A02–A05, B01/B01B, D01, D03/D04, E01, E02, F01/F02, F03/F04, F08, G03, H01, H02, I01, L01, N01, N02 and N03. The broader Driver and Operations figures use every non-deferred row in their respective matrices.

## 5. Driver canonical board coverage

Canonical inventory: `specs/product/ROUNDS-DRIVER-CANONICAL-MANIFEST-v6.md` and `ux/driver/en/screens/`.

| Board | Current scope | Status | Evidence now | Required closure |
|---|---|---|---|---|
| A01 Splash | Pilot P2 | `IMPLEMENTED` | The shared canonical A01 now renders from generated board measurements, runs the specified word/dot entrance and advances after 1.25 seconds or an explicit full-screen tap. Session restoration still starts independently at process boot, so the visual launch state does not defer recovery work. Timing, centered geometry and returning-Driver routing have automated coverage. | Complete physical-device visual/timing acceptance on the supported Android/iOS matrix. |
| A01B Choose Language | Pilot P0 | `PARTIAL` | The original generic selector is replaced by one Thai-first localized Flutter surface generated from both canonical EN/TH board measurements. Thai is the first-run default, English is first-class, selection changes the complete screen presentation, and the local pre-auth preference survives relaunch/offline. Reference-width geometry and 320 px Thai layout have automated coverage. | Sync the local selection conflict-safely to authenticated `driver.preferred_locale`, complete localization-key coverage for every active flow and pass physical Thai/English layout acceptance. |
| A02–A05 Entry / Team invite | Pilot P0 | `PARTIAL` | Protected Team email login and pilot one-tap login exist. | Replace pilot shortcut for release; implement canonical phone/OTP/invite path or record an approved product amendment. |
| A06 Team About You | Later onboarding depth | `DEFERRED` | No production onboarding form. | Promote with self-service Team onboarding. |
| A06B–A12 Independent identity/payment | Network | `DEFERRED` | Intentionally absent. | Build only with Network promotion and trust/payment policies. |
| B00 Start Shift | Slice 2 P1 | `PARTIAL` | The authenticated Driver session now projects today's effective recurring/date-exception shift and any real attendance. The canonical measured English/Thai B00 surface commits one explicit server-timed, versioned and idempotent shift start; the database snapshots schedule source/window and emits audit/domain evidence without changing assignment or custody. Automated contract/API/widget/golden coverage passes, migration `202609030017` is applied, and the real configured Samsung transition from B00 to the assigned-Round home passed. Unsupported notification/Hours actions remain inactive rather than fabricated. | Run the pgTAP behavior suite in a Docker-capable environment and define a real shift-level Operations contact identity/thread when no Round-scoped contact exists. Resolve GAP-013 late-start presentation. Ending/overtime remain B01D–B01F work. |
| B01 / B01B Team Home + assigned Round | Pilot P0 | `PARTIAL` | Waiting state, assigned Round projection and active overview exist. | Complete canonical home/assignment states, refresh behavior and visual acceptance. |
| B01C Switch to Network | Network | `DEFERRED` | Intentionally absent. | Slice 5+ only. |
| B01D–B01F Shift ending/overtime/end | Slice 2 P1 | `IMPLEMENTED` | The authenticated Driver app now derives the ending-soon, overtime and ready-to-end states from the immutable attendance snapshot, current assigned-Round truth and real stored route-plan timing. English and Thai surfaces use measurements extracted from all six supplied canonical boards. One typed offline-capable end command is authenticated, server-timed, versioned and idempotent; the database rejects an early end or any end while assigned work/custody remains, then records audit and domain-event evidence. Automated contract/API/widget/golden coverage passes and migration `202609040001` is applied. Overtime is factual elapsed time only, with no invented pay claim. | Run the pgTAP suite in a Docker-capable environment and complete physical near-end/overtime/end acceptance. B01F's post-end Network switch target remains deferred; Team Drivers return to the existing own-fleet home without fabricated Network availability. |
| B02 / B03 Verification + Network home | Network | `DEFERRED` | Intentionally absent. | Slice 5+ only. |
| C01 / C03 Delivery offers | Network | `DEFERRED` | Team work is assigned, not offered. | Slice 5+ only. |
| D01 Navigate to pickup | Pilot P0 | `VERIFIED` | An approved assigned Round now routes through the canonical D01 state using the authoritative pickup coordinate, live Google maneuver/ETA/distance events, measured D01 geometry, the canonical bottom action drawer and the D01→D03/D04 arrival transition. Automated/golden checks and a live Samsung provider check pass. | Physically approach the pickup to accept the 100 m/native-arrival reveal, then finish degraded-network/background road gates. |
| D03 / D04 Pickup confirmation | Pilot P0 | `VERIFIED` | Exact manifest checklist, offline command outbox, version/idempotency checks and server custody commit exist. | Complete final physical multi-item acceptance and visual comparison. |
| E01 Active Round overview | Pilot P0 | `VERIFIED` | Real Round data, map, measured UI metrics and golden geometry tests exist. | Final physical-device visual acceptance for supported widths. |
| E02 Navigate to current Stop | Pilot P0 | `ACCEPTED` | Embedded Google navigation, TWO_WHEELER route, arrival command and physical Samsung bench operation have been exercised. | Motorcycle road, degraded-network, background and battery field gates remain open. |
| E04–E06 Live Round change | Slice 2 P0 | `IMPLEMENTED` | The supplied measured Driver surface now renders server-authored before/after truth and route impact, supports Operations contact, and durably acknowledges one assigned versioned update. Operations previews real route/promise/shift consequences, atomically changes only authorized destination/window/sequence truth, preserves locked custody, exposes awaiting/acknowledged state, and blocks stale versions. Automated API/widget coverage, remote migration application and Android build/launch pass. | Exercise the complete Operations apply → physical Driver acknowledge → Operations observed transition against a live active multi-Stop Round, add canonical map-based pin selection, and finish device visual/road acceptance. Network paid add-Stop consent remains deferred. |
| F01 / F02 Drop-off handoff | Pilot P0 | `IMPLEMENTED` | Recipient/someone-else/left-at-location capture exists inside POD. | Match the canonical separate handoff state and finish device usability acceptance. |
| F03 / F04 Proof of delivery | Pilot P0 | `ACCEPTED` | Real camera photo, retained draft, resumable upload, server hash/size verification and commit survived Android bench relaunch. | Road/degraded-network acceptance and final canonical visual parity. |
| F08 Stop complete / next Stop | Pilot P0 | `VERIFIED` | Multi-stop continuation and golden geometry coverage exist. | Physical multi-stop acceptance with real server data. |
| G01 Recipient unavailable | Slice 2 P0 | `PARTIAL` | The measured canonical G01 opens from the delivery issue drawer, launches the real native dialer, retains an authenticated/audited call-attempt ledger, changes to a second-call action after one failed attempt and exposes the real Operations contact channel after two. It never invents a waiting or approved decision. | Define GAP-006 custody outcomes, then add a typed recipient-unavailable hold, real Operations decision and recovery state. |
| G02 Address/pin/entrance problem | Slice 2 P0 | `PARTIAL` | Canonical measured G02 opens from pickup navigation and the delivery issue flow, captures optional real device-location evidence and survives restart/offline through the durable command outbox. A typed versioned/idempotent server command snapshots the authoritative expected location, preserves destination/manifest truth, opens an audited Operations hold and projects the comparison into v45. The separate authorized E04–E06 live-change command now versions destination changes and Driver acknowledgement without weakening the hold. | Define the remaining GAP-006 exception-resolution outcome, then connect an explicit Operations correction decision to the live-change boundary before releasing the hold. Pickup-location mutation authority remains undefined and is not inferred. |
| G03 Package problem | Pilot/Slice 2 P0 | `VERIFIED` | Damage photo retention/outbox, authenticated upload, audited Operations hold, return confirmation and terminal reconciliation exist. | Complete all canonical package subtypes and final device visual acceptance. |
| G04 Cannot complete | Slice 2 P0 | `PARTIAL` | The supplied measured G04 now opens from the delivery issue drawer with the canonical no-access/refused/closed/other reasons, real recipient dialing, durable Driver-selected contact evidence and a durable structured Operations message. Its waiting state truthfully preserves Driver custody and never invents a return, continuation or approved decision. | Define GAP-006 custody outcomes, then add a typed cannot-complete hold, real Operations disposition and recovery state. |
| G05 Emergency | Slice 2 P0 | `PARTIAL` | The canonical measured G05 opens from the issue drawer, requires one explicit safe/urgent status before dismissal, captures optional real position without blocking safety reporting, survives offline through the command outbox and commits an immutable emergency event plus protected priority Operations hold/thread. Urgent help exposes explicit 1669/191 dialer handoffs, while Driver and Operations surfaces never invent acknowledgement, reassignment or release. | GAP-006 must define Operations acknowledgement, escalation ownership, reassignment and audited hold release before the flow can become verified; physical-device and real Driver-to-Operations acceptance remain open. |
| H01 Operations chat | Pilot P1 | `VERIFIED` | Persistent Team Driver ↔ Operations text thread works through the server. | Offline draft/send state and attachment support. |
| H02 Call/contact | Pilot P1 | `IMPLEMENTED` | Canonical recipient/Operations contact presentation opens the native phone app and records authenticated, tenant-scoped, versioned and idempotent Driver-selected outcomes. Attempts survive offline in the Driver outbox, project into the Stop and Operations thread, and do not pretend to be carrier proof or mutate custody. | Complete physical-device visual acceptance and, if required later, integrate a real masked-call provider with provider-owned connection evidence. |
| H03 Contact history | Slice 2 P1 | `IMPLEMENTED` | The measured canonical Driver ledger combines real Driver/Operations/system messages with typed recipient/Operations call attempts, removes duplicate call projections, preserves chronological evidence, labels locally saved/offline history and opens the existing H01 thread. It never renders the illustrative prototype events without persisted evidence. | Complete physical-device visual acceptance and add media/voice/location entries only when those channels have real durable evidence. |
| I01 Round complete | Pilot P0 | `VERIFIED` | Server-complete Round state and canonical completion screen/golden exist. | Final physical multi-stop and offline-completion acceptance. |
| J01 My Rounds | Slice 2 P1 | `IMPLEMENTED` | The canonical measured Driver workspace shows the real current Round and up to 30 tenant-scoped completed Team Rounds from the authenticated session. Completed rows use authoritative terminal Stop/POD/return evidence; saved route distance/duration are explicitly labelled planned. Completed detail opens in the canonical bottom sheet. Network jobs, fares and actual-route claims are absent. | Complete physical-device visual acceptance and add actual duration/distance only when durable execution telemetry defines those metrics. |
| K00 Team Hours | Slice 2 P1 | `SPECIFIED` | Recurring schedules/date exceptions exist only in Operations. | Driver clock/shift history and correction request policy. |
| K01 Network earnings | Network | `DEFERRED` | Intentionally absent. | Slice 5+ payment/settlement scope. |
| L01 Profile + Language | Pilot/Slice 2 P1 | `IMPLEMENTED` | The measured canonical Team subset shows authenticated Driver identity, active merchant relationship and assigned vehicle truth. Language changes through the real persisted English/Thai control; support opens the existing Round-scoped H01 thread; sign-out requires explicit confirmation. Prototype-only verification, identity editing, Network, payout and notification controls are absent. | Complete physical-device visual acceptance and add account mutation or verification states only after authoritative workflows define them. |
| M01 Notifications | Slice 2 P2 | `SPECIFIED` | No notification preference surface. | Define channel authority and implement preferences when notifications are promoted. |
| N01 Permissions | Pilot P1 | `PARTIAL` | The measured canonical Team permission surface reads the real location-service and app-permission state, requests only in-use location, distinguishes denied/permanently blocked/service-disabled states and opens the correct OS settings. Navigation no longer spins indefinitely when location is blocked. Camera remains contextual and all real photo paths show a recovery drawer on native denial without claiming evidence. | Validate background-navigation permission policy on Android/iOS before requesting it. Add notification permission only with a real promoted push channel, then complete physical denied/settings acceptance. |
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
| Communications | Pilot/Slice 2 P1 | `PARTIAL` | Persistent two-way server-backed text thread is verified, but the canonical capability is wider. | Attachments, offline drafts, call events, rich system ledger and live context behavior. |
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

- **D1 launch/language surface implemented 2026-09-03:** canonical A01 timing/animation and Thai-first A01B English/Thai geometry now use generated board measurements. Local pre-auth locale persistence, returning-Driver bypass and 320 px Thai layout are covered automatically; authenticated profile sync, all-active-screen string coverage and physical acceptance remain open.
- Complete assigned-Round offline read cache and consolidated sync truth.
- Finish N01/N02/N03 recovery states.
- Run golden/reference-viewport comparisons for every in-scope board.
- Run physical multi-stop, degraded-network, background, battery and motorcycle road acceptance.

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
