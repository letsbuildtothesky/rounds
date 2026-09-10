# J06-INTERCITY — Truck receipt into independent local routes

Status: complete written journey contract; application/device execution not yet performed.

## Actors and starting records

Truck T1 carries D1–D5; destination hub H1. R1 has D1–D3 units, R2 has D4–D5. Expected arrival09:00; receiver RH.

## Required sequence

| Step | Command / identity | Required result |
| --- | --- | --- |
| Plan at07:00 | GeneratePlan → ApplyPlanProposal → StagePlan | All local routes/drivers/stops are ready before goods arrive; provisional commitments reserve driver time. Pickup is destination H1. |
| Truck delayed | SaveTrip ETA update; preview/reallocate with WithdrawRelease/StagePlan | Preserve route/stop IDs. Operator can release S provisional interval and assign N; no automatic reshuffle or freelance consent bypass. |
| Actual receipt | ArriveTrip → ReceiveTrip for L1,L2,L4,L5 | Actual increments update custody and each unit dependency. R2 ready; R1 awaits L3. Worker processing can be paused and gates must already be current. |
| Independent departure | ReleasePlan for R2 → local ConfirmPickup → local proof journey | R2 departs with received goods; no whole-truck check blocks it. Wrong-manifest booking/receipt lines reject before movement. |
| Later receipt | ReceiveTrip for L3 → ReleasePlan R1 → local fulfillment | Same original deliveries/units/stops; no duplicate customer order or reset. CloseTrip requires all booked balances received or explicit discrepancy disposition. |

## Adverse branch and replay

Receive2 then3 of booked5 yields total5; replay changes0; another1 rejects QUANTITY_EXCEEDED. Missing D3 cannot freeze R2. Concurrent receipt/release recomputes under the same root locks; ETA alone never unlocks pickup.

## Facts and side effects

`round.readiness_changed`, `pickup.confirmed`, `fulfillment.completed`, `delivery.completed`. Emit only for the branch actually taken; retained evidence and success are alternative paths. Notifications/writeback use EVENT-CONSUMERS.json, not every row changed in a transaction.
