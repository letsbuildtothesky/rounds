# V2.3-r1 operating decisions and authority

## Reconciliation changelog

- 2026-09-08 · v2.3-r1: Remove obsolete partial approval; preserve independent complete orders and pre-arrival planning.

8 September 2026. Explicit latest user instruction: all destination routes may be planned before the inbound truck arrives. This decision is approved. The other workflow resolutions below are recommended specification decisions carried by this revision for review; commercial tariffs, retention and vendor field certification remain separately gated.

| Decision | Exact V2.3 rule |
| --- | --- |
| Planning before receipt | Generate, edit, move, save and stage complete routes using expected inbound manifests. The destination hub is their pickup site. Receipts never create a second copy of an already planned delivery. |
| Staging versus release | StagePlan publishes a provisional schedule to own drivers and reserves their planned busy range. Its cards say Awaiting inbound goods. ReleasePlan authorizes an operational departure only when all selected required lines are available; no simulated receipt. Freelancers may accept a future pickup with disclosed ready-by estimate and waiting/cancellation terms. Physical pickup remains gated. |
| Independent departures | Release may select ready Rounds within a plan. One missing parcel does not block other independent Rounds. A partly received customer order cannot be split. Explicitly adjust the route/assignment to let independent complete orders proceed; accepted freelancer changes still require consent. |
| ETA changes | Keep planned sequence/assignment stable, flag affected departure/promise risk and offer a recalculation preview. Applying a change is explicit; accepted freelancer scope is not silently altered. |
| Physical receipt | Each receipt command records incremental quantities, never a cumulative total. Same command ID replays the prior result; a new ID adds quantities only up to the unresolved expected balance. Receivers authenticate; remote planners cannot fabricate site receipt. |
| Slot scope | Exactly one delivery-window admission rule wins: site+brand, then site, then brand, then city. Ambiguous equal-specificity overlap is rejected. City/site/brand caps are alternatives, not silently cumulative. A separate shared capacity pool requires an explicit future model. |
| Slot refresh | RefreshSlotHold extends the existing live reservation subject to maximum total hold lifetime. Moving a held draft uses MoveSlotHold in one transaction. Expired records remain historical; a new hold uses a new reservation ID. |
| Reschedule | Preserve delivery ID and all previous attempts/custody. Atomically obtain new slot admission when applicable; close/release the prior current reservation without restoring historical throughput. Create the next attempt on the next release. Goods returned to base remain held by that site until received and collected anew. |
| Preparation | Per-delivery unknown/preparing/ready/blocked plus optional ready-by estimate and actor/time. Unknown does not block planning; not-ready blocks physical pickup. No partial approval or operator override permits a short pickup. Independent complete orders may proceed after explicit route adjustment. |
| Broadcast unplanned orders | StartBroadcast accepts delivery IDs or an existing Round, exclusively. It creates a search Round and claims its deliveries in the same transaction. Existing unreleased plan stops move atomically and the source proposal becomes stale. Released work requires explicit withdrawal/reassignment first. No own-capacity prerequisite. |
| Broadcast restart | RestartBroadcast creates a new search linked to the closed search. It is permitted only with no active agreement and all targeted claims/remaining obligations resolved. Old offers remain expired/taken/withdrawn. |
| Team refusal | AcknowledgeAssignment already supports cannot_comply. This preserves the current assignment, opens an operator action and blocks departure until resolved; it does not drop custody or penalize a driver automatically. Break/unavailable/no-show is explicit and invalidates affected planning inputs. |
| Vehicle binding | A shift occurrence assigns the vehicle for that driver/date/time. Non-overlapping shifts can share one vehicle. A command locks the vehicle and rejects overlapping active use; swapping after assignment rechecks cargo and timing and triggers an update. |
| Money | V2.3 records direct settlement and configured contractual adjustments; it does not initiate bank transfers, maintain a wallet or collect COD. Customer redelivery fees and customer self-service destination/reschedule requests are deferred explicitly. |
| Address review | Formatting-only normalized text retains the original source without a blocking correction. Changed destination/house/soi/unit or conflicting geography requires human review. Optional buyer metadata can warn; required recipient access/contact/handling cannot be silently discarded. |
| Design | Existing restrained blue identity/actions, light canvas and orange attention remain approved. No new visual theme. New workflow states reuse the board's established controls. |
