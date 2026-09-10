# Database application and migration boundary — V2.3

Working revision v2.3-r1 · 2026-09-08: execute the full fresh PostgreSQL17.11/PostGIS3.5.6 schema locally, correct the complete-order application order, and retain the untested legacy-client cutover boundary.

These files are a fresh reference schema for review. No deployed V2.1 database has been identified or upgraded. V22 files extend this package's revised base schema; they are **not safe standalone migrations against an arbitrary V2.1 installation**.

## Fresh PostgreSQL review pair

Version pair: empty isolated database (`review-0000`) → complete V2.3 reference (`review-0001-v2.3`). Provision required PostgreSQL/PostGIS extensions and role-creation privileges in the isolated review environment. Apply in this order:

1. ROUNDS-REVIEW-SCHEMA.sql
2. V22-INVARIANTS.sql
3. V23-COMPLETE-ORDER.sql
4. ROLE-POLICIES.sql
5. V22-ROLE-POLICIES.sql
6. SUPABASE-REALTIME-POLICIES.sql separately in a Supabase environment with real auth/realtime schemas.

The repository's full PostGIS fixture now applies steps1–5 without stripping any statement, installs131tables and records source hashes/versions. Restricted-role whole-order, foreign-key, seal, replay/rollback and original-assignment probes run against those tables. This is a fresh-schema test, not a migration of the existing public database, Supabase Auth/Realtime acceptance or all-business-command proof.

Validate schema application, role ownership/membership, RLS, triggers, constraints and command transaction behavior before any readiness claim. Syntax parsing cannot prove dependency order or privileges. For an empty disposable review database, rollback means discarding that isolated database and rebuilding it; it is not a production down migration.

## Driver local model

DRIVER-LOCAL-SCHEMA.sql is the complete clean reference SQLite schema at user_version2; previous reference version1 is not the installed app. The actual repository Driver database is version5. Its tested upgrade and field mapping must preserve pending outbox, observations, assets and local messages, add observation_bindings and execution_fences, and quarantine legacy unresolved chains whose original assignment fence cannot be established. Do not downgrade the app to reference version2 or manufacture current assignment versions for old observations. Transactional upgrade and crash/restart tests remain required; clean reference-schema execution is not that upgrade.

## Later production build specification

Before upgrading an actual deployment, identify its exact schema hash/version, migration history, role ownership and pending offline clients. Produce an expand/backfill/validate/contract migration for that concrete source → target pair. Reconcile existing partial deliveries into quantity-conserving units and validate foreign keys before making them mandatory. Provide old/new API compatibility, backup/restore and forward-repair procedures. Never silently drop evidence or claim rollback compatibility for clients that already emitted version-2 observations.

These production migration files and their runtime proof belong in the later build/release package. No live data transformation or destructive rollback is authorized by this reference document.

## Complete-order enforcement

V23-COMPLETE-ORDER.sql makes fulfillment_units one-to-one with deliveries and prohibits child/residual units. Deferred checks on deliveries, units, manifests, manifest lines and unit lines require every current manifest line to have its full allocation, including manifest-only changes and omitted allocations. Legitimate matching revisions can commit together. ConfirmPickup must still validate exact submitted quantities and physical readiness before custody mutation. Fresh reference only; production migration remains a build/release task.
