# Rounds v2.1 — Independent specification review

**Reviewed:** 8 September 2026  
**Source:** `Rounds-Specs-v2.1(1).zip`, 63 files  
**Archive SHA-256:** `7be9c63668ad006b27662e8b3b445f9b8b870f98fad25a722f069cf5b1d85d56`

**Verdict: a substantial, thoughtful specification package that still needs corrections before specification sign-off. I do not agree with “perfect; nothing needs changing.”**

The strongest parts are the operating principles: planning before receipt, independent ready-route departures, explicit freelance consent, receiver-confirmed custody, and the distinction between physical delivery and durable evidence. Preserve these. The problems are predominantly where those principles are translated into command contracts, database constraints and lifecycle transitions.

The package itself does not claim perfection. `review/REVIEW-RESOLUTION.md`, under “Important remaining specification work before build specs,” explicitly identifies unfinished service triggers, acceptance assertions, integrity/error audits, retention mechanics and adapter/projection work. `README.md` says these decisions should be finished before build specs are derived.

This review distinguishes **demonstrable contract contradictions**, **missing workflow decisions**, and **implementation/launch verification**. An unimplemented application is expected at this stage. Incompatible definitions of the same operation are specification defects today.

## Priority findings

| ID | Finding | Priority | Evidence classification |
| --- | --- | --- | --- |
| R01 | Payment request, response and persisted status disagree | High — correct before Network build specs | Direct contract contradiction |
| R02 | Partial fulfillment can become blocked by its own completion/uniqueness rules | High — correct before execution build specs | Workflow conflict under the written rules |
| R03 | Offline pickup-to-handoff lacks an identity/version binding contract | High — correct before driver build specs | Missing protocol decision |
| R04 | Freelance acceptance lacks the execution transitions it promises | High — correct before Network build specs | Product/graph disagreement |
| R05 | Disputes have no complete resolution lifecycle | High — correct before dispute build specs | Missing graph exits and outcome rules |
| R06 | Notification privacy policy omits an authorized service writer | High — define before communications integration | Role-policy gap; database execution still required |
| R07 | Departure-gate recomputation has conflicting ownership | Medium — settle before release-handler build specs | Synchronous rule versus generic worker contract |
| R08 | Commands require a proposal version the database does not define | Medium — settle before planner build specs | Contract/storage mismatch |

“High” means that an implementer following the supplied artifacts must invent a rule or violate another artifact. It is not a claim that a deployed application has been exploited or observed failing.

## R01 — Payment contracts use three different status systems

**Evidence**

- `contracts/openapi.json` → `components.schemas.settlement_state`, used by `RecordSettlementPayload.state`: `earned`, `due`, `externally_paid`, `disputed`, `adjusted`.
- The same file → `RecordSettlementData.state` refers to `State_freelance_agreements_state`: `active`, `completed`, `cancelled`, `disputed`.
- `database/ROUNDS-REVIEW-SCHEMA.sql` → `rounds.settlement_records.state`, also mirrored by `STATE-CODES.json`: `guaranteed`, `earned`, `due`, `paid`, `disputed`, `cancelled`.
- `review/CONTRACT-EXAMPLES.json` → `examples.RecordSettlementResult.data.state` is **`active`**, which is not a valid settlement database state.
- `contracts/TRANSITIONS.json` → `TR-244` makes `RecordSettlement` produce `paid`.

**Failure example**

A merchant records an external payment. The request can say `externally_paid`; the database cannot store that status. The database transition says `paid`; the response cannot return `paid`. Even translating the request does not solve the incorrectly typed response. There is no specified mapping that resolves this.

There is a separate lifecycle problem: P15 permits prepayment, and TR-244 permits `guaranteed → paid`, but TR-242 only earns a settlement from `guaranteed`. After prepayment, the graph has no path for subsequently recognizing earnings on that same settlement record. Payment and earning were described as independent facts but implemented as competing values of one state field.

**Correction**

Define one canonical settlement projection and explicit earning/payment/dispute dimensions, with immutable financial events. Alternatively, specify a complete mapping and lifecycle that preserves every promised independent fact. Fix request/response schemas, SQL, graph, examples and earnings calculations together. Define partial payment, adjustment and prepayment behavior; do not let `state=earned` become an unauthorized replacement for the completion trigger.

**Required acceptance**

Record an external payment, return its real settlement state, reload it and reconcile totals. Also test payment before completion, partial payment, later earning, cancellation compensation and a duplicate payment command. The “positive” fixture must correspond to a possible persisted record.

## R02 — Partial fulfillment can deadlock

**Evidence**

- P05, “Missing goods and partial pickup”: collecting a subset creates a remaining obligation that can be planned and fulfilled later.
- `TRANSITIONS.json` → TR-179: completing an attempt requires all remaining obligations resolved.
- TR-141 applies a similar condition to Round completion.
- `ROUNDS-REVIEW-SCHEMA.sql` → `one_active_dropoff` allows only one dropoff per `(tenant_id, delivery_id)` unless the old stop is `completed`, `failed` or `cancelled`. A `handed_over` stop still occupies that unique slot.
- `active_delivery_claims` also has unconditional uniqueness on `(tenant_id, delivery_id)`.
- `GeneratePlanPayload` selects delivery IDs; `plan_move` selects stops/Rounds. Neither defines how to select a particular remaining obligation or quantity slice for a second fulfillment.

**Failure example**

Five units are ordered. Driver S collects three with approval and delivers those three. Two remain at the merchant. The first attempt cannot complete while those two remain unresolved. Planning a second active dropoff for the same delivery conflicts with the unique index. The package does not define a separate obligation-scoped task that avoids this cycle or a permissible way to complete the first attempt independently.

This is an inference from the combined written rules, not a live-database deadlock observation. The unique-index restriction itself is concrete: the index applies to every row matching its predicate. [PostgreSQL partial-index semantics](https://www.postgresql.org/docs/current/indexes-partial.html)

**Correction**

Define the unit of fulfillment below the customer delivery: for example, an obligation/consignment with allocated manifest quantities and its own collection/dropoff work. Complete an attempt against its allocated portion; compute whole-delivery completion from all portions. Scope exclusive claims and stop uniqueness to that unit, while preventing the same quantity from being assigned twice. Preserve the customer delivery ID and sealed evidence.

Specify which Round and driver remain responsible for the residual goods. The first driver's job and payment must not remain indefinitely open merely because another delivery portion will be handled later.

**Required acceptance**

Collect and deliver three of five; finish the first driver's agreed portion; plan and deliver the remaining two with another driver; finish the original delivery once. Test the second allocation before and after the first handoff, plus agreed cancellation of the remaining two. The existing partial-pickup case stops too early to prove this journey.

## R03 — Offline continuation cannot yet be implemented from the supplied identity rules

**Evidence**

- P05 and `COMMAND-CATALOG.json` → `ConfirmPickup`: attempts are created in the pickup transaction, and the driver refetches their IDs before handoff.
- `RecordHandoffPayload` requires a real `attempt_id`.
- `SubmitProofPayload` requires a real `attempt_id` and `handoff_id`.
- `CompleteDeliveryPayload` requires a `proof_submission_id`.
- E04/E05 require durable offline observations with original identity, expected versions and idempotency, including pickup-before-handoff dependencies.
- `DRIVER-LOCAL-SCHEMA.sql` → `command_dependencies` expresses ordering, but no result-to-input binding protocol is specified. `local_observations` could support such a solution, but its conversion rules are not defined.

**Failure example**

The driver loses connectivity before pickup, collects the goods, then hands them to the recipient. The pickup command has not created an attempt on the server. What ID is placed in the locally queued handoff? What handoff ID is attached to proof? When replayed arrival changes the attempt version, which version should the queued handoff use?

“Replay in dependency order” alone does not answer identity substitution or version handling. Blindly refreshing every expected version would also defeat the protection against a genuinely intervening reassignment.

**Correction**

Choose an explicit protocol: preallocated/client-generated stable IDs, or local observation IDs with authenticated result bindings and deterministic command materialization. Specify when the immutable request hash becomes final, how successor versions incorporate only the driver's own successfully replayed predecessors, and what happens if a predecessor is rejected or retained for review. Preserve original observation time and actor throughout.

**Required acceptance**

Disconnect before pickup; collect; arrive; hand over; capture proof; kill and restart the app; reconnect. Verify one pickup, one attempt, one handoff and one completion without manual ID repair. Repeat with response loss and with an intervening reassignment; the latter must retain evidence without silently authorizing the new state.

## R04 — Accepted freelance work has no complete route into execution

**Evidence**

- P07, “V2 search and agreement lifecycle,” promises that acceptance records the agreement, assignment, driver range and offer state atomically.
- `TRANSITIONS.json` gives `RespondOffer` edges only for broadcasts, offers, freelance agreements, driver commitments and settlements.
- It has no `RespondOffer` edge creating an assignment or releasing a Round/its stops.
- TR-140 allows `ConfirmPickup` only from a `released` Round.
- TR-139 assigns the Round release transition to `ReleasePlan`, a planning operation requiring plan/proposal IDs.
- `COMMAND-CATALOG.json` → `RespondOffer.emitted_events` likewise contains no assignment/stop/Round release fact.
- `DriverRoundProjection` requires an assignment ID and assignment version.

**Failure example**

An operator broadcasts an unplanned delivery, and a freelancer accepts it. The product says the driver now has a job. Following the graph literally establishes a fare and busy range but leaves the required execution assignment/release undefined. Routing this through an own-team plan is not specified and does not cover future pickups that are accepted before readiness.

**Correction**

Define the complete acceptance transaction across agreement, assignment, Round, stops, claims and grants. Specify how accepted-but-not-ready work becomes executable when goods are ready, without requiring another acceptance or falsely authorizing collection early. Align the graph and emitted events with that transaction.

**Required acceptance**

Unplanned delivery → operator broadcast → freelancer accepts → driver opens assignment → actual pickup → handoff/proof → completion/earnings. Run a second version where acceptance precedes preparation/receipt readiness.

## R05 — Disputes can strand settlements and evidence

**Evidence**

- `OpenDispute` is an agreement-level finance command. Its events also cover delivery evidence, handoffs and proof submissions.
- `DecideDispute` is owned by P15 and requires `finance.decide`; its declared events are `delivery.evidence_state_complete`, `dispute.decided` and `handoff.corrected`.
- `TRANSITIONS.json` has **no outgoing edge from `settlement_records.state=disputed`**.
- It has **no outgoing edge from `proof_submissions.state=disputed`**.
- A disputed freelance agreement can only leave through `CancelAgreement`; there is no normal resolution back to the appropriate active/completed condition.
- TR-127 can mark the delivery evidence complete on a dispute decision while the proof submission has no corresponding resolution path.

**Failure example**

A completed job is disputed over payment. The operator resolves it and appends an adjustment. Which state closes the settlement dispute? Which state preserves that the job was completed? A POD dispute raises a second question: how can delivery evidence return to complete while its proof submission remains disputed?

**Correction**

Separate the dispute case lifecycle from payment, contractual fulfillment and proof validity. Define permitted outcomes for financial versus physical-evidence disputes, including dismissal, adjustment, upheld claim, corrected evidence and unresolved investigation. Define affected IDs and authority explicitly; a generic finance decision must not be the unspecified evidence-repair mechanism. Preserve prior earned, paid and completed facts.

**Required acceptance**

Resolve a payment-only dispute without changing valid POD. Resolve a proof dispute with an actual authorized evidence decision. Confirm that agreement, settlement, proof and delivery projections are coherent and that a valid resolution is possible without cancelling a completed job.

## R06 — Notification reads were restricted without defining the producer's write path

**Evidence**

- `database/ROLE-POLICIES.sql` → `notification_self` applies to all operations for `rounds_api`.
- Its insert/update check requires both the current tenant and `principal_id=rounds.context_principal()`.
- The file defines no `rounds_broker` policy/grant for `rounds.notifications`, nor a dedicated notification-writer policy.
- ADR-T01 says worker commands use authenticated service principals, and actor context comes from verified identity.

**Failure example**

A service worker handles a release event for driver S. Under the supplied API policy, its service principal cannot insert S's inbox row because the recipient differs from the current principal. The broker definitions do not supply an alternative. Switching the context to S is not a defined delegated-actor protocol.

This is a static role-contract gap, not a claim that the deployed system leaks notifications. PostgreSQL checks new rows against `WITH CHECK`; a false condition rejects the write. [PostgreSQL policy semantics](https://www.postgresql.org/docs/current/sql-createpolicy.html)

**Correction**

Keep private recipient-scoped reads and read-status updates. Define a constrained notification producer, with explicit recipient eligibility, tenant/event binding and audit attribution. Do not reopen tenant-wide inbox reads or casually use a table-owner/BYPASSRLS connection to make writes succeed.

**Required acceptance**

A genuine service principal creates notifications for two eligible recipients. Each sees and marks only their own row. Test an ineligible recipient, cross-tenant event, duplicate event and revoked recipient. Execute this under the actual restricted roles.

## R07 — A safety-relevant gate is simultaneously synchronous and worker-owned

**Evidence**

- P04, “Save, Stage and Release”: departure gates are recomputed after every affecting command **in the same transaction**; they are not timer-owned authorization decisions.
- TR-145–149 name `worker:gate_recompute` as the transition initiator.
- `SERVICE-ACTIONS.json` supplies that worker with the same generic event/provider/operator/timer trigger text used by 100 other service actions.

**Why this matters**

A handler author could maintain the gate synchronously; a worker author could reasonably queue it asynchronously. The latter leaves a window between a readiness/receipt/hold change and the persisted gate. The specs correctly require independent pickup validation, but that does not resolve who owns the gate and its emitted facts.

**Correction**

Specify synchronous gate derivation as part of named domain transactions, with a list of affected inputs and outcome rules. If a background repair/reconciliation operation exists, label it separately; it must not become the primary release authorization mechanism. Give each enabled service action a concrete initiating event/timer, dedupe identity and guard.

**Required acceptance**

Commit a readiness or hold change while delaying all worker processing. The stored gate and next release/pickup decision must already agree with the new inputs. Repeat with concurrent receipt and release.

## R08 — Proposal version validation has no persisted definition

**Evidence**

- `ApplyPlanProposal`, `ReleasePlan` and `ApplyOwnFleetAutomation` require an expected version for `plan_proposals`.
- `PlanProposalView` requires a positive `version`.
- The SQL table has `base_version`, `input_hash` and immutable proposal content, but **no `version` column**. `base_version` is the source plan version, not a defined proposal revision.
- The reference SQL makes proposal rows immutable.

**Correction**

Define proposals explicitly as immutable IDs plus content hash/expiry and source-plan version, exempting them from mutable-root version checks; or define a proposal version convention consistently in storage and projections. A constant version could work for immutable rows, but it must be the specified convention rather than an implementer's guess. Do not reinterpret `base_version` silently.

**Required acceptance**

Generate a proposal, return its complete identity/version metadata, and submit a valid apply/release request using only the documented projection. Change the source plan and confirm rejection without confusing source-plan version with proposal identity.

## Acceptance and consistency cleanup

The package's acceptance register contains 197 written cases. That is useful coverage planning, but it cannot certify a functioning system. The register accurately marks cases unexecuted.

Specific corrections are still necessary:

- `QA-PL-06` requires `PHYSICAL_INCOMPATIBILITY` from `ApplyPlanProposal`, whose allowed errors do not include that code; they include `VEHICLE_INCOMPATIBLE` instead.
- `QA-AD-03` requires `ADDRESS_REVIEW_REQUIRED` from both `StartBroadcast` and `ReleasePlan`; neither command's allowed-error list contains it.
- `QA-IC-04` requires `PHYSICAL_INCOMPATIBILITY` from `BookTrip`; its allowed-error list omits it.
- The payment example in R01 demonstrates why schema-valid synthetic fixtures are insufficient: the fixture uses a status belonging to a different entity.
- The independent count found 101 of 134 service actions sharing the same generic trigger paragraph. The package already acknowledges this weakness; replace it with operationally specific contracts for each enabled release slice.
- The new partial-pickup case proves creation of a remaining obligation, not its eventual planning, fulfillment, settlement and closure.

Not every blank event assertion is a defect: read-only and visual cases may appropriately produce no event. Prioritize exact actors, conditions, affected IDs and event/non-event assertions for consequential journeys.

Smaller contradictions should be removed in the same consolidation: E07's job table still includes template in notification dedupe identity while its later rule excludes it; the operating-decision reschedule row creates the next attempt on release while P05 and the command catalogue create it on pickup. Choose the controlling rule and remove the competing instruction.

## What belongs later, and what still needs a decision

I would not demand production measurements as a prerequisite to calling this a useful specification. PostgreSQL concurrency/RLS tests, generated-client compilation, device field tests and actual provider integration are later implementation/release evidence. Their absence should not be mislabeled as a discovered application bug.

The following decisions should nevertheless remain visible and gated:

- Exact proof requirements and authority for exceptions.
- Commercial waiting/cancellation/return rules, fee trigger and payment-accounting behavior.
- Retention durations and the authorized purge/anonymization pathway, including immutable GPS and legal holds.
- Enabled provider ingress, tracking audience field rules and the native navigation/location field gate.
- Final review of the separate approved Dispatch and Driver screen references.

Some values can remain tenant-configured. The behavior of missing, invalid, changed or revoked configuration still needs a deterministic contract. Provider-specific rollout can remain disabled until its own contracts and tests are finished.

## What this review actually checked

- Read the bodies of all 15 product and 10 engineering documents, the operating/review decisions, and targeted acceptance scenarios.
- Cross-checked the cited commands, payloads, projections, state graphs, service actions, examples, SQL constraints and role policies.
- Executed independent standard-library checks: all 11 JSON files parsed; local references in OpenAPI/event schemas resolved; the supplied driver SQLite DDL executed with 12 tables and `integrity_check=ok`.
- Reproduced the payment enum/fixture contradiction, missing freelance execution transitions, missing dispute exits, expected-version gaps, generic service-trigger reuse and the cited error-code mismatch by reading the actual machine artifacts.
- Verified all 63 extracted source files are byte-for-byte identical to the upload.

**Not executed:** the package's complete validator, full JSON Schema instance validation, PostgreSQL/PostGIS application, Supabase role/realtime execution, generated clients, a running API/worker system, provider calls or native-device tests. PostgreSQL and the package validator's Python dependencies were unavailable in this review environment. The SQL/role findings are source-level analysis pending the stated database tests.

## Recommended next revision

Keep the approved product direction and UI. Correct R01–R08 in a consolidated v2.2, updating product rules, command contracts, graph, SQL and examples together. Add six complete journey specifications: own-team delivery, accepted freelance delivery, partial fulfillment, offline pickup-to-proof replay, dispute resolution, and intercity receipt-to-local fulfillment.

Each journey should name its actors, starting records, exact commands and identifiers, state changes, physical quantities, payment effects and expected events. Include one adverse branch and retry/response-loss behavior. Derive build specs after these journeys can be walked through without inventing missing state, identifiers or authority.

The package is worth improving. Its level of detail is a strong starting point, but detail count and local structural PASS results are not substitutes for consistency between the workflows and their contracts.
