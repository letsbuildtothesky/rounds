# J01-OWN-TEAM — Own-team local delivery

Status: complete written journey contract; application/device execution not yet performed.

## Actors and starting records

Operator O, driver S, recipient C; delivery D1, manifest M1 quantity 1, unit U1, ready pickup site H1.

## Required sequence

| Step | Command / identity | Required result |
| --- | --- | --- |
| Intake | SaveDeliveryDraft → ReviewAddress → HoldSlot → CommitDelivery | Return delivery D1, manifest M1, unit U1 and committed slot identity; address review is explicit. |
| Plan | GeneratePlan(city_id,service_date,fulfillment_unit_ids=[U1]) → GetPlan → ApplyPlanProposal | Use proposal ID/version 1, source plan base_version and input/policy hashes. Preserve stable stop IDs. |
| Release | ReleasePlan(plan_id,proposal_id,input_hash,round_ids) | Atomic team assignment, claims and driver range; actual readiness must pass. Cache GetDriverRound assignment fence and pickup/dropoff/unit IDs. |
| Collect | ConfirmArrival(pickup stop) → ConfirmPickup(round_id,pickup_stop_id,manifest_ids,fulfillment_unit_ids,quantities) | Supply original execution_fence. Result binds collected U1, attempt A1, custody event and resource versions. Missing approval field is valid for full collection. |
| Deliver | ConfirmArrival(dropoff) → RecordHandoff(attempt_id=A1,receiver_kind,quantities) | Handoff H01 moves actual U1 quantity. Lost response recovers the same handoff ID through GetCommandStatus. |
| Evidence | ReserveAsset → upload → VerifyAsset → SubmitProof(attempt_id=A1,handoff_id=H01,policy_version_id,evidence) → CompleteDelivery | Proof ID comes from SubmitProof.data.resource.id. Complete U1/attempt/stop, derive whole D1 and this Round closure once. |

## Adverse branch and replay

Unready release returns PICKUP_NOT_READY/INBOUND_NOT_RECEIVED without assignment mutation. Duplicate pickup or completion command returns its original result and adds no physical quantity/event. No own-team payroll or freelance settlement is invented.

## Facts and side effects

`pickup.confirmed`, `handoff.recorded`, `proof.submitted`, `fulfillment.completed`, `delivery.completed`, `round.completed`. Emit only for the branch actually taken; retained evidence and success are alternative paths. Notifications/writeback use EVENT-CONSUMERS.json, not every row changed in a transaction.
