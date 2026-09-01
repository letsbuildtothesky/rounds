# Rounds · External Couriers Specification

**Version:** 1.4  
**Status:** Canonical product/build specification  
**First provider:** Lalamove  
**Scope:** Business web app + shared backend  
**System of record:** Rounds Supabase/Postgres

---

# 1. Product role

External Couriers provide backup or overflow delivery capacity beneath the Rounds operating layer.

They do not replace:

- Own fleet;
- Rounds Network.

Canonical fulfillment sequence:

```text
Own fleet
→ Rounds Network
→ External courier
```

External Courier is optional.

Rounds remains useful without any provider connected.

---

# 2. First provider — Lalamove

Lalamove is the first supported provider for Bangkok/Thailand.

The merchant should connect **its own provider/business account**.

Rounds does not need to resell the courier service or hold provider delivery funds.

Conceptually:

```text
Merchant pays Lalamove
Rounds operates the booking
```

This keeps:

- provider billing relationship;
- provider wallet/credit;
- merchant account ownership

with the merchant.

---

# 3. UX ownership

External Couriers live in:

```text
Settings
→ External couriers
→ Lalamove
```

Do not add a permanent `Lalamove` top-level navigation item.

Do not add permanent:

```text
Own | Network | Lalamove
```

buttons on every order.

External capacity appears contextually when it is a valid operational next action.

---

# 4. Connection state

Provider connection should expose:

- Connected / Not connected;
- account label;
- market/country;
- health/webhook state;
- provider billing/wallet status where exposed;
- booking authority;
- automatic fare limit.

Credentials/tokens are server-side secrets.

Never put provider secret keys into browser/mobile client code.

---

# 5. Quote flow

Rounds already knows:

- pickup;
- recipient;
- contact details;
- address/location;
- items;
- handling;
- promised time;
- vehicle requirement;
- multi-stop scope.

Provider quote should therefore require **zero retyping**.

Example:

```text
External capacity available

Lalamove · Car
฿226
Pickup ~12 min
Delivery ETA 15:42
Promise safe

Use Lalamove
```

Quote should retain:

- provider quote ID;
- quoted fare;
- currency;
- vehicle/service type;
- stop count;
- quote expiry;
- estimated pickup;
- delivery ETA;
- promise-risk result.

---

# 6. Booking authority

Default:

```text
Ask before booking
```

Optional:

```text
Automatic inside limit
```

Example merchant authority:

```text
Own capacity unsafe
AND Rounds Network exhausted
AND quote <= ฿250
AND promise remains safe
AND vehicle requirement passes
→ book Lalamove automatically
```

Every automatic booking must be auditable.

---

# 7. Live external delivery

After booking, the delivery remains in the normal Rounds Dispatch board.

Example:

```text
#10512
External · Lalamove
Driver assigned
Chaiwat S.
Car
Pickup ETA 9 min
Delivery ETA 15:42
```

The external driver can appear on the same Rounds map.

Marker language must be distinct from:

- Own driver;
- Rounds Network driver.

Do not over-brand the map with a large provider logo.

---

# 8. Data model

Suggested provider abstraction:

```sql
create type fulfillment_source as enum (
  'own',
  'rounds_network',
  'external'
);

create table external_courier_connections (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id),
  provider text not null,
  status text not null,
  account_label text,
  market text,
  authority text not null default 'ask',
  max_auto_fare decimal(10,2),
  credentials_ref text,
  webhook_status text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table external_courier_jobs (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id),
  provider text not null,
  provider_job_id text,
  provider_quote_id text,

  status text not null,
  vehicle_type text,

  quoted_fare decimal(10,2),
  currency text not null default 'THB',

  driver_name text,
  driver_phone text,
  vehicle_plate text,

  pickup_eta timestamptz,
  delivery_eta timestamptz,

  provider_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

Link orders/stops to the external job through a proper join table if one job can contain multiple Rounds deliveries.

---

# 9. Provider events

Normalize provider-specific states into Rounds states.

Examples:

```text
quote_created
external_booking_created
external_driver_assigned
external_driver_arriving_pickup
external_picked_up
external_en_route
external_delivered
external_cancelled
external_failed
external_pod_received
```

Provider webhook events update Rounds.

Customer notifications subscribe to **Rounds normalized events**, not provider-specific webhook formats.

---

# 10. Map

External driver may expose:

- name;
- vehicle;
- plate;
- live coordinate when provider supplies it;
- pickup ETA;
- delivery ETA.

Map shows external driver only while operationally relevant.

External marker is visually distinct but remains subordinate to the Rounds interface.

---

# 11. History & economics

Every external delivery contributes to unified History.

Record:

- provider;
- driver;
- vehicle;
- quote;
- final provider cost;
- distance;
- waiting where available;
- delivered time;
- POD;
- exception;
- provider booking ID.

Business reporting can show:

```text
Own fleet cost
Rounds Network spend
External courier spend
Cost per delivery
External courier usage trend
```

Potential value report:

```text
Rounds Network replaced 63 external courier jobs this month.
Estimated external spend avoided: ฿X
```

---

# 12. Failure behavior

Provider failure is explicit.

Examples:

- quote expired;
- provider insufficient credit;
- no provider driver;
- provider cancelled;
- provider API unavailable.

Do not treat a provider failure as a delivered/assigned state.

Return to Action with recommended alternatives.

---

# 13. Security

- provider secret credentials server-side only;
- tenant-scope every connection/job;
- encrypt provider credentials using an appropriate secret store;
- validate webhook signatures according to provider requirements;
- never expose another merchant's provider account/job data.

---

# 14. Multi-provider future

Architecture must be provider-agnostic.

Future providers may include:

```text
Lalamove
GrabExpress
SKOOTAR
merchant-contracted courier
```

Do not create core domain names such as:

```text
lalamove_order
```

Prefer:

```text
external_courier_job
provider = lalamove
```

Whether providers may be compared side-by-side depends on provider commercial/API terms and must be reviewed before building an aggregated price-comparison marketplace.

---

# 15. Acceptance criteria

- Merchant can connect/disconnect Lalamove.
- Network failure can lead to an explicit external quote.
- Quote uses existing Rounds order data without retyping.
- Merchant can approve booking.
- Optional automatic authority respects configured fare limit.
- External driver/job appears in normal Dispatch.
- External delivery appears in unified History with cost.
- Provider failure returns to Action.
- No hidden external booking occurs.
- Own / Network / External remain clearly distinguishable.

*End of specification.*

---

# ADDENDUM · Lalamove Pickup Contact vs Commerce Buyer

Provider terminology must not collapse Rounds buyer and pickup-contact roles.

For external courier booking:

```text
provider pickup / sender contact
= merchant pickup contact

provider recipient
= Rounds recipient
```

The Rounds buyer is not sent as the provider pickup contact merely because the buyer is the person sending a gift.

Example:

```text
Merchant / pickup: UrbanFlowers · Sukhumvit 39
Pickup contact: UrbanFlowers Dispatch

Buyer / gift sender: Maya
Recipient: John

Lalamove pickup contact = UrbanFlowers Dispatch
Lalamove recipient = John
```

The provider booking layer should derive pickup identity from the merchant/location profile automatically.

Buyer data remains available to Rounds for customer service, tracking policy and order context, but is separate from courier pickup identity.


# ADDENDUM · Settings S3 Authority Surface

Settings must make the external-provider position in the capacity ladder explicit:

```text
Own fleet → Rounds Network → External courier
```

The External Couriers page is responsible for provider connection and spend authority, not for redefining core Dispatch logic.

Canonical controls/readouts:

- connected / not connected;
- merchant-owned account label;
- provider market;
- webhook/connection health;
- Ask before booking / Automatic inside limit;
- editable maximum automatic fare;
- merchant-owned billing relationship;
- explicit fallback trigger and provider-failure behavior.

Automatic provider booking must remain auditable and may occur only when the quote is promise-safe and inside the configured merchant ceiling.

Provider failure returns the affected delivery to Action.

Settings must not imply that external providers are Rounds Network drivers or that external-provider availability grants access to other merchants' work.

# v1.3 Addendum · Quote, Cancellation, Custody and POD Completion

## Quote validity

A provider quote is an expiring commitment candidate, not a permanent price. Rounds stores the quote ID, quoted fare, service/vehicle, scope, pickup estimate, delivery ETA, promise assessment and expiry.

Before booking, Rounds must verify that:

- the quote has not expired;
- the quoted delivery scope still matches the delivery/Stops being booked;
- merchant booking authority still permits the spend;
- the delivery remains eligible for external fallback.

An expired or mismatched quote cannot be booked silently. The operator receives **Refresh quote / Requote**.

## Live provider lifecycle

Provider-specific states normalize into Rounds events, including at minimum:

```text
external_booking_created
external_driver_assigned
external_driver_arriving_pickup
external_picked_up
external_en_route
external_delivered
external_pod_received
external_cancelled
external_failed
```

The live drawer should show provider, current normalized state, booking authority, fare, driver/vehicle when assigned, pickup/delivery ETA, quote/job identifiers and a short provider event trail.

## Map identity

- Once a provider driver/location exists, the external courier may appear on the normal Dispatch map.
- Marker language remains visually distinct from Own and Rounds Network.
- A small provider label such as **Lalamove** is allowed and preferred over the generic word `External` when it improves scan clarity.
- Do not use a large Lalamove logo or provider-colored map takeover.
- Remove the live marker once delivery is complete or the booking is cancelled/failed.

## Cancellation and custody

### Before pickup
Operations may cancel the provider booking. If provider pickup has not occurred:

- cancel the external job according to provider capability;
- clear the external assignment;
- return delivery work to Action/capacity review;
- retain the cancelled provider job in audit/history.

### After pickup
Provider pickup creates external physical custody. From that point:

- ordinary cancellation/reassignment is blocked;
- provider failure/cancellation becomes an **external custody exception**;
- do not clear provider/job/custody evidence;
- do not assign another courier until return, transfer or other explicit custody resolution occurs.

This rule is identical in principle to own-driver custody protection: database reassignment cannot outrun physical reality.

## Provider POD

When the provider supplies delivery proof, normalize it into the Rounds POD/history record. Preserve source attribution such as `Lalamove / external provider`. Provider proof may include photo, receiver/handoff, location, timestamp, signature or provider-specific confirmation according to API capability.

`external_delivered` and `external_pod_received` may be separate events. History should make the difference visible where evidence is still pending.

## Prototype vs production

The canonical HTML may simulate provider quotes, assignments and webhook progression for UX testing only. Production must use:

- server-side merchant provider credentials;
- real provider quote/order endpoints;
- verified provider webhook/event ingestion;
- normalized Rounds events;
- provider-supplied driver/location/POD only when actually available.

The client must never fabricate production provider state.

## Additional acceptance criteria

- Expired quotes cannot be booked without requote.
- External booking can be cancelled before pickup.
- Post-pickup provider failure preserves external custody and creates an exception rather than silent reassignment.
- External provider marker identifies Lalamove clearly but remains subordinate to Rounds.
- Live drawer exposes normalized lifecycle and provider event evidence.
- Provider POD is normalized into the delivery record/History when available.

## Browser-offline and provider-availability boundary

An operator-browser outage is not itself a Lalamove provider failure.

- An offline Operations client cannot request/requote/book/cancel provider work unless the action reaches the server/provider and is confirmed.
- Do not create a synthetic quote, booking, cancellation or provider failure solely because the browser is offline.
- A provider job already committed server-side may continue while the browser is offline; on reconnection Rounds reconciles the current provider state before presenting it as live truth.
- A real provider/API/webhook failure continues to follow the existing external-failure and post-pickup custody rules.
- Connection tests must visibly pass through `Checking…`/loading rather than jumping directly to a healthy result.
