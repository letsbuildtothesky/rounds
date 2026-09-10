# Review resolution — V2

Date: 2026-09-08. This is the disposition of the supplied reviews, not a production certification. “Corrected specification” means the written contract has changed; implementation, migration and field tests remain unexecuted. Review source files are in inputs/.

## Claude

| Finding | Disposition | Change / remaining evidence |
| --- | --- | --- |
| B-01 | Corrected specification | Closed operational states in STATE-CODES.json and SQL CHECKs; typo/overlap test QA-SYSTEM-STATE-TYPO. |
| B-02 | Corrected specification | Typed event families and tagged event envelopes; reservation versus configuration payloads separated. Event shape validation is not consumer behavior proof. |
| B-03 | Corrected specification | Command-specific result data, typed error enum and labelled resources; hold expiry, upload capability, one-time tracking secret, handoff IDs explicit. |
| B-04 | Corrected specification | RetainedEvidenceResult plus incident/evidence IDs; physical commands distinguish retention from rejection and ordinary commit. |
| B-05 | Corrected specification | Manifest/policy/booking/tenant/attempt IDs in projections; DriverRound, ReturnTasks and Transfers queries. Complete journey still needs runtime integration test. |
| B-06 | Corrected specification | 150 individual feature checks and curated action mappings replace domain-union mappings. Implementation status remains unproved. |
| B-07 | Corrected specification | 172 numbered acceptance cases placed in owning P/E documents. Dedicated system cases include feature associations and concurrency tables. |
| B-08 | Decision recorded | ADR-T01: TypeScript service transactions on one pinned PostgreSQL connection own all eight critical operations. SQL enforces invariants; no parallel stored-procedure business engine. |
| B-09 | Corrected specification; runtime gate | ROLE-POLICIES.sql defines restricted roles, tenant/principal/broker context and realtime policy. Apply and run cross-tenant tests against Supabase before release. |
| D-01 | Corrected specification | Independent attempt, proof, outcome, assignment and preparation codes; core from/command/guard/to/event transitions. |
| D-02 | Corrected specification | Named lifecycle commands added with API payload/results, capability, root versions and transaction rules. |
| D-03 | Corrected specification | InitiateTransfer/ConfirmTransferReceipt/CancelTransfer; receiver-authenticated incremental receipt; typed transfer lines/custodians. |
| D-04 | Corrected specification | instruct/propose mode and ChangeProposalView old/new scope/fare/deadline; original agreement immutable, amendments separately accepted. |
| D-05 | Corrected specification | Positive additive receipts bounded by outstanding quantities; same command replay no-op; partial approval and remaining-obligation IDs; typed return/booking lines and receiver queries. |
| D-06 | Corrected specification | Single live draft hold/delivery slot; dead hold remains history; atomic MoveSlotHold and state-conditional timestamps. |
| D-07 | Corrected specification; concurrency gate | Plan/day and shift/day uniqueness; one live assignment/search/agreement/dropoff; template overlap resolved under scoped lock. Must exercise simultaneous changes in integration tests. |
| D-08 | Corrected specification | Typed custodians with site/principal references; custody event round/stop/trip/attempt context. |
| D-09 | Corrected specification; DB gate | Sealed manifest header/line and immutable-record triggers, accepted-scope guard and immutable amendments. Direct-SQL mutation tests remain mandatory. |
| D-10 | Decision recorded | Bounded policies; messaging/escalation/account families; closed customer events. Explicit authorized amounts replace imaginary computation from free-text fee references. |
| D-11 | Corrected specification | Required existing roots and conditional creation roots published; envelope versions authoritative and payload hashes additional. Server locks descendants. |
| D-12 | Corrected specification | Tracking exchange, scoped cookie, buyer/recipient projection rules, revocation/expiry 410 and one-time secret behavior. |
| D-13 | Corrected specification | Missing lifecycle events added to EVENT-CATALOG and tagged schemas; async consumers retain independent idempotency receipts. |
| D-14 | Corrected specification | Local closed states, encrypted asset metadata, invalidation, command roots and location buffer. Device crash lifecycle remains R0/R2 gate. |
| D-15 | Corrected specification | Counts generated from current package; self-contained defaults and reviewer guide; dictionary uses actual table names. |
| D-16 | Corrected specification; load gate | Outbox/board/inbox lookup indexes; membership/relationship reinvitation reactivates identity with new history rather than inserting duplicate. Load/rejoin tests required. |
| G-01 | Corrected specification | SetPickupReadiness and ready_by producer, draft fields and event; unknown readiness not inferred from GPS. |
| G-02 | Decision recorded | Reschedule keeps delivery ID and evidence history, creates next attempt at pickup and new admission where needed; custody remains at actual holder. |
| G-03 | Decision recorded | StartBroadcast atomically creates/converts selected unstarted work and reserves claims; released work requires explicit withdrawal; spare own capacity never blocks operator. |
| G-04 | Decision recorded | Most-specific slot scope wins: site+brand > site > brand > city; counters not cumulatively consumed. Same-specificity overlap rejects. |
| G-05 | Explicitly deferred | COD, customer self-service changes, automatic customer redelivery/cancellation fees and payout execution are excluded from this release. |
| G-06 | Corrected specification | Team cannot_comply response; break/resume/no-show and recovery with existing obligations retained. |
| G-07 | Corrected specification | Dated shift vehicle binding and locked vehicle availability; actual capability drives feasibility. |
| G-08 | User-approved decision | Destination hub is local pickup site. Full routes may be planned/staged before receipt; actual received lines gate collection/departure, not planning. |
| G-09 | Corrected specification; runtime gate | Supabase realtime.messages policy plus server-issued topic grants/expiry/revocation. Verify active-channel revocation on deployed version. |

## Grok

| Finding | Disposition | Change / remaining evidence |
| --- | --- | --- |
| F01 | Corrected specification | WithdrawRelease, PauseRound, ReassignRound; preserve performed work and physical custody. |
| F02 | Corrected specification | StartBroadcast accepts delivery IDs or Round selector; claim lock and Round creation/conversion atomic. |
| F03 | Decision recorded; field gate | Mapbox operations uses permitted Mapbox geometry. Google navigation stays on its own surface; unsupported motorcycle/truck estimates clearly unavailable. Vehicle legality/coverage remains field validation. |
| F04 | Corrected specification | One local outbox state vocabulary in E05 and local SQL; SQLite parse/execution checked, device crashes not yet tested. |
| F05 | Corrected specification | ApprovePartialPickup, approval ID, typed remaining obligations, additive receipt. Enable only after its release tests pass. |
| F06 | Corrected specification | Receiver-authenticated transfer protocol replaces one-actor TransferCustody. |
| F07 | Corrected specification | 123 current relational tables; counts reflect additional normalized physical-work entities. |
| F08 | Corrected specification | Single live hold and explicit atomic refresh/move; historical expiry retained. |
| F09 | Corrected specification | Client requests bounded duration; server computes broadcast/proposal expiry from server clock and policy. |
| F10 | Corrected specification | Independent state code families and projection mapping; no evidence-state alias in attempt. |
| F11 | Corrected specification | One live assignment per Round; versioned reassignment supersedes prior record. |
| F12 | Partially resolved; adapter gate | First-party signed integration ingress, raw-byte signature and replay rules defined. Native WooCommerce/Shopify/payment/voice provider envelope mappings still require adapter-specific contracts before enabling those adapters. |
| F13 | Corrected specification | Engineering cases now present in owning documents with measurable expected results. |
| F14 | Corrected specification | Included decisions/03-DEFAULTS-AND-OPEN-GATES.md and review/REVIEWER-GUIDE.md. |
| F15 | Corrected specification | Database ownership uses catalogue table names; cross-domain dependencies separate from ownership. |
| F16 | Corrected specification | Curated feature-specific actions/outcomes; all implementation status remains honest and unexecuted. |
| F17 | Corrected specification | SuspendTenant, CloseTenant, RestoreTenant with recovery constraints. |
| F18 | Corrected specification | OpenConversation idempotently creates/opens the authorized Round/trip/relationship thread; unique context indexes. |
| F19 | Open design gate | Approved board retained. Missing mobile/loading/error/return/call/recovery states still require design parity review; specs do not certify 100% UI completeness. |
| F20 | Open provider gate | Voice provider/native lifecycle not selected or proven by this revision. Preserve provider-isolated UI requirements; do not ship incoming-call promises before native tests. |
| F21 | Partially resolved; provider gate | ReserveVerificationEvidence/DecideVerification added. Identity/face provider and payout execution approval remain explicit gates; no fake automatic approval. |
| F22 | Corrected specification | Closed state CHECKs and machine-readable code registry. |
| F23 | Decision recorded | Tenant starts with draft policy configuration. CommitDelivery requires configured proof policy and reviewed destination requirements; unknown entrance noncritical warning distinct from materially altered address. |
| F24 | Corrected specification; runtime gate | Restricted roles/policies supplied; tenant isolation must be exercised on real database with the intended roles. |
| F25 | Corrected specification | Commitment state checked, so misspelled accepted state cannot bypass committed-range exclusion. |
| F26 | Corrected specification | ApplyOwnFleetAutomation command, preview/input hash/current roots and audit; never auto-starts freelance broadcast. |
| F27 | Corrected specification | Extract/review before final hold where possible; bounded refresh of same hold, explicit expired recovery, no multiple holds per draft. |
| F28 | Accepted architecture | Keep named command POST paths for generated clients; shared auth/envelope middleware, not 128 independent security implementations. |
| F29 | Open measurement gate | Performance/recovery targets explicitly proposed acceptance thresholds; load, restore and device experiments not claimed passed. |

## Gemini

The positive architectural assessment is useful, but it did not demonstrate build readiness. Keep the modular monolith, telemetry separation, durable offline evidence and provider boundaries. Treat native navigation/background operation, RLS query plans, and queue idempotency as release gates. Reduce address review fatigue by distinguishing changed destination-critical facts from noncritical suggestions. Adopt destination pre-planning explicitly. Avoid any unsupported assertion that an abstract adapter resolves map licensing.

## Remaining sign-off

1. Independent review of V2 contracts and database policy semantics.
2. Real PostgreSQL/Supabase migration and role-isolation tests, including direct SQL invariant attacks.
3. Generated TS/Dart client compile and complete command/query journey tests.
4. R0 low-cost Android/iOS background navigation, GPS, offline encryption and recovery harness.
5. Named native provider ingress/voice/verification choices and supported vehicle/routing geography before enabling each adapter.
6. Product acceptance of proposed numeric defaults, commercial amounts, proof policy and retention; these are configuration gates, not guessed tenant defaults.
7. Apply and verify board/driver design follow-through separately.
