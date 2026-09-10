# Complete-order launch decision — V2.3

Launch rule: each delivery is collected as its complete current manifest. One internal fulfillment unit represents the whole delivery; it cannot be split or independently assigned in portions. Missing required quantities block that delivery only. Other complete deliveries may proceed after explicit route/assignment adjustment. Pre-arrival planning remains allowed. Partial inbound/return receipts and actual damage or loss are recorded truthfully; they never authorize short pickup or automatic remainder delivery.

Splitting one order across drivers or trips is deferred. ApprovePartialPickup is reserved and disabled, with FEATURE_NOT_ENABLED and zero domain mutations. There is no tenant setting or operator override to enable it at launch. Future enablement requires a reviewed release, migration, explicit customer/driver scope rules and UI—not toggling an undocumented flag.

Keep the existing internal unit identity to preserve offline references and evidence. Enforce exactly one unit per delivery; no child or residual units. Planning/cancellation selectors must resolve the entire delivery. This internal identity is not a customer-facing split feature.

ConfirmPickup compares the submitted line-ID/quantity map with every required manifest line for each selected delivery. Missing, duplicate or extra lines and short/excess quantities reject before custody/attempt creation. A batch confirmation is atomic; to leave an incomplete order behind, adjust the route first and submit a new command for complete orders. Never silently drop stops or alter a freelancer agreement.

If goods have already physically moved in error, retain observations and open a custody incident rather than falsely declaring full pickup. Reconcile actual quantities through supervised return/transfer/disposition, without spawning a new remainder route. Failed handoffs, shortages, damage, returns and legitimate retry attempts remain supported. CompleteDelivery must not call an order delivered unless its complete required quantities were actually handed over with required proof.
