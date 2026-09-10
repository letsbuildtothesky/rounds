# Rounds — consolidated specifications V2.3-r1

## Changelog

- V2.3-r1 · 2026-09-08: reconcile whole-order rules, historic-only edges, pickup-readiness errors, retry/deduplication defaults and generated root mirrors against the repository; isolate workspace admission. [Active Build Specs](../../../build-v2.3/README.md) include module baselines and acceptance gates. UI/assets unchanged; original ZIP retained separately.

**V2.3 change:** complete-order pickup is mandatory at launch; splitting an order is deferred. Read [launch decision](decisions/04-COMPLETE-ORDER-LAUNCH.md). 131 endpoint contracts include one reserved/disabled ApprovePartialPickup endpoint; it is not an active launch capability.

8 September 2026. **This is the current specification set. It supersedes V2.1 for specification review.** In the complete project, it lives in `specs/`; the approved Dispatch and supplied Driver screen pack live in `ui/`. No earlier Foundation ZIP is needed.

## Start here

1. [Review resolution](review/REVIEW-RESOLUTION.md): what changed against each reviewer finding, and remaining gates.
2. Read **product/P01–P15** for operating behavior, then **engineering/E01–E10** for architecture and engineering constraints.
3. Walk the six complete scenarios in **journeys/** against the typed **contracts/** and reference **database/** files.
4. Read [validation](review/VALIDATION.md), [reviewer guide](review/REVIEWER-GUIDE.md) and [UI follow-through](review/BOARD-FOLLOW-THROUGH.md).
5. Follow the repository's [module readiness](../../../build-v2.3/READINESS.md) and [first workflow](../../../build-v2.3/FIRST-WORKFLOW.md). Build readiness does not imply a running v2.3 application or passing device/database acceptance.

## Main corrections

- Launch rule: each delivery is collected as its complete current manifest. One internal fulfillment unit represents the whole delivery; it cannot be split or independently assigned in portions. Missing required quantities block that delivery only. Other complete deliveries may proceed after explicit route/assignment adjustment. Pre-arrival planning remains allowed. Partial inbound/return receipts and actual damage or loss are recorded truthfully; they never authorize short pickup or automatic remainder delivery.
- Define offline observation identities, dependency/result binding and an immutable original-assignment fence; stale evidence is retained for review.
- Make freelance acceptance create the acknowledged assignment and executable released route atomically, with collection still gated by actual readiness.
- Separate earning, payment and dispute lifecycles, including prepayment, refunds and evidence-dispute recovery.
- Add restricted notification production, grant/entitlement identity checks, narrow principal access, explicit realtime resolver ownership and a privileged GPS purge path with holds.
- Consolidate fact events, specify consumers/dedupe and worker triggers, align policy/error contracts and make departure readiness synchronous.
- Preserve complete pre-arrival route planning and independent partial-receipt readiness.

## Inventory

| Area | Current contents |
| --- | --- |
| Product / engineering | 15 product and 10 engineering documents |
| API | 130 available/reserved-for-existing-release endpoints plus one disabled partial-pickup endpoint; 26 queries |
| Lifecycle / events | 62 state families; 373 transition rows; 221 fact-event schemas; 105 service/derived actions |
| Policies / database | 16 policy families; 131 relational tables; 14 driver SQLite tables |
| Review | 150 feature mappings; 197 written acceptance entries; 352 synthetic contract examples |
| Journeys | Six worked operational scenarios and six executable reference examples |

Counts are inventory, not proof of correctness. The 197 acceptance entries have not been executed against an application. Reference examples exercise small invariants and schema/graph relationships only.

## Authority and scope

The explicit operating decisions control product intent. OpenAPI is the typed HTTP authority; generated catalogues must match it. STATE-CODES and TRANSITIONS own persisted lifecycle codes; DOMAIN-RULES supplies domain predicates. SQL and those contracts must agree; report a disagreement instead of choosing one silently. Code registries and disabled provider surfaces have explicit enablement gates.

Rounds remains a multi-tenant SaaS. Broadcasting is an operator decision targeting eligible freelancers open for work, independent of own-fleet spare capacity. Own drivers receive team instructions. Intercity is optional. Manual Add Delivery remains alongside optional AI autofill; corrected Thai address facts require visible review. Lalamove, temperature and other deferred surfaces are not restored.

The approved UI files are preserved, not updated to implement V2.3 behavior. Review their outstanding alignment in BOARD-FOLLOW-THROUGH. [Migration boundary](database/MIGRATION-BOUNDARY.md) distinguishes this fresh reference schema from a production upgrade.

## Product specifications

- [P01 — Product Tenancy and Authority](product/P01-PRODUCT-TENANCY-AND-AUTHORITY.md)
- [P02 — Delivery Intake and Address Review](product/P02-DELIVERY-INTAKE-AND-ADDRESS-REVIEW.md)
- [P03 — Delivery Slots and Operating Calendars](product/P03-DELIVERY-SLOTS-AND-OPERATING-CALENDARS.md)
- [P04 — Planning Routing and Team Release](product/P04-PLANNING-ROUTING-AND-TEAM-RELEASE.md)
- [P05 — Execution Custody Proof and Exceptions](product/P05-EXECUTION-CUSTODY-PROOF-AND-EXCEPTIONS.md)
- [P06 — Driver Identity Fleet and Work Modes](product/P06-DRIVER-IDENTITY-FLEET-AND-WORK-MODES.md)
- [P07 — Freelance Broadcast Acceptance and Changes](product/P07-FREELANCE-BROADCAST-ACCEPTANCE-AND-CHANGES.md)
- [P08 — Intercity Transport and Handoffs](product/P08-INTERCITY-TRANSPORT-AND-HANDOFFS.md)
- [P09 — Messages Calls and Notifications](product/P09-MESSAGES-CALLS-AND-NOTIFICATIONS.md)
- [P10 — Maps Navigation and Location Knowledge](product/P10-MAPS-NAVIGATION-AND-LOCATION-KNOWLEDGE.md)
- [P11 — History Investigation and Exports](product/P11-HISTORY-INVESTIGATION-AND-EXPORTS.md)
- [P12 — Commerce Tracking and Customer Communication](product/P12-COMMERCE-TRACKING-AND-CUSTOMER-COMMUNICATION.md)
- [P13 — Settings Policy and Administration](product/P13-SETTINGS-POLICY-AND-ADMINISTRATION.md)
- [P14 — Approved UX Driver Coverage and Localization](product/P14-APPROVED-UX-DRIVER-COVERAGE-AND-LOCALIZATION.md)
- [P15 — Commercial Ledger and Deferred Scope](product/P15-COMMERCIAL-LEDGER-AND-DEFERRED-SCOPE.md)

## Engineering specifications

- [E01 — Architecture and Deployment](engineering/E01-ARCHITECTURE-AND-DEPLOYMENT.md)
- [E02 — Database Design and Invariants](engineering/E02-DATABASE-DESIGN-AND-INVARIANTS.md)
- [E03 — HTTP API and Read Projections](engineering/E03-HTTP-API-AND-READ-PROJECTIONS.md)
- [E04 — Commands Transactions Events and Concurrency](engineering/E04-COMMANDS-TRANSACTIONS-EVENTS-AND-CONCURRENCY.md)
- [E05 — Driver Offline Storage and Evidence](engineering/E05-DRIVER-OFFLINE-STORAGE-AND-EVIDENCE.md)
- [E06 — Telemetry Realtime and Native Lifecycle](engineering/E06-TELEMETRY-REALTIME-AND-NATIVE-LIFECYCLE.md)
- [E07 — Background Jobs Adapters and Recovery](engineering/E07-BACKGROUND-JOBS-ADAPTERS-AND-RECOVERY.md)
- [E08 — Security Permissions and Data Lifecycle](engineering/E08-SECURITY-PERMISSIONS-AND-DATA-LIFECYCLE.md)
- [E09 — Testing Migration Release and Operations](engineering/E09-TESTING-MIGRATION-RELEASE-AND-OPERATIONS.md)
- [E10 — Provider Decisions Sources and Open Gates](engineering/E10-PROVIDER-DECISIONS-SOURCES-AND-OPEN-GATES.md)
