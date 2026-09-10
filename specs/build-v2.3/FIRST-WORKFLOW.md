# W01 — Existing workspace to whole-order delivery and history

Version 1.21 · 2026-09-10 · READY_TO_IMPLEMENT, not implemented end to end or release-approved.

## Changelog

- 1.21 (2026-09-10): mount the ADR-Q06 delivery/context reader in Phase39 cards and limited read-only details, with independent report navigation and responsive/search/stale/Auth tests. Category/map projection and full intake/planning writes remain next; no phone activation.
- 1.20 (2026-09-10): record the default-off Dispatch pickup-report shell and ADR-Q06 read-only delivery-board dependency. Approved delivery-list mounting, category/map projection and full intake/planning writes remain next; no phone activation.
- 1.19 (2026-09-10): add staged tab/login draft and immutable-attempt recovery; own-team drawer reuse approved. Actual host/source/browser/phone acceptance remains separate.
- 1.18 (2026-09-10): implement ADR-Q05 Operations discovery and browser reply/status connection; actual local HTTP/database/Driver test preserves original IDs and avoids duplicate sends. Mounted form/recovery, reload and device activation remain separate.
- 1.17 (2026-09-10): wire staged G03 report/reopen into original issue reads and immediate host loading with last-known/Auth safeguards. Pre-pickup recovery artwork review, Dispatch connection and installed workflow remain separate open gates; no migration or deployment.
- 1.16 (2026-09-10): ADR-Q04/T08 connect original-report Driver reads and real Operations wait/escalate transaction/status. Preserve held orders and old decision data; physical actions and approved host/Dispatch controls remain open. Current test evidence is separate from implementation readiness.
- 1.15 (2026-09-09): stage G03 source-derived choices/evidence and encrypted editable photo/note flow through explicit ReportIssue. Preserve original evidence/assignment and distinguish actual local form/controller tests from recovery/Operations, source and phone activation gates.

- 1.14 (2026-09-09): connect the native pickup-photo purpose adapter, durable original-report camera intent and verified asset materialization into ReportIssue. Reuse the uploader and preserve existing data. Approved G03 mutable form/preview and recovery/decision routes remain the next connection; no phone activation.

- 1.13 (2026-09-09): implement ADR-M04 server pickup-photo binding and verified damaged/wrong report attachment. Preserve old evidence and scope; leave native photo materialization and approved G03 routes as the next concrete connection. No phone/provider activation.

- 1.12 (2026-09-09): complete the original delivery-version dependency and native missing/wait report capture/materialization/status connection (ADR-S09). Keep old snapshots/queues intact. Purpose-bound pickup photos and approved recovery/Operations decision routes are next; no phone activation.

- 1.11 (2026-09-09): implement ADR-T07 pre-pickup ReportIssue, exact current/original scope and immutable report, synchronous package hold and registered HTTP/status/rollback tests. Preserve existing issues, approved UI and installed phone. Native issue/media/decision connections remain unfinished.
- 1.10 (2026-09-09): connect the shared pickup component to durable checklist/confirmation intent and original-arrival status recovery (ADR-S08). Keep full recovery destinations, source comparison, mapped upgrade and phone activation explicit.
- 1.9 (2026-09-09): implement ADR-Q03 authorized pickup display/native presentation seam without inferring parcels or refreshing original execution authority. Keep route command orchestration, unpacked UI and device activation separate.
- 1.8 (2026-09-09): record the first visible English pickup port on the legacy route and centralize current implementation boundaries in the detailed checkpoints; v2.3 data wiring and visual/phone acceptance remain open.

- 1.7: fresh encrypted SQLCipher/photo storage and actual local crash/byte tests implemented; no legacy converter, mobile activation or screen changes.
- 1.6: implement unwired native credentials and read-only Driver5 preflight. Encrypted storage/conversion and phone integration remain unfinished.
- 1.5: server-side registration/renewal/revocation implemented; the issued capability now exercises real pickup/recovery in isolated tests. Native enrollment/storage, provider and queue upgrade remain open.
- 1.4: authenticated pickup/status boundary implemented and locally tested behind an isolated runtime gate; configured Auth, enrollment and client compatibility remain open.
- 1.3: implement first-local pickup with exact wire validation and real custody/attempt/event writes; HTTP and migration remain open.
- 1.2: full isolated schema and real-row tests execute; local R1 preparation does not depend on deferred Intercity.
- 1.1: implement and locally test the W01.2 transaction foundation; preserve the explicit full-schema/handler/client gates.
- 1.0: define the first complete existing-workspace workflow and its six implementation checkpoints.

## Scope and starting condition

Use this repository at baseline `19d6c1e7dc570546026cfb41135fae74c6b4e23e`. Start from an existing configured own-team workspace with explicit city/site, driver/vehicle, recipient contact and approved proof/slot policy. Seed isolated fixtures through controlled test credentials; never use a fake sign-in or fixture ID in production. CreateTenant admission, freelance tariffs and new voice/KYC vendors are not dependencies.

The first complete workflow is manual draft → reviewed address/window → committed whole order → plan expected goods → stage assignment → actual readiness → explicit release → driver pickup → navigation → actual handoff → durable photo → verified proof → completed order/history. Include shortage/hold, lost response and return recovery; a happy path alone is not the workflow.

R1 first uses local orders with no required inbound dependency. SetPickupReadiness records the operator's preparation declaration and synchronously re-evaluates gates; ready_by is not an automatic receipt. Plan/stage may precede preparation. Release and actual driver whole-order confirmation remain separate. Neither planning nor preparation creates custody or receipts. Required inbound orders stay blocked until genuine receipt; deferred R4 execution is never simulated as a production receipt. P02 owns this local path.

## Implementation sequence inside the existing codebase

| Checkpoint | Existing seam and change | Exit evidence |
| --- | --- | --- |
| W01.1 | `packages/domain-ts` whole-order gate; source-derived `packages/contracts/src/v23` metadata. Keep old contracts intact. | Exact line-map/decimal/batch/readiness tests and metadata mirror checks. This increment is not exposed as an HTTP endpoint. |
| W01.2 | `services/api` pinned restricted-role runner + command receipts; isolated schema/mapping. | Real rollback, same-ID replay/conflict, RLS/city scope and original assignment fence tests. Never substitute an in-memory repository for this exit. |
| W01.3 | Adapt existing `delivery-intake.tsx`/create-delivery seam to draft/review/commit and `operations-planning`/capacity/route seams to proposal/stage/release. | No custody before receipt; stable routes and IDs planned before arrival; ready independent orders can leave after explicit adjustment. Phase39 source comparisons. |
| W01.4 | Adapt `driver_api.dart`, pickup and evidence stores to observation/binding/frozen request chain; add new v2.3 handlers. | Exact pickup, correct unit→attempt binding, original-fence retention after reassignment, kill/restart/lost response, private upload verification. |
| W01.5 | Bind existing D03/E02/F01/F03/F08/I01 and Dispatch detail/history to new outcomes; preserve navigation integrations. | Actual actions and back/dismiss/error behavior, original-reference screenshots, delivered only after full handoff and verified proof. |
| W01.6 | Essential shortage/Operations hold/return and migration recovery. | Full D1=5/received3 plus independent complete D2; no partial pickup, fake receipt, residual delivery or lost photo. Incremental return remains supported. |

Dependencies in this table are work to implement, not claims of completed tests. New runtime path remains unavailable until W01.2 and relevant W01.4 compatibility gates pass. Do not relabel the old RPC path v2.3 merely because W01.1 unit tests pass.

## Exact observable acceptance

1. Commit replay returns the same delivery, manifest and one unit. Approved source/card geometry and manual-entry affordance match Phase39.
2. Plan D1 and D2 before inbound arrival. Staging preserves stable plan/Round/stop IDs and says awaiting goods; it cannot record receipt or pickup.
3. D1 requires five; only three are actually available. D2 is fully ready. Combined pickup has zero writes; approval cannot bypass. Explicit adjustment and fresh assignment allow complete D2, not three units of D1. After five are available and ready, D1 collects in full.
4. Every selected manifest line occurs once with exact quantity. Reject missing/extra/duplicate lines/selectors, wrong tenant/stop/unit, negative/nonfinite/out-of-range/overprecision quantities, stale versions and preparation not-ready. Compare valid quantities as integer ten-thousandths.
5. Device can lose response after each commit: recover by original command ID, not new ID. One custody event/attempt per unit. Reassigned offline evidence is retained with an incident and cannot change current work.
6. Physical handoff, saved on phone, uploading, verified and delivered are distinct. Closing/reopening cannot lose the photo; another account cannot access it. History agrees with final proof-backed outcome.
7. Wrong/unavailable recipient opens real issue/recovery. Incremental returns preserve actual custodian balances; no automatic delivery completion or fabricated receiver confirmation.
8. Capture source/app/diff at matched content viewport for every involved state, then physical-device tests. Source syntax/reference examples/unit tests do not replace these gates.

## Current checkpoint reporting

Visible work includes the [English D03/D04 pickup port](W01-PICKUP-UI-CHECKPOINT.md) on the existing route and the [default-off Phase39 Dispatch shell](W01-DISPATCH-BOARD-CHECKPOINT.md) mounting actual city/date delivery/context cards and the independent bounded pickup-report/reply workflow. The ADR-Q06 reader now supplies local search and limited read-only details; full categories, planning and maps are not connected. Neither static source geometry nor synthetic component/Flutter captures replace the still-open original-source/phone comparison. No installed v2.3 route activation is implied.

W01.1 exact whole-order validation and W01.2 restricted database/HTTP execution exist locally. Arrival, pickup, handoff, asset verification, proof and completion are covered by the scoped [transaction checkpoint](W01-TRANSACTION-CHECKPOINT.md). The [native checkpoint](W01-NATIVE-STORAGE-CHECKPOINT.md) records encrypted preservation, authenticated context, camera and bounded original-fence execution/photo queues. The [provider checkpoint](W01-POD-PROVIDER-CHECKPOINT.md) records the Supabase protocol adapter with local doubles, not configured cloud acceptance. Current commands, hashes and results live in [run evidence](generated/test-results.json); prior counts are not current acceptance.

W01.3 intake/planning and W01.5 full screen binding remain unfinished. The authorized display, original-arrival pickup, encrypted G03 form/report/media and native original-issue recovery adapters are staged. ADR-T08 supplies actual wait/escalate writes; ADR-Q05 connects finite city/date Operations discovery, draft/attempt reload and browser reply/status recovery through real local HTTP/SQL into the Driver query. Its approved own-team drawer is mounted in the default-off verified-login host; configured browser/Auth/SQL, dirty-browser reload and source-parity acceptance remain separate. ADR-Q06 supplies board.read-scoped delivery/context/state/position/planning facts, now mounted in source-derived delivery cards without grant widening. Next implement authoritative categories before enabling their counts, and connect maps with provenance. Driver pre-pickup recovery is a separate pending proposal. Other physical decision actions remain disabled. Configured Auth/private storage, mapped legacy conversion, multi-order/branched native execution and phone/provider/source visual evidence remain open. No shared migration, installed-client switch, deployment or push is implied.
