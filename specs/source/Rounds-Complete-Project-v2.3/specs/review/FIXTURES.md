# Acceptance fixtures retained in V2.3

Logical names below are stable fixture aliases. Fixture IDs are published in FIXTURE-IDS.json. Derivation: UUIDv5 using UUID namespace URL `6ba7b811-9dad-11d1-80b4-00c04fd430c8` and the exact UTF-8 name `rounds-spec-v2.1-fixture/` + alias. This preserves existing fixture identity; it is not a production ID convention. Times are Asia/Bangkok unless stated; business date 2026-09-09, initial server time 07:00. None are live user orders.

Tenant A and Tenant B are isolated. Tenant A cities Bangkok/Hua Hin, brands B1/B2, origin site O1 and destination hub H1. Operator OA has both A cities; OH only Hua Hin; OB only tenant B. S and N are team drivers. F1/F2 are eligible freelancers open for work. Receiver RH can receive at H1; S has no RH identity or site-receiver permission. Merchant MA can set preparation readiness.

D1–D5 are five distinct deliveries with one unit each, manifests M1–M5 and line IDs L1–L5; trip T1 carries all five from O1 to H1, ETA09:00. R1 contains D1–D3 and R2 D4–D5. Every delivery has reviewed entrance, proof policy PV1, promised 10:00–12:00. At 07:00 there are zero H1 received units. Receiver later receives L1,L2,L4,L5; L3 is missing. Separate partial-quantity fixture DQ has line LQ expected 5 and source balance 5.

Bike V1 max_stops 3, unit capacity 5; van V2 capacity 20. Service 5min/stop, return 20min/reload 10min where named. S/N shifts 07:00–17:00. Plan date is the fixture business date. Slot SL1 capacity 1, cutoff 08:00, window 10:00–12:00; hold 300s, total lifetime 1800s. Two approved drafts DA/DB compete for SL1. Alternate slot SL2 has capacity 1, window 13:00–15:00.

Initial versions are 1. Each committed aggregate mutation increments its version once; tests fetch new versions before subsequent normal commands. Race tests intentionally use the same base version. Every replay repeats exact command_id and payload; new physical receipt uses a new command_id. Fake provider supports success, failure, timeout-after-accept and duplicate receipts. Profile/schema-only tests do not certify real provider performance.


FIXTURE-IDS.json fixes the UUID for every named alias; harnesses must use that mapping. R3 is a spare unstarted route, S1 the R1 pickup stop, H2 an alternate Hua Hin site. IQ is DQ missing-goods issue, Q1 an availability request, EN1 the entrance, TE1 the collection entitlement, MQ the DQ manifest, GA the tenant location grant, PK1 a package, A1/A2 agreements, BK1 a booking. Named fixture setup must create the relevant typed record before action; IDs alone are not a seed database. All times are Asia/Bangkok unless explicitly UTC.
