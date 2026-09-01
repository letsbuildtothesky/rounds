# Rounds · Drivers Live Availability & Contact Contract

**Version:** 1.4  
**Status:** Canonical — availability/contact contract + History H3 + Drivers V5 command surface + Network Supply + edge-state semantics  
**Canonical UX checkpoint:** `rounds-edge-states-v45.html`  
**Related specs:** Business Product Master, Driver + Broadcast Operating Model, Dispatch Route Editing & Communications, Driver UX Behavior Master, History Operating Memory

## 1. Purpose

This specification defines how Rounds represents **who is working, who is available, who becomes available soon, and who a merchant is allowed to contact**.

It exists because `online`, `available`, `open for jobs`, `on shift`, `known driver`, and `messageable` are not the same thing.

Rounds must keep those concepts separate.

## 2. Canonical driver state model

A driver has multiple independent dimensions:

1. **Identity** — the global person/vehicle account.
2. **Business relationship** — Team / Preferred / Known / previously used / blocked / none.
3. **Network eligibility** — whether the driver is allowed to receive open Network work.
4. **Presence freshness** — whether the Driver App/session is currently fresh enough to represent live state.
5. **Work availability** — whether the driver is accepting compatible new work now or later.
6. **Commitment state** — active Assignment/Offer/Round already accepted.
7. **Contact permission** — what this merchant may do with this driver before and during work.

Do not collapse these fields into one generic `status` value in the product model.

## 3. Merchant-facing availability language

### 3.1 Own team drivers

Canonical states may include:

- `On shift · available`;
- `On Round 18`;
- `Available after 16:20`;
- `On break / temporarily unavailable`;
- `Off shift`;
- `Offline / presence stale`.

Own-driver next-available time is derived from accepted work, route state, shift end and operational constraints.

### 3.2 Rounds Network drivers

Canonical states may include:

- `Open for jobs`;
- `Open for jobs · available after 16:20`;
- `On a Round`;
- `Not accepting jobs`;
- `Offline / presence stale`.

`Open for jobs` means the driver is publishing Network availability and is eligible to be considered for compatible work. It does not mean the merchant owns the driver's time or may contact the driver socially.

### 3.3 Projection language

`Available after HH:MM` is a projection, not a reservation or promise.

The system should update it when:

- accepted route duration changes;
- traffic/weather materially changes ETA;
- a live Stop is added/removed through valid rules;
- the driver pauses future Network availability;
- shift/availability horizon changes.

Where confidence is low, use less precise language such as `Available after current Round` rather than false precision.

## 4. Presence freshness

Availability must be freshness-aware.

A stale Driver App connection must not continue to render as confidently live/open.

Implementation thresholds may be configured technically, but product behavior must distinguish:

- fresh live presence;
- recently stale / reconnecting;
- offline/unknown.

The merchant should never be encouraged to rely on an old availability state as if it were current.

## 5. Contact-permission matrix

| Driver relationship/state | Merchant action before accepted work | Merchant action during accepted work |
| --- | --- | --- |
| Own team driver | Message / Call / Voice note according to team policy | Message / Call / Voice note |
| Preferred/known Network driver, direct-contact opt-in | Ask availability; relationship Message where enabled | Job-linked Message / Call / Voice note |
| Preferred/known Network driver, no direct-message opt-in | Ask availability only | Job-linked Message / Call / Voice note after acceptance |
| Unknown open-network driver | Offer/Broadcast only | Job-linked Message / Call / Voice note after acceptance |
| External courier driver | Provider-defined contact path | Provider-defined contact path |

Unknown Network supply must never become a browsable social inbox.

## 6. Ask availability

`Ask availability` is the preferred pre-job action for a known/preferred Network relationship.

It is a structured relationship request, not a delivery chat message.

The request may include:

- merchant identity;
- rough requested time;
- optional vehicle/work category;
- optional job reference if a real job already exists;
- respond available / not available / later path.

An availability response:

- does not accept a job;
- does not reserve the driver unless a future reservation feature explicitly exists;
- does not alter custody;
- does not create payout liability;
- may inform later matching/Broadcast.

## 7. Relationship messaging vs delivery messaging

Rounds has two conceptually different communication contexts:

### Relationship-level contact

Used only for allowed preferred/known merchant-driver interaction before accepted work.

Examples:
- Ask availability;
- direct merchant message where the driver opted in.

### Job-linked communication

Starts when work is assigned/accepted and is tied to the delivery/Round.

Examples:
- route instruction;
- pickup question;
- live change;
- exception;
- POD/custody communication.

Do not silently mix relationship messages into an unrelated delivery thread.

## 8. Driver controls

A Network-eligible driver must be able to control Network availability without changing identity or verification.

Canonical driver controls include:

- `Open for jobs` on/off;
- temporary pause/unavailable state;
- team-shift state where relevant;
- direct merchant-contact preference for known/preferred relationships where the product supports it.

Active accepted work cannot be abandoned by turning availability off. The driver must complete, transfer or escalate the active work through the normal operating flow.

## 9. Team vs Network priority

Team obligations and Network availability are different work modes.

During an active team shift:

- team assignments have priority;
- open-network offers are normally suppressed;
- outside Network work is allowed only when employer policy and driver settings permit it.

A team driver may become open-network eligible outside the team shift without becoming a separate `hybrid` identity type.

## 10. Location privacy

Rounds may use exact GPS internally for:

- matching;
- distance gating;
- route/ETA calculation;
- accepted-job tracking;
- safety/exception behavior according to policy.

Before acceptance, an unknown Network driver's merchant-facing state should use only what is operationally necessary, such as:

- approximate distance to pickup;
- approximate area;
- vehicle;
- availability;
- relationship/verification state;
- matching suitability.

Do not expose unrestricted exact live coordinates merely because a driver is `Open for jobs`.

## 11. Performance and History

Availability is not a universal performance metric.

### Own drivers

If an own driver is scheduled for a team shift, History may compare the scheduled obligation with actual operating behavior, including late start/no-show evidence.

### Network drivers

The following are **not automatically negative**:

- offline;
- not open for jobs;
- pausing availability;
- being unavailable before accepting work.

Network reliability evidence should focus on commitments and execution:

- Offer response/acceptance where useful;
- cancellation/no-show after acceptance;
- pickup/delivery punctuality after acceptance;
- custody/POD compliance;
- incidents on accepted work.

## 12. Drivers page requirements

Before styling, the canonical Drivers product surface must be capable of answering:

1. **Who is working?**
2. **Who is available now?**
3. **Who becomes available soon?**
4. **What are they currently doing?**
5. **What vehicle/capacity do they have?**
6. **What relationship do we have with them?**
7. **May I Message / Call / Ask availability / only send an Offer?**

### Own driver row/detail

Should expose operationally relevant state such as:

- on/off shift;
- current Round;
- next available;
- vehicle;
- shift horizon;
- Message / Call;
- performance/history entry point.

### Network driver row/detail

Where allowed, expose:

- `Open for jobs` / current accepted-work state;
- projected next available;
- approximate distance/area;
- vehicle;
- Preferred/Known relationship;
- merchant-specific completed work/history;
- permitted action (`Ask availability`, `Message`, `Offer`, etc.).

## 13. Broadcast integration

Broadcast uses availability as an eligibility input, not merely a display state.

A driver who is not open for compatible Network work must not receive new Network Offers.

Distance → relationship → eligibility/availability → vehicle/capacity/current commitments → promise safety remain part of the matching logic defined in the Broadcast spec.

## 14. No-ghost-control rule

The UI must not show actions the merchant cannot actually take.

Examples:

- unknown Network candidate → do not show Message;
- known driver without direct-message permission → show Ask availability, not fake Message;
- offline/stale driver → do not imply immediate contact/availability without clear state;
- active accepted job → show the real job-linked contact actions.

## 15. Acceptance criteria

A Drivers implementation is behaviorally correct when:

- live presence and work availability are visibly distinct concepts;
- own vs Network availability follows the correct operating relationship;
- `Open for jobs` is driver-controlled and affects matching;
- projected next availability updates with accepted work;
- unknown Network drivers cannot be casually messaged;
- preferred/known drivers may be asked about availability according to relationship permission;
- accepted work unlocks the normal job-linked communication contract;
- exact pre-acceptance Network location is protected;
- being offline/not-open does not become a hidden Network performance penalty;
- every visible contact action is actually permitted by current state.


## 16. History H3 presentation lock

History H3 implements this contract as a compact current-context layer beside durable driver evidence.

Canonical presentation rules:

- Own driver rows may show current Round and projected next availability beside Message / Call actions.
- Network rows may show `Open for jobs`, `On a Round`, `Not accepting jobs` or stale/offline context without treating the state as performance.
- Preferred/known Network relationships show `Ask availability` where permitted.
- A relationship Message control is shown only when direct-contact opt-in is represented as enabled.
- `Ask availability` visibly changes request state in the prototype instead of acting as a ghost button.
- Relationship messages remain separate from delivery/job-linked threads.
- Pre-acceptance Network location remains approximate (distance/area), never unrestricted exact live GPS.

The dedicated top-level Drivers product redesign may later make current availability more prominent, but it must inherit these semantics.


## 17. Top-level Drivers V5 command surface

The top-level Drivers product now implements this contract directly.

### 17.1 Stable information architecture

The page title remains `Drivers`; Own team / Network / Schedule are stable sub-surfaces below it. Switching sub-surfaces must not make the primary screen identity jump.

### 17.2 Own-team command row

A live own-driver row must make these facts scannable without opening a drawer:

1. driver identity;
2. current Round/loading state;
3. projected next availability;
4. vehicle + shift;
5. current work;
6. compact evidence context;
7. permitted live actions.

When the driver has active work, Message / Call / Open Round are real actions. When no active Round exists, the UI must not show fake live-work actions.

### 17.3 Network command row

A Network row must keep availability separate from relationship/performance. It may show approximate pre-job area, relationship, accepted-work history and current availability.

- `Open for jobs` may expose Offer work.
- `Ask availability` is shown only where relationship rules permit it.
- Message is shown only where direct relationship messaging is enabled.
- `Not accepting jobs` does not expose an Offer-work CTA and is never penalized.
- exact pre-job GPS remains protected.

### 17.4 Drawer hierarchy

Driver drawers are operational first: live state / next availability / primary contact or work action, then shift/vehicle context, then compact evidence. `Open full driver history` links to the durable History record rather than duplicating it.

### 17.5 Schedule lock

Schedule belongs only to own drivers. The current calendar day is explicitly highlighted and summary coverage is derived from that current date, including schedule exceptions and vehicle-profile overrides.

## 18. Network Supply map visibility

Live availability may also appear spatially on the optional Network Supply map layer.

### 18.1 Identity and location

- `Open for jobs` may appear as a generalized map point.
- Unknown open drivers remain anonymous until the normal offer/acceptance relationship permits more detail.
- Known/preferred identity may be surfaced only where the relationship and privacy/contact contract allows it.
- `Busy` capacity may remain anonymous even when approximate next availability is shown.
- Exact pre-accept GPS remains prohibited.

### 18.2 Contact

The map layer does not create new contact rights.

- Unknown open supply → Offer/Broadcast only.
- Known/preferred → `Ask availability` or relationship message only when already permitted.
- Accepted active work → job-linked Message/Call according to the normal contract.

### 18.3 Performance

Visibility, being busy, being offline, or not accepting jobs remains non-penalizing Network context. Only accepted commitments are eligible for Network execution/performance history.

## 19. Operator connectivity is not driver presence

The Operations client's connectivity and a driver's presence are separate facts.

- If the Operations browser loses connectivity, do not relabel an own or Network driver `Offline`.
- The live presence surface should show that freshness is paused/last-known until a new server presence event is received.
- Availability actions that require a live request, including `Ask availability`, are blocked from an offline client and must not create a fake request record.
- Existing accepted-work evidence and durable History remain readable where locally available.
- On reconnection, refresh presence/availability before restoring a live `Online` / `Open for jobs` claim.
