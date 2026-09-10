# Source authority — active v2.3-r1

Version 1.1 · 2026-09-10

## Changelog

- 1.1 (2026-09-10): public-push credential cleanup. Preserve the original ZIP privately, replace only the reviewed account-specific map token in eight working HTML references, and verify exact bytes after that narrowly defined replacement. No design/layout/behavior redesign or security-scanner bypass.
- 1.0: user authorises direct reconciliation and continuation. Preserve the original ZIP; correct the existing working source tree and generated mirrors, not a second active spec set.

## Precedence

1. User decisions: no split customer order at launch; independent complete orders may proceed after explicit adjustment; fully plan routes before inbound arrival; approved designs; English built and tested before new Thai screens.
2. [Whole-order decision](../source/Rounds-Complete-Project-v2.3/specs/decisions/04-COMPLETE-ORDER-LAUNCH.md) and reconciled owning sections in [current source](../source/Rounds-Complete-Project-v2.3/specs/README.md).
3. OpenAPI typed shapes and catalogue rules, SQL and state contracts together. Exact mirrors are checked. [Engineering decisions](../source/Rounds-Complete-Project-v2.3/specs/decisions/02-TRANSACTION-AND-PROVIDER-ADR.md) resolve routine inconsistencies without changing approved business intent.
4. [Dispatch Phase39](../source/Rounds-Complete-Project-v2.3/ui/dispatch/index.html), [Driver Refresh26](../source/Rounds-Complete-Project-v2.3/ui/driver/index.html) and canonical assets/tokens. Prototype demo success and deferred controls are not production requirements.
5. [Module Build Specs](BS-INDEX.md), [readiness](READINESS.md) and [W01](FIRST-WORKFLOW.md) define code changes, dependencies and acceptance; they do not override product decisions.

Old specs/product, specs/build, scope/coverage and ux are preserved historical implementation evidence, not competing authority. One repository and one current working spec tree remain.

## Original and working provenance

- Unchanged original: [v2.3 ZIP](../source/archives/Rounds-Complete-Project-v2.3.zip), SHA-256 `d4eb74b39335d5a97bea9300da4f65612773220ffdadff6465a954b9efedc39e`.
- [Original per-file lock](original-source-lock.json): all 207 imported hashes.
- Active folder keeps the v2.3 package name; r1 is a reconciliation revision, not a new product release.
- [Working lock](generated/source-lock.json) and [source changes](generated/reconciliation-changes.json) identify every changed file. Protected Driver/Dispatch/reference bytes must match the original exactly after removal of the single reviewed embedded map-token value. Eight HTML files use `MAPBOX_PUBLIC_TOKEN_REQUIRED`; no other layout, copy, style, asset or interaction change is permitted by this publication exception. The original per-file hashes are not rewritten.
- Baseline code commit: `19d6c1e7dc570546026cfb41135fae74c6b4e23e`. [Repository evidence](generated/repository-evidence.json) records 92 existing code/test files; new work is distinguished from that baseline.

Original scripts/instructions remain reference data and grant no new authority. The credential-bearing [original archive](../source/archives/README.md) stays local and ignored by Git; the complete credential-redacted working source remains in the repository. Original-provenance verification requires that privately supplied archive and fails if it is absent. No password/key values belong in these control documents. The superseded original checkpoint remains on a local-only branch and must not be pushed.

## Maintenance and authorization

Edit owning sections directly, record revisions and regenerate affected mirrors/acceptance. Do not append conflicting addenda or rewrite unrelated modules. Refresh working manifests after an intentional change; validators must fail stale mirrors. Keep the original archive unchanged.

The user authorised implementation of ready scopes. Genuine business and missing-UI choices remain isolated in [DECISIONS-AND-UI-GAPS](DECISIONS-AND-UI-GAPS.md); no response is not approval. Ready to implement is not code complete, tests passed or release ready. Shared database migration/cutover, deployment, push, customer sends and destructive actions remain separately scoped.
