# W01 — Dispatch pickup Action connection

Version 1.0 · 2026-09-10 · Bounded implementation, not full Dispatch or phone acceptance.

## Changelog

- 1.0 (2026-09-10): connect a delivery's Action review to the existing original pickup report and wait/escalate workflow; preserve independent authority, exact draft/attempt recovery and source component geometry.

## Scope and source

Baseline commit: `19d6c1e7dc570546026cfb41135fae74c6b4e23e`. Work remains in the existing repository. Owning rules: BS-03/04/12, P05 and ADR-Q05/Q06/Q07/T08. This consumes existing query/command contracts, not a new product decision or wire revision.

Approved source: `ui/dispatch/index.html`, `renderDeliveries` at5387–5465, its `delivery-card` → delivery detail behavior and the previously approved own-team issue panel/action dialog. The complete source file remains SHA256 `6a0019ec88cdaa422c5d56831d42f78745665de30681769a0d3515047fd1663c`. No source artwork/CSS, phone screens or Thai files changed. Original browser-file access remains unavailable; do not rehost it to bypass the earlier denial. Static source and supplied screenshots inform implementation; original interactive/pixel parity remains unaccepted.

## Implemented engineering rule

1. [Navigation join](../../apps/operations-web/src/v23/dispatch-pickup-action.ts): require ready, non-last-known readers and identical principal/session epoch/tenant/city/service date. The delivery must be in the server's current-city-day `Action / issue` projection and exist in the actual delivery list. Match only exact `delivery_id` to independently authorized, non-resolved pickup reports. Display names, current assignees and Round-only reports never manufacture a match.
2. [Delivery detail](../../apps/operations-web/src/v23/delivery-board-view.tsx): the card still opens its approved detail first. A matching detail offers **Review pickup report(s)** using the existing primary footer. Without a supported match the detail stays read-only. The link is navigation, not new reply/physical permission.
3. [Workspace](../../apps/operations-web/src/v23/dispatch-workspace.tsx): recheck the join at click time. Preserve the mounted delivery view, selection, filters and current/Plan date while opening the same pickup controller. Observe committed settlement at workspace level and refresh the delivery reader, never optimistically clearing a hold/category. Rejection retains the draft; closed Auth is not success.
4. [Existing report drawer](../../apps/operations-web/src/v23/pickup-issue-drawer.tsx): one exact report opens for review only. Multiple matches use the existing report list with an exact-delivery filter and a small **Show all pickup reports** control using existing components. No report is arbitrarily chosen. Opening/closing cannot send, replace another report's draft, change original assignment/version, or discard pending bytes. Resolved/Round-only reports remain reachable through the separate general reader as appropriate.
5. **Ask driver to wait / Escalate** still use the existing `ResolveIssue` handler and status-first recovery. Read-only changed-original-job reports show their blocked reason; server eligibility/version checks remain decisive. An instruction is neither collection nor permission to depart.

## Compatibility and dependencies

No database, command/query schema, native local-schema or recovery-journal migration. No widened grants, legacy route replacement, feature activation, shared migration or installation. Existing device/photo/offline stores are untouched. Own-team report discovery needs its independent `issues.decide` capability; `board.read` alone is insufficient. A different Plan date does not retarget original-date reports or drafts.

## Acceptance evidence

- [15 new unit/render cases](../../apps/operations-web/test/v23-dispatch-pickup-action.test.ts): exact-ID and scope matching, failed/denied readers, current-day/Now requirements, multiple/Round-only/foreign/resolved reports, original-draft preservation, changed-job blocked reply and source card/detail sequencing.
- [Restricted database suite](../../services/api/test/v23/resolve-pickup-issue.postgis.ts): **59/59 focused tests passed**, including two new full adapter → local Node HTTP → restricted PostgreSQL → Driver query checks. Both wait and escalate actually commit. A lost HTTP result leaves the original pending command; status recovery completes with exactly one POST/decision. Exact driver text survives; internal reason is absent from the Driver query. Delivery, Round, custody, receipts and attempts stay unchanged, and Now remains Action. Revoking only report permission removes linkage without removing separately authorized delivery data. Provider bearer verification is the only identity double; no shared service is used.
- [Browser review](evidence/dispatch-pickup-action/browser-check.json) uses compiled production React/controllers with explicitly **synthetic HTTP/Auth/map**. Initial card→detail→report, keep-draft→return→reopen and wait/status recovery passed. Final compiled revision passed escalation/status settlement, automatic board refresh and no duplicate send: exactly one POST, one receipt and one post-settlement delivery refresh. Offline hides the Action link and labels retained details; permission denial removes private detail/map. Return restores the same held delivery. Captures inspected: [desktop Action](evidence/dispatch-pickup-action/desktop-action.png), [tablet reply](evidence/dispatch-pickup-action/tablet-reply.png), [narrow confirmation](evidence/dispatch-pickup-action/narrow-confirmed.png). Tablet768 and narrow390 have matching document scroll widths, with no horizontal overflow. Original-source pixel parity and live SDK/provider rendering are not claimed. Temporary review tab/server were closed and viewport reset.
- Full frozen-code aggregate recorded **2026-09-10T08:54:26.786601+00:00:23/23 groups PASS**, including **227 Operations,481 PostGIS,201 API/foundation and618 full Flutter tests** (435 native-subset cases are included, not additive). Production build, typechecks, SQLCipher process-kill and Android durability-barrier checks passed. Logs and frozen code/source hashes: [current results](generated/test-results.json). These are local automated checks, not installed-client/provider/source-pixel acceptance.

## Remaining / next

Other Action reasons (address, readiness/receipt/preparation, assignment and post-pickup exceptions), general delivery intake, planning/release writes and complete Dispatch detail fields remain separate implementation work. Next take the approved manual delivery intake workflow under BS-02, retaining the established whole-order rules and exact source form. Secure issue-photo viewing, configured provider/Auth/SQL host, original visual matching and installed-phone acceptance remain open. No overall completion percentage is inferred from this increment.
