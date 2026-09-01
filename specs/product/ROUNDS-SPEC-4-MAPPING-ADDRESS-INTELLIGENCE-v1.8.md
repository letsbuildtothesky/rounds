# Rounds · Mapping, Address Intelligence & Street Imagery Specification

**Version:** 1.8
**Status:** Canonical product/build specification  
**Scope:** Dispatcher web app, Driver app, shared backend, mapping/search providers  
**Operations renderer:** Mapbox GL JS for V1; Driver active navigation uses embedded Google Navigation SDK subject to Phase 0 field validation  
**Address/routing/street-imagery providers:** abstracted and constrained by vendor terms; do not infer provider choice from the Operations basemap  
**System of record:** Rounds Supabase/Postgres

---

# 0. Current implementation provider boundary — controlling

This section overrides older provider-specific wording elsewhere in this specification where a conflict remains.

- **Operations map renderer:** Mapbox GL JS for V1. It renders Rounds-owned operational layers and does not determine canonical route truth.
- **Driver active navigation:** embedded Google Navigation SDK using `TWO_WHEELER` in Thailand, subject to `ROUNDS-PHASE-0-FIELD-VALIDATION-SPEC-v1.2.md`.
- **Server planning/routing:** provider abstraction remains open until evidence/cost/licensing evaluation. The planner owns Stop sequence/feasibility; active navigation may choose a different physical path for the current leg.
- **Address/geocoding/Places:** provider remains open. Selection must be coherent with the Operations map and vendor storage/display terms. Do not use Google-derived map content on a non-Google map unless the applicable Google terms explicitly permit that use.
- **Route truth:** planned route, active navigation leg and actual Rounds-owned location trail are distinct concepts. A navigation reroute may update live ETA/downstream consequence calculations without rewriting history as driver error.
- **Basemap rule:** the basemap is a renderer, not a routing engine. No browser-side Mapbox Directions call may become authoritative route/ETA truth.
- **Advanced address features:** Street imagery, 3D site inspection, learned entrance graphs and broader Address Intelligence are product capabilities but are not Pilot/Slice 1 dependencies. Slice 1 requires raw address, an operational pin, access note and a structured wrong-pin/entrance correction path.

---

# 1. Product principle

The map is not decoration.

Rounds uses mapping to answer four operational questions:

1. **Where is the work?**
2. **How should the work move?**
3. **Can the driver actually access the destination?**
4. **What should Rounds remember so the next delivery is easier?**

The canonical mapping experience therefore combines:

- live operational map;
- route decision visualization;
- address search/resolution;
- vehicle-access points;
- entrance/handoff points;
- 3D and satellite site inspection;
- optional street-level imagery;
- learned merchant delivery-location knowledge.

Rounds must not collapse all of these into one latitude/longitude field.

---

# 2. Provider architecture

## 2.1 Mapbox — V1 Operations renderer

Use Mapbox GL JS in Operations for:

- Dispatcher live basemap;
- Rounds-owned route/Stop/driver overlays;
- Network Supply and Broadcast radius visualization;
- external-courier markers;
- satellite/3D site inspection where enabled;
- custom Rounds visual styling;
- selection, consequence and promise-risk visualization supplied by authoritative Rounds state.

Mapbox does **not** own Driver active navigation, server planning truth, address/geocoding provider choice, or authoritative ETA calculations. The Operations client renders results produced by Rounds/server contracts.

## 2.2 Street imagery provider abstraction

Street imagery is **not** the basemap.

Represent it behind an interface:

```text
StreetImageryProvider
  provider: google_street_view | mapillary | none
  availability(lat,lng,radius)
  openViewer(target)
  captureTimestamp?
  attribution
```

### Google Street View

Preferred when:

- dependable street coverage is required;
- panorama quality/continuity materially helps dispatch;
- account/API economics are acceptable.

### Mapillary

Use as:

- free supplemental imagery;
- fallback when Google is not configured;
- source for merchant/driver-captured street imagery ecosystems;
- markets/streets where Mapillary has useful coverage.

Do not assume Mapillary coverage exists.

Street mode must gracefully show **No imagery available** rather than block delivery.

---

# 3. Canonical map modes

## 3.1 Operations — default

Purpose: run the business.

Visual rules:

- light/faded Rounds basemap;
- irrelevant POIs suppressed;
- quiet minor roads;
- readable major roads;
- pale water/parks;
- Rounds routes dominate;
- selected route/decision dominates;
- unrelated work can fade contextually.

Visible operational layers:

- pickup/merchant;
- own drivers;
- Rounds Network drivers when relevant;
- external courier driver when relevant;
- Stops;
- selected/unassigned work;
- current and proposed routes;
- Broadcast radius only during Broadcast;
- traffic only when decision-changing.


### 3.1.1 Marker language

Marker roles must be visually different at a glance:

- **Own drivers:** primary Rounds marker treatment; visually strongest.
- **Rounds Network / freelance drivers:** secondary/hollow treatment.
- **External courier drivers:** tertiary/external treatment, only when in use.
- **Stops:** numbered sequence markers.
- **Current Stop:** stronger emphasis than future Stops.
- **New / unassigned delivery:** distinct insertion marker.
- **Traffic:** shown on affected route segments and in ETA copy, not as noisy area-wide circles by default.

Dispatcher should not have to read initials to understand whether the marker is an own driver, freelance network driver, Stop, or new delivery.

## 3.2 Satellite

Purpose: understand physical site/driveway/compound context.

- Mapbox satellite imagery;
- Rounds route/markers remain above imagery;
- no separate satellite product surface;
- one click returns to Operations.

## 3.3 3D Site

Purpose: inspect a destination closely.

- fly to selected destination;
- zoom approximately building/site level;
- pitch approximately 40–60 degrees;
- rotation enabled;
- 3D buildings where data exists;
- selected destination emphasized;
- vehicle access marker;
- entrance/handoff marker;
- known merchant instructions;
- Address Intelligence shown beside site.

## 3.4 Street

Purpose: see real street-level context where imagery exists.

- opens provider-backed street viewer;
- preserve selected order context;
- show vehicle access and handoff metadata beside imagery;
- Google preferred / Mapillary fallback;
- street imagery failure never blocks delivery;
- return to 3D Site or Operations in one action.

---

# 4. Camera controls

Rounds provides its own minimal controller:

- Zoom in;
- Zoom out;
- Rotate left;
- Compass / North reset;
- Rotate right;
- 2D / 3D tilt toggle.

Also preserve native Mapbox gestures:

- mouse/touch pan;
- scroll/pinch zoom;
- rotate gesture;
- pitch gesture.

The compass visibly reflects map bearing.

A selected Round or order may automatically reframe the map.

---

# 5. Decision visualization

When Rounds recommends an action, the map must explain it.

Example:

```text
Best move
Add #10432 to Somchai · Round 18
+1.8 km · +7 min · no promise risk
```

Map simultaneously:

1. emphasizes Somchai and Round 18;
2. fades unrelated Rounds;
3. marks `NEW · #10432`;
4. draws current route;
5. draws proposed route change distinctly;
6. fits relevant geography;
7. shows route/load/promise impact.

The map and decision drawer may never tell different stories.


## 5.1 Traffic, ETA and promise-risk intelligence

Traffic is not a permanent visual wallpaper layer.

Rounds should use traffic to improve delivery decisions, not to make the map noisy.

Canonical rules:

- Use traffic-aware routing for active ETA calculation.
- Show **current ETA**, **typical ETA**, and **traffic delta** when helpful.
- Highlight only the affected route segment when congestion materially changes the outcome.
- Do **not** default to broad red/yellow congestion circles across the map.
- Surface traffic when it changes dispatch judgment, promise safety, customer communication, or route recommendation.

Routing/traffic basis is provider-abstracted. The selected server routing source should expose, where available:

- current duration;
- typical duration;
- congestion/incident context;
- closures/restrictions;
- a versioned route result that can be reconciled with the active navigation leg.

The Operations Mapbox renderer must not independently recalculate canonical ETA.

Example readout:

```text
Round 18
Next Stop ETA 12:16
Typical 12:04
Traffic +12 min
Promise risk: none
```

If promise risk appears, the dispatcher surface should explicitly say so and recommend the next safe move.

## 5.2 Delivery ETA is not only drive time

Rounds ETA should combine:

- route travel time;
- live traffic delay;
- pickup dwell time;
- expected handoff time;
- building/concierge access history;
- merchant-specific handling constraints.

This makes ETA more useful than a mapping provider's raw travel time.

---

# 6. Address Intelligence

## 6.1 Definition

Address Intelligence converts messy delivery input into operational location knowledge.

It combines:

- original merchant/customer input;
- provider-selected address/place search and geocoding;
- provider/Rounds-derived routable vehicle points where legally usable;
- entrance points where provider coverage or Rounds-owned observations support them;
- prior successful Rounds deliveries;
- driver-confirmed corrections;
- dispatcher-confirmed corrections;
- merchant instructions;
- failure history;
- sender/recipient confirmation where necessary.

## 6.2 Rounds must preserve the original

Never overwrite the submitted address destructively.

Store:

- original input;
- resolved/canonical representation;
- operational vehicle point;
- entrance/handoff point;
- source;
- confidence;
- correction history.

---

# 7. Thai-first resolution pipeline

Input may include:

- Thai;
- English;
- mixed Thai/English;
- building nickname;
- official building name;
- soi;
- moo;
- district/subdistrict;
- phone number;
- landmark;
- room/floor;
- LINE-copied instructions;
- alternate romanization.

Pipeline:

1. Parse raw text.
2. Separate contact/floor/unit/instructions from geographic address.
3. Search known Rounds location knowledge first.
4. Search the configured address/place provider when merchant/Rounds knowledge is insufficient.
5. Compare result against Bangkok/merchant context.
6. Compare against prior successful delivery coordinates.
7. Determine vehicle point.
8. Determine entrance/handoff when available.
9. Produce confidence.
10. Act according to merchant authority.

Do not call generic fuzzy matching “AI” unless Rounds is actually combining evidence and explaining the result.

---

# 8. Confidence and authority

Suggested product states:

## High confidence

Examples:

- exact/strong provider match;
- multiple successful merchant confirmations;
- location unchanged across recent deliveries;
- known vehicle and entrance points.

Behavior:

- Rounds may automatically route to confirmed operational point when merchant policy allows;
- audit what was used.

## Medium confidence

Behavior:

- route to Action;
- show recommended correction;
- dispatcher confirms.

## Low confidence

Behavior:

- do not silently change;
- request sender/recipient confirmation;
- permit driver evidence if already on site.

---

# 9. Learned delivery-location knowledge

Successful deliveries should improve future operations.

**Production storage is Postgres, not loose JSON files.**

A successful delivery can confirm:

- building;
- property/site;
- vehicle stopping location;
- driveway/gate;
- entrance/lobby;
- handoff location;
- parking/loading note;
- security/concierge procedure;
- aliases;
- access hours;
- vehicle restrictions.

Repeated confirmation increases confidence.

Repeated failures reduce confidence and may force review.

---

# 10. Data model

## 10.1 `location_knowledge`

```sql
create type location_knowledge_status as enum (
  'candidate', 'confirmed', 'needs_review', 'retired'
);

create table location_knowledge (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id),

  canonical_name text,
  canonical_address text,

  building_lat decimal(10,7),
  building_lng decimal(10,7),

  vehicle_lat decimal(10,7),
  vehicle_lng decimal(10,7),

  entrance_lat decimal(10,7),
  entrance_lng decimal(10,7),

  source text not null, -- merchant_history | provider | driver | dispatch | recipient
  source_provider_id text,

  confidence decimal(5,4) not null default 0.5,
  successful_confirmations integer not null default 0,
  failed_confirmations integer not null default 0,

  aliases jsonb not null default '[]'::jsonb,
  access_notes jsonb not null default '{}'::jsonb,

  last_confirmed_at timestamptz,
  last_failed_at timestamptz,
  status location_knowledge_status not null default 'candidate',

  sensitivity text not null default 'pii',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index on location_knowledge (account_id, canonical_name);
create index on location_knowledge (account_id, status);
```

## 10.2 `location_observations`

Every piece of evidence is separate from the aggregate knowledge.

```sql
create table location_observations (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id),
  location_knowledge_id uuid references location_knowledge(id),
  order_id uuid references orders(id),
  driver_id uuid references drivers(id),

  observation_kind text not null,
  -- arrival_gps | driver_correction | dispatcher_correction |
  -- pod | recipient_confirm | sender_confirm | provider_result

  lat decimal(10,7),
  lng decimal(10,7),

  outcome text,
  evidence jsonb not null default '{}'::jsonb,
  observed_at timestamptz not null default now(),

  sensitivity text not null default 'pii'
);
```

## 10.3 Additive order fields

```sql
alter table orders
  add column original_dropoff_address text,
  add column resolved_dropoff_address text,
  add column location_knowledge_id uuid references location_knowledge(id),

  add column building_lat decimal(10,7),
  add column building_lng decimal(10,7),

  add column vehicle_access_lat decimal(10,7),
  add column vehicle_access_lng decimal(10,7),

  add column entrance_lat decimal(10,7),
  add column entrance_lng decimal(10,7),

  add column address_confidence decimal(5,4),
  add column address_resolution_status text,
  add column address_resolution_source text;
```

Existing `dropoff_lat/dropoff_lng` can remain for compatibility but should represent the current operational navigation target explicitly in application logic.

---

# 11. JSONB usage

JSONB is appropriate for flexible metadata such as:

```json
{
  "aliases": ["Emporio Place", "Emporio Sukhumvit 24"],
  "access": {
    "gate": "South driveway",
    "parking": "Short stop in lobby driveway",
    "security": "Tell guard UrbanFlowers delivery"
  }
}
```

Do **not** store the entire address-learning system as loose JSON files.

Postgres is the system of record.

---

# 12. Tenant and privacy rules

Default learning scope is the merchant/account.

Do not expose one merchant's recipient/home-address history to another merchant.

Potential future global knowledge must be:

- explicitly designed;
- legally reviewed;
- stripped of customer-specific PII;
- focused on public/building access knowledge;
- compliant with Thai PDPA and relevant market law.

Building/public-venue knowledge is different from private household recipient history.

---

# 13. Address/geocoding provider storage and display rule

Provider terms differ by API/product and temporary/permanent use. Operations basemap, address provider and routing provider must be selected as a legally coherent posture rather than independently by convenience.

Implementation must:

- use the provider option appropriate for persistence;
- never assume all Search Box results may be stored permanently;
- store Rounds-owned operational observations independently;
- keep provider attribution/IDs only as permitted.

If Rounds persists a provider-derived address result, use a provider/API plan that explicitly permits the intended storage.

---

# 14. Dispatcher UX

## Order intake

Address field can show:

- `Resolved`;
- `Known location`;
- `Review location`;
- `Unresolved`.

## Order drawer

Show:

```text
Address Intelligence
Customer supplied
Rounds resolved
Vehicle access
Entrance
Confidence
Evidence
```

Actions:

- Resolve/verify;
- Use correction;
- Ask sender/recipient;
- Inspect site;
- Street view;
- Keep original;
- Save confirmed location.


Live-dispatch map/drawer should also show when relevant:

- current ETA;
- typical ETA;
- traffic delta;
- promise-risk outcome;
- driver type (own / network / external);
- item context only when it helps operations.

## Wrong-address exception

Decision first:

```text
Address appears wrong
Recommended: use corrected location
Impact: +2.4 km · +9 min
Driver consent required if Network scope materially changes
```

Then evidence/history below.

---

# 15. Driver UX

Driver app should navigate to the **vehicle access point**, not blindly to the building centroid.

Near arrival, the UI can transition from road guidance to:

```text
Vehicle entrance ahead
South driveway
Tower B lobby after drop-off
```

Driver can report:

- pin wrong;
- entrance wrong;
- access closed;
- better driveway;
- building not found.

Driver corrections are **observations**, not instant global truth.

Driver can confirm:

- `Vehicle stopped here`;
- `Entered here`;
- `Handoff here`.

The driver app remains low-cognitive-load while driving.

---

# 16. Successful-delivery learning

On successful POD:

1. store actual arrival coordinate;
2. store handoff coordinate if available;
3. compare to current knowledge;
4. create observation;
5. increment successful confirmation when within tolerance;
6. update `last_confirmed_at`;
7. increase confidence conservatively;
8. flag conflicting evidence rather than averaging blindly.

Example:

```text
The Emporio Place
7 successful deliveries
Vehicle: Sukhumvit 24 south driveway
Handoff: main lobby
Last confirmed: yesterday
```

---

# 17. Failure learning

A failed delivery may indicate:

- wrong building point;
- inaccessible gate;
- stale entrance;
- changed security policy;
- recipient-specific problem unrelated to location.

Do not automatically blame the location.

Failure observations must distinguish:

```text
location_failure
recipient_unavailable
building_access_closed
security_refused
traffic_only
driver_error
other
```

---

# 18. Street imagery UX

Street view is contextual, not permanent.

Entry points:

- Inspect destination;
- Can't find;
- Address wrong;
- Dispatcher manual site inspection.

Street panel shows:

- selected order;
- image provider;
- capture date when available;
- vehicle access;
- entrance/handoff;
- Rounds known instructions.

Street imagery never overrides confirmed Rounds knowledge automatically.

---

# 19. Map controls and gestures

Canonical custom controller:

```text
+
−
rotate left
compass / north
rotate right
2D / 3D
```

Mapbox native gestures remain available.

On iPad:

- pinch zoom;
- two-finger rotate;
- two-finger pitch;
- tap-based alternatives for all critical controls.

No critical action depends on hover.

---

# 20. External courier integration

Lalamove/external couriers receive the operational navigation target selected by Rounds.

When provider capability allows, transmit:

- canonical address;
- vehicle access lat/lng;
- entrance/access notes;
- merchant/order reference.

Rounds remains the system of record for the merchant's learned delivery location.

Do not silently push unconfirmed corrections to an external courier.

---

# 21. Events / audit trail

Recommended events:

```text
address_resolution_started
address_resolution_proposed
address_resolution_confirmed
address_resolution_rejected
location_observation_created
vehicle_access_confirmed
entrance_confirmed
street_imagery_opened
site_inspection_opened
location_knowledge_promoted
location_knowledge_review_required
```

Every automatic correction should be explainable after the fact.

---

# 22. Acceptance criteria

## Mapping

- Operations / Satellite / 3D Site / Street modes work.
- Map mode changes preserve Rounds operational context.
- Zoom, rotate, north reset and pitch controls work.
- Selected Round/decision remains visually dominant.
- Route geometry follows roads.

## Address Intelligence

- Original address is never destroyed.
- Known successful location can override navigation target under merchant authority.
- Low-confidence correction requires review.
- Driver can submit correction evidence.
- Successful POD can reinforce location knowledge.
- Conflicting corrections trigger review.
- Merchant tenancy is enforced.

## Bangkok field QA

Test:

- large condos;
- hotels;
- hospitals;
- malls;
- gated residences;
- office towers;
- sois with multiple entrances;
- Thai-only addresses;
- mixed Thai/English;
- copied LINE messages;
- wrong pin;
- valid address with wrong driveway;
- underground/high-rise GPS drift.

---

# 23. V1 / V1.1 boundary

## V1

- Mapbox Operations renderer;
- map controls;
- provider-abstracted address/place resolution consistent with vendor terms;
- merchant-level learned vehicle point;
- driver/dispatcher corrections;
- simple confidence;
- 3D/Satellite inspection;
- structured wrong-address workflow.

## V1.1 / progressive rollout

- entrance points where provider coverage supports;
- Street imagery;
- richer learned entrance/handoff model;
- automated confidence scoring;
- AI extraction from messy Thai/English address text;
- proactive address correction before dispatch;
- address-quality analytics.

Do not delay core Rounds launch solely for Street imagery.

---

# 24. Strategic outcome

Rounds should eventually know:

**not merely where the address is, but how deliveries actually succeed there.**

That knowledge compounds with every completed delivery and directly improves:

- routing;
- driver time;
- failed-delivery rate;
- customer experience;
- merchant support load;
- external courier handoff;
- Automatic Dispatch confidence.

That is the mapping moat.

*End of specification.*

---

# ADDENDUM · Canonical Map Phase 2 — Traffic, ETA, Marker Roles & Product Context

The following decisions are now locked into the real UX.

## Traffic intelligence

- Active vehicle route/traffic intelligence comes from the selected server routing provider, not from the Operations basemap.
- Request detailed traffic/restriction annotations when supported by that provider.
- Preserve current and typical duration when the provider exposes both so Rounds can calculate traffic delta.
- Calculate `traffic_delta = duration - duration_typical`.
- Do **not** paint congestion colors over the entire city by default.
- Highlight only the route segment whose congestion materially changes the delivery decision.
- A small contextual map callout may say `Traffic +12 min`.
- If traffic does not threaten a promise, state `still safe` and do not create Action.
- If traffic threatens a promised window, promote the delivery/Round to Action with the expected lateness and recommended next move.

## ETA model

Raw road ETA is only one component.

Rounds delivery ETA may combine:

1. current traffic-aware drive time;
2. typical drive time / traffic delta;
3. pickup dwell;
4. historical handoff dwell at the destination;
5. building/security/concierge access history;
6. handling constraints;
7. remaining Stop sequence.

Dispatcher can display:

```text
ETA 12:16
Typical 12:04
Traffic +12 min
Promise risk None
```

## Traffic map visual rule

Default = no traffic heatmap, no giant congestion circles, no colored road wallpaper.

Contextual signal order:

1. affected Round segment changes to amber;
2. red only when promise/route safety is actually at risk;
3. compact traffic callout on the affected segment;
4. header/drawer gives the actual minute impact.

Broad congestion regions may be considered later only when they improve planning decisions. They are not the default live-dispatch language.

## Driver marker roles

The marker itself should communicate the labor source before the user reads a name.

- **Own/team driver:** filled Rounds/navy vehicle marker.
- **Rounds Network / freelance:** hollow orange/dashed marker; preferred may use solid outline.
- **External courier:** neutral square/tertiary marker and explicit provider text in context.
- **Stop:** numbered circle in Round sequence.
- **Current Stop:** stronger accent.
- **New/unassigned order:** orange insertion marker.

Own/team and Network/freelance may never share the same primary marker treatment.

## Product/item context

When merchant order data includes a useful product image, Dispatch may show a small thumbnail on order rows and live-delivery detail.

Rules:

- image is optional;
- no empty image placeholder;
- if image is absent, render text only;
- image is operational context, not ecommerce merchandising;
- keep order number, recipient, promise window and state more important than the image;
- thumbnails should be aggressively compressed/resized for dispatch use.

The reference UX uses approximately 50px display thumbnails and sub-3KB WebP demo assets.

## Map controls

Canonical controller remains:

```text
+
−
rotate left
compass / north reset
rotate right
2D / 3D
```

All controls must be functional in Operations, Satellite and 3D Site modes. Native Mapbox gestures remain enabled.

## Street

Street remains contextual. It is not a fourth permanent navigation product.

- enter from destination inspection / can't find / wrong address;
- Google Street View preferred for coverage when configured;
- Mapillary fallback/supplemental where imagery exists;
- absence of street imagery never blocks delivery.

---

# ADDENDUM · Weather Intelligence & Contextual Weather Layer

## Provider architecture

Weather is a separate data provider layered over the Operations map.

Recommended production architecture:

```text
Mapbox GL JS
  Operations basemap + Rounds-owned operational overlays

RoutingProvider
  planned route / travel time / traffic context

WeatherProvider
  current precipitation
  precipitation forecast
  severe-weather signal
  map/radar tiles
  point/route weather queries
```

Tomorrow.io is a suitable production candidate because its Weather Maps tiles can be superimposed on Mapbox and include current and forecast precipitation. Provider choice remains abstracted so Rounds is not structurally dependent on one weather vendor.

RainViewer can be useful for development/demo radar experiments, but its public API is not the canonical commercial production dependency without appropriate commercial terms/SLA.

## UX rule

Weather follows the same principle as traffic: **decision signal, not permanent wallpaper**.

Default Operations map:

- no full-screen rain radar unless the user asks for it;
- if weather affects an active/future Round, show a compact weather impact and a subtle local weather cell;
- affected route/driver/delivery remains visually dominant;
- dispatcher may toggle the weather layer `Auto / On / Off`.

Example:

```text
Round 18
Typical ETA       12:04
Traffic ETA       12:16   (+12m)
Weather buffer    +4m
Rounds ETA        12:20
Promise ends      13:00
Risk              none
```

## Avoid double counting

Current traffic can already reflect weather-related congestion.

Do not simply add "rain minutes" on top of traffic blindly.

Weather may add an independent buffer only for effects such as:

- forecast rain ahead that is not yet represented by traffic;
- reduced motorbike operating speed/safety policy;
- waterproofing/loading time;
- fragile-product handling;
- site handoff exposure;
- severe-weather merchant policy.

The decision engine records why a weather buffer was applied.

## Weather + vehicle/product rules

Examples:

- heavy rain + exposed cake + motorbike → prefer/require car under merchant policy;
- thunderstorm + motorbike → hold or route to safer vehicle/network capacity if policy requires;
- rain expected after current delivery but before a future Stop → re-sequence if it protects the promise safely;
- severe conditions → create Action rather than silently forcing a risky assignment.

## Data / events

Recommended fields or snapshot object:

```text
weather_condition
precipitation_intensity
weather_window_start
weather_window_end
weather_eta_buffer_seconds
weather_risk_level
weather_provider
weather_observed_at
```

Recommended events:

```text
weather_risk_detected
weather_eta_adjusted
weather_vehicle_rule_triggered
weather_action_required
weather_risk_cleared
```

---

# ADDENDUM · Driver Map Interaction

**Controlling detailed spec:** `ROUNDS-SPEC-6-DISPATCH-ROUTE-EDITING-COMMS-v1.11.md`

Driver markers now have two interaction layers:

- primary click/tap: open operational Round;
- desktop right-click / touch long-press: quick-contact menu.

Communications may coexist with map highlighting on desktop. The operator must be able to center on the driver/active Round without closing the conversation.

# v1.5 Addendum · Delivered Stop Feedback

After an authoritative delivered/POD event is committed, the dispatcher map may show a short success acknowledgement at that Stop:

- Stop becomes a completed/check state;
- a restrained success ring may pulse briefly;
- a compact card may show Delivered time, manifest verification and POD-photo state;
- the transient effect settles into the normal completed marker within a few seconds.

This is feedback for the operator, not game scoring. Do not use confetti, points, streaks or effects that obscure active routes.

The animation must never precede the committed completion event and must not imply proof that has not been saved.

# Addendum · Live Destination Correction After Pickup

A dispatcher may correct a live delivery's operational destination after pickup without overwriting the original location evidence.

Rules:

- preserve original/raw address and previous operational point in audit history;
- if the physical destination changes, confirm a new operational pin / vehicle arrival point;
- if only entrance/address text changes at the same physical point, explicitly retain the existing point;
- recalculate the current route from live driver state to the revised point;
- recalculate affected downstream route/ETA state;
- push the revised route/destination to the assigned Driver App;
- require driver acknowledgement;
- never use a destination correction to bypass physical custody transfer rules.

The map may briefly surface `Live update sent` / `Driver acknowledged`, but those are acknowledgement feedback, not the source of truth.

# ADDENDUM · Network Supply Map Layer

## Map-layer purpose

The Operations map may render a privacy-safe Network Supply layer in Live Dispatch. This is separate from the exact tracking layer for the merchant's own fleet and accepted Network jobs.

## Pre-acceptance location treatment

- Raw Network GPS must not be exposed to a merchant before an accepted-work tracking relationship exists.
- Display coordinates must be generalized/fuzzed to an appropriate area-level precision.
- Busy drivers working for another merchant must not expose that merchant's route, Stops, customer, destination or exact live path.
- The UI may expose approximate area, approximate distance, state (`Open for jobs` / `Busy`) and approximate next availability where supported.

## Rendering and scale

- Use a native Mapbox GeoJSON/vector source.
- Cluster supply at low zoom levels.
- Resolve clusters into small individual capacity points at normal operational zoom.
- Filter supply by viewport/radius and operational relevance.
- Do not create hundreds of high-frequency DOM markers for generalized supply.
- Generalized supply may refresh more slowly than exact accepted-job tracking.

## Visual semantics

- Open capacity: small hollow orange point.
- Busy capacity: smaller, lower-emphasis neutral point.
- Cluster: restrained orange-outline count.
- Existing exact accepted-job markers retain their stronger job-linked visual treatment and supersede anonymous supply for that accepted work.
