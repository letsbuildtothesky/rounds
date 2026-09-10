# J03-COMPLETE-ORDER — Shortage blocks one order, not its neighbours

Status: written contract; application/database execution pending.

D1/M1 requires five items; only three are ready. D2 is a separate complete order on the planned route.

1. Plan and stage D1 and D2 before stock/inbound readiness. No pickup is implied.
2. Report D1 shortage. ConfirmPickup(D1, quantity 3) rejects COMPLETE_ORDER_REQUIRED with zero custody, attempts or residual units. ApprovePartialPickup rejects FEATURE_NOT_ENABLED.
3. Explicitly adjust the route to leave D1 pending and retain D2; preserve appropriate team acknowledgement or freelance consent. D2 may be collected complete and delivered normally.
4. When all five items for D1 are physically received and prepared, confirm exactly five under its current assignment fence. Create one whole-order attempt; remaining_units and obligation_ids are empty.
5. Handoff the complete D1 order, verify proof and complete. Replay adds zero. A direct second unit insert or non-null parent_unit_id fails SQL constraints.

Missing, duplicate or excess manifest lines reject. An atomic batch containing incomplete D1 does not silently collect D2; retry with a new explicit complete-order selection after route adjustment. Already moved goods are retained as incident evidence for custody reconciliation, not hidden or converted into an authorized short pickup.

Facts: pickup.confirmed, fulfillment.completed, delivery.completed only on actual successful branches. Rejection emits no success fact. Partial inbound receipts are truthful inventory/custody updates, not delivery authorization.
