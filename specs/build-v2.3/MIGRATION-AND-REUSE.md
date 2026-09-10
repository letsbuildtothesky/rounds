# Existing-build reuse and migration

Version 1.6 · 2026-09-10 · Active migration contract; local encrypted legacy archive implemented, no active-client/shared migration.

## Changelog

- 1.6 (2026-09-10): ADR-T08 migration0008 preserves original issue decisions, adds nullable reason and narrow Operations report SELECT. Test an actual old-schema upgrade; no rewrite of prior migrations, Driver5 or shared database.
- 1.5: implement exact-byte legacy preservation into unassigned encrypted quarantine, scoped draft/media scanning and resumable preservation receipts. Semantic mapping, mobile/broker verification and cutover remain gated.
- 1.4: fresh encrypted working store implemented separately from Driver5; byte/crash evidence is not a legacy conversion receipt. Unknown old owners must not become the current principal's data.
- 1.3: implement read-only Driver5 row inventory and prove fixture DB/photo preservation. Record field mapping requirements without pretending the importer/encryption are complete.
- 1.2: full fresh PostGIS schema executes; existing-data mapping, Driver5 upgrade and cohort cutover remain unimplemented.
- 1.1: record the tested empty-fixture receipt-scope migration and preserve the full PostGIS/backfill/cutover gates.
- 1.0: record actual version-5 Driver storage baseline, one-writer compatibility and module-specific reuse cards; implementation authorized without authorizing cutover.

## Preserve

Baseline commit19d6c1e7dc570546026cfb41135fae74c6b4e23e and all current migration history, local queues, media and application IDs. Work in this same repository; isolated environment/cutover remains separately gated. [Module cards](READINESS.md) contain verified code paths and per-module compatibility requirements. Do not require a new GitHub repository. Existing main is a reference, not evidence that v2.3 is installed.

| Existing path | Treatment / required proof |
| --- | --- |
| `apps/operations-web/app/operations-map.tsx`, map helpers | Reuse candidate: Mapbox lifecycle, camera and geographic markers. Rebind to scoped v2.3 projections; compare Phase39 controls and verify provider provenance. |
| `apps/operations-web/app/communications-panel.tsx`, `use-operations-communications.ts` | Reuse media/draft/realtime mechanics where suitable. Replace thread identity with job/relationship conversations; compare new floating/tray interactions. |
| `apps/operations-web/app/operations-workstation.tsx`, oldv45 CSS | Refactor projection/state orchestration and port exact approved current layout. Do not keep old layout merely because data wiring works. |
| `apps/driver_harness` native navigation, geolocator, camera, recorder, upload utilities | Retain proven integration knowledge; confirm new lifecycle/auth/evidence contracts. No claim existing plugin tests cover three device classes. |
| `lib/src/ui/*`, design/theme/goldens | Reuse behavioural primitives selectively. Rebase reference measurements and goldens to supplied Refresh26 English states; old goldens remain history, not target. |
| `lib/src/storage/driver_command_outbox.dart`, POD outbox | Replace queue orchestration with BS-05 observations/bindings/fences; preserve eligible local bytes and IDs via tested migration. |
| `services/api/src/supabase-gateway.ts`, old RPC command handlers | Replace business transactions with restricted TypeScript connection-owned transactions. Storage/Auth adapters may remain; do not route new core mutations through admin RPC. |
| `packages/contracts`, `packages/domain-ts` | Separate generated v2.3 contracts from handwritten legacy shapes. Reuse invariant tests only after adapting assertions to new rules. |
| `services/location_ingest` | Reuse batch/freshness algorithms after entitlement/bounds tests; align service hosting/worker model without one transaction per point. |
| `supabase/migrations`, tests, `field/`, `docs/` | Immutable migration/evidence history; write new forward migrations after actual source mapping. Never rewrite applied SQL to make history match a new schema. |

## Schema path

ADR-T08's isolated [migration0008](../../services/api/migrations/v23/0008-issue-decision-reason.sql) follows0006/0007. Existing issue_decisions retain every field; reason is newly nullable with no fabricated backfill. The only added report policy permits SELECT for current active tenant/city issues.decide grants; original actor-only INSERT and immutable guards stay. Tests construct a pre-0008 schema with existing decisions, apply the forward migration, compare all fields and test both role denial and immutable-history protection. No local schema, old queues/photos, legacy public tables or active-client data is touched. This narrow upgrade test is not an old-deployment→v2.3 cutover test.

First isolated fresh-schema execution uses the source MIGRATION-BOUNDARY order: base → V22 invariants → V23 complete-order → role policies → V22 role policies; Supabase realtime policies separately in an actual Supabase environment. PostgreSQL/PostGIS versions, extensions, role ownership and privileges must be pinned and tested. Generic SQLite/SQL syntax checks are insufficient.

W01.2 retains the five-table native PostgreSQL17.10 foundation and adds the complete fresh131-table PostgreSQL17.11/PostGIS3.5.6 fixture. Neither is an existing-data migration. The local `services/api/migrations/v23/0001-command-receipt-scope.sql` upgrade refuses populated receipts and must not be applied to legacy public tables. Existing receipt city scope must be proven or preserved for recovery, never guessed. Actual field mapping/backfill and Driver5 queue upgrade are still required before client switching. [Checkpoint and tests](W01-TRANSACTION-CHECKPOINT.md).

Then map the actual old deployment: tenant/principal/auth identities, cities/sites, promises/timezones, deliveries/manifests/lines, stops/rounds/assignments, pickups/custody, handoff/proof/assets, messages, command receipts and outstanding local actions. Produce source→target mapping with counts, checksums, ambiguity reason and retained source ID. Existing status cannot establish a physical event or external acceptance. Do not fill missing handoff/assignment history using fabricated current IDs.

Recommended cutover is one writer per cohort/tenant: isolated staging first, then an explicitly scheduled switch after pending clients are reconciled. No unreviewed dual-write to old public tables and new rounds schema. Read-only shadow comparisons can check identities, balances and metrics before switching. Rollback before new writes may select the old build; after new observations exist, rollback requires proven compatibility or forward repair—not reinstalling an old app over a new queue.

## Driver upgrade

The [native checkpoint](W01-NATIVE-STORAGE-CHECKPOINT.md) records concrete source-to-target fields and the implemented preflight. It opens an explicit existing database read-only, inventories all seven application tables and flags missing per-record ownership/fences. The preflight does not copy/delete files, invent authority or activate replay. The separate ADR-U02 preservation archive now copies exact legacy DB bytes, allowlisted raw drafts and six owned media roots into SQLCipher quarantine; source issues stay explicit and no account inherits the data. The per-principal SQLCipher/AES-GCM working store remains separate. Mobile encryption/backup verification, paused-writer lifecycle integration, secure-marker identity reconciliation and verified mapping into new observations still gate the actual client upgrade. The archive provides no read/export/replay/delete or cutover API; its sealed receipt is preservation evidence only, including any missing/unsafe-source issues.

The baseline harness_database.dart declares schema version 5. Also read the installed app version before upgrade; do not assume it equals the 14-table clean reference's user_version2. Preserve original ownership, timestamps, endpoint/request identity and local files. Map only provable old chains; ambiguous original-assignment fences go to quarantined recovery, not silent reauthorization. Test kill at every file/database transition and upgrade with pending/unknown/uploading work. Another account must not unlock the previous user's evidence. Rename `driver_harness` to target `driver-app` only as a mechanical reviewed step; preserve package ID, signing and OS data sandbox unless a deliberate migration requires otherwise.

## Cutover evidence

Require DB+object backups and restore drill; contract compatibility; per-table counts and custody/proof reconciliation; generated-client compile; two-tenant/city roles; old/new event/idempotency replay; offline-upgrade and abort plan; provider receipts with resend suppression; approved environment secrets. Any uncertain evidence is retained with an incident mapping. Do not delete material source or media during implementation or cutover without explicit, recoverable migration approval.
