# J04-OFFLINE — Offline pickup through proof with restart

Status: complete written journey contract; application/device execution not yet performed.

## Actors and starting records

Device has authorized A1/version 7, R1, U1, stops and policy cached. Connectivity fails before pickup.

## Required sequence

| Step | Command / identity | Required result |
| --- | --- | --- |
| Observe | Persist local O1 pickup, O2 arrival, O3 handoff, O4 proof, O5 completion | Each has original time/fence; O3 references O1 attempt binding; O4 references O3 handoff binding and local assets; O5 references O4 proof binding. They are not final API request hashes. |
| Restart | Kill/reopen app; read encrypted observations/bindings/assets | Same O1–O5 and captured evidence survive. UI says pending sync, not server complete. |
| Resolve pickup | Materialize C1 ConfirmPickup, freeze exact hash and send | Committed result maps U1→attempt A1x and root versions. On lost response GetCommandStatus(C1) recovers exactly that result. |
| Bind successors | Resolve O2/O3 from C1 and arrival result, then materialize handoff C3 | Only own predecessor resource versions update the chain. Original assignment A1/version7 stays unchanged; never replace it from a current reassignment. |
| Upload and finish | Upload/verify assets → bind C3 handoff ID into SubmitProof C4 → bind C4 proof ID into CompleteDelivery C5 | Freeze each command only after all bindings resolve. Exactly one attempt, handoff, proof submission and completion for the observation chain. |

## Adverse branch and replay

If A1 was superseded while offline, block dependent physical commands. RetainOfflineObservations stores original chain/assets under incident; new assignment/custody remains unchanged. Rejected/retained predecessor never yields a success binding. Retry after response loss reuses original frozen C ID/hash.

## Facts and side effects

`pickup.confirmed`, `handoff.recorded`, `proof.submitted`, `fulfillment.completed`, `evidence.retained_stale`. Emit only for the branch actually taken; retained evidence and success are alternative paths. Notifications/writeback use EVENT-CONSUMERS.json, not every row changed in a transaction.
