# Approved UI follow-through — V2.3

The combined project preserves the supplied Phase39 Dispatch and Refresh26 Driver pack byte-for-byte. This revision updates specs and contracts, **not the HTML implementation**. The table below is the behavior alignment backlog; none is claimed shipped by this archive.

Preserve logo geometry, restrained blue, board spacing/hierarchy, map-click driver actions, timeline, and manual Add Delivery alongside optional AI autofill. UrbanFlowers is a sample workspace; Rounds remains SaaS. Optional Intercity features stay hidden/disabled for local-only tenants.

| Surface | Alignment to verify/implement | Contract / scenario |
| --- | --- | --- |
| Destination Plan / timeline | Complete routes before receipt; show hub, ETA and exact blocking quantities; retain route/stop IDs as ETA changes; preview driver reallocation | P04/P08; J06; StagePlan |
| Partial hub receipt | Confirm actual line quantities incrementally; one missing parcel cannot block independently ready work; no fake receipt | ReceiveTrip; J06 |
| Complete-order pickup | Block an incomplete order; independently complete orders may proceed after route adjustment. No split approval or residual assignment. | J03; complete-order decision |
| Broadcast acceptance | Only eligible freelancers open for work receive offers; winner sees acknowledged assignment and route immediately; expected readiness visible | P07; J02; RespondOffer |
| Team vs freelance changes | Own-driver instruction acknowledgement distinct from freelancer material-change consent; no capacity gate on the operator's Broadcast action | P06/P07 |
| Offline recovery | Distinguish recorded locally, uploading, server verified and retained for review; show recoverable chain without false completion or duplicate upload | E05; J04 |
| Finance and disputes | Separate agreed/earned/paid/refund due and financial/evidence cases; evidence rejection stays visible after money resolution | P15; J05 |
| Pause/cancel/transfer | Readable hold reason; safe cancellation paths and explicit receiver decline; no disappearance of in-custody goods | PauseRound; CancelRound; DeclineTransfer |
| Address intake | Preserve manual entry; original and AI-suggested Thai address side-by-side with changed facts and explicit review | P02 |
| Driver on map → chat | Contextual persistent conversation, draft/unread preservation; background arrivals do not steal focus | P09 |
| Location and connection state | Distinguish stale/offline/no permission; sanitized device health only; hide live GPS immediately when access ends | E06/E08 |
| Capacity / weather / map | Binding limits and genuine free-after include reload/return; reasoned weather buffer; no invented traffic/routing capability; entrance inspection and Street View setup | P04/P10/P13 |
| Tablet and phone states | Check touch, keyboard focus, rotation, long Thai text and loading/empty/error states at P14 viewports | P14 |

## Concrete morning walkthrough

At 07:00, select Hua Hin / Plan / today. An inbound truck expected at 09:00 has five local deliveries. Create R1 for D1–D3 and R2 for D4–D5; assign/stage both before any receipt. Label their inbound dependencies and provisional driver busy time. If the truck is late, show the timing risk and offer a preview or explicit reallocation; keep stable route/stop identity.

Receive D1, D2, D4 and D5. R2 can become ready independently; R1 identifies D3 as missing. The operator may move D3 to later work under current claim/consent constraints. Only actual received/prepared quantities can be collected.

Earlier source inspection identified a handoff-navigation helper and an all-parcels receipt form as targets to verify in the running board. Later wrappers may affect behavior. Treat them as inspection targets, not certified runtime defects or fixes.

## Remaining design checks

Walk incoming/missed/in-call states, account/verification gates, waiting pickup, incomplete-order blocking, post-pickup returns, upload recovery and source conflicts in the supplied app screens. Resolve any driver/Dispatch logo treatment differences through the existing brand decision; do not silently redesign. Confirm every existing approved control retains its function before certifying parity.
