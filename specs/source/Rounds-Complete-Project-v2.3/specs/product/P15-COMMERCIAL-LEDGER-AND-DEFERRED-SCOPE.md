# P15 — Commercial Ledger and Deferred Scope

Consolidated V2.3 specification · 8 September 2026

## Commercial scope

Rounds business subscription and configured fixed Network-use fees remain separate from product GMV, guaranteed freelance fare and team payroll. No percentage commission, wallet, COD or bank-transfer execution is introduced. Merchant and driver settle directly; Rounds records authorized evidence of that settlement.

Prices, taxes and waiting/cancellation/return compensation schedules require an approved commercial configuration before the affected automatic charge or adjustment is enabled. Missing configuration gives POLICY_NOT_CONFIGURED, never an invented tariff. Customer-paid redelivery and self-service address/reschedule changes remain deferred.

## Independent settlement dimensions

A settlement has lifecycle open/closed/cancelled, earning_state unearned/earned/void, and derived payment_state unpaid/partially_paid/paid/overpaid. The original amount_minor is the guaranteed fare. Authorized immutable adjustments change current entitlement; earned_minor records the portion actually earned under the accepted scope. Disputes are separate cases and do not replace these facts.

Net paid is the sum of payment entries minus refund entries. Every entry has positive integer minor units, one currency, immutable command ID and unique external reference within its settlement/direction. RecordSettlement only records external payment/refund evidence; it cannot mark work earned or initiate payment. Refund cannot exceed net paid.

Payment classification compares net paid with current nonnegative entitlement: zero net paid is unpaid; a positive smaller amount is partially_paid; equality is paid; excess is overpaid. due_minor=max(earned_minor-net_paid,0). refund_due_minor=max(net_paid-final_entitlement,0) once final entitlement is established. Prepayment can be paid while earning_state remains unearned; later completion earns the agreed amount without losing the payment.

A settlement closes only after final entitlement is established, all financial cases are resolved and due/refund_due are zero. Cancellation can void unearned entitlement, but prepaid funds still need a recorded refund before closure. Authorized compensable cancellation can instead establish earnings. Never infer a refund from cancelling a job.

## Partial work and earning

Round completion earns its current accepted scope under the configured agreement. Launch assignments contain complete deliveries, never separately priced portions of one delivery. Waiting, cancellation, returns and failed attempts use the existing agreed compensation rules; a shortage does not create another delivery fee or automatic second agreement.

## Typed disputes

OpenDispute creates financial or evidence case with one matching target: agreement or proof submission. Case lifecycle is open/investigating/decided/closed. A financial reviewer may dismiss or append an authorized adjustment; valid POD and physical completion remain unchanged. An evidence reviewer may uphold, reject or adopt verified replacement evidence. Finance authority does not confer proof-review authority.

DecideDispute validates kind, target and permission; records actor/reason/outcome; applies authorized effects and closes the case atomically. A completed agreement stays completed. An upheld proof returns to its recorded prior validity; a rejected proof requires genuine replacement and remains visibly incomplete. Disputes do not create photographs, custody or earnings by assumption.

## Subscription and metering

Meter a configured, approved business event once using immutable usage identity. Retries, offer expiry and notification delivery cannot create extra Network fees. No fee consumer is enabled until its trigger and tariff are selected. Provider invoice reference, corrections and entitlement suspension are auditable. Suspension preserves recovery of accepted physical obligations.

## Deferred modules

Rounds Direct remains a future merchant ordering/channel concept using canonical intake/slots. Deferred scope includes Lalamove/external booking, temperature hardware and validated cold holding, reputation/on-route ranking, other-country rollout, building visit grouping, florist inventory/waste, customer marketplace, COD and payout execution. Retain compatible historical evidence without exposing an unimplemented active module. Tenant-configured cities do not certify Vietnam/China/provider rollout.

### QA-BC-15

Actor: Authorized actor for DecideDispute,RecordSettlement; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute DecideDispute,RecordSettlement under the condition in expected outcome; query affected records and compare committed events..

Then: Earned amount and paid reference are separate facts; authorized dispute adjustment appends an event and does not overwrite original amount..

Status: written requirement; application execution pending.

### QA-DF-01

Actor: Authorized actor for Deferred; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute Deferred under the condition in expected outcome; query affected records and compare committed events..

Then: No Lalamove/external booking command is offered in current release; historical provider records remain readable..

Status: written requirement; application execution pending.

### QA-DF-02

Actor: Authorized actor for Deferred; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute Deferred under the condition in expected outcome; query affected records and compare committed events..

Then: No live sensor ingestion/temperature alert contract is implied by handling notes..

Status: written requirement; application execution pending.

### QA-DF-03

Actor: Authorized actor for Deferred; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute Deferred under the condition in expected outcome; query affected records and compare committed events..

Then: No unvalidated packaging/holding duration is labelled safe by the software..

Status: written requirement; application execution pending.

### QA-DF-04

Actor: Authorized actor for Deferred; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute Deferred under the condition in expected outcome; query affected records and compare committed events..

Then: No automatic Vietnam/China rollout is enabled merely by configuring a city label..

Status: written requirement; application execution pending.

### QA-DF-05

Actor: Authorized actor for Deferred; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute Deferred under the condition in expected outcome; query affected records and compare committed events..

Then: Building-level grouping, reputation ranking and on-route matching stay outside active V2 commands..

Status: written requirement; application execution pending.

### QA-DF-06

Actor: Authorized actor for Deferred; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute Deferred under the condition in expected outcome; query affected records and compare committed events..

Then: No florist inventory/recipe/waste plugin is part of Rounds dispatch scope..

Status: written requirement; application execution pending.
