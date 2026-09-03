# Rounds · Implementation Coverage and Gap Control

**Version:** 1.0  
**Date:** 2026-09-03  
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
| Driver · English Pilot business path only | 60.4% (`30.8 / 51`) | gate incomplete | not comparable to the complete board set |
| Driver · all currently authorized own-fleet depth | 45.5% (`35.0 / 77`) | gate incomplete | approximately 30% of the complete Driver V1 board set; roadmap estimate only |
| Operations · currently authorized own-fleet depth | 68.7% (`36.40 / 53`) | gate incomplete | approximately 35% of the complete Operations vision; roadmap estimate only |
| Combined authorized English own-fleet work | 54.9% (`71.40 / 130`) | **not release-ready** | approximately 20–25% of Slices 1–7; roadmap estimate only |

The Driver percentage is higher for the narrow delivery loop than for the complete 47-board product because Network onboarding, offers, earnings and marketplace behavior are deliberately outside the current own-fleet slice.

The Driver Pilot-only numerator/denominator uses these rows: A01, A01B, A02–A05, B01/B01B, D01, D03/D04, E01, E02, F01/F02, F03/F04, F08, G03, H01, H02, I01, L01, N01, N02 and N03. The broader Driver and Operations figures use every non-deferred row in their respective matrices.

## 5. Driver canonical board coverage

Canonical inventory: `specs/product/ROUNDS-DRIVER-CANONICAL-MANIFEST-v6.md` and `ux/driver/en/screens/`.

| Board | Current scope | Status | Evidence now | Required closure |
|---|---|---|---|---|
| A01 Splash | Pilot P2 | `SPECIFIED` | App boots directly into language/session routing. | Implement canonical launch state and restore transition without delaying urgent session recovery. |
| A01B Choose Language | Pilot P0 | `PARTIAL` | Locale selection and persistence exist. | Complete canonical visual parity and full-string coverage; Thai layout acceptance remains open. |
| A02–A05 Entry / Team invite | Pilot P0 | `PARTIAL` | Protected Team email login and pilot one-tap login exist. | Replace pilot shortcut for release; implement canonical phone/OTP/invite path or record an approved product amendment. |
| A06 Team About You | Later onboarding depth | `DEFERRED` | No production onboarding form. | Promote with self-service Team onboarding. |
| A06B–A12 Independent identity/payment | Network | `DEFERRED` | Intentionally absent. | Build only with Network promotion and trust/payment policies. |
| B00 Start Shift | Slice 2 P1 | `SPECIFIED` | Operations schedules exist; Driver shift command does not. | Add server-authoritative shift start and effective-shift truth. |
| B01 / B01B Team Home + assigned Round | Pilot P0 | `PARTIAL` | Waiting state, assigned Round projection and active overview exist. | Complete canonical home/assignment states, refresh behavior and visual acceptance. |
| B01C Switch to Network | Network | `DEFERRED` | Intentionally absent. | Slice 5+ only. |
| B01D–B01F Shift ending/overtime/end | Slice 2 P1 | `SPECIFIED` | Operations shift boundaries exist. | Add warnings, overtime policy and versioned end-shift command. |
| B02 / B03 Verification + Network home | Network | `DEFERRED` | Intentionally absent. | Slice 5+ only. |
| C01 / C03 Delivery offers | Network | `DEFERRED` | Team work is assigned, not offered. | Slice 5+ only. |
| D01 Navigate to pickup | Pilot P0 | `PARTIAL` | Native Google navigation surface exists, but the assigned Round currently enters manifest confirmation instead of the full canonical pickup-navigation state. | Wire authoritative pickup destination, arrival and D01 dock states. |
| D03 / D04 Pickup confirmation | Pilot P0 | `VERIFIED` | Exact manifest checklist, offline command outbox, version/idempotency checks and server custody commit exist. | Complete final physical multi-item acceptance and visual comparison. |
| E01 Active Round overview | Pilot P0 | `VERIFIED` | Real Round data, map, measured UI metrics and golden geometry tests exist. | Final physical-device visual acceptance for supported widths. |
| E02 Navigate to current Stop | Pilot P0 | `ACCEPTED` | Embedded Google navigation, TWO_WHEELER route, arrival command and physical Samsung bench operation have been exercised. | Motorcycle road, degraded-network, background and battery field gates remain open. |
| E04–E06 Live Round change | Slice 2 P0 | `SPECIFIED` | No production change/acknowledgement state. | Implement consequence preview, versioned change, Driver ack/decline/contact and stale-change handling. |
| F01 / F02 Drop-off handoff | Pilot P0 | `IMPLEMENTED` | Recipient/someone-else/left-at-location capture exists inside POD. | Match the canonical separate handoff state and finish device usability acceptance. |
| F03 / F04 Proof of delivery | Pilot P0 | `ACCEPTED` | Real camera photo, retained draft, resumable upload, server hash/size verification and commit survived Android bench relaunch. | Road/degraded-network acceptance and final canonical visual parity. |
| F08 Stop complete / next Stop | Pilot P0 | `VERIFIED` | Multi-stop continuation and golden geometry coverage exist. | Physical multi-stop acceptance with real server data. |
| G01 Recipient unavailable | Slice 2 P0 | `PARTIAL` | Category appears in a common issue drawer and can open external messaging. | Durable typed exception, evidence, Operations resolution and recovery state. |
| G02 Address/pin/entrance problem | Slice 2 P0 | `PARTIAL` | Category appears in the issue drawer. | Durable server exception, corrected destination/pin flow and route consequence handling. |
| G03 Package problem | Pilot/Slice 2 P0 | `VERIFIED` | Damage photo retention/outbox, authenticated upload, audited Operations hold, return confirmation and terminal reconciliation exist. | Complete all canonical package subtypes and final device visual acceptance. |
| G04 Cannot complete | Slice 2 P0 | `PARTIAL` | Category appears in the issue drawer. | Durable outcome choices, custody disposition and Operations resolution. |
| G05 Emergency | Slice 2 P0 | `PARTIAL` | Category appears in the issue drawer. | Dedicated priority channel, acknowledgement, escalation and non-dismissible safety behavior. |
| H01 Operations chat | Pilot P1 | `VERIFIED` | Persistent Team Driver ↔ Operations text thread works through the server. | Offline draft/send state and attachment support. |
| H02 Call/contact | Pilot P1 | `PARTIAL` | Contact drawer and external call/message launch exist. | Audited call events, failure states and canonical contact presentation. |
| H03 Contact history | Slice 2 P1 | `SPECIFIED` | Operations has thread history; Driver has no canonical cross-channel history ledger. | Build Driver ledger from messages/calls/system events. |
| I01 Round complete | Pilot P0 | `VERIFIED` | Server-complete Round state and canonical completion screen/golden exist. | Final physical multi-stop and offline-completion acceptance. |
| J01 My Rounds | Slice 2 P1 | `SPECIFIED` | No Driver history workspace. | Server projection and canonical history states. |
| K00 Team Hours | Slice 2 P1 | `SPECIFIED` | Recurring schedules/date exceptions exist only in Operations. | Driver clock/shift history and correction request policy. |
| K01 Network earnings | Network | `DEFERRED` | Intentionally absent. | Slice 5+ payment/settlement scope. |
| L01 Profile + Language | Pilot/Slice 2 P1 | `PARTIAL` | Language toggle and sign-out exist in the Round action drawer. | Canonical profile, language and account states. |
| M01 Notifications | Slice 2 P2 | `SPECIFIED` | No notification preference surface. | Define channel authority and implement preferences when notifications are promoted. |
| N01 Permissions | Pilot P1 | `PARTIAL` | Camera/location permissions are requested contextually. | Canonical denied/permanently-denied recovery and settings handoff. |
| N02 Offline/reconnecting | Pilot P0 | `PARTIAL` | Durable command, telemetry and media outboxes exist and do not claim false success. | Full assigned-Round read cache, unified dependency status and canonical offline surface. |
| N03 GPS unavailable | Pilot P0 | `PARTIAL` | Navigation/location errors are surfaced. | Dedicated canonical GPS state, permission/service distinction and recovery acceptance. |

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
| Plan adjustment before approval | Slice 2 P0 | `PARTIAL` | Selection can be cleared/rebuilt; canonical HTML demonstrates richer movement. | Server preview/commit for Stop move, reorder, departure change and affected-lane recalculation. |
| Round approval/assignment | Pilot/Slice 2 P0 | `VERIFIED` | Server recalculates route, validates window/shift/cargo, database independently recalculates multidimensional capacity, requires fitting snapshots, then atomically assigns. | Run live cargo-configured acceptance and add service dwell before declaring full BS-09 approval. |
| Round execution detail | Pilot P0 | `VERIFIED` | Server-backed Stop/custody/exception state and communication links exist. | Remaining v45 Round actions and realtime projection depth. |
| Pickup exception resolution | Pilot P0 | `VERIFIED` | Audited correction returns Stop to assigned and requires manifest recheck. | Broader pickup outcomes/evidence views. |
| Delivery exception resolution | Pilot/Slice 2 P0 | `PARTIAL` | Damaged-item hold, return confirmation and reconciliation exist. | Recipient/address/cannot-complete/emergency outcomes and performance treatment. |
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
| GAP-007 | Which post-pickup fields Operations may change and when Driver acknowledgement is mandatory needs final policy. | Business operations | Locked physical manifest never mutates; no post-pickup change is silently applied. | Product/Operations decision before E04–E06. |
| GAP-008 | Batch intake file contract and partial-failure policy are not locked. | Product/integration | Continue single canonical intake; do not invent a production spreadsheet format. | Product + UrbanFlowers data owner before batch intake. |
| GAP-009 | Production retention periods for GPS, POD, exception media, messages and audit evidence are not locked. | Legal/privacy | Keep data private and access-controlled; do not claim compliant expiry. | Business/legal decision during BS-17 hardening. |
| GAP-010 | Notification channels, templates, retry rules and recipient consent are not locked. | Product/legal | No fake notification success. Store only canonical events until notifications are promoted. | Product decision before M01/BS-11 notification work. |
| GAP-011 | Supported Android/iOS versions and final release/device matrix are not locked. | Product/engineering | Current Samsung/API 36 is evidence, not the supported-device declaration. | Engineering/product before store submission. |
| GAP-012 | Field evidence is incomplete for motorcycle route quality, OEM background behavior, battery and degraded networks. | External evidence | Bench acceptance cannot be promoted to field acceptance. | Phase 0 field run before Pilot release. |

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

### Checkpoint B — canonical Round management

- Connect server-backed Round overview/detail actions required by v45.
- Add Stop move/reorder/departure preview and versioned commit.
- Recalculate only affected Rounds and present consequences before confirmation.
- Keep automatic plan generation absent until its real heuristic and persistence exist.

### Checkpoint C — remaining own-driver operational states

- Complete D01 pickup navigation.
- Implement durable G01/G02/G04/G05 exception paths and Operations outcomes.
- Implement E04–E06 post-pickup change acknowledgement after GAP-007 closes.
- Complete H02/H03 contact event/history behavior.

### Checkpoint D — offline, field and visual closure

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
