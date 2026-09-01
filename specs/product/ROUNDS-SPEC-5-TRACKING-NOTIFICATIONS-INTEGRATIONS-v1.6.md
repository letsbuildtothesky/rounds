# Rounds · Tracking, Notifications & Commerce Integrations Specification

**Version:** 1.6
**Status:** Canonical architecture specification
**Scope:** merchant web tracking, sender/recipient notifications, Shopify, WooCommerce/WordPress, generic API/webhooks

---

# 1. Product principle

The merchant owns the customer relationship.

Rounds operates delivery and supplies merchant-branded status communication underneath that relationship.

A recipient should not need the Rounds app.

---

# 2. Secure delivery tracking link

Every delivery may issue one or more expiring/tokenized web tracking URLs.

Tracking link must not expose internal IDs or unauthorized PII.

Suggested conceptual types:

```text
sender_tracking
recipient_tracking
internal_tracking
```

The sender and recipient do not necessarily see the same information.

## Sender view

May show:

- delivery status;
- current ETA/window;
- driver progress / number of Stops away where appropriate;
- delivered timestamp;
- POD/photo where merchant policy permits;
- exception/recovery status.

## Recipient view

May show less detail:

- delivery coming;
- ETA/window;
- neutral driver/location information;
- contact/update actions where allowed.

Gift/surprise policy can suppress product/sender information until handoff.

---

# 3. Notification events

Canonical events include:

```text
delivery_scheduled
out_for_delivery
eta_materially_changed
recipient_action_required
delivered
delivery_failed
retry_scheduled
returned_to_merchant
```

Merchant selects which events produce customer communication.

## Example requested flow

### Out for delivery

Email/SMS to sender:

```text
Your gift is on the way
Track delivery: <secure tracking link>
Estimated arrival: 12:20–12:50
```

Recipient messaging is controlled separately to preserve surprise rules.

### Delivered

Email/SMS to sender:

```text
Your gift has been delivered
Delivered at 13:04
View delivery confirmation
```

---

# 4. Channels

Provider abstraction:

```text
NotificationChannel
  email
  sms
  line
  whatsapp
  webhook
```

V1 can launch with email + SMS while retaining the abstraction.

Channel delivery status is logged:

```text
queued
sent
delivered
failed
clicked
```

Do not make dispatch depend on notification success.

---

# 5. Sender ≠ recipient

Rounds must retain two-party gift logic.

Notification rules can differ by party:

```text
sender: detailed tracking + POD
recipient: neutral delivery notice
```

If `surprise = true`, recipient communications may be disabled or neutralized.

---

# 6. Commerce integrations

## Shopify

Inbound:

- receive order/create/update webhooks;
- map eligible orders to Rounds deliveries;
- ingest merchant order reference, addresses, customer/recipient contacts, delivery timing and item/handling metadata.

Outbound where merchant chooses:

- create/update fulfillment state;
- publish fulfillment events such as in-transit / out-for-delivery / delivered;
- include ETA/tracking information where supported.

Use current Shopify GraphQL Admin APIs for new implementation. Webhook handlers must verify authenticity and be idempotent.

## WooCommerce / WordPress

Canonical integration is **WooCommerce**, because ordinary WordPress alone has no standard commerce-order object.

Inbound:

- WooCommerce order-created/order-updated webhooks;
- REST API for reconciliation / fetch.

Outbound:

- update order metadata/status according to merchant configuration;
- store Rounds delivery/tracking reference;
- optionally add merchant-visible delivery note/event.

WooCommerce webhook signatures must be verified. Processing must be idempotent.

## Generic API/webhook

Any merchant system can integrate through:

```text
POST /deliveries
PATCH /deliveries/:id
webhook: delivery.status_changed
webhook: delivery.delivered
webhook: delivery.exception
```

Exact API contract is a later implementation spec, but the product architecture is locked now.

---

# 7. Integration mapping

Rounds must not force the commerce store to use named delivery slots.

Accept either:

- Rounds slot ID/name; or
- promised_start + promised_end.

Store external IDs:

```text
integration_provider
external_order_id
external_fulfillment_id
external_customer_id (when permitted/needed)
```

---

# 8. Notification templates

Templates belong to the merchant/workspace.

Variables can include:

```text
recipient_name
sender_name
merchant_name
order_reference
tracking_url
eta_start
eta_end
delivered_at
handoff_type
```

Templates must support EN/TH and merchant brand styling.

---

# 9. Tracking security / privacy

- random, unguessable signed/tokenized tracking URLs;
- expiry / revocation;
- no driver personal phone number exposed by default;
- no private merchant notes;
- no other deliveries/Round details exposed;
- honor merchant surprise/privacy rules;
- log access to sensitive tracking/POD when appropriate.

---

# 10. Data model sketch

```sql
create table tracking_sessions (
  id uuid primary key,
  account_id uuid not null,
  order_id uuid not null,
  audience text not null, -- sender | recipient
  token_hash text not null,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table notification_deliveries (
  id uuid primary key,
  account_id uuid not null,
  order_id uuid not null,
  audience text not null,
  channel text not null,
  event_type text not null,
  destination text,
  status text not null,
  provider_message_id text,
  sent_at timestamptz,
  delivered_at timestamptz,
  failed_at timestamptz,
  error_code text,
  created_at timestamptz not null default now()
);

create table commerce_connections (
  id uuid primary key,
  account_id uuid not null,
  provider text not null, -- shopify | woocommerce | generic
  status text not null,
  credentials_secret_ref text,
  config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

Secrets are never stored in browser code or plain database fields; use the approved server-side secret mechanism.

---

# 11. Delivery-event engine

Business event occurs once.

Then independent consumers may:

1. update Dispatch/history;
2. update tracking page;
3. send email/SMS;
4. notify connected Shopify/WooCommerce;
5. publish merchant webhook.

One failed notification must not roll back delivery state.

All event handling is idempotent/retry-safe.

---

# 12. What to design later

The architecture is locked now; detailed visual design can follow later for:

- sender tracking page;
- recipient tracking page;
- email templates;
- SMS copy;
- notification Settings UI;
- Shopify install/onboarding UX;
- WooCommerce plugin/onboarding UX;
- delivery-report/POD share page.

Do not block the current Dispatch build on these visual surfaces.

---

# ADDENDUM · Channel Separation

Driver communications and customer tracking notifications are separate systems.

- Dispatcher↔driver message/voice/call: Spec 6 / internal operational communication.
- Sender/recipient email/SMS/LINE/WhatsApp/tracking page: Spec 5 / external notification.

Do not route internal driver chat through customer notification providers by default.

---

# ADDENDUM · Settings Ownership & External Fulfillment Events

The canonical Settings surface now separates:

- External couriers;
- commerce integrations;
- Tracking & notifications.

## Commerce connector writeback

Shopify / WooCommerce / custom connectors should receive normalized Rounds fulfillment state regardless of physical source.

Example:

```text
Rounds delivery starts
  source = external
  provider = lalamove

→ merchant tracking link updates
→ email/SMS event may send
→ Shopify/WooCommerce fulfillment state may update
```

Customer-facing tracking should remain merchant/Rounds-branded rather than redirecting the customer into a third-party courier application by default.

## External provider identifiers

A delivery may retain:

- external provider;
- external order/job ID;
- external quote ID;
- provider status;
- provider driver metadata;
- provider POD reference;
- provider cost.

These belong to Rounds fulfillment records so History remains unified.

---

# ADDENDUM · Buyer and Recipient Notification Roles

Notification routing must use explicit buyer and recipient roles.

## Buyer = recipient

Send one logical notification stream. Do not duplicate messages merely because both role references point to the same person.

## Buyer ≠ recipient

Buyer and recipient may receive different messaging.

Example gifting flow:

```text
Buyer:
Your gift is on the way.
Your gift was delivered.

Recipient:
A delivery is on the way to you.
```

Recipient messaging may be suppressed by surprise-protection rules.

## Merchant / pickup contact

Merchant pickup contacts are operational contacts and are not customer notification recipients by default.


---

# ADDENDUM · Settings S4 Control Surface

The architecture above is now represented directly in the canonical merchant Settings surface.

## Commerce connection state

Settings must expose the commerce connection as an operational data-flow contract, not a generic integration tile.

At minimum the merchant can see:

- active provider / source;
- inbound order-intake state;
- webhook/API health;
- last reconciliation time;
- fulfillment-state writeback state;
- tracking-reference writeback state.

Supported first-party UX choices remain:

- Shopify;
- WooCommerce;
- Custom API / webhook.

Manual, screenshot, PDF, CSV, clipboard and normal `+ Deliveries` intake remain available when no commerce connector is active.

## Connector permissions

The merchant can independently control whether the connected source may:

- ingest eligible order create/update events;
- receive normalized fulfillment-state writeback;
- receive merchant-branded tracking-reference writeback;
- receive normalized delivery-exception writeback.

A connector may never bypass review of uncertain delivery data or silently dispatch an uncertain draft.

## Connection safety

- webhook/API processing is authenticated where the provider supports signatures;
- delivery event handling is idempotent/retry-safe;
- credentials/secrets remain server-side;
- connector failures do not corrupt the Rounds operational record;
- Test / Reconcile is a real action and visibly updates connection health in the prototype.

## Tracking audiences

Settings explicitly separates Sender/Buyer and Recipient audiences.

- Sender may receive detailed delivery confidence, ETA/progress and POD where policy permits.
- Recipient may receive a more neutral experience.
- When Buyer = Recipient, Rounds deduplicates the logical notification stream.
- Surprise protection can suppress or neutralize recipient-facing messaging.

## Channel controls

The Settings UI exposes merchant-controlled customer channels independently from operational driver communication.

Current surface includes:

- Email;
- SMS;
- LINE.

Notification/channel failure never rolls back Dispatch, custody, route or POD state.

## Event routing

The merchant can choose Sender and/or Recipient routing for canonical delivery events:

- `delivery_scheduled`;
- `out_for_delivery`;
- `eta_materially_changed`;
- `recipient_action_required`;
- `delivered`;
- `delivery_failed`;
- `retry_scheduled`;
- `returned_to_merchant`.

Global audience state and surprise/privacy policy remain higher-order boundaries over individual event selections.

## Tracking preview and privacy

Settings may preview Sender and Recipient tracking experiences, but previews must preserve the real privacy contract:

- no private merchant notes;
- no other Round Stops;
- no driver personal phone number by default;
- tokenized/unguessable tracking links in production;
- POD/details only where merchant policy permits.

`rounds-edge-states-v45.html` is the canonical Operations UX checkpoint; its Settings S4 surface contains the current integrations/tracking UX.


# ADDENDUM · Canonical Commerce Intake API & Connector Model

## One normalized contract

Shopify, WooCommerce/WordPress and custom systems are adapters into the same Rounds delivery-intake contract. No connector owns a separate delivery model.

Canonical sources:

1. Shopify App;
2. WooCommerce extension for WordPress commerce sites;
3. Public Rounds Delivery API;
4. inbound partner webhooks where appropriate;
5. existing manual / image / PDF / CSV / clipboard intake.

## Connector rules

- connectors call server-side Rounds APIs; they do not write Rounds tables directly;
- inbound create/update is idempotent by tenant + provider + external source ID/version;
- source order data normalizes to the same actor, address, manifest, service-date, window and cargo structures used by manual intake;
- connector input still runs normal validation/address intelligence/planning rules;
- writeback uses Rounds normalized state, not vendor-specific own/Network/Lalamove internal states;
- provider signatures/OAuth/webhook authenticity are verified server-side;
- connector errors/reconciliation are visible and auditable;
- disconnecting a connector never deletes existing delivery/custody/history evidence.

## Public Rounds API product contract

A merchant with a custom site/ERP must be able to create/update/cancel eligible deliveries without installing Shopify/WooCommerce.

The eventual Build Spec must define versioned endpoints/contracts for at least:

- create delivery;
- update pre-custody delivery data;
- cancel eligible delivery;
- read delivery/fulfillment state;
- receive signed Rounds webhooks;
- reconciliation/idempotency semantics.

Exact endpoint names/payloads are deliberately deferred to Engineering Build Specs.

## Outbound events

Public/commerce consumers should be able to subscribe to normalized events such as:

- delivery.created / scheduled;
- delivery.assigned;
- delivery.picked_up;
- delivery.eta_changed (material changes only where configured);
- delivery.delivered;
- delivery.failed / exception;
- delivery.retry_scheduled;
- delivery.returned;
- POD/evidence available where merchant policy permits.

## Localization

Customer/driver notification content is localized according to audience preference/configuration. Connector state values and webhook event names remain language-neutral.
