# P05 — Execution Custody Proof and Exceptions

## Reconciliation changelog

- 2026-09-10 · v2.3-r1 Now categories: extend QA-DI-01 with same-snapshot issue/execution category precedence, city day, exact brand/search counts and read-only command boundaries under ADR-Q07. No new physical rule or artwork.
- 2026-09-10 · v2.3-r1 Dispatch draft/reload: extend QA-DI-03 with exact-attempt recovery after recreation, original-version draft review and failed persistence. No new physical decision or UI approval is inferred.
- 2026-09-10 · v2.3-r1 Dispatch read/reply: extend QA-DI-03 with ADR-Q05 original report discovery, allowed actions and actual browser-client/HTTP/database/Driver round trip. Preserve designs and distinguish staged transport from mounted UI.
- 2026-09-10 · v2.3-r1 native recovery: bind committed/reopened G03 reports to original issue reads, with immediate host loading and explicit read-only refresh. Extend QA-DR-08 for unavailable/last-known replies, version regression and Auth-generation races; pre-pickup artwork still needs review.
- 2026-09-10 · v2.3-r1 Operations instructions: ADR-T08 implements only wait/escalate with no quantities or physical release. Preserve exact private reason and attributed immutable decisions; extend QA-DI-03 for real role/transaction/recovery/upgrade tests. Other actions and approved UI activation remain open.
- 2026-09-10 · v2.3-r1 recovery read: ADR-Q04 exposes original report state and real Operations instructions separately from readiness/execution. Registered/native acceptance is in E03; ResolveIssue, approved host recovery and phone remain open.
- 2026-09-09 · v2.3-r1 G03 form: expand QA-DR-08 for durable editable notes/camera candidates, retake preservation and explicit one-time report submission. Separate local source-derived widget tests from Operations/host recovery, source visual and phone acceptance.

- 2026-09-09 · v2.3-r1 native pickup photos: QA-DR-08 adds encrypted camera/transfer/report replay and preservation checks under ADR-S09; approved G03 and actual device acceptance remain separately required.

- 2026-09-09 · v2.3-r1 pickup photos: ADR-M04 adds original-report purpose-bound photo reservation/verification and requires verified damage/wrong evidence before report commit. Preserve old photos and source designs; expand QA-DR-08, not phone acceptance.

- 2026-09-09 · v2.3-r1 pickup reports: ADR-T07 connects pre-pickup package/wait reports, original-fence/quantity validation, immutable observation and synchronous order/departure hold. QA-DR-08 and generated contracts distinguish basic reports from unresolved media/native/decision activation.
- 2026-09-09 · v2.3-r1 proof/completion: ADR-T06 preserves notes/arrival identity and immutable submissions, synchronously validates required references, and atomically completes whole orders without closing unresolved Rounds. QA-DR-07 and contract/migration mirrors updated; phone/provider acceptance remains separate.
- 2026-09-09 · v2.3-r1 POD increment: ADR-M02 defines actual byte/ownership verification and immutable handoff binding; QA-DR-07 gains size/type/hash/replay/revocation/rollback cases. No provider, phone or proof/completion acceptance is inferred.
- 2026-09-09 · v2.3-r1 arrival increment: define ADR-T05 explicit own-team arrival, GPS quality/override, pre-arrival preparation independence and atomic observation/attempt acceptance. No geofence threshold, custody, proof or client activation is inferred.
- 2026-09-09 · v2.3-r1 handoff increment: ADR-T04 fixes complete-order handoff custody/receiver semantics and policy rejection; catalogue, mirrors and QA-DR-07 agree. Arrival, verified proof/completion and client cutover remain separate work.
- 2026-09-08 · v2.3-r1 / local pickup increment: clarify first-local-custody provenance and per-manifest batch event bindings (ADR-T03); no transport or client activation implied.
- 2026-09-08 · v2.3-r1: Specify readiness/error, atomic whole-order validation and precise acceptance negatives.

Consolidated V2.3-r1 specification · 10 September 2026

## Complete delivery and attempt

Launch rule: each delivery is collected as its complete current manifest. One internal fulfillment unit represents the whole delivery; it cannot be split or independently assigned in portions. Missing required quantities block that delivery only. Other complete deliveries may proceed after explicit route/assignment adjustment. Pre-arrival planning remains allowed. Partial inbound/return receipts and actual damage or loss are recorded truthfully; they never authorize short pickup or automatic remainder delivery.

CommitDelivery creates one internal unit containing all manifest quantities. ConfirmPickup succeeds only for the entire selected delivery. With three of five items ready, report the shortage and keep pickup blocked; no approval can turn it into a three-item collection. Once all five are ready, collect them together. Independent complete orders may leave on an explicitly adjusted route.

## Arrival, collection and custody

Current assigned driver confirms arrival; GPS can suggest but never execute it. StopView distinguishes pickup/dropoff/return/transfer and exposes stable stop/unit identity. Missing GPS follows configured warning/override with recorded reason. Arrival is not custody.

For the R1 own-team local adapter, ConfirmArrival accepts a valid longitude/latitude with finite nonnegative accuracy in metres, or no point/accuracy with a nonblank override reason. A coordinate without accuracy, accuracy without a coordinate, negative/nonfinite accuracy or mixed GPS/override submission is VALIDATION_FAILED. The absent-GPS branch requires gps_override_allowed in the delivery's captured effective schema1 ProofPolicy; at a shared pickup every assigned complete order must allow it. Missing/invalid policy is POLICY_NOT_CONFIGURED and an explicitly forbidden override is NOT_AUTHORIZED. Coordinates and accuracy are driver observations, not independently verified proximity: the approved policy has no arrival radius/accuracy threshold, so this adapter invents none and must not label a geofence as passed. Poor quality remains recorded for review.

Only a released/en_route current stop on the original authorized assignment can arrive. Pickup arrival may occur before preparation/inbound readiness and changes neither; it creates no attempt or custody. Dropoff arrival requires the already-collected whole unit and its actual pending/en_route assigned attempt, and cannot precede its collection time. Return/transfer/freelance execution stays outside this local adapter. Commit actual_arrival_at, the dropoff attempt's arrived_at/state if applicable, one proposed location observation (including a null-point override), one stop.arrived fact, audit outbox and original receipt atomically. Bind the observation to the stop via affected_resources; do not create live tracking samples or promote a doorstep revision. Replays return the original observation/versions; fresh conflicts cannot overwrite an arrival. Stale-observation retention remains a required separate branch, not a claim made by a rejected command.

ConfirmPickup locks the original assignment fence, Round, units, manifest lines and custody balance. Actual inbound receipts and preparation must permit collection. Non-ready preparation or collection observed before the recorded pickup arrival returns PICKUP_NOT_READY. Compare quantities as exact integer ten-thousandths after validating the four-decimal contract; reject duplicate selectors/lines, missing/extra lines and unequal quantities before any batch write. It seals the physical manifest, records custody and creates one pending attempt per collected whole unit. Its result returns unit IDs, attempt IDs/versions and custody event; remaining_units and obligation_ids are empty for successful launch pickup. Collected allocation cannot subsequently be edited.

For a first local order with no inbound dependency or earlier custody, the authenticated driver's exact full-quantity confirmation is the first physical observation. Record pickup into that driver's principal custodian, with no asserted source custodian and condition `not_assessed` because this command carries no condition assessment. Do not pre-create balances at planning/preparation, fabricate a merchant receipt, or label observed goods undamaged without evidence. If goods already have a ledger history, debit their actual custodian through the applicable verified custody path; never reintroduce them as new local stock.

Batch pickup creates one custody event and one typed `pickup.confirmed` fact per manifest, each binding the actual unit and attempt. `current_versions` lists changed roots; `resources` lists every new attempt and immutable custody event (version1). For compatibility, singular `data.custody_event_id` anchors the first manifest in ascending UUID order; it is not the entire batch. Each fact's own custody ID binds its one manifest/unit/attempt. Clients bind attempts by `fulfillment_unit_id`, never array position. A ready departure gate that remains ready emits no fictitious readiness-change fact.

## Handoff and proof

RecordHandoff requires the actual attempt, receiver and quantities; it returns handoff_id. SubmitProof binds that attempt/handoff and the captured policy to verified assets. CompleteDelivery completes this whole-delivery attempt/unit only after actual handoff and required durable proof. Whole-delivery and Round outcomes are separate synchronous derivations.

For the R1 own-team path, require the original acknowledged assignment, an arrived dropoff/attempt, a collected whole unit and exact full-manifest quantities held by that driver. Lock the linked recipient/alternate contact when supplied; an alternate must be a live alternate contact for this delivery, not merely the same tenant. Receiver-required policy needs that contact. Unattended handoff requires the captured policy to allow it plus nonblank place/instruction references; a driver-entered reference is an observation, not proof of separate customer consent. Missing, malformed, unsupported or not-yet-effective policy fails POLICY_NOT_CONFIGURED; policy-forbidden unattended action fails NOT_AUTHORIZED. Never substitute a sample policy.

Handoff creates one recorded handoff and immutable custody event, debits the driver's complete quantities and moves attempt/stop to handed_over. A recipient/approved location is outside tracked principal/site stock: do not fabricate a recipient account or balance. Record condition not_assessed because this command carries no condition assessment. Leave delivery outcome/evidence, unit delivered quantities, active claim and Round closure unchanged for proof/completion. Emit one handoff.recorded fact and its permitted audit outbox, not delivery.completed or a customer notification. Duplicate commands recover the same IDs; competing commands cannot debit twice. ADR-T04 scopes local implementation evidence separately from stale-observation retention and live client activation.

Driver may continue after real handoff and safe local evidence capture while upload remains pending. Show this distinction; local capture is not server completion. Receiver changes invalidate attributed signature, not unrelated good images. Operator evidence remains visibly operator-originated. No finance dispute decision fabricates driver media.

ADR-M02's first own-team asset adapter binds delivery photos/signatures to that recorded handoff and original assignment. ReserveAsset commits identity without upload secrets; authorized replay/status signs a fresh staging capability. VerifyAsset checks actual size/SHA256 and full permitted raster decoding, seals and rereads a private server-write-only copy, then rechecks current authority and original binding/version before verified state/fact/receipt commit together. Old upload links cannot overwrite the sealed copy. Failed upload/verification and receiver changes preserve original photos. General files/scanning, configured storage and the native sender are separate dependencies; a verified image alone satisfies no whole-delivery completion decision.

ADR-T06 SubmitProof stores pending immutable typed items, exact nonblank notes and explicit references to this stop's actual arrival observation, with original handoff/actor/policy/assignment and a successor attempt version. An incomplete valid submission stays pending; new evidence creates a new candidate without rewriting history. CompleteDelivery rechecks every supplied reference and all required kinds under locks, verifies eligible pending items synchronously, then completes the whole unit/attempt/dropoff/proof/delivery and archives its claim atomically. No short or mixed quantity completion. Required unresolved stops, return/custody duties or commitments keep Round open; other orders do not prevent this complete order finishing. Only eligible scoped own-team commitments are completed; no broker/provider/financial side effect is inferred. Exact receipt replay remains readable after closure, with current authorization.

## Offline continuation

Before connectivity is lost, cache the assignment fence and unit/stop identities. Capture ordered immutable local observations, not incomplete final commands. E05 defines result bindings for pickup → attempt, handoff → handoff_id and proof → proof_submission_id. Freeze each command’s exact bytes/hash only after its predecessor bindings resolve. Replays reuse that identity. An intervening assignment change preserves observations through RetainOfflineObservations; it does not refresh away the conflict.

## Exceptions, returns and transfers

Missing goods, wrong address, recipient unavailable, unable to continue and emergencies use typed issues. Issue creation alone authorizes no custody movement. Pickup waiting records elapsed time/readiness estimate separately from compensation; configured terms or explicit agreement govern money.

For ADR-T07's R1 pre-pickup branch, package reports hold only the selected complete order's readiness and synchronously block the containing Round's departure. The order stays open/uncollected: no partial pickup, unresolved post-custody outcome, return or disposition is inferred. Independent orders remain ready but require explicit route adjustment. A pickup_wait report alone changes no preparation/readiness and creates no receipt/payment. Reports can precede arrival/preparation under the original acknowledged assignment. Preserve exact details/point and affected quantities in an immutable report; an empty list means not measured. Nonempty quantities must be unique, current-manifest, positive four-decimal values no greater than expected. Migration0006 preserves older issues without invented original ownership/fences.

The server adapter rejects unsupported post-pickup/transport/other issue branches and unbound asset references. ADR-M04 reserves issue_photo against the original delivery, pickup/unit/manifest and assignment/report observation, then uses actual-byte/sealed-copy verification. Damaged/wrong reports require exactly one verified image with the identical original report scope/time; missing/waiting need none. Handoff-bound POD assets cannot represent pickup evidence. G03 choices/evidence is staged against the native editable form and explicit report transport; this does not complete host recovery or source/phone acceptance. A report receipt proves an open report, not an Operations decision or customer send. ADR-T08 separately implements attributed wait/escalate instructions with quantities=[] and no goods/readiness/preparation/compensation change. Other decision actions fail closed until their specific checks are implemented; partial pickup remains prohibited.

CreateReturn names the manifest, quantities, current custodian and destination receiver. ReceiveReturn/ReceiveTrip are positive increments, not cumulative totals; identical replay adds zero. Every line must belong to its header’s manifest and that manifest to its delivery. A partial receipt leaves the unreceived balance with its actual custodian.

InitiateTransfer requests a handoff. Named receiver uses ConfirmTransferReceipt for actual positive increments or DeclineTransfer before any receipt. Sender cancellation/expiry also requires zero receipt. Partial transfers require disposition of the remaining balance. No command silently asserts that the other party received goods.

Before pickup, cancellation releases future claims and admission as applicable. After pickup, return/transfer/disposition must precede cancellation closure. Reschedule preserves history and obtains new admission where needed. Closed attempts are never reopened to hide a second journey.

ADR-Q04 supplies a read-only original-report status connection to the authenticated native lease. Instructions come only from actual unambiguous Operations decision records; an empty successful decision list means no instruction returned, while a failed request means status unavailable. Readiness/preparation remain distinct facts, not instructions to fabricate collection. No unchanged/freshly fetched assignment can replace the report's original identity. ADR-T08 appends actual wait/escalate decisions, each preserving original reason, authenticated actor and server time; a successor references the prior decision without editing it. The staged G03 report/reopen path now enters its host destination immediately with loading and reads the original issue. Refresh cannot resend a report; failures preserve a visibly last-known reply without granting departure. E05 defines lifetime and original-lease guards. Approved pre-pickup recovery artwork, Dispatch controls and the installed phone workflow remain open.

## Evidence disputes and immutable history

Financial disputes and evidence disputes are different typed cases. Payment disputes leave handoff and POD validity alone. Evidence reviewer can uphold prior verified proof, reject it with cause or adopt an already verified replacement for the same attempt/handoff/policy. The original evidence remains retained; replacement does not invent a new physical delivery.

Sealed manifests/packages, accepted agreement revisions, custody and financial events remain protected. Cross-manifest references reject. Stale physical observations are retained under HTTP 200 retained_for_review or the explicit RetainOfflineObservations command result, with incident identity and no current-assignment mutation.

### QA-DI-01

Actor: Authorized actor for GetBoard; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetBoard under the condition in expected outcome; query affected records and compare committed events..

Then: Filter Action by brand B1: displayed count equals returned rows and selecting a row shows the same delivery ID. ADR-Q07 reads actual issue/current-execution facts in the same authorized date snapshot. Unresolved issues take priority, actual collection/handoff stays On road until completion, and Done retains its actual outcome. Preparation/receipt/unknown facts are not promoted to Ready. Test archived/resolved/foreign issues, obsolete attempts, revoked access, missing/duplicate projection entries and current-city-day rollover. Search and brand produce identical count/row sets; Show all exposes scheduled orders outside status buckets. Read-only card/detail is not permission to collect, release or complete; original pickup-reply drafts/authority remain unchanged.

Status: written requirement; application execution pending.

### QA-DI-02

Actor: Authorized actor for GetDelivery; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetDelivery under the condition in expected outcome; query affected records and compare committed events..

Then: D1 detail includes manifest ID, proof policy version, preparation, assignment, inbound dependency and evidence references required for next commands..

Status: written requirement; application execution pending.

### QA-DI-03

Actor: Authorized Operations actor for Board pickup_issues and ResolveIssue; original registered Driver reads its own reply. Identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Execute ResolveIssue under the condition in expected outcome; query affected records and committed events. For the R1 pre-pickup subcase create an actual original ReportIssue, discover it through ADR-Q05 Board pickup_issues with a different authorized Operations principal, construct wait/escalate from that actual issue/version and read it as the original registered Driver. Include Round-only waiting, city/date filtering, revoked rights and changed assignment with no allowed action. Test the real browser client through local HTTP/restricted SQL; inject response loss after commit and require own-receipt recovery without a second POST, including after controller recreation from the tab/login-scoped journal. Check browser stale/failed/coalesced reads, exact retry bytes, identity changes during awaits, disabled controls and malformed responses. Draft reopen preserves exact text and original versions; fresh authorized reads precede disclosure, changed work requires review, pending attempts block replacement, and failed/corrupt/conflicting storage cannot silently lose drafts or send volatile commands. Test duplicate/concurrent requests, changed bytes/stale versions, revocation, other city/tenant/actor, reassignment, post-pickup and corrupt chains. Inject SQL/result-validation failure after domain writes and journal settlement failure after commit. Upgrade an old schema with an immutable decision lacking reason. Browser transport/storage-double tests do not assert mounted drawer, actual browser lifecycle, reference screenshot or phone acceptance.

Then: Resolve address/recipient issue for D1: only that issue version changes and follow-up action is recorded on D1. R1 wait/escalate atomically appends one attributed immutable decision, increments only issue.version/state and writes event/outbox/receipt. Exact instructions are readable by the original Driver, private reason is not. No quantity, readiness, custody, arrival or payment is fabricated. Supersession retains predecessors; replay/status returns the original receipt. Failed writes roll back all effects; unsupported actions reject FEATURE_NOT_ENABLED, including partial pickup for every role. Old decision fields remain unchanged, new reason=NULL; Operations gains only scoped report SELECT, never cross-actor INSERT or Driver UPDATE.

Status: R1 wait/escalate implementation has local restricted-SQL/HTTP tests; exact current PASS/FAIL is in repository checkpoint evidence. Remaining address/recipient/physical decisions and configured Dispatch/phone acceptance are pending.

### QA-DI-06

Actor: Authorized actor for GetDriverRound; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetDriverRound under the condition in expected outcome; query affected records and compare committed events..

Then: After S1 completed, current/next stop IDs advance exactly once; free_after includes remaining travel, return and reload minutes..

Status: written requirement; application execution pending.

### QA-DI-07

Actor: Authorized actor for RescheduleDelivery; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute RescheduleDelivery under the condition in expected outcome; query affected records and compare committed events..

Then: Failed D1 moves to next day's slot: same delivery ID, original failed attempt preserved, one new active reservation and next release creates a new attempt..

Status: written requirement; application execution pending.

### QA-DI-10

Actor: Authorized actor for CancelDelivery; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute CancelDelivery under the condition in expected outcome; query affected records and compare committed events..

Then: Cancel after pickup5: quantity 5 remains in held/return/transfer/disposition ledger; no DELETE removes those facts..

Status: written requirement; application execution pending.

### QA-BC-09

Actor: Authorized actor for ConfirmPickup,CompleteDelivery; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ConfirmPickup,CompleteDelivery under the condition in expected outcome; query affected records and compare committed events..

Then: Pickup5 then handoff5: custody and evidence transitions are separate; final completion requires verified required proof..

Status: written requirement; application execution pending.

### QA-CM-10

Actor: Authorized actor for CompleteDelivery; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute CompleteDelivery under the condition in expected outcome; query affected records and compare committed events..

Then: Notification provider fails after completed handoff/POD: delivery stays delivered and notification job records failed/unknown independently..

Status: written requirement; application execution pending.

### QA-DR-05

Actor: Authorized actor for ConfirmArrival,ConfirmPickup; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Read GetDriverRound; explicitly arrive at pickup before and after goods become ready, then collect complete orders and explicitly arrive at the current dropoff. Exercise valid GPS, missing/invalid quality, allowed/forbidden/missing-policy overrides, original-assignment/device/city denial, same/different-command races, changed payload and forced SQL/result rollback. Then execute through the phone.

Then: Use actual IDs and predecessor versions, never display text. One observation/fact per committed arrival and stable receipt on retry; rejected paths have no domain writes. Arrival does not fabricate preparation, inbound receipt, pickup custody or delivery completion. Exact pickup and assigned attempt are preserved. Local HTTP/SQL evidence is separate from phone, geofence/provider and stale-evidence-retention acceptance.

Status: written requirement; application execution pending.

### QA-DR-07

Actor: Authorized actor for RecordHandoff,SubmitProof,CompleteDelivery; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: After whole pickup and explicit arrival, test handoff/asset ownership, quantities, receiver policy, actual bytes and original-assignment/device failure. Submit all six typed proof kinds and incomplete candidates; test exact note/location persistence, wrong handoff/policy/asset, duplicate references, receiver correction, invalidated items, revoked scope, concurrency and forced completion rollback. Complete one of multiple orders and a final order with unresolved return/commitment duties. Verify receipt/status replay after closure and scoped commitment permissions. Then run upload interruption, proof and completion through the phone.

Then: Handoff, verified asset, pending proof and complete delivery remain separate truthful facts. Preserve source bytes and immutable older submissions; no guessed notes/location/receiver. Only exact whole quantities and valid required proof complete atomically with claim retirement, facts, outbox and receipt; failure changes none. Replays do not duplicate completion. Unresolved Round duties stay open; another order remains queryable under its unchanged assignment digest. Scoped commitment access cannot create/change reservations or read other owners/cities/tenants. Missing policy fails POLICY_NOT_CONFIGURED. Provider doubles and isolated SQL acceptance are not phone/UI, configured upload or stale-retention acceptance.

Status: written requirement; application execution pending.

### QA-DR-08

Actor: Authorized actor for ReportIssue; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Execute ADR-T07 ReportIssue with registered-device own-team authority; test empty/explicit quantities, invalid/foreign/excess lines, original-fence/role/city/device negatives, concurrent duplicate/conflicting commands, status recovery, forced SQL/result failure, independent D2 and upgrade from preexisting issues. For damaged/wrong, execute ADR-M04 reserve/upload/verify/report with actual raster bytes; reject missing/unverified/POD/foreign/report-mismatched images, changed scopes during provider IO and mutation of original bindings. Exercise native ADR-S09 camera intent, encrypted bytes, purpose-aware transfer and explicit report with interruption/reopen, lost upload/receipt, scope invalidation and forged local/remote references; compare actual Dart bytes/hash against TypeScript validators. Preserve old photos/queues and require no fabricated arrival/handoff or self-dependency. Exercise editable G03 choices/notes/photo candidates before submission: latest queued edits after camera return, optional empty note omission, exact nonempty 240-scalar bound, cancelled/successful retake preservation, selected-capture tampering, restart at file/selection/freeze boundaries and repeated-submit deduplication. A saved draft/photo is not a sent report. Compare operational records and reports; source/host recovery/device scenarios remain required separately.

Then: A typed basic exception needs no fabricated quantities. Original details/location/assignment/time and selected verified photo ID remain durable and immutable; retries add nothing. Required-photo reports cannot commit before verification or substitute another purpose/report. Package report holds D1 and blocks departure without changing D1 quantities/outcome/custody or D2 readiness/allocation; waiting invents no receipt/preparation/money. SQL failure leaves no partial issue/hold/fact/outbox and preserves prior assets. Unsupported media/branches reject rather than being discarded. Test the staged G03 report/reopen callback with delayed and failed reads: navigate once with loading, retrieve only the committed original issue, coalesce Refresh, preserve exact superseding instructions and mark failed prior reads last-known. Reject regressed versions and late same-account reauthentication/disposal results. No read mutates queue/evidence or sends ReportIssue/ConfirmPickup. Optional detail follow-up, emergency contact, approved recovery artwork and phone acceptance remain required; ResolveIssue wait/escalate is separately scoped in QA-DI-03.

Status: written requirement; application execution pending.

### QA-DR-10

Actor: Authorized actor for ConfirmPickup; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ConfirmPickup under the condition in expected outcome; query affected records and compare committed events..

Then: App killed with queued physical observation: restart retains original actor/command/roots; changed assignment yields retained_for_review with incident ID..

Status: written requirement; application execution pending.

### QA-V21-PARTIAL-APPROVAL

Actor: MA approves; S collects

Given: DQ expected 5 units; only 3 prepared; issue IQ open

When: D1 needs five, only three available; D2 is complete. Attempt partial D1 and an atomic D1+D2 pickup, then invoke approval. Explicitly adjust assignment to D2 only and retry with new identity; finally receive/prepare all five for D1.

Then: Short pickup and mixed batch reject COMPLETE_ORDER_REQUIRED or actual inbound readiness error with zero custody/attempt/residual writes. Approval returns FEATURE_NOT_ENABLED for every role. D2 succeeds only after explicit adjustment, with one whole unit. D1 succeeds only when all five are present and ready. Replay produces no extra balance or fact.

Status: written requirement; application execution pending.

### QA-V21-FULL-PICKUP

Actor: Driver S

Given: M1 quantity 1 prepared and actually present at correct pickup

When: For a full actually present manifest, test preparation unknown/preparing/blocked and ready; omit approval_decision_id. Also send missing/extra/duplicate line IDs, short/excess quantities, duplicate selectors and decimal quantities with more than four places.

Then: Only ready plus exact line-map equality can commit; non-ready preparation returns PICKUP_NOT_READY. Invalid IDs/selectors/precision reject validation or manifest contract; unequal quantities return COMPLETE_ORDER_REQUIRED. Batch rejects before writes. No approval ID, child unit or remainder obligation is created. Exact four-place decimal quantities are compared as integer quanta.

Status: written requirement; application execution pending.

### QA-V21-STALE-ARRIVAL

Actor: Former driver S.

Given: R1 reassigned to N while S device offline.

When: Replay S genuine offline arrival with old assignment version.

Then: Observation retained_for_review with incident; N current assignment/stop state unchanged.

Status: written requirement; application execution pending.
