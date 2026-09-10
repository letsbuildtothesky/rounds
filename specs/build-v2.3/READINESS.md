# Module readiness — v2.3-r1

Version 1.0 · 2026-09-08 · Rendered from MODULE-READINESS.json.

READY_TO_IMPLEMENT means requirements for the named scope are settled, not code complete or tests passed. Dependencies are implementation work, not necessarily product decisions.

One repository and one current spec set. Later phases remain in full-product scope; they are not secretly dropped.

| Module | Status | Ready/deferred scope |
| --- | --- | --- |
| [BS-00](BS-00.md) | READY_TO_IMPLEMENT | Restricted command infrastructure and versioned contract boundary |
| [BS-01](BS-01.md) | READY_TO_IMPLEMENT | Existing-workspace membership, city/site and typed policy configuration |
| [BS-02](BS-02.md) | READY_TO_IMPLEMENT | Manual draft, address review, slot admission and whole-order commit |
| [BS-03](BS-03.md) | READY_TO_IMPLEMENT | Plan expected complete orders before arrival, stage, then explicitly release ready work |
| [BS-04](BS-04.md) | READY_TO_IMPLEMENT | Whole-order pickup, handoff, proof, completion and essential return/issue recovery |
| [BS-05](BS-05.md) | READY_TO_IMPLEMENT | Observation/binding/materialization architecture and non-destructive queue upgrade |
| [BS-06](BS-06.md) | READY_TO_IMPLEMENT | Own-team identity/invites, shifts, vehicle and profile; Network-specific entry deferred to R3 |
| [BS-07](BS-07.md) | READY_TO_IMPLEMENT | Text/media/voice-note conversations and durable notification workers |
| [BS-08](BS-08.md) | READY_TO_IMPLEMENT | Existing Mapbox/Google boundaries, exact controls, safe telemetry and unavailable weather states |
| [BS-09](BS-09.md) | READY_TO_IMPLEMENT | Whole-order history, safe exports, adapter contracts and tracking privacy |
| [BS-10](BS-10.md) | DEFERRED | R3 freelance acceptance, agreement changes and direct settlement; retained in full-product plan |
| [BS-11](BS-11.md) | DEFERRED | R4 optional Intercity transport/receiver execution; pre-arrival planning is already required in BS-03 |
| [BS-12](BS-12.md) | READY_TO_IMPLEMENT | Port existing English references and bind their real actions; proposed missing states await review |
| [BS-13](BS-13.md) | READY_TO_IMPLEMENT | Isolation, evidence safety, migration verification and release gates |

## Isolated blocked decisions

See [DECISIONS-AND-UI-GAPS](DECISIONS-AND-UI-GAPS.md): CreateTenant admission, live policy/provider choices and genuinely absent UI variants are BLOCKED_BY_DECISION for their affected scope only. They do not block W01 using an existing configured tenant. R3/R4 and new Thai work are DEFERRED as described in the release plan.

## First implementation

[W01: own-team whole-order workflow](FIRST-WORKFLOW.md). The first code increment is the exact whole-order precondition gate and its source-derived metadata, not a claim of completed HTTP/DB/phone wiring.
