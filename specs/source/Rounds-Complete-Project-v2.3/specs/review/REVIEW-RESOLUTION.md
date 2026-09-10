# V2.3 scope correction

The user has selected complete-order pickup for launch. Split-order execution described in the prior review dispositions below is superseded by decisions/04-COMPLETE-ORDER-LAUNCH.md. The one-unit-per-delivery SQL constraint, disabled partial approval, exact-full-quantity pickup contract and rewritten J03 now define launch. Other V2.2 corrections remain.

## Prior review dispositions (historical context; not split-launch authorization)

# Review resolution — V2.3

8 September 2026. Disposition of the two supplied independent V2.1 reviews and the quoted Grok/Gemini feedback. **Corrected in specifications/source** does not mean tested in PostgreSQL or shipped in the board/app. Original reviews are preserved in inputs/.

## Eight operational findings

| Finding | V2.3 correction | Evidence to review |
| --- | --- | --- |
| R01 — Payment state mismatch | Independent settlement lifecycle, earning and payment states; append-only payment/refund records; prepayment and overpayment/refund handling; typed result | P15; J05; RecordSettlement; SettlementView; settlement_payments |
| R02 — Partial fulfillment deadlock | Fulfillment-unit allocation, quantity conservation, unit-scoped claims/dropoffs, independent attempt completion and residual obligations | P04/P05; J03; V22-INVARIANTS.sql |
| R03 — Offline continuation | Immutable local observations and assignment fence; bind server result IDs by fulfillment unit before materializing dependent commands; retain stale/rejected chains for review | E05; J04; RetainOfflineObservations; driver SQLite |
| R04 — Acceptance into execution | RespondOffer atomically creates agreement, acknowledged freelance assignment, released Round/stops, commitment and settlement; readiness gates remain physical | P07; J02; TRANSITIONS; Event_work_accepted |
| R05 — Dispute exits | Separate financial/evidence cases; explicit resolution and proof restoration/replacement; finance cannot repair rejected evidence | P05/P15; J05; dispute_cases; transitions |
| R06 — Notification producer | Dedicated restricted producer role, eligible recipient/source checks, immutable logical dedupe; recipient reads and read_at updates remain narrow | E08; V22-ROLE-POLICIES.sql |
| R07 — Gate ownership | Departure-gate changes derive synchronously inside their originating transaction; workers notify, never create a safety window | P04/P05; E04; derive:departure_gate |
| R08 — Proposal version | Immutable proposal version 1, persisted check and typed projection; plan base version/policy/input hashes are separate concurrency checks | ApplyPlanProposal; PlanProposalView; V22-INVARIANTS.sql |

## Detailed engineering findings

| Finding | Action and remaining boundary |
| --- | --- |
| Q-01 — Policy discriminants | Aligned all 16 kinds, including map/weather, through payloads, policy schemas and SQL; static parity check passes. |
| Q-02 — Tracking grants | Bound tenant/driver/entitlement identities and active work; self-scoped entitlement reads; position/sample reads recheck grant and entitlement. Global opt-in discovery cannot become an unrelated merchant grant. Real restricted-role and race tests remain required. |
| Q-03 — Notifications | Same correction as R06. Fan-out does not impersonate the recipient. Runtime recipient/source isolation remains a test gate. |
| Q-04 — Event explosion | Removed generated state-label aliases and fake event workers; consolidated critical outcomes into facts with typed identities, worker envelope identity and explicit consumer eligibility/dedupe. Payloads and names validate; exactly-once effects still require implementation tests. |
| Q-05 — Guards/workers | Replaced target-name boilerplate with domain rules, operation-specific critical branches and individually named service triggers. Synchronous derivations are distinguished from durable workers. Six journeys expose the critical dependencies. Release build specs must still turn these into concrete handlers, leases, retry tests and provider reconciliation. |
| Q-06 — Errors | Scoped command/query bindings, SQL constraint/token mapping and ERROR-BINDINGS coverage. Retained evidence is a retained outcome, not an ordinary retryable rejection. Actual exception translation remains unexecuted. |
| Q-07 — Cancel/pause/decline | Explicit CancelRound and receiver DeclineTransfer commands; pause is an operational_hold dimension. Active cancellation requires custody/disposition and consent/compensation obligations resolved. |
| Q-08 — Manifest integrity | Header ownership and cross-manifest line guards extend to returns, transfers, remaining obligations and fulfillment units. SQL parsed; adversarial database inserts remain a gate. |
| Q-09 — Principal privacy | Column grants expose public identity fields only; auth_subject and disabled_at are not exposed by a broad principal SELECT grant. |
| Q-10 — Realtime resolver | Dedicated non-login, non-BYPASSRLS resolver owner with its own auth.uid()-scoped policy; no implicit superuser dependence. Supabase execution is pending. |
| Q-11 — GPS purge | Explicit expiry, scoped holds, dedicated purge/audit roles, immutable audit and replay-safe privileged purge function. Holds serialize with purge. Engineering bounds do not choose a country's legal retention policy; missing approved retention disables raw history capture. |
| Q-12 — Competing prose | Rewrote execution, broadcast, finance and offline narratives; aligned message/policy terms and acceptance ownership. Current codes come from the canonical contracts, not old addenda. |
| Q-13 — Traceability/validation | Corrected mismatched feature ownership; published fixture UUID derivation; removed duplicate UI notes; replaced stale validation claims with actual output; added migration boundary and six journey examples. The legacy acceptance register is retained as written requirements, not promoted to runnable tests. |
| Q-14 — Residual schema/projections | Closed critical kind/role/audience fields, documented extensible code registries, sequential agreement revisions, driver shift overlap, scoped date indexes, sanitized device health and audience-specific tracking projections. Finite generic CRUD results remain appropriate for simple actions; complex execution/payment results are typed. Disabled adapters still require concrete registry/envelope decisions. |

## What is deliberately not claimed

- No PostgreSQL/Supabase application, RLS runtime, simultaneous-transaction race, generated-client compilation or production migration was run in this revision.
- No provider, offline phone lifecycle, battery saver/navigation field harness or actual notification/GPS purge execution was run.
- No Dispatch/Driver HTML was redesigned or certified against these new behaviors.
- The 197 acceptance entries include legacy high-level cases. They must become failure-detecting, release-specific tests during build specification and implementation. The six reference examples are not substitutes for them.
- Voice, verification/KYC/liveness, country-specific routing capabilities and provider display obligations, commerce adapter envelopes, tariffs and approved retention remain gated. Generic contract structure does not enable those products.

## Recommended stopping rule

Review the six journeys and changed invariants first. Correct any demonstrated contradiction before freezing this baseline. Then derive R0 and the own-team R1 build specs with concrete handlers/jobs, migration execution and adversarial tests. Keep freelance/Intercity/provider launch gates visible for their releases. Do not repeatedly expand counts or rewrite the entire product merely to call it perfect.
