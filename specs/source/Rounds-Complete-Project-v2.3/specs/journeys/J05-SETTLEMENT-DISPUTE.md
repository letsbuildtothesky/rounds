# J05-SETTLEMENT-DISPUTE — Prepayment, earning and typed dispute resolution

Status: complete written journey contract; application/device execution not yet performed.

## Actors and starting records

Agreement G1 guarantees 1000 minor units; settlement S1 open/unearned/unpaid; valid proof P1 after work.

## Required sequence

| Step | Command / identity | Required result |
| --- | --- | --- |
| Prepay | RecordSettlement(agreement_id=G1,direction=payment,amount_minor=400,currency,payment_reference,occurred_at) | Append payment; S1 unearned/partially_paid with net paid400. Do not mark delivered/earned. |
| Earn | Complete agreed Round | S1 earned1000, paid400, due600; completion does not erase earlier payment. |
| Pay remainder | RecordSettlement(...amount_minor=600,new payment_reference...) | Paid1000; due0; close if final entitlement and no open financial case. |
| Financial dispute | OpenDispute(kind=financial,agreement_id=G1) → DecideDispute(financial_adjustment=-100,...) | Finance authority appends adjustment; entitlement900, net paid1000, refund_due100. Completed job and valid P1 remain unchanged. Record actual refund100 to balance; case closes after authorized effects. |
| Evidence dispute | OpenDispute(kind=evidence,proof_submission_id=P1) → DecideDispute(evidence_upheld) | Proof reviewer restores previously verified proof; finance-only actor rejects NOT_AUTHORIZED. Rejected proof instead requires a genuine verified replacement, with original evidence retained. |

## Adverse branch and replay

Replaying same payment reference/command adds zero; differing bytes for same command reject. Refund beyond net paid rejects. Prepaid1000 then cancellation with no entitlement records refund_due1000 until actual refund; no imaginary money movement. Reject replacement proof for a different handoff.

## Facts and side effects

`settlement.payment_recorded`, `settlement.earned`, `settlement.balance_changed`, `dispute.opened`, `dispute.resolved`. Emit only for the branch actually taken; retained evidence and success are alternative paths. Notifications/writeback use EVENT-CONSUMERS.json, not every row changed in a transaction.
