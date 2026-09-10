# Rounds — complete project V2.3-r1

## Changelog

- V2.3-r1 · 2026-09-08: repository reconciliation corrects owning sections/contracts/acceptance in place. Original ZIP is preserved separately; approved UI/assets unchanged. See current [Build Specs](../../build-v2.3/README.md) and [audit dispositions](../../build-v2.3/AUDIT.md).

**One project archive. Current specs, approved Dispatch, all supplied Driver screens and design assets are together.** Updated 8 September 2026.

Open [OPEN-PROJECT.html](OPEN-PROJECT.html) after extracting the whole ZIP for a clickable board/screen index. To read or independently review the specifications, start at [specs/README.md](specs/README.md).

## Where everything is

| Folder / file | Use |
| --- | --- |
| specs/product/ | All 15 product specs — P01 through P15 |
| specs/engineering/ | All 10 engineering specs — E01 through E10 |
| specs/contracts/ | Current API, events, policies, lifecycle, errors and worker/consumer contracts |
| specs/database/ | Reference database schema, invariants, role policies, dictionary and Driver SQLite model |
| Complete-order pickup | Block an incomplete order; independently complete orders may proceed after route adjustment. No split approval or residual assignment. | J03; complete-order decision |
| specs/decisions/ | Operating decisions, architecture choices and open launch gates |
| specs/review/ | Reviewer dispositions, acceptance/feature register, validators, results and UI follow-through |
| ui/dispatch/index.html | Current approved Phase39 Dispatch — unchanged |
| ui/driver/ | Entire supplied Refresh26 pack: 47 screen HTML files, 26 presentation pages, assets, tokens, style guide and notes |
| design/README.md | Links to the current design references |
| review/ | Project source-preservation evidence and screen inventory |
| reference/ | Original board, early feature register and historical specs archive — comparison only |

## What this version means

V2.3 corrects the reviewed spec contradictions around partial quantities, offline identities, freelance execution, finance/disputes, notifications, location grants, gate ownership and policy/event contracts. Read [review resolution](specs/review/REVIEW-RESOLUTION.md) for exact changes and remaining boundaries.

The approved UI remains intact. Behavior changes that still need applying to the board or app are listed in [UI follow-through](specs/review/BOARD-FOLLOW-THROUGH.md). Source checks and reference examples passed; PostgreSQL/Supabase runtime, generated clients, devices and browser parity were not tested in this revision.

**This is the active reconciled specification and design source. Repository-grounded release Build Specs now live in specs/build-v2.3 of the repository.** Their readiness status is not application acceptance. Historical build documents inside reference/Original-Specs-Historical.zip are not the active Build Specs.

You do not need the previous Foundation or complete-review ZIPs to read this package. Use specs/ as the current set; preserve historical material only as reference.

## Opening the designs

Extract everything, then open OPEN-PROJECT.html in Chrome. The Driver presentation pages link to their matching source screens. Some source HTML files contain multiple states/tabs; 47 is the number of screen files, not a claim that every state is covered.

Map/provider features still require their existing connection/configuration and network access. This archive preserves the working prototype files; it does not supply a deployed API, freelancer network or production credentials.

## Current scope correction

Launch rule: each delivery is collected as its complete current manifest. One internal fulfillment unit represents the whole delivery; it cannot be split or independently assigned in portions. Missing required quantities block that delivery only. Other complete deliveries may proceed after explicit route/assignment adjustment. Pre-arrival planning remains allowed. Partial inbound/return receipts and actual damage or loss are recorded truthfully; they never authorize short pickup or automatic remainder delivery.

Use this V2.3 package instead of V2.2. Board/app files remain unchanged; launch behavior must follow the corrected specs.
