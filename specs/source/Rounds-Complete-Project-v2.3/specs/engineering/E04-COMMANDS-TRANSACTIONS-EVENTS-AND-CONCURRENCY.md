# E04 — Commands Transactions Events and Concurrency

Rounds engineering specification · Consolidated V2.3-r1 · 10 September 2026

## Changelog

- 2026-09-10 · v2.3-r1 address review: ADR-T10 shares receipt → draft → sorted suggestions lock order with SaveDeliveryDraft, and commits selected revision/history/fact/outbox atomically. Review uses its own current capability and original receipt scope; no slot or physical readiness is implied.
- 2026-09-10 · v2.3-r1 manual intake: ADR-T09 uses receipt → existing draft → referenced configuration → sorted suggestions/revision/fact writes. Creation has zero expected roots; original command status needs deliveries.create, never issues.decide by implication.
- 2026-09-10 · v2.3-r1 Operations instructions: ADR-T08 freezes original report job scope and adds the final issue-root lock/supersession/version check. Wait/escalate changes no physical state; scoped role, replay/rollback and upgrade acceptance accompany the handler.
- 2026-09-09 · v2.3-r1 handoff: resolve attempt-addressed original receipt scope inside the authorized transaction and revalidate it under domain locks (ADR-T04).
- 2026-09-08 · v2.3-r1 HTTP increment: freeze original receipt job authorization, preserve unprovable old scope and distinguish status recovery from current assignment authority (ADR-A01).
- 2026-09-08 · v2.3-r1: fix canonical whole-envelope identity, bounded transaction retry, receipt scope and savepoint rejection semantics (ADR-T02). This records the implementation contract, not full-workflow acceptance.

## Transaction protocol

Authenticate and resolve capability/context → canonicalize/hash request → acquire idempotency receipt → lock roots/dependencies in stable order → validate current state/versions/relations → commit state + event + outbox + sanitized command result → acknowledge → worker performs external effect. A rejected precondition creates a safe rejection result/audit as applicable without partial operational mutation. Database error rolls back all domain changes. Retry serialization/deadlock failure with same command identity and bounded attempts; never treat retry as a new operator decision.

Snapshot the validated whole request before awaiting a connection. ADR-T02 defines canonical JSON and SHA-256, including original command ID, context, occurred_at, selected-root versions, payload and original execution fence. The receipt uniqueness scope remains actor+tenant+command ID. Read/replay requires live authorization and the receipt's original tenant/city; a same-tenant user with access to another city cannot read that result. Do not expose an unrestricted receipt query.

Physical pickup/handoff receipts additionally freeze server-validated authorization_round_id/authorization_assignment_id (ADR-A01/T04). Attempt-addressed handoff resolves its original Round through the actual attempt/stop and supplied original assignment inside the same authorized transaction before receipt access; it accepts no caller Round selector. Revalidate this association under canonical domain locks before mutation. Scope resolution uses the frozen pre-await identity and cannot read the eventual result as authority. These private metadata fields authorize status against the original job; they are not current versions or caller-supplied query authority. Store neither bearer/device credentials nor the entire request in the receipt. Nullable old fields remain unprovable and fail closed at the new status boundary; never backfill a current assignment. Subject/scope/hash/job fields become immutable after insertion in isolated migration0002.

Acquire the receipt before a domain savepoint. A typed business rejection rolls back all domain writes/events/outbox to that savepoint, then commits only the sanitized rejection receipt. Force deferred constraints before recording success. Unknown/internal failures roll back the entire transaction. Retry SQLSTATE 40001/40P01 at most three total attempts, with 10ms then20ms delays and unchanged request identity. Once COMMIT outcome is uncertain, return UNKNOWN_RESULT and recover the original receipt; never automatically start a fresh command. Worker/provider retry remains the separate ADR-J01 schedule.

Canonical lock ordering: command receipt → tenant-scoped admission keys → existing intake draft IDs → delivery IDs → fulfillment-unit claims/IDs → Round/trip/broadcast/offer IDs (assignment/stops follow their Round) → manifest/line IDs → driver relationship/global driver guards → existing issue roots, each sorted by stable ID within class. An acceptance or release handler takes the global guard before inserting its committed range, following the same order. ADR-T08 locks an existing issue only after its original execution dependencies; Operations reads related driver identity without gaining account UPDATE authority. Its informational decision needs no custody guard or provider call. ADR-T09 manual draft save locks its draft before referenced configuration and sorted address suggestions; it takes no slot admission lock because it consumes no capacity. Future hold/commit/move writers take admission keys before the draft. All handlers must follow this order; no provider/network calls occur while holding locks. Idempotency scope is fixed before locking domain roots. Add newly introduced lock classes to this shared order and run concurrency regression tests before release.

## Critical atomic operations

| Operation | Locked/validated scope | Atomic result |
| --- | --- | --- |
| Manual address review | current draft/version/input hash → sorted matching suggestions | consecutive effective revision plus immutable before/proposed/selected decision and address.reviewed; no unconditional ready or entrance/physical effect |
| Slot hold/commit/move | template/date materialization, occurrence(s), draft/delivery | exact counted hold/commit; no split capacity or source loss |
| Team release | plan/proposal, affected claims, Round/stop and driver ranges | released snapshot, assignments, versions and outbox |
| Freelancer acceptance | offer/broadcast revision/deadline, included claims, global driver conflict guard | one agreement, owner claims and committed busy range; losers closed |
| Pickup | current assigned Round, sealed manifest/lines, custodian balance | verified physical collection event and balances, no mutable content rewrite |
| Handoff/proof completion | attempt/stop, receiver, manifest/custody, policy, verified asset receipts | physical handoff separately from final fully evidenced completion |
| Change acceptance | latest proposal/base agreement, all affected work/ranges/custody | whole accepted scope revision or no mutation; completed work protected |
| Return/transfer/trip receipt | booked manifest, source balances, authorized receiver and exact quantities | balanced custody events and only real received readiness |
| Integration update | provider event/source revision, delivery version | deduped normalized update or review-needed proposal, not stale overwrite |

The reference exclusion constraint blocks overlapping committed ranges; the service still validates future changes and shifts. Uniqueness of agreement/active claim is the final concurrency backstop. Cross-row quantities/capacity require transactions, not application preflight alone.

## Facts, consumers and synchronous derivations

Each event records one meaningful fact for a subject/version. Changes to several rows belonging to that fact are listed in its typed payload; do not emit a second alias for every affected table state. work.accepted carries agreement/assignment/Round/settlement creation. fulfillment.completed records one executed portion. delivery.completed occurs once only when all customer quantities are delivered. round.completed and settlement.earned are distinct contractual facts, not alternate triggers for customer delivery notifications.

EVENT-CONSUMERS.json binds exact events to consumers, eligibility and dedupe identities. Unlisted effects are disabled. Audit/refetch hints never imply financial or notification effects. Notification identity is event+recipient+channel+kind; template revision is a frozen attribute, not retry identity. Commerce full-fulfillment writeback consumes delivery.completed only.

User-command events carry command_id and authenticated actor. Worker/timer events carry worker_run_id and nullable command_id; exactly one cause identity is present. Actor may identify a service principal or be null for an authorized timer; source/job scope is recorded. No fabricated user command is required.

Named derive:* actions run inside the affecting transaction. Departure gate, unit/delivery/Round closure, residual obligation and settlement derivations cannot be queued authorization decisions. Worker delays must not leave ReleasePlan/ConfirmPickup using stale readiness. Internal gateway/outbox/job transitions do not recursively emit domain events.

## Ambiguous provider outcomes

Provider may accept a send/payment/configuration request before connection fails. Store provider intent/idempotency/reference. On timeout classify unknown; reconcile provider receipt/query where possible before retry. If provider has no safe dedupe/status query, manual resolution queue prevents automatic duplicate effects. Never infer failed effect solely from worker timeout. A lease expiry does not mean another worker's effect did not happen.

## Offline and stale commands

Queue client observations with original ID/expected version/observed time. Re-authenticate before sync. Stale draft edit rejects and preserves local proposal. Stale acknowledgement resolves latest update without falsely acknowledging it. Stale proof/custody observation is retained as evidence/incident for human reconciliation; do not automatically merge it into a reassigned job or delete it. Client offline states use pending labels until server receipt. Queue order dependencies are explicit (upload before proof commit, pickup before handoff).

## Audit boundaries and recovery

Immutable event, manifest and agreement histories are enforced by restricted DB privileges and TypeScript transaction handlers plus database guards (ADR-T01); a table lacking updated_at is not enough. Supplemental operator correction is a separate actor/source event. Post-restore replay uses event/consumer receipts and provider reconciliation to avoid repeating side effects. Outbox may be rebuilt from durable events only with idempotent consumer contracts.

Required adversarial tests: last-slot race; two acceptance winners; assignment versus broadcast race; duplicate pickup; duplicate media completion; source update versus live change; driver transfer versus offline proof; delayed ack of superseded update; worker crash after external accepted effect; feature disable with active custody. Every failure must preserve a reconstructable physical and contractual state.

### QA-SYSTEM-LAST-SLOT

Actor: Authorized actor for HoldSlot; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; plus parameters explicitly stated in steps.

When: DA and DB concurrently request SL1 with capacity 1..

Then: Exactly one live held reservation, total held+committed1; loser SLOT_FULL or STALE_VERSION; replay winner adds0 reservations..

Status: written requirement; application execution pending.

### QA-SYSTEM-HOLD-MOVE

Actor: Authorized actor for MoveSlotHold; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; plus parameters explicitly stated in steps.

When: DA holds SL1; SL2 is already full..

Then: Move rejects SLOT_FULL; DA still has its original SL1 hold and no second live hold..

Status: written requirement; application execution pending.

### QA-SYSTEM-REVISION-CAP

Actor: Authorized actor for SetSlotOverride,HoldSlot; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; plus parameters explicitly stated in steps.

When: SL1 old revision holds1; pointer changes to a new revision capacity 1..

Then: No second hold is admitted; logical template/date count stays1; old promise unchanged..

Status: written requirement; application execution pending.

### QA-SYSTEM-RECEIPT-INCREMENTS

Actor: Authorized actor for ReceiveTrip; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; plus parameters explicitly stated in steps.

When: DQ booked5; RH receives2 with C1 then3 with C2; replay both then submit1 with C3..

Then: Balances2 then5 then5; C3 QUANTITY_EXCEEDED with no movement; receipts retain distinct IDs C1/C2..

Status: written requirement; application execution pending.

### QA-SYSTEM-RETURN-PARTIAL

Actor: Authorized actor for ReceiveReturn; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; plus parameters explicitly stated in steps.

When: DQ return expected 5, RH receives2 then3..

Then: Return receiving at 2, received at 5; source balance decreases2 then3; replay changes0..

Status: written requirement; application execution pending.

### QA-SYSTEM-DST

Actor: Authorized actor for SaveSlotTemplate; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; plus parameters explicitly stated in steps.

When: Materialize America/New_York2026-03-08 02:30 and2026-11-01 01:30 without fold choice..

Then: Both reject VALIDATION_FAILED with nonexistent/ambiguous local-time field reason; Bangkok equivalent resolves normally..

Status: written requirement; application execution pending.

### QA-SYSTEM-PREARRIVAL

Actor: Authorized actor for StagePlan,ReleasePlan,ReceiveTrip; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; plus parameters explicitly stated in steps.

When: At07:00 stage R1/R2; at 09:00 receive L1,L2,L4,L5 only..

Then: R1/R2 planned before receipt; R2 may release; R1 stays staged missingL3; receiving L3 later unlocks same R1 with no duplicate deliveries or reset sequence..

Status: written requirement; application execution pending.

### QA-V21-EVENT-STATE

Actor: Worker consumer.

Given: Complete work.accepted fact fixture.

When: Remove assignment_id and validate.

Then: work.accepted has required agreement/assignment/Round/unit identities; incomplete accepted-work fact rejects schema validation.

Status: written requirement; application execution pending.
