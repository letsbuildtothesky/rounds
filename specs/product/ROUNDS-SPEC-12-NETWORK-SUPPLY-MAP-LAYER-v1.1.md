# Rounds · Network Supply Map Layer

**Version:** 1.1  
**Status:** Canonical product/build specification  
**Canonical UX checkpoint:** `ux/operations/rounds-operations-current-v45.html`
**Related specs:** Business Product Master, Driver + Broadcast Operating Model, Mapping & Address Intelligence, Drivers Live Availability & Contact, Operations Visual System

## 1. Purpose

Network Supply lets Operations answer a simple question before dispatching external capacity:

> **What Rounds Network capacity is nearby, open now, or likely to become available soon?**

It is an optional capacity-awareness layer. It is not a surveillance surface and it is not a substitute for Broadcast/acceptance.

## 2. Default behavior

- Off by default.
- Available in Live Dispatch.
- Hidden from the own-fleet Plan surface by default so own-fleet planning remains conceptually clean.
- The normal operational map remains dominant when the layer is on.

## 3. States

### Open for jobs

A driver has published current willingness to receive relevant Network work.

The merchant may see:
- generalized point;
- approximate area/distance;
- vehicle/capability where policy allows;
- Preferred/Known relationship where applicable;
- identity only when relationship/privacy rules permit.

### Busy

The driver is committed elsewhere.

The merchant may see:
- anonymous generalized capacity point;
- approximate area;
- approximate expected availability where available.

The merchant must not see:
- other merchant identity;
- route;
- Stops;
- recipients/customers;
- exact live GPS/path.

### Accepted for this merchant

Once work is accepted, the existing exact job-linked tracking/communication contract becomes authoritative for that job. The accepted driver should not continue to be represented merely as anonymous supply for the same merchant/job context.

## 4. Privacy

Pre-acceptance exact Network GPS is protected.

Generalization may use:
- coordinate fuzzing;
- grid/area snapping;
- neighborhood centroiding;
- other backend privacy-preserving spatial treatment.

The client must not receive raw GPS and merely hide it cosmetically when policy says the merchant is not entitled to exact location.

## 5. Contact and offer rights

Network Supply does not grant arbitrary messaging rights.

- unknown open capacity → Offer/Broadcast;
- known/preferred → Ask availability / relationship message only if already allowed;
- accepted work → job-linked Message/Call.

## 6. Visual system

- open = hollow orange point;
- busy = small neutral low-opacity point;
- cluster = compact orange-outline count;
- accepted job = existing stronger job-linked driver marker;
- active layer state must clearly disclose `locations generalized until acceptance`.

## 7. Performance / rendering

Production must favor native map data rendering:

- GeoJSON/vector source;
- clustering at low zoom;
- viewport/radius filtering;
- server-side or stream-side relevance filtering;
- generalized supply refresh roughly every 10–30 seconds where appropriate;
- exact accepted-job tracking may refresh more frequently under the existing tracking contract.

Avoid one DOM element per generalized Network driver at scale.

## 8. Safety and correctness

- Supply count/availability is advisory, not guaranteed.
- A driver is not reserved until acceptance is committed.
- Stale availability must age out according to presence freshness rules.
- Other-merchant work remains confidential.
- Exact pre-acceptance location is a backend authorization/privacy rule, not only a UI convention.

## 9. Acceptance criteria

1. User can turn Network Supply on/off from Live Dispatch.
2. Normal map remains readable when supply is shown.
3. Open/busy states are visually distinguishable without competing with current work.
4. Low zoom clusters supply rather than flooding the map.
5. Busy point details reveal no other merchant/job data.
6. Unknown open supply cannot be casually messaged.
7. Exact tracking begins only under the accepted-work contract.
8. Plan mode does not silently mix this layer into own-fleet planning.

## 10. Offline / stale supply behavior

Network Supply is live/advisory data and must expose freshness honestly.

- If the Operations browser loses connectivity while the layer is visible, existing points may remain only as **last-known** context; the UI must state that live availability is paused/stale.
- An offline client may hide the layer, but it cannot newly enable/query live Network Supply or claim a fresh count.
- Do not convert stale/open supply into accepted or reserved capacity.
- On reconnection, refresh the supply source before returning to normal `Open` / `Busy` live claims.
