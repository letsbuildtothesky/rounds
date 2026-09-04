# Rounds · Operations Edge States

**Version:** 1.0  
**Status:** Canonical product/build specification  
**Canonical UX checkpoint:** `ux/operations/rounds-operations-current-v45.html`
**Scope:** Operations web app; cross-surface loading, quiet, offline, stale, degraded and recovery behavior

## 1. Purpose

Operational software cannot become ambiguous when nothing is happening or when a dependency fails. This spec defines the state grammar that keeps Rounds truthful without turning normal quiet periods into alarms.

## 2. State taxonomy

Rounds distinguishes:

1. **Loading** — truth is not known yet.
2. **Quiet / empty** — truth is known and there is no work/record for the current scope.
3. **No match** — data exists, but the current search/filter returns none.
4. **Browser offline** — this Operations client cannot exchange new live data.
5. **Stale / last-known** — previously observed live data remains visible but freshness is no longer guaranteed.
6. **Dependency degraded** — one service such as Mapbox/provider integration is unavailable while the rest of Rounds remains usable.
7. **Domain failure** — a real operational failure such as provider cancellation/no driver/API failure, handled by the owning product contract.
8. **Recovering / restored** — connectivity/service returned and Rounds is reconciling current truth.

Never collapse these into one generic `Something went wrong` state.

## 3. Truth rules

- Never show `0`, `No deliveries`, `All clear`, `Offline driver` or `Healthy` while the relevant truth is still loading or stale.
- Browser connectivity is not backend health, driver presence, provider health or customer-notification health.
- Existing server-side workflows may continue while an operator browser is offline.
- A client must not fabricate successful state transitions while it cannot reach the authority that commits them.
- After recovery, refresh/reconcile before presenting live claims as current.

## 4. Browser-offline behavior

Locally available/last-known records remain readable. From the offline client, block new live-coordination actions including Network Broadcast mutation, provider quote/booking, outbound driver send/call, availability requests and remote map modes.

Blocked actions:

- explain the connectivity constraint;
- leave canonical operational state unchanged;
- do not append fake message/call/provider/network audit events;
- preserve unsent communication drafts/staged attachments where possible.

## 5. Communications

- Draft text and staged attachments remain visible.
- Composer shows a compact amber note that sending from this browser is paused.
- Driver live-presence wording becomes `Live status paused` / last-known semantics; do not infer the driver is offline.
- Reconnection restores live presence only after fresh state is received/reconciled.

## 6. Map

- Initial map load has a real loading state.
- Mapbox/map failure is localized to the map area and does not remove the Dispatch rail, Plan data or business navigation.
- The degraded map surface explains what still works and exposes a real Retry action.
- If a map was already loaded and the browser goes offline, retain useful last-rendered context where technically possible; do not claim live freshness.
- Do not substitute a decorative fake map for a failed live map.

## 7. Dispatch quiet states

- Action empty → `Nothing needs attention.`
- Ready empty → no deliveries waiting to leave; `+ Deliveries` may be offered.
- Live empty → no work moving now, neutral.
- Done empty → nothing completed in current scope yet.
- Search no-match → echo the search and offer Clear search.
- Scoped no-match → explain the selected delivery view and offer Show all.

## 8. Planning quiet states

- No unplanned deliveries for selected date = `Quiet planning day`.
- Generate Plan is disabled and visually non-primary.
- Timeline explains that no Rounds need building yet.
- Search no-match exposes Clear search.
- Proposed plan with no uncovered work = positive covered state, not a blank list.

## 9. History and Drivers

- History with no durable records explains that operating memory starts with the first completed/recorded work.
- Filter no-match preserves the surrounding KPIs/context and exposes Clear filters.
- No incidents is a valid positive state.
- No Network availability is an availability state, not negative performance evidence.

## 10. Settings / remote checks

Remote connection tests/reconciliation pass through `Checking…` before success/failure. Browser offline must never be converted into a fake provider/API failure or fake healthy result.

## 11. Recovery

When connectivity returns:

1. show a brief recovering state;
2. refresh/reconcile live sources;
3. avoid replaying a blocked action automatically unless the original domain explicitly supports safe idempotent retry;
4. restore live claims only from refreshed truth;
5. settle the global strip once recovery is confirmed.

## 12. Responsive behavior

Edge-state messages and recovery actions must remain readable at the locked laptop/iPad viewports without causing document-level horizontal overflow. Drawers and Plan retain their responsive workstation behavior.

## 13. Phone scope

This specification does not create a phone-sized full Operations product. Full Operations remains laptop/iPad class. A future phone companion is a separately scoped alert/approval/lookup experience.

## 14. Acceptance criteria

1. Search/filter no-match is distinct from true empty state.
2. Offline Network/Lalamove/comms actions do not mutate canonical state.
3. Communications preserve drafts and do not mark drivers offline solely because Operations lost connectivity.
4. Map failure leaves the rest of Dispatch usable and exposes Retry.
5. Plan quiet day has no active-looking dead Generate button.
6. Remote connection tests show a loading/checking state.
7. Recovery does not fabricate current truth before refresh/reconciliation.
8. Edge states work at laptop and iPad-class responsive breakpoints.
