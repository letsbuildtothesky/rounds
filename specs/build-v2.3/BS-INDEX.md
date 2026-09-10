# Build Spec index

Version 1.0 · 2026-09-08 · Active v2.3-r1 implementation ownership index.

## Changelog

- 1.0: link repository-grounded module cards and scoped readiness after in-place reconciliation.

See [readiness](READINESS.md) and [W01](FIRST-WORKFLOW.md). Every module card records the baseline commit, relevant code, retain/adapt/replace, dependencies, migration/offline constraints and acceptance tests. Blocked actions are named separately; later phases are deferred, not removed. Ready does not assert passing tests.

Every row applies with BS-00, BS-12 and BS-13. Detailed source ownership, commands, payloads/results, required roots, versions, errors and events are in [commands.json](generated/commands.json); no command is omitted simply because it is a later release. Paths there are **proposed**, not existing handlers.

| Spec | Implementation ownership | Source owners |
| --- | --- | --- |
| [BS-00](BS-00.md) | Environments, schema, transaction runner, contracts and compatibility | E01–E04 |
| [BS-01](BS-01.md) | Tenancy, capabilities, setup and typed settings | P01/P13, E08 |
| [BS-02](BS-02.md) | Intake, addresses, slots and calendars | P02/P03 |
| [BS-03](BS-03.md) | Planning, staging/release, timelines and changes | P04, P06/P07 change boundaries |
| [BS-04](BS-04.md) | Whole-order execution, custody, proof, issues and recovery | P05 |
| [BS-05](BS-05.md) | Encrypted Driver observations, identity binding and replay | E05/P05 |
| [BS-06](BS-06.md) | Driver identity, shifts, fleet, entry and profile | P06 |
| [BS-07](BS-07.md) | Comms, calls, notifications and durable workers | P09/E07 |
| [BS-08](BS-08.md) | Mapbox, navigation, telemetry, entrances/weather | P10/E06/E10 |
| [BS-09](BS-09.md) | History, exports, commerce, tracking/customer channels | P11/P12 |
| [BS-10](BS-10.md) | Freelance acceptance, consent, settlement and disputes | P07/P15 |
| [BS-11](BS-11.md) | Optional Intercity and receivers | P08 |
| [BS-12](BS-12.md) | Exact-reference UI, screen/state binding and localization | P14/all supplied UI |
| [BS-13](BS-13.md) | Security, release, recovery and evidence | E08/E09 |

## Exhaustive source registers

- [Features: 150](generated/features.json) and [written acceptance: 197](generated/acceptance.json).
- [Commands: 131 including disabled approval](generated/commands.json).
- [Queries and ingress](generated/queries-and-ingress.json).
- [131 tables with owners](generated/tables.json).
- [All transitions/events/consumers](generated/transition-event-index.json).
- [105 service/derived actions](generated/service-actions.json).
- [47 Driver references and reuse leads](generated/driver-screens.json).
- [Readable 47-file Driver checklist](generated/DRIVER-CHECKLIST.md).
- [Static controls in all Driver and Dispatch HTML](generated/ui-controls-static.json).

Queries follow their domain: Workspace/Settings→BS-01; SlotOccurrences→BS-02; Board/Plan→BS-03; Delivery/DriverRound/ReturnTasks/Transfers→BS-04 with BS-03/06; Drivers/DriverHome→BS-06; Conversation/Notifications→BS-07; Entrance/RouteEstimate→BS-08; History/Tracking/Connections→BS-09; Offers/Broadcasts/NetworkSupply/Earnings→BS-10; Trips→BS-11. CommandStatus/OperationStatus/AssetAccess are shared BS-00/04/05/13 boundaries. Location ingress→BS-08; connection events/tracking exchange→BS-09. Every query must have an explicit permission test, not only a UI consumer.

Registers are coverage indexes, not independent changelogs or evidence of implementation. Reconciled working product/schema files are the typed definitions; the original ZIP is provenance only. Apply case-specific failure assertions from module cards and the acceptance matrix, not just a generic happy path.
