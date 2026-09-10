# J02-FREELANCE — Freelance acceptance through execution

Status: complete written journey contract; application/device execution not yet performed.

## Actors and starting records

Operator O; opted-in freelancer F; unplanned unit U1; broadcast B1; current scope revision/hash; eligible vehicle.

## Required sequence

| Step | Command / identity | Required result |
| --- | --- | --- |
| Broadcast | StartBroadcast(fulfillment_unit_ids=[U1],...configured fare/search...) | Operator decides even when an own driver is free. Creates search Round R1/stops, unit claim and offered candidates. |
| Accept | RespondOffer(offer_id,scope_revision,scope_hash,response=accept) | Atomically create agreement G1, acknowledged origin=freelance assignment A1, released Round/stops, driver interval and open/unearned/unpaid settlement. Other offers become taken. |
| Inspect | GetDriverRound | Contains A1 and version, U1 and stops even if goods are not ready. No own-team plan/proposal is needed. |
| Wait for goods | SetPickupReadiness or actual ReceiveTrip | Gate changes synchronously on the same assignment. No second acceptance, no inferred receipt from ETA. |
| Execute | ConfirmArrival → ConfirmPickup → RecordHandoff → SubmitProof → CompleteDelivery | Use J01 identity chain. Complete agreed units, close Round, derive settlement.earned for accepted scope; customer notification consumes delivery.completed only. |

## Adverse branch and replay

Two simultaneous accepts have one winner; loser cannot obtain assigned private data. Acceptance before readiness does not authorize pickup. Response loss recovers original assignment/agreement; replay cannot create a second guarantee or fee.

## Facts and side effects

`work.accepted`, `offer.taken`, `pickup.confirmed`, `fulfillment.completed`, `settlement.earned`. Emit only for the branch actually taken; retained evidence and success are alternative paths. Notifications/writeback use EVENT-CONSUMERS.json, not every row changed in a transaction.
