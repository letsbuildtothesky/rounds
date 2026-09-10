# V2.3-r1 configuration defaults and open launch gates

## Reconciliation changelog

- 2026-09-08 · v2.3-r1: Choose explicit durable retry schedule as routine engineering decision ADR-J01.

Entries marked Review below are proposed configuration/test-fixture defaults, not promised service levels. Retry behavior is the adopted engineering decision ADR-J01, not awaiting business approval. The user-approved rules include whole-order pickup and pre-arrival planning. Missing commercial/retention/provider approval yields POLICY_NOT_CONFIGURED for affected irreversible actions; drafting/planning remains available where safe.

| Setting | Proposed default | Allowed bound / validation | Status |
| --- | --- | --- | --- |
| Slot hold | 300 seconds | 60–1,800; max total lifetime 1,800 from initial hold | Review |
| Materialization | 90 days | 1–366 days | Review |
| Slot duration | 3 hours example; actual template required | 60–86,400 actual elapsed seconds; explicit DST ambiguity errors | Tenant config |
| Import source | 20 MB; PDF 100 pages; batch 500 drafts | Hard ceilings 20 MB/100/500 | Review |
| Message attachments | 10 × 20 MB | At most10, each <=20MB; reject policy exceeding schema cap | Review |
| Pickup wait reminder | 300 seconds | 30–1,800; never a payment trigger | Review |
| Contact escalation | 2 failed attempts | 1–5; help always available immediately | Review |
| Search waves | No global radii default | Radius100–100,000m; response10–300s; total30–3,600s; strictly increasing radii | Tenant config |
| Location freshness | 30 seconds | Policy5–300s; UI stale label after threshold | Review |
| Sample/batch/fanout | 5s / 15s / 2s | Field hypotheses; balance battery/network/load | R0 field gate |
| OTP | 5 attempts/300s | 1–10 attempts;60–3,600s; provider additional rate caps respected | Review |
| Availability request | 15 min | 60–86,400s; server expiry | Review |
| Pre-job chat | Off | Driver opts into specific known relationship | Launch decision |
| Proof | Tenant must accept matrix; example manifest+photo+receiver | Receiver/handling-specific required items, explicit GPS outage rule | Tenant setup gate |
| Fees | No invented tariff | Explicit authorized amounts; network fee only from approved numeric config | Owner decision |
| Retention | No arbitrary global duration | Purpose/class/country, legal hold and deletion schedule approved | Owner decision |
| Latency | p95 read400ms / command500ms | Measured on declared representative fixture; core commit excluding async provider work | Proposed SLO |
| Availability/recovery | 99.9%; RPO5min / RTO60min | Restore/load evidence required | Proposed SLO |
| Workload test | 1,000 tracked drivers, 5s sample/15s batches, 50 concurrent operators | 30-min sustained run; see QA-SYSTEM-LOAD | Test fixture, not measured capacity |
| Retry | Five retry delays: 5/30/120/600/1800 seconds after the initial attempt | Deadline and Retry-After take precedence; unknown effects reconcile, never blind resend | Engineering decision ADR-J01 |
| Alerts | Outbox delay2min; proof pending15min | Escalation only, not auto-completion | Review |

Roles and city capabilities remain explicit. Owner/Admin configure scope; Dispatch manages assigned cities; Fleet manager manages shifts/vehicles; Receiver confirms only granted sites; Finance handles authorized records; driver has only assigned-job/self permissions. Administrative role labels never grant another tenant's data. Launch requires approval of country identity/voice/customer channel adapters. Mapbox Operations direction is selected in ADR-M01; motorcycle/truck field behavior and account display/storage rights remain release gates.

CreateTenant establishes owner membership, empty city/site setup and versioned proposed default configurations. Commercial terms, proof acceptance and retention policy are incomplete until explicitly saved by the authorized owner. CommitDelivery requires the active proof-policy version; incomplete setup returns POLICY_NOT_CONFIGURED with the specific setting path. It must never use an UrbanFlowers fixture ID.
