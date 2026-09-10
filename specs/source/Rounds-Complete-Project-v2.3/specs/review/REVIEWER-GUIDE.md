# Independent reviewer guide — V2.3

Review the current specs/ folder in the combined project. Historical source archives are reference only. Start with README and REVIEW-RESOLUTION, then all P/E documents and the six journeys. Check prose against OpenAPI, STATE-CODES, TRANSITIONS, DOMAIN-RULES, consumer/worker definitions and SQL.

## Priority walkthroughs

1. J01: own-team intake → slot → staged assignment → release → pickup → handoff → proof → completion, including duplicate commands.
2. J02: operator broadcasts without own-capacity permission; one freelancer wins and can execute without a missing assignment or second acceptance.
- Launch rule: each delivery is collected as its complete current manifest. One internal fulfillment unit represents the whole delivery; it cannot be split or independently assigned in portions. Missing required quantities block that delivery only. Other complete deliveries may proceed after explicit route/assignment adjustment. Pre-arrival planning remains allowed. Partial inbound/return receipts and actual damage or loss are recorded truthfully; they never authorize short pickup or automatic remainder delivery.
4. J04: pickup and later actions while offline; bind missing server IDs after reconnect; preserve the original assignment fence through a reassignment conflict.
5. J05: external prepayment, earning, dispute adjustment and refund; financial resolution must not change evidence validity.
6. J06: plan destination rounds before truck arrival; partial receipt unlocks independent received units only; late truck does not silently reschedule a freelancer.

For each, challenge actors/permissions, exact identities, versions, quantities, retained/rejected results, replay, event dedupe and terminal recovery paths. Reachable state codes alone do not prove valid business behavior.

## Reproduce checks

Install the pinned dependencies in requirements-validation.txt. From specs/ run:

```bash
python review/validate_package.py
python review/validate_journey_examples.py
```

Both are read-only. See VALIDATION.md and the captured stdout files for the exact checks and limitations. The example checks are intentionally small reference models/schema tests; they are not an application.

## Next independent execution

Use the exact SQL order and fresh-schema boundary in database/MIGRATION-BOUNDARY.md. Apply to an isolated PostgreSQL/PostGIS instance under realistic migration ownership. Exercise restricted API, broker, notification, entitlement, retention and resolver roles; do not use a superuser as the application actor. Test notification fan-out, same-driver/tenant grants, off-duty revocation, manifest/unit conservation, immutable proposals/agreements, concurrent acceptance, offline replay and purge/hold races. Test the separate realtime file in actual Supabase, not only a simulated auth schema.

Validate TypeScript/Dart client generation from finite responses; run the phone harness and board/driver alignment separately. Historical reviewer database results describe V2.1 only and cannot certify V2.3.

Return findings with file/schema/command, contradictory rules or reproducible failure, operational impact, correction and an acceptance case. Separate a missing product decision from a build task or launch gate. Build specs are the next artifact after this specification review, not an assumed part of this archive.
