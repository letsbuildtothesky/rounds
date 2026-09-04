# ROUNDS — SPEC 2
## Business & Product Master Specification

**Status:** Canonical product master v2.26  
**Date:** 1 September 2026  
**Scope:** Business model, product thesis, network model, operating model, commercial model, and V1 boundaries.  
**Visual authority:** This business/product master does not duplicate pixel-level UI rules. Current visual behavior is defined by the canonical Operations HTML, the Driver board library, the Operations Visual System, and the Driver UI Constitution. Those sources are already designed and are not waiting for a separate redesign.

## Changelog

- **v2.26 — 2026-09-04:** Consolidated the append-only product phases into
  the owning master, removed the premature end marker and replaced
  supersession instructions with direct canonical statements. Product behavior
  is unchanged.

---

## Implementation boundary — product-complete V1 vs first deploy

This specification defines the **product-complete Rounds V1 target**. It does **not** mean every V1 capability ships in the first deploy.

Implementation is deliberately vertical and evidence-led. The active implementation scope is controlled by `ROUNDS-IMPLEMENTATION-SCOPE-LADDER-v1.0.md`.

The first production slice is UrbanFlowers-first and Own-Team-first: one merchant, Team drivers, delivery intake, assignment/Round execution, pickup/custody, embedded navigation, live location, handoff/POD, completion and History.

The following designed capabilities remain part of the product library but are **not Slice 1 dependencies**: public/open Network, live face check/biometric verification, Network earnings/Get Paid, settlement automation, broad Network admin, Lalamove, production commerce connectors, advanced Address Intelligence, Street imagery/3D, and Rounds Direct. They are promoted only by the implementation scope ladder and the Build Spec for the active slice.

Canonical Driver boards are a **product-design library**, not a command to implement all 47 screens in the first release.

---

## 1. What Rounds is

Rounds is a **delivery operating system and shared driver network for businesses**.

A business can use Rounds to manage its own drivers, build multi-stop delivery rounds, assign work, track delivery progress, collect proof of delivery, and handle overflow when its own fleet does not have enough capacity.

The network layer is what makes Rounds different from normal dispatch software.

When a business has more deliveries than its own drivers can handle, Rounds can broadcast the work to nearby drivers. The business first reaches drivers it already knows and trusts inside the relevant distance. If they do not accept, the job expands to the wider Rounds network.

Rounds therefore combines two products:

1. **Rounds Dispatch** — software for running the business's own delivery operation.
2. **Rounds Network** — shared delivery capacity that businesses can use when their own fleet is full, unavailable, or inefficient for a particular job.

Rounds is not a consumer marketplace, not a food-discovery app, and not a traditional courier company. The business remains the owner of the customer relationship, the order, the brand, and the commercial relationship with the customer.

Rounds owns the infrastructure that moves the order.

---

## 2. The problem Rounds solves

Businesses that deliver locally have a structural capacity problem.

Delivery demand is not evenly distributed across the day.

UrbanFlowers is a clear example: a large percentage of orders can cluster in the morning. The business may have enough drivers for an average day, but not enough drivers for the morning peak. Hiring enough full-time drivers to cover the peak means paying for excess capacity for the rest of the day. Not hiring enough means constantly buying overflow capacity from Lalamove or similar services.

Restaurants have the same problem at different times. Their peaks are often concentrated around lunch and dinner. A bakery, florist, pharmacy, laundry business, ecommerce merchant, and restaurant can all have different high-demand periods.

This creates unused driver capacity in one business at exactly the time another business needs more capacity.

Today that capacity is fragmented.

A florist may know ten riders by name. A restaurant may have five drivers who are idle after lunch. A pharmacy may use a LINE group of local riders. A business may repeatedly use the same Lalamove riders without owning any reusable relationship with them.

Rounds turns those disconnected relationships into a usable network.

The core economic problem is therefore not simply “how do I deliver this order?” It is:

- How do I run my own drivers efficiently?
- How do I absorb peaks without permanently overstaffing?
- How do I reuse drivers I already trust?
- How do I access nearby capacity without paying marketplace-style economics?
- How does a driver earn more from idle time without constantly switching between unrelated systems?

Rounds is built around those questions.

---

## 3. The core principle

Rounds should preserve value for the two parties actually creating the delivery:

**the business and the driver.**

The business should keep control of:

- the customer;
- the order;
- the selling price;
- the delivery promise;
- the driver rate;
- its own driver relationships;
- its brand experience;
- its customer data.

The driver should know exactly what they are being offered and keep the full amount they accepted.

Rounds should make money from software and successful network infrastructure, not by taking a percentage of the merchant's sale or silently reducing the driver's fare.

This principle drives the business model, the network model, and the decision not to become a consumer marketplace.

---

## 4. What Rounds is not

### 4.1 Not a GrabFood-style marketplace

Rounds does not need consumers to download an app, browse restaurants, compare merchants, search menus, read reviews, or discover products.

Rounds does not need to create consumer demand.

The merchant already has demand. Rounds helps fulfil it.

### 4.2 Not a percentage-of-GMV business

Rounds does not take 20%, 30%, or any other percentage of the value of the food, flowers, medicine, gifts, or products being sold.

A ฿2,000 dinner is not automatically more expensive for Rounds to deliver than a ฿400 dinner. The commercial model should reflect the logistics work performed, not the basket value.

### 4.3 Not a driver employer

Rounds does not need to centrally employ the whole driver network.

Drivers may be employed by a merchant, independently self-employed, merchant-linked, or verified members of the open Rounds network.

### 4.4 Not only fleet-management software

If Rounds only managed a business's existing drivers, it would still be useful, but it would miss the structural advantage.

The shared network is fundamental.

### 4.5 Not dependent on a dedicated dispatcher

A business should not need to create a full-time dispatch position just to use Rounds.

A larger operator may choose to have a dispatcher. A small restaurant should not need one.

The dispatcher is a **software capability**, not a mandatory job title.

---

## 5. The three layers of delivery capacity

Rounds should treat business delivery capacity in three layers.

### Layer 1 — Own Team Drivers

These are drivers employed by, contracted directly to, or operationally controlled by the business.

They are the first capacity the business uses.

Rounds should optimize their work before buying outside capacity. That includes building multi-stop rounds, balancing routes, and avoiding unnecessary empty travel.

### Layer 2 — Preferred / Known Drivers

These are drivers the business already knows or trusts but who are not necessarily part of the company's own permanent team.

A preferred driver can become known to the business because:

- the business invited the driver directly;
- the driver previously completed a delivery for the business;
- staff marked the driver as preferred;
- the driver has an established relationship with the business;
- the driver was introduced through another trusted Rounds business.

A preferred driver can be preferred by multiple businesses.

This relationship is an asset belonging to the merchant's delivery network inside Rounds.

### Layer 3 — Open Rounds Network

These are qualified, available drivers who can receive jobs from subscribing businesses even if they have never worked with that specific business before.

They provide the outer capacity layer when own drivers and preferred drivers cannot absorb demand.

---

## 6. Global driver identity — the key architectural principle

A driver should not fundamentally “belong” to only one business account.

The driver is a person with one Rounds identity.

Relationships sit around that identity.

A driver may simultaneously be:

- an UrbanFlowers team driver;
- a preferred driver for a bakery;
- a previously used driver for a pharmacy;
- eligible for the open Rounds network while off shift.

Therefore the correct conceptual model is:

### Driver identity

One persistent identity for the person, vehicle, verification, reputation, and history.

### Business membership

Defines whether the driver is an employee/team driver or otherwise formally attached to a specific business.

### Business-driver relationship

Defines whether that business knows, prefers, blocks, trusts, or has previously worked with that driver.

### Network eligibility

Defines whether the driver is allowed to receive open Rounds jobs.

### Availability state

Defines whether the driver is currently available for a particular mode of work.

This removes the need to treat “Hybrid” as a permanent driver identity.

A team driver who is allowed to take network work after their shift simply has:

- an active Team relationship with their employer; and
- open-network eligibility outside the employer shift.

Hybrid behavior becomes a capability created by relationships and state rather than a separate kind of human being.

---

## 7. Why the network compounds

Every new Rounds business can bring three things into the system:

1. delivery demand;
2. its own team drivers;
3. external riders it already knows.

That means a new merchant can increase both sides of the network at once.

UrbanFlowers may contribute three team drivers plus twenty known riders accumulated from previous deliveries.

A restaurant may contribute five team drivers and ten local riders.

A pharmacy may contribute two team drivers and several trusted evening riders.

The useful network becomes larger without Rounds having to recruit every driver centrally.

This is the central flywheel:

**more businesses → more driver relationships → more local density → faster fill → better business economics → more businesses.**

There is a second flywheel around time of day.

Different categories peak at different times.

A florist may be overloaded in the morning. Restaurants may peak at lunch and dinner. Pharmacies may see more evening or urgent demand. Ecommerce may distribute work differently again.

That temporal complementarity can increase driver utilization across the day.

The same driver who helps UrbanFlowers in the morning may be available for restaurant work later.

This is one of the strongest structural reasons the shared network can become efficient.

---

## 8. Dispatch priority — distance first, relationship second

Rounds must not send work to a preferred driver far away while ignoring a good nearby driver simply because of the relationship.

**Distance determines the active candidate pool. Relationship determines priority inside that distance.**

The default broadcast logic should therefore work in waves.

### Step 0 — Own team capacity

Before any network broadcast, Rounds checks whether one of the business's own drivers can take the delivery without creating a bad route or missing existing delivery windows.

If yes, the system can assign or recommend the job internally.

If no, it moves to the network.

### Wave 1 — Preferred drivers within 3 km

Offer the job first to available preferred/known drivers whose current position is within 3 km of the pickup and who meet the job requirements.

### Wave 2 — All qualified Rounds drivers within 3 km

If no preferred driver accepts, open the job to the wider qualified network inside the same 3 km radius.

### Wave 3 — Expand radius

If the job remains unfilled, expand outward.

A practical default may be:

- preferred drivers inside 3–5 km;
- then all qualified drivers inside 3–5 km;
- then another merchant-defined expansion, for example 5–8 km.

The exact radii and timers should be configurable later based on density and category.

The non-negotiable rule is:

**A distant preferred driver does not jump ahead of the entire closer network.**

---

## 9. Driver eligibility for a broadcast

A driver should only be included in a broadcast wave if the driver is operationally suitable for the job.

Eligibility may include:

- currently available;
- not already committed beyond route capacity;
- correct vehicle type;
- within the active radius;
- not blocked by the merchant;
- not suspended from the network;
- capable of meeting pickup and delivery windows;
- legally or operationally eligible for the category where required;
- compatible with package size or special handling;
- able to complete the proposed round before another committed job.

Later, route direction should become an important signal.

A driver 2.8 km away moving directly toward the pickup may be more useful than a driver 1.5 km away travelling in the opposite direction with three committed stops.

The first version can use simpler rules, but the architecture should expect route-aware matching.

---

## 10. Multi-stop is fundamental, not optional

Rounds is not a one-delivery-at-a-time product.

A core purpose of Rounds is to make each driver trip more productive.

UrbanFlowers should be able to take several deliveries and build a **Round**:

- Pickup from UrbanFlowers;
- Stop 1;
- Stop 2;
- Stop 3;
- Stop 4;
- return, continue elsewhere, or finish.

The system should optimize the sequence using:

- delivery windows;
- geography;
- traffic;
- vehicle capacity;
- priority/VIP flags;
- item constraints;
- driver shift end;
- existing commitments.

Multi-stop affects both owned drivers and the network.

### Team-driver rounds

The merchant can assign a complete optimized round to an own driver.

### Network rounds

The merchant may also broadcast a bundled multi-stop round to an outside driver where it is economically and operationally sensible.

The driver should then accept the entire clearly defined package with a guaranteed total payout, number of stops, route estimate, and expected duration.

### Dynamic additions

Later, Rounds may add a new stop to an active round if the detour is acceptable and the driver agrees where required.

The concept of the **Round** is a core product object and should exist in the data model from the beginning.

---

## 11. The route-fit idea

Rounds should eventually optimize not only “who is closest?” but “who can do this with the least waste?”

Examples:

- A driver has just delivered in Sathorn and is returning toward Phrom Phong.
- A new job needs to go from Sathorn to Asoke.
- Rounds can identify that the job is effectively on the driver's way back.

The offer could economically make sense for all parties even if the absolute fare is lower than a completely separate trip because the driver avoids an empty return journey.

This creates the long-term concept:

**jobs that fit your route.**

It can reduce empty kilometers, improve driver earnings per working hour, and reduce the business's delivery cost.

This should be treated as a major future optimization layer even if V1 starts with distance + availability + relationship.

---

## 12. Driver onboarding — three practical paths

The old binary of “Team” versus “full public freelancer” is not enough for the real network acquisition loop.

Rounds needs three onboarding paths.

### 12.1 Team Driver

Used when a business is onboarding its own driver.

The business vouches for the employment relationship and invites the driver.

The flow should be extremely fast.

The objective is not to perform full public-network KYC before the driver can do their normal job for their employer.

Typical minimum:

- phone verification;
- business invite;
- name;
- vehicle/plate;
- basic identity/photo.

### 12.2 Merchant-Linked Driver

This is critical for bootstrapping Rounds.

A rider comes to UrbanFlowers through an existing delivery. UrbanFlowers wants to use that rider again without waiting for a full open-network application process.

UrbanFlowers can invite the rider through a QR code or link.

The driver completes a lightweight setup and becomes eligible to receive UrbanFlowers work directly.

Initial merchant-linked eligibility can be restricted to the inviting merchant until the driver completes the full verification required for the open network.

This gives Rounds a **trust ladder** rather than forcing every rider through the highest-friction onboarding on day one.

### 12.3 Verified Network Driver

A driver who wants work from any Rounds business completes the full Rounds network verification.

That can include:

- verified identity;
- selfie;
- vehicle and plate;
- driver's licence where applicable;
- payment information;
- insurance/documentation where required;
- acceptance of network terms.

Once approved, the driver can receive jobs across the open network.

### Team driver becoming network eligible

An employer-linked team driver can later enable open-network work outside their employer shift if:

- the employer permits it where required;
- the driver completes any extra payout or verification requirements;
- the driver explicitly goes available for network work.

---

## 13. Preferred-driver relationships

The preferred-driver layer should become one of the most valuable parts of Rounds.

A business should be able to build a reusable network over time.

Possible relationship states include:

- invited;
- used before;
- preferred;
- priority;
- blocked;
- team;
- inactive.

A business may also want operational notes such as:

- good with fragile flowers;
- knows our pickup procedure;
- has a large delivery box;
- reliable for early morning;
- preferred for Sukhumvit;
- good for multi-stop work.

These relationships should be visible to the business but should not become an opaque public marketplace score.

The merchant should feel that Rounds helps them **build their own delivery network**, not rent an anonymous network forever.

---

## 14. Business operating model — no dedicated dispatcher required

Rounds must work for both small and large businesses.

### Small business mode

A small restaurant, bakery, florist, or pharmacy may have no dedicated dispatcher.

The operator should be able to:

1. create or receive an order;
2. mark it ready for delivery, or let an integration do that automatically;
3. let Rounds choose the next dispatch action according to business rules;
4. receive a simple confirmation when a driver is assigned.

The owner, cashier, kitchen manager, or shop staff can then continue doing other work.

Rounds should perform the dispatch work in the background.

### Larger operations mode

A larger business may have a dispatcher or operations manager who wants full control over:

- routes;
- driver assignments;
- network broadcasts;
- exceptions;
- live map;
- reassignments;
- delays;
- route balancing.

The same product can support both modes.

The business does not need to hire a dispatcher to justify Rounds. Rounds should reduce dispatch labor, not create it.

---

## 15. Automatic dispatch

The long-term default should be automation with merchant-defined authority.

Example:

An order becomes ready.

Rounds checks:

1. Can this fit into an existing own-driver round?
2. Is an own driver available for a new round?
3. Should the business wait and batch it with another order?
4. If own capacity is insufficient, which network wave should start?
5. Which driver accepts?
6. Does the accepted job need to be inserted into a round?

The merchant can choose how much of this is automatic.

A small restaurant may use near-full automation.

UrbanFlowers may want greater control over high-value bouquets, VIP windows, or fragile deliveries.

Rounds should therefore be rules-driven rather than forcing one operating style.

---

## 16. Order intake

Rounds should not require the business to retype every customer order.

Orders may enter from:

- manual creation;
- ecommerce integrations;
- POS integrations;
- merchant API;
- uploaded batch/CSV;
- future direct-order tools from Rounds Direct.

The exact integrations are an implementation roadmap decision.

The business/product requirement is that Rounds treats delivery orders as an input from the merchant's existing commerce operation rather than forcing the merchant to rebuild commerce inside Rounds.

---

## 17. Business model

Rounds should have **two core monetization engines and one strategic direct-commerce engine**.

The model should remain simple enough for a merchant to understand immediately:

**subscription + fixed successful-network fee + optional direct-commerce infrastructure**

Rounds does not need a percentage of merchant sales to become a large business.

### 17.1 Revenue engine 1 — SaaS subscription

Businesses pay a recurring subscription for the Rounds operating system.

The subscription covers software value such as:

- own-driver management;
- route planning;
- multi-stop rounds;
- dispatch rules;
- live delivery operations;
- proof of delivery;
- driver relationships;
- business history and reporting;
- integrations according to plan;
- access to Rounds Direct according to plan;
- access to the Rounds network capability.

The exact plan structure and pricing are not fixed in this specification.

### 17.2 Revenue engine 2 — fixed successful-network fee

When Rounds successfully provides external network capacity, Rounds can charge the business a **fixed network fulfillment fee**.

This fee is not a percentage of the merchant's basket and is not deducted from the driver's accepted fare.

Example for illustration only:

- Driver offer: ฿120
- Driver receives: ฿120
- Rounds successful-network fee: ฿15
- Business logistics cost: ฿135

If the merchant sold a low-value item or a high-value item, the Rounds network fee does not increase simply because the basket value increased.

The business pays for successful delivery infrastructure, not a tax on the value of its sale.

### 17.3 Revenue engine 3 — Rounds Direct

Rounds Direct is the merchant-owned direct-commerce layer.

Rounds can monetize it through a higher subscription tier, a fixed order infrastructure fee, or a combination of both. The commercial rule remains the same:

**Rounds should not take a percentage of the merchant's sale.**

Third-party card/payment processing fees can pass through transparently where applicable. Rounds should not hide those costs inside a marketplace commission.

The merchant should remain the seller of record and, where technically and legally practical, customer payment should settle directly to the merchant rather than passing through a Rounds-controlled balance.

### 17.4 Why the three engines belong together

The subscription monetizes the operating system.

The network fee monetizes the moment when Rounds successfully supplies capacity outside the merchant's own fleet.

Rounds Direct monetizes the infrastructure that helps a merchant bring more of its own customer demand into a direct channel.

They reinforce one another:

**more direct orders → more delivery demand → more driver activity → denser network → better fill rates → more valuable Rounds subscription.**

### 17.5 Later add-ons

Potential later revenue includes:

- additional business locations;
- enterprise controls;
- advanced integrations/API access;
- premium analytics;
- advanced route optimization;
- custom SLA/support;
- automated settlement services if legally and commercially appropriate;
- premium Rounds Direct commerce capabilities.

These are add-ons, not reasons to compromise the zero-percentage position.

---

## 18. The three Rounds promises

Rounds should protect three statements because they describe the intended architecture, not merely the marketing.

### 18.1 We don't own your customer

The merchant remains the business the customer is buying from.

Rounds can provide identity, checkout, saved addresses, search, delivery tracking, and convenience, but it does not convert the merchant's customer into an anonymous platform-owned customer.

Where the customer lawfully opts into the merchant's communication or loyalty program, the merchant keeps that relationship.

### 18.2 We don't take a percentage of your sale

Rounds earns through subscriptions, fixed network fees, and transparent infrastructure fees.

Rounds does not earn more simply because the merchant sells a more expensive bouquet, meal, gift, cake, medicine, electronic item, or other product.

This matters especially for businesses with higher average order values, where percentage commissions can become economically irrational even when the physical delivery work is unchanged.

### 18.3 We don't hold your money

The preferred architecture is for customer funds to settle directly to the merchant's own payment account wherever practical.

Rounds should not create unnecessary working-capital delay by collecting the merchant's gross sales and paying them out later after deducting a commission.

Likewise, the driver payment model should not require Rounds to custody driver earnings in V1. Rounds can record who owes what and whether it was paid without becoming the wallet in the middle.

Together these create the core trust statement:

**Your customer. Your sale. Your money. Rounds powers the order and the delivery.**

---

## 19. Driver payment and settlement

Rounds does not need to hold driver money in V1.

The business can pay the driver directly according to the agreed payout method and schedule.

However Rounds must still provide a clear **settlement ledger**.

For every external-network job, the system should know:

- driver fare earned;
- business that owes it;
- delivery/round reference;
- date earned;
- status: earned / due / paid / disputed;
- payment method;
- expected payout date;
- payment reference where available.

This solves the accountability problem without forcing Rounds to become a regulated wallet before the product needs it.

A driver who worked for UrbanFlowers, a bakery, and a pharmacy should be able to understand who owes what and when.

A merchant should be able to reconcile the same ledger.

Later, Rounds can evaluate automated payouts, prefunding, or payment orchestration if the legal and commercial case is strong enough.

### 19.1 Customer-payment cash flow

Rounds Direct should improve merchant cash flow rather than recreate marketplace settlement delay.

The preferred payment architecture is:

**customer → merchant payment account**

Rounds records the order and the payment state but does not need to receive the merchant's gross sale first.

This creates several benefits:

- the merchant receives funds faster according to its own payment-provider settlement;
- Rounds does not need to finance merchant working capital;
- there is no large merchant balance sitting inside Rounds;
- reconciliation becomes transparent;
- the zero-percentage position remains structurally credible.

If a specific payment method or market requires another structure, it should be treated as an exception rather than the default business model.

---

## 20. How network fares are set

The business should control what it is willing to pay for network work.

The pricing rule can eventually include:

- base pickup amount;
- distance;
- number of stops;
- vehicle type;
- urgency;
- time window;
- waiting time;
- oversized or fragile handling;
- return trip;
- surge or special-event premium.

But the driver should not be forced to mentally calculate the rule.

The driver sees a **guaranteed total offer** before accepting.

For a multi-stop round, the driver sees the guaranteed total for the round.

If the scope changes materially after acceptance, any fare adjustment must be explicit.

---

## 21. No hidden network ranking

Rounds can rank candidates operationally, but it should not become a marketplace where merchants can secretly pay to jump ahead or drivers are manipulated by opaque algorithms.

Candidate ordering should be based on useful logistics factors such as:

- distance;
- existing relationship;
- route fit;
- availability;
- capacity;
- reliability;
- job requirements.

The business should understand the broad logic.

The driver should understand why they are or are not eligible where practical.

Paid placement should not determine which driver gets a delivery.

---

## 22. Rounds Direct — merchant-owned direct commerce

Rounds Direct is not a distant side project. It is a **strategic network-building layer** that can feed merchant-owned demand into the Rounds delivery system.

Rounds does not need to spend heavily convincing consumers where to eat, what florist to use, or which pharmacy to choose. The merchant already has customers, reputation, repeat demand, social audiences, physical locations, packaging, websites, and word of mouth.

Rounds Direct gives those merchants a better direct channel.

### 22.1 What the customer can do

A customer can reach a merchant in three primary ways:

**Scan** — scan a merchant's Rounds QR code on packaging, a receipt, table card, storefront, delivery insert, advertisement, or other merchant-owned touchpoint.

**Link** — open a direct merchant link sent through LINE, Instagram, Facebook, email, SMS, the merchant's website, or another lawful merchant-owned channel.

**Search** — open Rounds and search for a business the customer already knows, for example by business name and location.

The important distinction is that Rounds can make merchants **searchable** without turning the product into a marketplace that manipulates discovery.

### 22.2 Merchant storefront

A Rounds Direct merchant surface can include:

- merchant branding;
- products or menu;
- pricing;
- options/add-ons;
- delivery address;
- delivery time/window;
- pickup option where relevant;
- payment;
- saved customer details with consent;
- order history;
- delivery tracking;
- reorder.

The experience should feel like ordering **from the merchant**, powered by Rounds.

### 22.3 Search without marketplace ownership

Rounds can provide a neutral search layer so a customer can find a business by name, neighborhood, or category.

Search does not require Rounds to become a traditional marketplace.

The initial principle should be:

**help the customer reach the merchant they are looking for; do not manufacture an auction for the customer's attention.**

Therefore the core model should avoid dependence on:

- sponsored ranking;
- paid placement;
- exclusivity deals;
- platform-funded coupon wars;
- opaque recommendation algorithms that decide who gets demand;
- marketplace-owned customer lists.

Neutral discovery can expand later if it benefits merchants without breaking these principles.

### 22.4 The Order Direct movement

Rounds can become recognizable to customers as the infrastructure behind direct ordering.

A merchant can display a simple signal:

**ORDER DIRECT WITH ROUNDS**

The movement is not "leave every marketplace immediately." Marketplaces can still create valuable new-customer discovery for some businesses.

The movement is:

**when you already know the business you want, order direct.**

That is especially compelling for repeat orders.

The merchant can keep more of the sale. The customer can potentially receive better direct value. The merchant owns the relationship. Rounds provides the operating and delivery infrastructure.

### 22.5 Why Direct strengthens the driver network

Every merchant joining Rounds Direct can bring demand into the delivery network without Rounds having to acquire that demand centrally.

The merchant may also bring:

- its own team drivers;
- riders it already knows;
- recurring delivery patterns;
- repeat customers.

This creates a powerful network loop:

**merchant joins → merchant brings customers → customers create direct orders → orders create driver demand → merchant brings drivers/preferred riders → network density improves → Rounds becomes more useful to the next merchant.**

Rounds Direct is therefore not only a commerce feature. It can be a **network-acquisition engine** for both demand and supply.

### 22.6 Customer convenience can still compound

A customer may use one Rounds identity across many independent merchants for convenience such as:

- saved delivery addresses;
- payment preferences where permitted;
- recent merchants;
- favorite merchants;
- order history;
- delivery tracking.

This convenience belongs to the customer. It should not be used as justification for taking ownership of the merchant relationship.

### 22.7 Commercial model

Rounds Direct should be monetized through infrastructure economics rather than marketplace commission.

Possible models include:

- included in a premium Rounds subscription;
- fixed monthly Direct add-on;
- small fixed per-order infrastructure fee;
- transparent third-party payment-processing fees passed through separately.

No percentage of the merchant's basket is required.

---

## 23. Why Rounds should not become a traditional consumer marketplace

A searchable Rounds consumer surface is useful. A traditional demand marketplace is a different business.

Rounds should not build its core around persuading consumers to browse thousands of merchants, then monetizing who gets shown first.

A traditional marketplace adds a large new cost and operating burden:

- consumer acquisition;
- restaurant/merchant discovery economics;
- ranking and recommendation;
- marketplace promotions;
- platform-funded discounts;
- advertising inventory;
- customer support for marketplace disputes;
- refund operations;
- cross-merchant merchandising;
- demand-generation subsidies;
- constant competition for consumer habit.

Most importantly, that model creates pressure to own the customer and extract a percentage from the transaction — exactly the structure Rounds is designed to avoid.

Rounds can still have a consumer app or website.

The boundary is:

**Rounds can help a customer find and order from a merchant. Rounds should not need to stand between the merchant and customer as the economic owner of that relationship.**

That lets Rounds become large on the consumer side without becoming GrabFood.

---

## 24. Restaurant strategy

Restaurants are one of the clearest Rounds opportunities because they combine repeat demand, concentrated delivery peaks, existing rider relationships, and strong sensitivity to percentage-based marketplace economics.

Rounds should support two complementary restaurant jobs:

### 24.1 Delivery operations

The restaurant can use:

- its own drivers when efficient;
- preferred riders when extra capacity is needed;
- the open Rounds network for overflow;
- multi-stop rounds for grouped local orders;
- automated dispatch so ordinary staff do not become full-time dispatchers.

### 24.2 Direct repeat ordering

A restaurant can use Rounds Direct for customers who already know and want that restaurant.

The customer can scan a QR, open a merchant link, or search the restaurant by name inside Rounds.

That gives the restaurant a direct reorder channel without requiring Rounds to purchase consumer demand.

The restaurant can decide whether to offer direct-order pricing, loyalty, free delivery thresholds, pickup, or other merchant-owned incentives.

### 24.3 Marketplace coexistence

Rounds does not require a restaurant to abandon third-party marketplaces that create useful new-customer discovery.

A merchant may use marketplaces for acquisition while using Rounds for:

- direct customers;
- repeat customers;
- website/LINE/social orders;
- corporate orders;
- catering;
- high-value orders;
- owned delivery operations.

Rounds should not depend on merchants violating another platform's merchant agreement to move orders off-platform. The product should be attractive using customer relationships and channels the merchant is entitled to use.

### 24.4 High-order-value restaurants and merchants

Percentage commissions become especially painful as average order value increases because the platform fee rises with the sale even when the delivery work is similar.

This means Rounds is not only attractive to low-ticket restaurants. Premium restaurants, catering, group orders, corporate food orders, large cakes, gift baskets, and other high-value local commerce may have an even stronger economic reason to use fixed infrastructure pricing.

---

## 25. Business opportunity map

Rounds should not be thought of as a restaurant-only product. The underlying opportunity exists anywhere a business has local customer demand, delivery peaks, existing driver relationships, or high basket values that make percentage-based intermediary economics unattractive.

The strongest early businesses are those where Rounds can improve both **commerce economics** and **delivery operations**.

### 25.1 Florists and gifting businesses

**Why they fit:** High average order values, strong same-day expectations, delivery peaks around mornings and occasions, fragile/high-value products, frequent use of own drivers plus overflow couriers.

**Rounds opportunity:** Multi-stop morning rounds, preferred riders, POD, VIP/fragile rules, direct repeat ordering, gifting checkout, corporate gifting, scheduled delivery windows.

UrbanFlowers is the primary proving ground for this category.

### 25.2 Restaurants

**Why they fit:** Lunch/dinner peaks, repeat customers, existing marketplace dependence, strong direct-order potential, many businesses already know local riders.

**Rounds opportunity:** Direct ordering, automated dispatch, own-driver + preferred-driver + pool capacity, delivery batching, merchant-owned customer relationship.

### 25.3 Bakeries, cafés and dessert businesses

**Why they fit:** Scheduled orders, cakes and celebration orders with higher basket values, morning/event peaks, fragile products, repeat local customers.

**Rounds opportunity:** Pre-scheduled rounds, direct reorder links, careful-driver preferences, route batching, proof of delivery.

### 25.4 Cakes and celebration specialists

This can be treated as a high-value subcategory rather than ordinary food delivery.

**Why they fit:** Expensive products, strict delivery times, fragile handling, customer anxiety around successful arrival.

**Rounds opportunity:** Specialist-driver tags, premium delivery handling, direct checkout, recipient tracking, POD, scheduled multi-stop event rounds.

### 25.5 Pharmacies and health retail

**Why they fit:** Local recurring demand, urgency, evening demand that can complement other categories' peak times, existing neighborhood customer relationships.

**Rounds opportunity:** Fast local dispatch, trusted-driver relationships, delivery proof, repeat-order direct channels, after-hours network capacity where legally permitted.

Rounds must respect all applicable pharmacy, prescription, identity, and product-handling laws; regulated-product rules are a market-specific layer, not something the dispatch product should assume away.

### 25.6 Specialty grocery, butcher, seafood and fresh-food merchants

**Why they fit:** Repeat ordering, heavy/bulky bags, freshness windows, neighborhood density, direct LINE/phone ordering already common.

**Rounds opportunity:** Vehicle matching, grouped neighborhood rounds, temperature/handling notes, direct ordering, scheduled weekly deliveries.

### 25.7 Premium food, catering and corporate food orders

**Why they fit:** High basket values make percentage commissions especially unattractive; deliveries may involve larger loads, fixed windows, and multiple recipients.

**Rounds opportunity:** Fixed-fee economics, van/car matching, multi-stop corporate rounds, scheduled delivery, POD, invoice-linked operations.

### 25.8 Local ecommerce and D2C brands

**Why they fit:** Brands may already own their ecommerce demand but still outsource last-mile delivery one order at a time.

**Rounds opportunity:** Shopify/WooCommerce/API order intake, same-day local delivery, own-driver management, preferred network, route batching, branded tracking.

### 25.9 Beauty, skincare and cosmetics

**Why they fit:** Often higher average order values, repeat customers, lightweight local deliveries, strong social/LINE commerce.

**Rounds opportunity:** Direct checkout links, same-day delivery, merchant-owned CRM relationship, network delivery without GMV commission.

### 25.10 Jewelry, accessories and premium small goods

**Why they fit:** High value relative to physical delivery cost, strong need for trustworthy handoff and POD.

**Rounds opportunity:** Preferred/verified drivers, restricted driver pools, signature/photo POD, timed delivery, direct merchant checkout.

### 25.11 Electronics and device/accessory retailers

**Why they fit:** High ticket size, urgent replacement purchases, local same-day demand, delivery economics that should not scale with product value.

**Rounds opportunity:** Fixed delivery infrastructure, verified handoff, recipient ID/signature rules where needed, own-fleet + network capacity.

### 25.12 Pet stores and pet supplies

**Why they fit:** Repeat orders, heavy food bags, local customer loyalty, predictable replenishment cycles.

**Rounds opportunity:** Scheduled recurring routes, car/bike capacity matching, direct reorder, neighborhood batching.

### 25.13 Laundry and dry cleaning

**Why they fit:** The business naturally requires two-way movement: pickup and return. Demand is local and route density matters enormously.

**Rounds opportunity:** Pickup rounds, return rounds, scheduled recurring jobs, route optimization, driver capacity utilization.

### 25.14 Tailors, alteration and repair businesses

**Why they fit:** Pickup-return workflow, repeat local customers, time windows, items already tied to a known customer.

**Rounds opportunity:** Two-leg job lifecycle, scheduled routes, proof of pickup/return, direct booking.

### 25.15 Print shops, documents and business services

**Why they fit:** Urgent same-day movement, office-to-office routes, repeated B2B customers, business-hours density.

**Rounds opportunity:** Fast dispatch, bike network, multi-stop office rounds, POD, account-based invoicing.

### 25.16 Auto parts and workshop supply

**Why they fit:** Urgent point-to-point local deliveries, businesses often value speed more than consumer marketplace discovery, repeat B2B relationships.

**Rounds opportunity:** Parts-store-to-workshop delivery, route-fit jobs, vehicle requirements, direct B2B order intake.

### 25.17 Home décor, small furniture and homeware

**Why they fit:** Higher basket values and larger items make percentage fees unattractive, while vehicle matching matters.

**Rounds opportunity:** Car/van/pickup driver network, scheduled windows, POD, multi-item delivery, merchant-owned ecommerce.

Large furniture and complex installation should be a later operational expansion because they introduce manpower and handling requirements beyond ordinary courier work.

### 25.18 Plants and garden retail

**Why they fit:** Fragile/bulky local products, scheduled delivery, higher basket values, need for appropriate vehicle types.

**Rounds opportunity:** Vehicle matching, handling instructions, trusted-driver preferences, scheduled rounds.

### 25.19 Corporate gifting and B2B distribution

**Why they fit:** High-value orders, dozens of recipients, fixed campaign dates, strong multi-stop requirements.

**Rounds opportunity:** Bulk upload, route optimization, multi-driver rounds, POD per recipient, corporate delivery reporting.

This is particularly attractive because one commercial order can generate many delivery stops without requiring consumer marketplace demand.

### 25.20 Subscription and replenishment businesses

Examples include recurring flowers, coffee, meal plans, office supplies, pet food, beauty refills, and specialty grocery.

**Why they fit:** Predictable repeated demand allows excellent route planning.

**Rounds opportunity:** recurring rounds, route density, scheduled driver capacity, lower empty mileage, direct billing integration.

### 25.21 Hotels, serviced apartments and hospitality partners

**Why they fit:** Guests and residents frequently need local items, documents, gifts, food, laundry, and business deliveries.

**Rounds opportunity:** B2B dispatch accounts, concierge-created jobs, preferred network, local merchant connections.

The opportunity is logistics infrastructure rather than turning Rounds into a hotel marketplace.

### 25.22 Local retailers with existing LINE / social commerce

This is a broad and important segment in Southeast Asia.

**Why they fit:** Many merchants already sell through chat and social channels but lack structured checkout and delivery operations.

**Rounds opportunity:** payment/order links, lightweight Rounds Direct storefront, customer address capture, automated dispatch, settlement record.

### 25.23 Which categories should come first

The first expansion should prioritize businesses that score highly on several dimensions at once:

- high repeat rate;
- local delivery density;
- strong peak/overflow problem;
- existing driver relationships;
- meaningful delivery spend;
- high enough basket value that percentage commissions are painful;
- operational simplicity suitable for bikes/cars/vans;
- willingness to invite existing riders into Rounds.

A strong Bangkok launch mix could therefore combine **florists/gifting + restaurants + bakery/cake + pharmacy/health retail + local ecommerce**, then add categories that improve time-of-day and geographic network utilization.

### 25.24 Why a mixed business network is stronger

The network should not optimize for one category only.

Different businesses generate demand at different times and in different directions.

A mixed merchant base creates the possibility that the same driver earns from several categories across one day instead of waiting for a single vertical's next peak.

That improves driver economics and makes the shared pool more resilient.

---

## 26. Product surfaces

Rounds ultimately has several surfaces, but they all serve the same operating network.

### 26.1 Business dashboard

For businesses to:

- create/import deliveries;
- manage own drivers;
- build and optimize rounds;
- set dispatch rules;
- manage preferred drivers;
- broadcast to the network;
- watch live delivery state;
- handle exceptions;
- review POD;
- reconcile driver settlement;
- analyze performance.

### 26.2 Driver app

For drivers to:

- manage shift/network availability;
- receive assignments or offers;
- accept network work;
- follow single- or multi-stop rounds;
- navigate;
- confirm pickup;
- complete delivery;
- capture POD;
- report issues;
- see work history and external earnings where applicable.

### 26.3 Rounds admin

For Rounds to:

- verify businesses;
- verify open-network drivers;
- handle trust/safety cases;
- suspend accounts where necessary;
- oversee network integrity;
- manage disputes and exceptions;
- monitor network health.

### 26.4 Recipient tracking

A lightweight recipient tracking experience can later allow the delivery recipient to see ETA/status without becoming a consumer marketplace.

### 26.5 Integrations/API

Connects merchant commerce systems to Rounds so dispatch can happen without duplicate data entry.

### 26.6 Rounds Direct / consumer direct surface

A merchant-owned direct-commerce surface that lets customers scan, open a direct link, or search for a business and place an order without entering a commission marketplace.

Rounds Direct connects the merchant order directly into the Rounds operating and delivery network.

---

## 27. Product-complete V1 scope — not the first deploy

This section describes the **complete V1 product target**. It must not be interpreted by implementation agents as the scope of Pilot/Slice 1. The first deploy is intentionally smaller and is defined by `ROUNDS-IMPLEMENTATION-SCOPE-LADDER-v1.0.md`.

The product-complete V1 should prove the operating model and the network model. Rounds Direct is a strategic pillar, but the first technical releases do not need to reproduce a complete ecommerce platform before dispatch works reliably.

A lightweight merchant Direct pilot can run alongside or immediately after the core delivery pilot if it is simple enough to feed real UrbanFlowers/partner demand into Rounds.

### Business-side V1

Must include:

- business account;
- own-driver management;
- manual order creation/import path;
- ready-for-delivery state;
- multi-stop round creation;
- route ordering/optimization;
- driver assignment;
- preferred-driver relationship management;
- 3 km preferred-first broadcast logic;
- open-network expansion;
- live order status;
- proof of delivery;
- basic issue handling;
- settlement ledger;
- network fee accounting;
- basic performance history.

### Driver-side V1

Must include:

- one global driver identity;
- team relationship support;
- merchant-linked relationship support;
- verified-network eligibility;
- shift/availability state;
- assignment flow;
- network offer flow;
- guaranteed fare display for network jobs;
- multi-stop round support;
- pickup confirmation;
- navigation handoff/integration;
- delivery completion;
- POD;
- issue reporting;
- external-network earning/settlement view.

### Rounds admin V1

This is required before broad/public Network rollout, **not for Slice 1**. Pilot support may use narrow protected internal controls inside the Operations/admin boundary; do not build a separate third application merely because the product-complete V1 eventually needs Network administration.

Product-complete V1 must include enough tooling to:

- onboard businesses;
- verify public-network drivers;
- manage driver eligibility;
- inspect deliveries and disputes;
- support pilot merchants;
- suspend abusive or unsafe participants.

---

## 28. Explicitly out of V1

V1 should not be slowed down by features that do not prove the core thesis.

Out of scope unless later required:

- consumer food marketplace;
- algorithmic/sponsored restaurant discovery feed;
- cross-merchant menu browsing;
- advertising marketplace;
- loyalty program;
- Rounds-funded consumer demand acquisition as a prerequisite for the model;
- sponsored merchant ranking or paid demand placement as a core business model;
- percentage commission on merchant GMV;
- percentage deduction from driver fare;
- Rounds-held driver wallet;
- complex regulated payment custody;
- full autonomous customer-service system;
- unnecessary custom VoIP stack if native phone/chat is sufficient;
- advanced AI dispatcher commands;
- international expansion features;
- visual redesign decisions.

---

## 29. UrbanFlowers as the proving ground

UrbanFlowers is not just the first customer. It is the environment that can seed both sides of the network.

UrbanFlowers already has:

- its own drivers;
- concentrated delivery peaks;
- recurring need for overflow capacity;
- repeated contact with outside riders;
- meaningful same-day delivery requirements;
- high-value items where reliable operations matter.

The first pilot should prove:

1. UrbanFlowers can run its own drivers more efficiently through multi-stop rounds.
2. UrbanFlowers can invite riders it already sees and build a preferred-driver network.
3. Overflow can be filled through Rounds instead of automatically going to Lalamove.
4. The same external driver can later take work from another Rounds merchant.
5. The business can operate the system without adding a full-time dispatcher just because Rounds exists.
6. The economics are better while drivers still receive attractive pay.

---

## 30. Rollout strategy

### Stage 1 — UrbanFlowers only

Use own drivers plus a small invited preferred-driver network.

Prove multi-stop operations, broadcast, acceptance, POD, settlement, and reliability.

### Stage 2 — Friendly Bangkok merchants

Add a small number of hand-picked businesses with complementary demand patterns.

Ideal mix may include restaurant, bakery, pharmacy, and another ecommerce/gifting operation.

Each business should bring some of its existing drivers or known riders into Rounds.

### Stage 3 — Dense local network

Focus on geographic density before broad city coverage.

A strong 3 km network around a few Bangkok commercial zones is more useful than thousands of scattered drivers.

### Stage 4 — Open verified driver onboarding

Once the network has enough business demand, allow more drivers to join proactively rather than only through merchant invitations.

### Stage 5 — Broader commercial launch

Sell Rounds to businesses with a proven local fill rate, delivery-cost case, and reference customers.

### Stage 6 — Scale Rounds Direct

Rounds Direct can be piloted earlier with UrbanFlowers or selected merchants, but broad Direct rollout comes after the delivery OS + network are reliable.

At this stage, expand merchant search, QR/link ordering, direct reorder, saved customer convenience, and integrations while protecting the three Rounds promises.

---

## 31. Geographic strategy

Rounds should optimize for local density, not vanity coverage.

The value of the network depends on how many relevant drivers are within a few kilometers of a pickup when the business needs them.

Therefore early expansion should be zone-based.

A business considering Rounds should care about:

- preferred drivers it already brings;
- available network drivers in its area;
- average acceptance time;
- fill rate inside 3 km;
- typical delivery fare;
- route density nearby.

This can eventually produce neighborhood-level network strength rather than one misleading citywide driver count.

---

## 32. Network quality and trust

Rounds should build trust at two levels.

### Global network reputation

Signals may include:

- completed deliveries;
- acceptance reliability;
- pickup punctuality;
- delivery punctuality;
- cancellation/no-show rate;
- incident history;
- verification status;
- vehicle verification.

### Merchant-specific trust

Signals may include:

- number of deliveries completed for that merchant;
- merchant preference status;
- merchant private notes;
- familiarity with pickup location;
- successful handling of special items;
- merchant block status.

Merchant-specific trust should influence priority inside the relevant distance without overriding basic logistical suitability.

---

## 33. Business controls

Each business should eventually be able to define rules such as:

- use own drivers first;
- preferred-driver broadcast radius;
- open-pool radius;
- maximum network fare;
- vehicle requirements;
- whether multi-stop network rounds are allowed;
- which deliveries require own/preferred drivers only;
- VIP or fragile-delivery restrictions;
- automatic versus manual broadcast;
- batching thresholds;
- maximum delay before external broadcast;
- delivery time promises;
- fallback behavior when no driver accepts.

This lets a florist operate differently from a restaurant without requiring different products.

---

## 34. What happens when no driver accepts

Rounds should not pretend the network has infinite supply.

If the configured waves fail:

1. the merchant is told clearly that the network has not filled the job;
2. Rounds can recommend the next action: increase fare, expand radius, rebatch, reassign own capacity, or retry;
3. the merchant can manually use an external courier if needed.

An automated third-party courier fallback may be added later, but it is not required to prove Rounds and should not be structurally necessary.

The important product behavior is honest failure with useful next actions.

---

## 35. Network fee philosophy

The fixed fee should remain small enough that merchants still have a strong reason to use Rounds instead of percentage-based marketplaces or expensive courier aggregation.

The fee is justified because Rounds created successful external capacity.

It should not become a disguised commission.

The commercial principle should therefore be:

- flat subscription for software;
- transparent fixed network fulfillment fee when Rounds supplies external capacity;
- driver fare is separate and visible;
- no percentage of basket value;
- no hidden driver deduction.

This is simple enough for a merchant to understand immediately.

---

## 36. Illustrative economics

The following numbers are examples only, not final pricing.

### Own-driver job

Merchant uses its own salaried driver.

- Network fee: ฿0
- Included in subscription

### Preferred/network driver job

- Driver guaranteed fare: ฿120
- Rounds fixed successful-network fee: ฿15
- Merchant total logistics cost: ฿135
- Driver receives: ฿120

### Restaurant order

- Food value: ฿1,200
- Driver guaranteed fare: ฿90
- Rounds network fee: ฿15
- Delivery infrastructure cost: ฿105

Rounds does not earn more because the food basket is worth ฿1,200.

That distinction is part of the product promise.

---

## 37. Why businesses will pay a subscription even with a network fee

The subscription is not simply an access charge for driver supply.

The business receives an operating system even on days when no external driver is used.

Rounds should improve:

- own-driver productivity;
- route density;
- multi-stop efficiency;
- dispatch labor;
- POD quality;
- delivery visibility;
- exception handling;
- records;
- driver relationship management;
- capacity planning.

The network fee then pays for the extra value event: **Rounds successfully found capacity outside the business's own fleet.**

The two charges pay for two different things.

---

## 38. Why drivers join

Rounds must also create a compelling driver proposition.

Drivers gain:

- more work during idle periods;
- access to multiple businesses through one identity;
- the ability to build repeat merchant relationships;
- clear guaranteed fare before accepting network jobs;
- full ownership of the accepted fare;
- potentially more jobs that fit existing routes;
- clearer settlement tracking;
- less dependence on one aggregator;
- reputation that carries across participating businesses.

A team driver can gain additional off-shift income without abandoning their employer relationship.

A merchant-linked rider can turn an informal relationship into recurring work.

A public freelancer can gain access to business demand that was previously fragmented across calls, LINE groups, and personal contacts.

---

## 39. Why businesses invite their drivers instead of keeping them private

At first glance a business may ask why it should allow its drivers to earn from other merchants.

The answer is reciprocity and utilization.

When the business has excess driver capacity, the driver can earn elsewhere.

When the business has excess delivery demand, it can access the wider network built by everyone else.

This creates shared resilience.

The employer still controls whether its own team drivers can accept outside work during employment hours.

Rounds should never allow network work to interfere with an active employer shift without the employer's rules permitting it.

---

## 40. The strategic moat

Rounds' defensibility should come from the network and relationship graph, not from a dispatch screen alone.

Potential moats include:

### Local density

A dense 3 km network is difficult for a new entrant to recreate instantly.

### Business-driver relationship graph

Rounds learns which drivers each business already trusts and which merchants each driver knows.

### Multi-stop operating data

The system learns real delivery durations, pickup friction, route patterns, neighborhood behavior, and round efficiency.

### Complementary demand

A diversified merchant base can create better driver utilization across the day.

### Embedded workflow

Once a merchant runs its own drivers, routes, POD, preferred network, and delivery records through Rounds, switching means losing an operational system rather than merely changing courier apps.

### Economic positioning

“No percentage of your sale” and “driver keeps the fare” create a structural position that becomes harder to copy for marketplaces built on transaction commissions.

---

## 41. Core metrics

Rounds should measure the network as an operating system, not just count users.

### Merchant economics

- average delivery cost;
- network fee per delivery;
- cost versus previous courier solution;
- own-driver utilization;
- stops per round;
- deliveries per driver hour;
- empty-kilometer reduction;
- dispatch labor time saved.

### Network performance

- 3 km fill rate;
- preferred-driver fill rate;
- open-network fill rate;
- median time to first accept;
- percentage filled before radius expansion;
- driver arrival time to pickup;
- completion/on-time rate;
- cancellation/no-show rate.

### Network growth

- active businesses per zone;
- active drivers per zone;
- preferred relationships per business;
- drivers connected to multiple businesses;
- percentage of network supply originated through merchant invitations;
- jobs per available driver hour.

### Multi-stop performance

- average stops per round;
- distance saved versus separate trips;
- time saved versus separate trips;
- delivery-window compliance;
- driver earnings per active hour for network rounds.

### Retention

- business retention;
- driver retention;
- preferred-driver reuse rate;
- percentage of businesses using both own-fleet and network features.

---

## 42. The first proof points

Before broad launch, Rounds should be able to answer “yes” to the following:

1. Can UrbanFlowers reduce dependence on Lalamove for overflow?
2. Can UrbanFlowers increase its own-driver productivity through multi-stop rounds?
3. Can a rider who already visits UrbanFlowers join the preferred network quickly?
4. Can another business add its drivers and immediately increase useful shared supply?
5. Can Rounds fill a meaningful percentage of network jobs within the first 3 km?
6. Can drivers earn attractive fares while Rounds still makes money from a fixed fee?
7. Can a small merchant use Rounds without hiring a dispatcher?
8. Can the system survive real Bangkok peak periods without operators constantly intervening?
9. Can driver settlement remain clear without Rounds holding the money?
10. Do businesses retain and reuse drivers they discover through the network?

If these are true, the underlying business has been proven.

---

## 43. Key risks and how the model addresses them

### Risk: Not enough drivers

Start with business-supplied drivers and preferred-driver invitations rather than waiting to recruit a giant public pool first.

### Risk: Not enough merchant demand for drivers

Begin with merchants that already have repeated delivery volume and add categories with different peak times.

### Risk: Drivers only accept high-paying jobs

That is expected. Businesses control their rates. The network should expose the consequences of low offers rather than hide them.

### Risk: A small business needs a dispatcher

Default toward rules and automatic dispatch so normal staff can operate the business without staring at a map.

### Risk: Payment disputes

Maintain a shared settlement ledger and delivery/POD evidence even when money moves directly business-to-driver.

### Risk: Businesses and drivers bypass Rounds after meeting

Rounds should remain valuable because it provides dispatch, routing, records, multi-stop optimization, POD, settlement, and access to the wider network. The fixed fee should also be small enough that bypassing the system is less attractive than losing the infrastructure.

### Risk: Unsafe or unreliable drivers

Use verification levels, merchant-specific trust, global reputation, suspension tools, and controlled open-network eligibility.

### Risk: Too much complexity

Keep the core commercial model simple: subscription + fixed successful-network fee.

### Risk: Rounds drifts into a consumer marketplace

Treat merchant customer ownership as a non-negotiable product principle.

---

## 44. Non-negotiable product principles

1. **Distance first, relationship second.** Preferred drivers get priority inside the relevant radius; distant preferred drivers do not override much closer qualified supply.
2. **3 km is the default first network radius.** Preferred drivers first, then the wider qualified network inside the same radius.
3. **Multi-stop is fundamental in V1.** Rounds must model and execute rounds, not only single deliveries.
4. **One global driver identity.** Merchant relationships and work modes sit around the driver; the driver is not locked to one account identity.
5. **The merchant builds an asset.** Preferred-driver relationships accumulate and remain usable.
6. **The driver keeps the accepted fare.** Rounds does not silently deduct a percentage.
7. **No percentage of merchant sales.** Rounds does not tax the value of the product being sold.
8. **Rounds does not own the merchant's customer.** Direct-order infrastructure strengthens the merchant relationship rather than replacing it.
9. **Rounds should not hold merchant money by default.** Customer funds should settle to the merchant directly wherever practical.
10. **Subscription + fixed network fee is the core business model.** Direct commerce can add subscription/fixed infrastructure revenue without introducing GMV commission.
11. **Search is allowed; marketplace dependence is not required.** Customers can scan, link, or search for businesses without Rounds becoming a sponsored-ranking marketplace.
12. **No dedicated dispatcher is required.** Small businesses must be able to use automation and simple controls.
13. **Rounds Direct is merchant-owned commerce.** The customer should feel they are ordering from the merchant, powered by Rounds.
14. **Network density matters more than citywide vanity numbers.** Build strong local zones first.
15. **The product must work for both own-fleet and overflow use.** Neither side is an add-on afterthought.
16. **The network must fail honestly.** If no driver accepts, the merchant sees it and receives useful next actions.
17. **High-AOV businesses are a core opportunity.** Delivery infrastructure should not become more expensive merely because the merchant sells a more valuable product.
18. **Businesses can bring both demand and supply.** Every merchant can bring customers, own drivers, and known riders into the network.
19. **Cash flow is part of the product value.** Rounds should reduce commission leakage and unnecessary settlement delay rather than recreate them.
20. **Visual/UI authority is separate from this business master.** The canonical Operations HTML, Driver board library, Operations Visual System and Driver UI Constitution define the designed product. This specification must not imply that those surfaces are awaiting another redesign.

---

## 45. Open commercial decisions

The following remain intentionally open and should be tested rather than guessed in this document:

- exact subscription tiers;
- exact monthly prices;
- exact fixed successful-network fee;
- whether preferred-driver fills have a lower fee than open-pool fills;
- bundled-round network fee treatment;
- cancellation/no-show fee rules;
- default broadcast timer per wave;
- default expansion beyond 3 km;
- merchant-specific maximum radius;
- whether some plans include a number of network fills;
- payment/settlement automation timing;
- legal structure for network drivers by market;
- insurance requirements;
- when open public driver acquisition begins;
- when Rounds Direct becomes a product;
- exact Rounds Direct pricing model.

---

## 46. Strategic statement

Rounds should become the infrastructure layer between a local business, its customer order, and the person who physically delivers it.

The customer can scan, follow a link, or search for the business they want and order direct.

The business keeps the customer relationship, the sale, and the money.

The business can use its own driver when that is efficient.

It can use a driver it already knows when it needs extra capacity.

It can reach the wider network when neither is enough.

The driver can move between businesses without losing identity, reputation, or relationships.

Rounds earns because the operating system is useful, because the network successfully solves capacity, and because direct-commerce infrastructure helps merchants bring more of their own demand into the system.

This creates the long-term proposition:

**Order direct. Run your own deliveries. Build your own driver network. Use the shared network when you need it.**

And the trust promise beneath it:

**We don't own your customer. We don't take a percentage of your sale. We don't hold your money.**

---

## 47. One-sentence definition

**Rounds is the direct-commerce and delivery operating system that lets local businesses keep their customers and sales, run their own drivers, reuse trusted riders, and fill overflow through a nearby shared network — without paying a percentage of the sale.**

---

---

## Business-side Mapping & Address Intelligence

**Canonical detailed spec:** `ROUNDS-SPEC-4-MAPPING-ADDRESS-INTELLIGENCE-v1.8.md`

The Dispatcher product must include a first-class mapping/address layer.

## Settings

Settings → Delivery Rules / Mapping may configure:

- address correction authority;
- learned-location behavior;
- Street imagery provider;
- Mapbox/imagery credentials where applicable;
- whether high-confidence known locations may be applied automatically.

## Dispatch

The map explains recommendations.

When a delivery is selected, Dispatch can expose:

- original address;
- resolved address;
- vehicle arrival point;
- entrance/handoff;
- location confidence;
- successful prior confirmations;
- Inspect Site;
- Street view.

## History / reporting

Track:

- wrong-address rate;
- corrections by source;
- repeat-location success;
- dwell time by location;
- addresses requiring repeated manual intervention.

## Integrations

Website/store/API inputs may send raw addresses. Rounds resolves them into operational locations.

The merchant does not need to adopt Mapbox-specific IDs.

---

## Dispatch Map Phase 2

**Canonical mapping rules:** `ROUNDS-SPEC-4-MAPPING-ADDRESS-INTELLIGENCE-v1.8.md`

Dispatcher UX requirements:

- product thumbnails are optional operational context; never show broken/empty boxes;
- own, Network/freelance and external-courier drivers have visibly different map marker families;
- live delivery detail shows traffic-aware ETA, typical ETA, traffic delta and promise risk when relevant;
- traffic appears on the affected Round, not as default city-wide visual noise;
- map controls support zoom, rotate, north reset and 2D/3D;
- Operations / Satellite / 3D Site / Street remain contextual modes inside the same Dispatch map;
- order/route selection must preserve context while switching map modes.

---

## Weather, Driver Communications, Tracking & Commerce Integration

## Live driver communication

From a live delivery or Round the dispatcher can:

- message the driver in realtime;
- send a voice note;
- share a location/map context;
- place an in-app VoIP call;
- review call/message history attached to the delivery.

Communication is contextual. The dispatcher does not leave Dispatch to open a generic messaging product.

## Weather

Weather risk is part of operational recommendation/ETA logic. See `ROUNDS-SPEC-4-MAPPING-ADDRESS-INTELLIGENCE-v1.8.md`.

## Tracking / notification architecture

Detailed canonical rules live in `ROUNDS-SPEC-5-TRACKING-NOTIFICATIONS-INTEGRATIONS-v1.6.md`.

Core product decision:

- every delivery can have a secure web tracking link;
- sender and recipient may receive different information;
- delivery-start and delivered events can trigger merchant-branded email/SMS/other configured channels;
- integrations such as Shopify and WooCommerce can create deliveries and receive status/fulfillment updates.

---

## Route Editing & Driver Communications

**Controlling detailed spec:** `ROUNDS-SPEC-6-DISPATCH-ROUTE-EDITING-COMMS-v1.11.md`

Business Dispatch now separates operating context from human communication.

- Round/Order drawer remains operational.
- Communications is a persistent separate surface on desktop.
- Right-click/long-press active driver provides quick Message / Call / Voice note.
- Own-fleet future Stops reorder by stable Stop ID and handle-only drag.
- iPad uses tap move controls and one contextual surface at a time.
- Unread driver replies remain visible while dispatcher works elsewhere.

---

## Business Product Completion

**Controlling UX:** `ux/operations/rounds-operations-current-v45.html`

This addendum locks the completed business-side navigation and management model.

## Drivers

`Drivers` contains three sub-surfaces:

1. **Own drivers**
   - employed/team drivers;
   - current Round;
   - scheduled shift;
   - vehicle;
   - today deliveries;
   - rolling on-time performance;
   - hours/overtime;
   - recent delivery and incident history;
   - Message / Call / Show live Round / Schedule.

2. **Network drivers**
   - independent Rounds drivers;
   - Preferred / Known merchant relationship;
   - vehicle;
   - deliveries for this merchant;
   - on-time rate;
   - offer acceptance;
   - last used;
   - verification / incidents;
   - merchant notes.

   Network drivers are not employees and do not receive merchant shift schedules.

3. **Schedule**
   - recurring own-driver schedules;
   - date exceptions;
   - vehicle per shift;
   - slot/time-window capacity impact.

## History

History is one operating record across:

- Own fleet;
- Rounds Network;
- External courier.

A delivery record can show:

- order reference;
- fulfillment source;
- driver/provider;
- vehicle;
- promised window;
- delivered time/state;
- POD;
- waiting/dwell;
- traffic impact;
- weather impact;
- exception;
- calls/messages;
- direct delivery cost.

History should support business metrics such as:

- total delivery cost;
- cost per delivery;
- own-fleet cost;
- Network spend;
- external-courier spend;
- failed/retry cost;
- waiting time;
- utilization.

## Settings

Settings is the business control center:

- Overview;
- Dispatch;
- Delivery rules;
- Rounds Network;
- External couriers;
- Integrations;
- Tracking & notifications.

Do not move these controls into Dispatch merely because they affect Dispatch.

## External courier

External courier is a third fulfillment source, not a new Rounds room.

Canonical fulfillment source enum conceptually becomes:

```text
own
rounds_network
external
```

External provider is separate metadata:

```text
provider = lalamove | future_provider
```

See `ROUNDS-SPEC-7-EXTERNAL-COURIERS-v1.4.md`.

---

## Intelligent New Delivery Intake

**Version:** Business Product Master v2.7  
**Controlling UX:** `ux/operations/rounds-operations-current-v45.html`

## Product rule

Rounds should consume delivery information the business already has before asking a dispatcher to re-enter it.

Canonical New Delivery intake sources:

```text
Screenshot / image
PDF
Clipboard paste
Manual entry
Commerce/API import
```

The first four belong to the single-delivery intake experience. Commerce/API and CSV remain batch/system intake paths.

## Screenshot / image / PDF flow

Canonical interaction:

```text
New Delivery
→ drop screenshot/image/PDF, choose file, or paste from clipboard
→ AI extracts structured delivery draft
→ Address Intelligence resolves destination/access knowledge
→ dispatcher reviews only uncertain/missing fields
→ Add delivery
```

The extraction result is always a **draft**.

AI intake must never directly:

- dispatch a driver;
- book Rounds Network;
- book an external courier;
- overwrite uncertain address data destructively.

## Extracted delivery structure

AI should attempt to extract or infer:

- merchant/order reference;
- sender/buyer name and phone when present;
- recipient name;
- recipient phone;
- raw delivery address;
- building/hotel/venue name;
- floor/room/unit/landmark/access note;
- promised delivery time/window;
- item description/quantity;
- handling requirement;
- vehicle recommendation;
- delivery instruction such as `call before arrival`;
- surprise/gift sensitivity where evident.

The original raw source is retained as evidence/reference.

## Confidence and review

Each extracted field has an evidence/confidence state conceptually:

```text
confirmed / high confidence
needs review / medium confidence
missing / unresolved
```

Do not show fake numerical percentages unless the production extraction system can defend them.

Use human language such as:

```text
Matched
Read from screenshot
Recommended
Needs review
Missing
```

Fields requiring review should be visually prominent but not alarming.

The final `Add delivery` action should remain available only when required operational fields are valid.

Required before creating an operational delivery:

- recipient/contact policy satisfied;
- usable destination/location;
- promised start/end or valid slot;
- item/handling sufficient for vehicle decision;
- pickup readiness state.

## Address Intelligence handoff

AI extraction preserves:

```text
raw_address
raw_location_text
```

Then Address Intelligence may resolve:

- canonical place/building;
- map point;
- routable vehicle point;
- known entrance/handoff point;
- aliases;
- merchant-specific prior delivery knowledge.

Example:

```text
Raw: Park Hyatt Bangkok, Wireless Road
Matched: Park Hyatt Bangkok
Vehicle access: Wireless Road entrance
Known handoff: Hotel reception
```

Never silently replace the raw address/source.

## Vehicle recommendation

AI may recommend a vehicle from:

- product/handling rules;
- package class/size;
- merchant product knowledge;
- destination/access constraints.

Example:

```text
Bouquet + 1 lb cake
Handling: Fragile
Recommended: Car
```

Recommendation is separate from a hard merchant vehicle rule.

## Clipboard

While New Delivery is open:

```text
⌘V / Ctrl+V image
→ same image intake flow
```

Plain-text clipboard content may also be parsed into the same structured draft.

The dispatcher should not need to first save a screenshot to disk.

## Multiple files

V1 UX may process one source into one delivery.

Future batch intake may allow:

```text
10 screenshots
→ 9 delivery drafts found
→ 7 ready
→ 2 need review
```

Do not complicate the single-delivery drawer with batch-management UI in the first implementation.

## Manual entry

Manual entry remains available as a fallback and must not be hidden behind AI success.

Recommended hierarchy:

```text
Use what you already have
[screenshot / paste / file]

or enter manually
```

## Production implementation boundary

The HTML UX may simulate extraction for design/testing. Production OCR/vision extraction must run through an authenticated backend/AI service.

Do not embed privileged AI credentials in client HTML.

## Acceptance criteria

- New Delivery prominently accepts screenshot/image/PDF.
- Clipboard image paste is discoverable and supported by the interaction model.
- Processing state is visible.
- Extracted draft is editable.
- Confidence/missing states are clear.
- Address resolution is visible separately from raw input.
- Original source remains accessible during review.
- Manual entry remains available.
- AI does not auto-dispatch or auto-book capacity.
- Added delivery uses reviewed structured fields rather than demo placeholder values.
---

## Unified New Delivery Intake

**Canonical interaction:** The dispatcher does not choose between separate AI
and manual-entry modes. Both operate on one continuous intake surface.

## Locked interaction

`New Delivery` is one continuous surface.

At the top:

```text
Drop screenshot, image or PDF
or paste with clipboard
```

This area is an **optional accelerator**, not a gate.

Immediately beneath it, the normal delivery fields are already visible and editable.

Therefore:

```text
New Delivery
→ optional drop / paste
→ delivery fields already present
```

There is no:

```text
Choose AI
vs
Enter manually
```

step.

There is no `Enter manually` button.

## AI behavior

If a source is dropped/pasted:

```text
source
→ AI extraction
→ Address Intelligence
→ fill the same delivery fields
→ mark confidence / review state
```

The dispatcher continues editing those same fields.

AI must not introduce a second form or a separate manual workflow.

## Efficiency principle

If the dispatcher already knows the delivery data, they can begin typing immediately.

If Rounds can read existing material, it should reduce typing without adding clicks.

The intake surface should prefer:

```text
less re-entry
less mode switching
fewer clicks
```

over explaining the AI feature.

---

## Merchant / Buyer / Recipient / Pickup Actor Model

The canonical actor model does not use `sender` as an ambiguous generic role.

## Canonical actors

Rounds distinguishes:

```text
merchant
pickup_location
pickup_contact

buyer
recipient
```

For gifting businesses, the buyer is commonly the person sending the gift.

For ordinary food/local-commerce deliveries, buyer and recipient are commonly the same person.

`sender` must not be used as a generic UI label because courier providers may use `sender` to mean the pickup contact.

## New Delivery

Recipient is the primary required delivery person.

The intake contains:

```text
Recipient
  name
  phone
  delivery address

Ordered by
  Same as recipient
  Someone else
```

Default relationship is merchant-configurable.

When `Same as recipient` is selected:

- no buyer fields are displayed;
- buyer name/phone derive from recipient;
- no duplicated typing.

When `Someone else` is selected:

- buyer name/phone fields appear;
- for a gifting merchant this may be the gift sender.

## Merchant pickup

Merchant pickup identity is inherited from the Rounds business/location profile.

The dispatcher does not re-enter the merchant as a delivery `sender`.

Example:

```text
Merchant: UrbanFlowers
Pickup location: UrbanFlowers · Sukhumvit 39
Pickup contact: UrbanFlowers Dispatch

Buyer: Maya
Recipient: John
```

## AI intake

AI may infer:

- buyer = recipient;
- buyer ≠ recipient;
- buyer name/phone;
- recipient name/phone.

AI fills the same New Delivery fields and the relationship remains editable.

## Data model compatibility

New records should conceptually store:

```text
buyer_name
buyer_phone
buyer_same_as_recipient

recipient_name
recipient_phone

pickup_location_id
pickup_contact_id / pickup contact snapshot
```

Legacy `sender` fields may temporarily remain as compatibility aliases but must not control product terminology.

---

## Phase 1B1 — Vehicle, Cargo & Round Rules

**Status:** Locked before UX implementation  
**Purpose:** Give Rounds enough physical-operating knowledge to build valid Rounds from large delivery sets.

The canonical vehicle model is multidimensional and is not represented mainly
by a generic `stops per slot` planning number.

---

## 1. Vehicle profile is the reusable operating rule

Physical delivery constraints belong primarily to a **vehicle profile**, not repeatedly to each driver.

Example profiles:

```text
Motorbike + delivery box
Car
Van
Pickup
Refrigerated van
Cargo bike
```

Drivers and shifts reference a vehicle profile.

A driver may have a normal/default profile and a date-specific shift may override it.

---

## 2. Separate Round capacity from planning throughput

These are different numbers.

### Maximum stops per departure

Physical limit for one Round leaving the pickup location.

Example:

```text
Motorbike + box
max delivery stops per departure = 2
```

This means the driver may carry no more than two delivery Stops on that departure.

### Planning throughput

Expected number of deliveries one overlapping driver may complete during a planning time block/slot after returning and departing again.

Example:

```text
Bike
max 2 Stops per Round
estimated 5 deliveries across a 3-hour slot
```

Never use planning throughput as permission to put five Stops on one bike Round.

---

## 3. Departure pattern

Vehicle profile supports:

```text
multi_stop
return_after_every_delivery
return_after_round
return_when_capacity_exhausted
```

Meanings:

### multi_stop
Load an allowed set of deliveries, complete the route, then return/end according to merchant rules.

### return_after_every_delivery
Canonical physical pattern:

```text
pickup
→ delivery
→ pickup
→ next delivery
```

Each delivery requires a new pickup cycle.

### return_after_round
Load up to the profile's permitted Stop/cargo capacity:

```text
pickup
→ Stop 1
→ Stop 2
→ pickup
```

Then a new Round may begin.

### return_when_capacity_exhausted
Optimizer may continue adding valid Stops until physical cargo or configured Stop capacity is exhausted, then requires return/reload.

---

## 4. Cargo classes

Merchant can define reusable cargo/load classes.

Initial Rounds classes may include:

```text
Flowers
Standard cake
Large cake
Hamper
Large arrangement
Standard parcel
```

A delivery can contain one or more cargo class quantities.

Example:

```text
1 × Flowers
1 × Standard cake
```

AI/imports may infer these classes from order items, but the merchant can correct them.

---

## 5. Vehicle cargo limits

Each vehicle profile defines maximum quantity per cargo class.

Example configuration:

```text
Motorbike + delivery box

max Stops / departure: 2
departure pattern: return_after_round

Flowers: 2
Standard cake: 1
Large cake: prohibited
Hamper: prohibited
Large arrangement: prohibited
```

Another profile may be:

```text
Car

max Stops / departure: 6
departure pattern: multi_stop

Flowers: 8
Standard cake: 4
Large cake: 2
Hamper: 3
Large arrangement: 2
```

These are merchant configuration examples, not universal Rounds defaults.

---

## 6. Mixed-load rules

Vehicle profiles may define a mixed-load rule.

Example:

```text
Bike:
1 cake + 1 flower allowed
2 cakes prohibited by capacity
large cake + anything prohibited
```

The optimizer evaluates the **combined physical load of the whole proposed Round**, not each delivery in isolation.

---

## 7. Round validity

Before a delivery can be inserted into or planned onto a Round, Rounds must evaluate:

```text
driver shift
assigned vehicle profile
max Stops per departure
cargo quantities
prohibited cargo
mixed-load rule
pickup/reload requirement
ready time
promised window
route time
current custody
```

A route that is geographically efficient but physically invalid is not a candidate.

---

## 8. Driver assignment

Drivers do not duplicate the entire vehicle rule.

Own-driver profile stores/reference:

```text
default vehicle profile
```

Schedule/shift can override:

```text
vehicle profile for this shift
```

Driver detail should expose the active profile and a short operational summary such as:

```text
Motorbike + box
2 Stops / departure
Return after Round
Flowers 2 · Cake 1
```

---

## 9. Settings ownership

Canonical location:

```text
Settings
→ Delivery Rules
→ Vehicles & Capacity
```

This surface owns:

- vehicle profiles;
- departure patterns;
- max Stops per departure;
- planning throughput;
- cargo capacities;
- mixed-load rules;
- pickup turnaround/reload assumption.

Do not force dispatchers to choose these constraints repeatedly while dispatching.

---

## 10. Planner contract

The future bulk planner must consume the same rules.

Given:

```text
40 deliveries
3 bikes
1 car
driver shifts
vehicle profiles
cargo
promised windows
```

Rounds may generate multiple sequential Rounds per driver.

Example:

```text
Somchai · Bike
Round 31 · 2 Stops
return to pickup
Round 34 · 2 Stops
return to pickup
Round 38 · 1 Stop
```

The planner may not exceed the vehicle profile merely to cover more orders.

---

## 11. Network contract

Rounds Network matching uses the same cargo/vehicle requirements.

Broadcast eligibility must exclude a Network driver whose declared vehicle cannot satisfy the accepted Round scope.

An accepted Network Round's physical scope cannot be materially expanded beyond the accepted cargo/Stop constraints without the existing consent rules.

---

## 12. Data model direction

Conceptual tables:

```text
vehicle_profiles
cargo_classes
vehicle_profile_cargo_limits
driver_vehicle_assignments
```

Round/Stop planning should snapshot the controlling vehicle-profile version or relevant capacity facts so historical records remain explainable after settings change.

---

## Acceptance criteria

- Merchant can define/edit vehicle profiles.
- Merchant can set Round departure pattern.
- Merchant can set max Stops per departure.
- Merchant can set separate planning throughput.
- Merchant can set cargo-class quantity limits.
- Prohibited cargo is explicit.
- Drivers/shifts reference profiles rather than duplicating rules.
- Driver detail exposes active vehicle/round behavior.
- Existing capacity coverage remains functional.
- Future planner can call one common load-validation function.

---

## Phase 1B2 — Bulk Delivery Intake

**Status:** Locked before UX implementation  
**Purpose:** Make one delivery and 40+ deliveries use the same intake architecture.

---

## 1. One intake surface

The canonical action becomes:

```text
+ Deliveries
```

It handles:

- one manually entered delivery;
- one screenshot/image;
- many screenshots/images;
- PDF;
- CSV;
- pasted text;
- pasted spreadsheet/tabular rows;
- connected-commerce orders later.

Do not create separate user-facing systems called `New Delivery` and `Import Orders`.

The one-order case must remain fast.

---

## 2. Default surface

At the top:

```text
Drop screenshots, images, PDF or CSV
one or many
or paste with clipboard
```

Immediately beneath it, the normal single-delivery fields remain editable.

The drop/import capability is an accelerator, not a mode gate.

---

## 3. Batch detection

If the source contains more than one delivery, Rounds creates a batch draft.

Examples:

```text
40 screenshots
→ up to 40 extracted delivery drafts

CSV / pasted spreadsheet
→ one draft per valid row

one PDF
→ AI may find one or many deliveries
```

The system should never force the dispatcher to split a valid multi-delivery source manually.

---

## 4. Batch review statuses

Each draft is classified as:

```text
ready
needs_review
missing_data
```

### ready

Required delivery data is present and Address Intelligence has enough confidence to create an unplanned delivery.

### needs_review

The delivery can likely be recovered by a dispatcher correction, for example:

- ambiguous building;
- conflicting phone;
- uncertain time window;
- cargo inference requiring confirmation.

### missing_data

A blocking required field is absent, for example:

- recipient name;
- deliverable address;
- delivery promise where merchant policy requires one.

A `missing_data` delivery is never silently added as ready.

---

## 5. Batch review surface

The batch surface shows:

```text
Found
Ready
Needs review
Missing data
```

and a compact delivery list.

Each row should expose enough information to detect problems quickly:

- order/reference;
- recipient;
- area / matched address;
- promised window;
- cargo/item summary;
- inferred vehicle compatibility;
- source;
- review state.

Dispatcher may:

- filter by review state;
- select/deselect drafts;
- open one draft for editing;
- return to the batch without losing work.

---

## 6. Add-ready behavior

Primary batch action:

```text
Add all ready deliveries
```

or, if selection is modified:

```text
Add selected ready deliveries
```

Rules:

- only drafts that pass required-field validation may be committed;
- review/missing drafts remain in the batch;
- committed deliveries are marked:

```text
planning_state = unplanned
```

They are not automatically routed or dispatched.

This is the handoff contract to Phase 1B3 planning.

---

## 7. Original evidence

For screenshot/image/PDF extraction, each draft retains source/evidence linkage.

For CSV/pasted rows, preserve the raw imported row/source where practical.

AI-normalized data does not erase the original source.

---

## 8. Actor model

Bulk intake uses the same canonical actor model:

```text
merchant/pickup = business profile
recipient = required delivery person
buyer = same as recipient OR someone else
```

No separate `sender` input is introduced for bulk work.

---

## 9. Cargo and vehicle rules

Every committed bulk delivery must run through the Phase 1B1 cargo inference / vehicle compatibility rules.

Bulk import cannot bypass:

- cargo classes;
- prohibited loads;
- physical vehicle requirements.

The later planner consumes the resulting structured cargo load.

---

## 10. Connected commerce

Shopify/WooCommerce/API orders should eventually enter the same normalized batch/unplanned pipeline.

The connector is a source, not a separate planning domain.

Conceptually:

```text
source
→ normalized delivery draft(s)
→ review only if needed
→ unplanned delivery pool
→ Plan Rounds
```

---

## 11. Acceptance criteria

- The main action says `+ Deliveries`.
- Single manual delivery remains available without an extra mode click.
- File picker accepts one or many files.
- CSV is accepted.
- Pasted spreadsheet rows can create a batch.
- Batch summary exposes ready/review/missing counts.
- Individual drafts can be edited.
- Invalid drafts cannot be bulk-committed as ready.
- Added batch deliveries are tagged `unplanned`.
- Old separate CSV import UX no longer competes with the main intake.

---

## Phase 1B3A — Plan Rounds Workspace

**Status:** Locked before UX implementation  
**Purpose:** Turn a large unplanned delivery pool into understandable sequential Rounds across available own drivers.

---

## 1. Planning is a Dispatch operating mode

Planning is not a new top-level room.

Canonical:

```text
Dispatch
→ Live
→ Plan
```

or an equivalent strong `Plan Rounds` entry point from unplanned work.

`Live` answers:

```text
What is happening now?
```

`Plan` answers:

```text
Given today's unplanned deliveries and available capacity, what Rounds should exist?
```

---

## 2. Planning workspace geometry

Canonical desktop layout:

```text
Left: unplanned / planning issues
Center: map
Bottom: driver + vehicle timeline
Right: selected planned Round / delivery / planning explanation
```

Map remains the dominant spatial surface.

Timeline is a planning instrument, not a second dashboard.

---

## 3. Planner inputs

The generated plan consumes the existing canonical rules:

- unplanned deliveries;
- ready time;
- promised start/end;
- Address Intelligence;
- cargo classes;
- vehicle profile;
- max Stops per departure;
- departure/return pattern;
- pickup/reload turnaround;
- driver schedule;
- shift vehicle profile;
- current/future availability;
- route/travel estimate;
- traffic where relevant.

The planner must not create a physically invalid Round merely to maximize coverage.

---

## 4. Output is sequential Rounds, not only routes

The planner assigns deliveries into **Rounds**.

Example:

```text
Somchai · Bike 01
Round 31 · 2 delivery Stops
return to UrbanFlowers
reload
Round 34 · 2 delivery Stops
return to UrbanFlowers
Round 38 · 1 delivery Stop
```

A Round is one physical departure with defined custody.

---

## 5. Timeline semantics

Each own driver receives one timeline lane.

A Round block shows at minimum:

- Round ID;
- start time;
- end time;
- delivery Stop count;
- vehicle profile;
- state.

Gaps may represent:

- return to pickup;
- reload/turnaround;
- idle capacity;
- shift boundary.

Return/reload time is not hidden inside the next route.

---

## 6. Map semantics

Selecting a planned Round:

- emphasizes its route and Stops;
- de-emphasizes unrelated planned work;
- opens the planned-Round drawer.

Selecting an unplanned delivery:

- centers/emphasizes the delivery;
- exposes its planning state.

Planning uses the same Mapbox operational map language as Live Dispatch.

---

## 7. Generated plan summary

After generation, show an operational summary such as:

```text
40 deliveries
4 own drivers
13 Rounds

37 covered
3 uncovered

6 bike departures
7 car/van departures
0 promise violations
4 returns to base
```

Do not present optimization as an unexplained magic result.

---

## 8. Plan explanation

The workspace should explain the structural reasons behind the plan.

Examples:

```text
Bike profiles allow maximum 2 Stops per departure.
4 deliveries require Car.
2 bike Rounds require return/reload before the next departure.
Morning own-fleet capacity is exhausted at 11:40.
```

This explanation is generated from the same constraints used by the planner.

---

## 9. Uncovered deliveries

Uncovered work remains explicit.

A delivery may remain unplanned because:

- no compatible vehicle;
- shift capacity exhausted;
- promised window cannot be met;
- cargo conflict;
- ready time too late;
- route time too long.

Phase 1B3A only identifies/explains uncovered work.

Network / external recovery recommendations may be shown as context, but automatic reassignment and manual planning interactions belong to later phases.

---

## 10. Approval boundary

Phase 1B3A may generate a proposed plan.

Generated Rounds are not yet live driver instructions merely because they appear on the planning timeline.

Canonical lifecycle:

```text
unplanned deliveries
→ proposed plan
→ review / adjustment
→ approve plan
→ upcoming/live Rounds
```

The final interactive adjustment / approval mechanics are completed in Phase 1B3B.

---

## 11. Planner explainability

Every proposed Round should be able to answer:

```text
Why this driver?
Why this vehicle?
Why these deliveries together?
Why return now?
Why is this delivery uncovered?
```

The first UX does not need to expose every algorithmic score, but must expose decision-changing constraints.

---

## 12. Acceptance criteria

- Dispatch has a visible Plan mode.
- Unplanned deliveries are visible as a pool.
- Plan mode includes a bottom driver/vehicle timeline.
- One driver may have multiple sequential Rounds.
- Return/reload gaps are visible.
- Generated plan respects Phase 1B1 vehicle/cargo rules.
- Clicking a Round focuses it on map and drawer.
- Plan summary exposes coverage and uncovered work.
- Plan explanation references real constraints.
- Proposed plan remains distinct from live execution.

---

## Phase 1B3B — Plan Adjustment & Approval

**Status:** Locked before UX implementation  
**Purpose:** Make a generated plan safely editable and convert it into executable Rounds only after explicit approval.

---

## 1. Proposed plan remains editable

Phase 1B3A output is a proposal.

Canonical lifecycle:

```text
unplanned deliveries
→ generate plan
→ proposed Rounds
→ adjust / review
→ approve plan
→ upcoming Rounds
```

A proposed Round is not sent to a driver.

---

## 2. Delivery movement

Dispatcher may move:

- uncovered delivery → proposed Round;
- planned delivery → another proposed Round.

Desktop:

```text
drag delivery
→ target Round
→ impact preview
→ apply move
```

Touch / iPad:

```text
select delivery
→ Move
→ choose target Round
→ impact preview
→ apply move
```

Required functionality must not depend on drag-and-drop.

---

## 3. Drag starts from delivery, not driver

The movable object is a delivery Stop.

Do not drag driver cards.

A Round is the drop/assignment target.

The same planning mutation function must power desktop drag and touch Move actions.

---

## 4. Impact preview

Before committing a move, Rounds evaluates the proposed target using the same physical validator used by planning.

Preview exposes decision-changing consequences:

- target vehicle profile;
- Stops before / after;
- cargo fit;
- added route time;
- added distance;
- target finish time;
- promise status;
- return/reload implications.

Example:

```text
Move #10618 → Round 34

Stops        1 → 2
Distance     +2.8 km
Finish       11:09 → 11:23
Promise      Safe
Cargo        Fits bike profile

Apply move
```

---

## 5. Invalid moves

Invalid moves are blocked.

Examples:

```text
Bike already at 2 Stops
Large cake prohibited on Motorbike profile
Delivery promise would be missed
Driver shift would be exceeded
Mixed cargo rule violated
```

The interface explains the reason and suggests compatible target Rounds where possible.

Do not let the dispatcher create a physically invalid plan merely because they dragged onto a block.

---

## 6. Recalculation scope

After an applied move, recalculate the affected planning chain.

At minimum:

- source Round;
- target Round;
- downstream start/end times in those driver lanes;
- return/reload gaps;
- load percentage;
- route/distance estimate;
- uncovered/covered counts;
- promise-risk summary.

The rest of the plan should remain stable where possible.

---

## 7. Empty Round behavior

If the last delivery is moved out of a proposed Round:

- remove the empty proposed Round;
- close the resulting timeline gap;
- recalculate later Rounds for that driver;
- keep Round IDs stable where practical for the remainder of the current proposal.

---

## 8. Uncovered recovery in planning

Uncovered deliveries remain first-class planning work.

In Phase 1B3B dispatcher may:

- manually place one into a compatible own-fleet Round;
- leave it uncovered for later Network / External recovery.

Do not silently create a Network or third-party booking during own-fleet plan adjustment.

---

## 9. Approval

Primary final action:

```text
Approve plan
```

Approval requires:

- all proposed own-fleet Rounds pass physical validation;
- no internal planner error;
- uncovered work is explicitly acknowledged if any remains.

If uncovered deliveries remain, approval may proceed only after a clear acknowledgement such as:

```text
Approve 12 own-fleet Rounds
4 deliveries remain uncovered
```

Those uncovered deliveries remain in Action/Planning for separate recovery.

---

## 10. Approval result

On approval:

- proposed Rounds become `upcoming`;
- assigned deliveries become planned;
- each Round receives its final driver / vehicle / Stop scope;
- plan approval is timestamped/audited;
- Dispatch returns to Live;
- upcoming Rounds are visible as normal operational work;
- uncovered deliveries remain unplanned.

Approval does not mean every Round has physically departed.

---

## 11. Plan mutation audit

Planning session should retain lightweight audit events such as:

```text
Round generated
#10618 moved R34 → R36
#10622 added from uncovered → R35
Round 37 removed after becoming empty
Plan approved
```

Production storage belongs in the planning/audit data model.

---

## 12. Acceptance criteria

- Uncovered delivery can be dragged onto a target Round.
- Planned Stop can be moved to another Round.
- Touch/iPad has a non-drag equivalent.
- Every move uses one shared validator.
- Invalid moves are blocked with a reason.
- Valid moves show an impact preview before applying.
- Affected timeline timings recalculate.
- Empty Rounds are removed cleanly.
- Covered/uncovered counts update.
- Approve Plan is explicit.
- Approval distinguishes upcoming work from live work.
- Remaining uncovered deliveries survive approval.
---

## Phase 1B3B implementation reconciliation

The implemented UX confirms the following controlling details.

## Generated-plan validation parity

The automatic planner and manual move preview must use compatible validation semantics.

A generated candidate Stop must not be inserted when its estimated arrival is already outside the promised delivery window.

Therefore:

```text
Generate Plan
and
Move Delivery
```

both respect:

- vehicle profile;
- Stop capacity;
- cargo compatibility;
- promised end time;
- driver shift.

Approval then runs a final full-plan validation.

## Desktop and touch interaction

Desktop planned Stop movement begins from an explicit drag handle.

Touch/iPad uses the visible `Move` action and Round picker.

Both call the same move simulation and apply function.

## Approval state naming

Product semantic state after approval is:

```text
Upcoming Round
```

The current frontend may internally reuse the legacy `status = planned` value while displaying `state = Upcoming`.

Backend/domain implementation should prefer a clear lifecycle enum or equivalent state model rather than relying on display wording.

## Approval with uncovered work

Own-fleet plan approval is allowed with uncovered work only after explicit acknowledgement.

Covered work becomes Upcoming.

Uncovered work remains:

```text
planning_state = unplanned
Action = capacity decision still required
```

No Network or external courier is booked as a side effect of own-fleet plan approval.

---

## Phase 1B3C — Planning Precision

**Status:** Locked before UX implementation  
**Purpose:** Make Planning truthful across dates, operating hours and physical capacity dimensions.

---

## 1. Planning date is explicit

Plan mode always has a planning date.

Canonical control:

```text
‹  Saturday, 29 Aug  2026  ›
Today
```

The planning date controls:

- deliveries included in the planning pool;
- driver shifts;
- vehicle assignments for that date;
- slot/date exceptions;
- planned Round dates;
- timeline horizon.

Do not rely on an implicit assumption that every unplanned delivery belongs to `today`.

---

## 2. Planning date source

Each delivery should conceptually carry a service/planning date in addition to promised start/end time.

Example:

```text
service_date = 2026-08-29
promised_start = 14:00
promised_end = 17:00
```

Bulk intake and connected-commerce sources must map the delivery date where available.

If only a clock window is available and merchant policy implies same-day, Rounds may default the draft to the current planning date, but the value remains explicit/editable.

---

## 3. Dynamic timeline horizon

The timeline must not be permanently hard-coded to `08:00–18:00`.

Rounds derives a useful horizon from:

- earliest active driver shift;
- latest active driver shift;
- earliest promised delivery;
- latest promised delivery;
- proposed Round start/end;
- reasonable visual padding.

Example businesses may therefore produce:

```text
Bakery      05:00–14:00
UrbanFlowers 07:00–20:00
Restaurant  10:00–01:00
```

The timeline scale and tick positions derive from the same calculated horizon.

---

## 4. Overnight horizon

If an operating day extends past midnight, Rounds must support a horizon greater than 24:00 in planning arithmetic while displaying human-readable next-day time appropriately.

Do not truncate a valid late-night shift merely because the wall clock passes midnight.

---

## 5. Physical capacity is multidimensional

A single generic `vehicle load %` is not sufficient.

A Round has multiple simultaneous physical limits.

Example:

```text
Motorbike + box

Stops      1 / 2
Flowers    0 / 2
Cake       1 / 1
```

Even though Stop utilization is 50%, the Round is fully constrained by Cake.

Canonical language:

```text
Capacity constrained by Cake
```

---

## 6. Capacity readout

For a planned Round, show relevant used/maximum dimensions:

- delivery Stops;
- cargo classes present or decision-relevant;
- prohibited dimensions when relevant to a failed move.

Do not clutter the surface with zero-value cargo classes that do not affect the current Round.

Example:

```text
Capacity
Stops       2 / 2
Flowers     2 / 2
Cake        0 / 1

Constrained by Stops + Flowers
```

---

## 7. Capacity utilization logic

For each dimension:

```text
utilization = used / configured maximum
```

The bottleneck is the highest active utilization.

If more than one dimension is at the same controlling utilization, expose both.

A prohibited class has:

```text
max = 0
```

and is a hard incompatibility, not a percentage.

---

## 8. Move impact preview

Planning move preview must show physical capacity truth.

Replace ambiguous:

```text
Vehicle load 50%
```

with something equivalent to:

```text
Capacity after move
Stops    1 → 2 / 2
Cake     0 → 1 / 1
Flowers  1 → 1 / 2

Constrained by Stops + Cake
```

Only decision-relevant dimensions need to be shown.

---

## 9. Planner summary by date

Plan summary and approval refer to the selected planning date.

Approval audit should retain:

```text
planning_date
approved_at
```

Upcoming Rounds created from the plan inherit the selected service date.

---

## 10. Acceptance criteria

- Plan mode visibly exposes the selected date.
- Previous / next date navigation works.
- Today shortcut works.
- Planning pool is date-scoped.
- Timeline horizon derives from the selected date's shifts/work.
- Timeline tick positions use the dynamic horizon.
- Round drawer exposes multidimensional capacity.
- Move preview exposes capacity by dimension.
- Bottleneck/constraining dimension is named.
- Approval stores/inherits the planning date.
---

## Phase 1B3C implementation reconciliation

The implemented planning precision pass confirms the following additional controlling details.

## Selected-date fleet truth

The Plan workspace derives driver availability for the selected planning date from:

```text
date exception
else recurring weekly schedule
```

A driver who is off on the selected date is not inserted into the planner merely because they exist in the Team list.

A date-specific vehicle-profile override controls that shift.

## No-work dates

If the selected planning date has zero unplanned deliveries:

- Generate Plan is disabled;
- Rounds does not fabricate a zero-work proposal.

## Overnight planning

When a selected operating day contains a shift crossing midnight, early-next-day delivery windows can be represented as planning minutes greater than `24:00`.

Display may show:

```text
01:00 +1
```

to distinguish next-day wall-clock time from the start of the selected operating day.

## Planning intake date

The New Delivery and batch-review flows now carry an explicit delivery/service date.

Manual creation defaults to the current selected planning date.

CSV/pasted tabular import may supply:

```text
Delivery date
Service date
Date
```

in `YYYY-MM-DD` form.

## Capacity truth

The UI now treats the maximum active physical dimension as the capacity bottleneck.

Examples:

```text
Stops   1 / 2
Cake    1 / 1

Constrained by Cake
```

and:

```text
Stops    2 / 2
Flowers  2 / 2

Constrained by Stops + Flowers
```

The legacy planning `loadPercent` compatibility value may still exist internally, but where used it should reflect the highest active physical utilization rather than Stop count alone.

## Phase 1C · Physical Delivery Truth — Manifest, Verification & POD

The canonical manifest does not treat `items` as display-only text or a single
generic package label.

## Canonical physical manifest

Every delivery has one structured physical manifest. The manifest is the physical truth that follows the delivery from intake through pickup, custody, handoff and history.

Conceptual line:

```text
manifest_line_id
product_ref?          // optional commerce/catalog reference
label                 // human-readable item
quantity              // positive integer
handling_class?       // fragile / chilled / large / etc when relevant
```

Examples:

```text
Red velvet cake      ×2
Rose bouquet         ×1
Cookie box           ×1
```

The manifest may originate from:

- connected commerce line items;
- screenshot/image/PDF/CSV/clipboard extraction;
- a batch source;
- manual Operations entry.

All sources normalize into the same manifest model. Free text may be preserved as source evidence, but driver verification uses the structured manifest.

## Fast manual entry

Manual delivery intake must make multiple item lines and quantities fast to enter. Operators must not be forced to encode `2 cakes + bouquet + cookies` into one unstructured field.

Required interaction:

```text
Item                         Qty
Red velvet cake              2
Rose bouquet                 1
Cookie box                   1
+ Add another item
```

## Pickup verification and custody

When itemized verification is required, the driver confirms the exact manifest at pickup before custody changes.

Example:

```text
[✓] Red velvet cake ×2
[✓] Rose bouquet ×1
[✓] Cookie box ×1

4 / 4 units verified
Confirm pickup
```

A quantity line is confirmed as a unit group; the driver does not need two taps for quantity two. If the physical quantity differs, the driver reports the actual mismatch rather than falsely confirming the line.

Canonical state progression:

```text
Manifest received
→ Driver checking
→ All required lines verified
→ Confirm pickup
→ Pickup verified
→ Driver custody
```

`Picked up` must not be inferred only from GPS departure or button navigation.

The Dispatch board receives the same verification truth and can show, for example:

```text
Driver checking · 3 / 4 units
Pickup verified · 4 / 4 units
Driver custody
```

## Manifest immutability after pickup

Before pickup, Operations may correct the manifest.

After pickup is confirmed, the physically confirmed manifest is custody evidence and cannot be silently rewritten. A product/quantity change after pickup requires an explicit operational event such as:

- return to merchant;
- additional pickup;
- physical transfer;
- package/item exception;
- replacement workflow.

Changing the destination or route does not rewrite the manifest.

## Delivery-side verification

The same physical manifest is used again at handoff.

The driver confirms that the package handed over still contains the expected lines/quantities. This creates a second verification stage distinct from pickup.

```text
Pickup verified       4 / 4
Handoff verified      4 / 4
```

A mismatch blocks ordinary completion and enters the structured exception path.

## Proof of delivery

POD is generated by the Driver App at the destination, not uploaded later by Operations as a substitute for driver proof.

Depending on merchant policy, the completion record may contain:

- delivery/handoff photo;
- GPS/geofence evidence;
- handoff type;
- received-by name/relationship;
- signature when required;
- delivery note;
- pickup manifest verification;
- handoff manifest verification;
- communication/call evidence.

The physical verification and POD belong to the same immutable delivery history.

## Completion signal on Dispatch map

A successful Stop may create a short, restrained completion signal on the Operations map after the authoritative Delivered/POD event is committed.

Desired behavior:

```text
Stop 3 → ✓
soft success ring
Delivered · 10:42
4 / 4 items verified · POD photo saved
```

The temporary state settles into the normal completed marker after a few seconds. It is operational feedback, not gamified confetti and not the source of truth itself.

## Phase 3B · Shared Communication Attachment Model

Operations and Driver App use one delivery/Round conversation record.

Supported human communication content:

- text;
- voice note;
- photo;
- file/document;
- location;
- Rounds map context;
- ordinary web links detected from message text.

## Links are message content

A normal pasted or typed URL is auto-detected and renders as a link preview/card. `Link` is not a separate attachment button.

## Desktop drop / paste

On desktop/tablet Operations, the conversation accepts files and URLs by drag/drop. Clipboard image paste stages the image. Drag/drop is an accelerator and never the only required way to attach.

When a valid drag enters the conversation, the UI explicitly reveals the target:

```text
Drop to send to Pim T.
Photos, PDFs, files or links
```

Dropped/pasted content is staged, not immediately sent.

## Staging before Send

One or many attachments may be staged above the composer. The operator can:

- review attachments;
- remove an attachment;
- add an accompanying text message;
- add another attachment;
- press Send once.

The same conceptual behavior applies on the Driver App, with Camera/Photo/File/Location actions appropriate to mobile.

## Attachment menu

Operations `+` menu contains sendable objects only:

```text
Photo
File
Location
Map context
```

Contact History is navigation/audit and must not appear inside the attachment menu.

## Contact History ledger

Contact History is a chronological audit ledger, not a second chat rendering.

It can filter:

```text
All
Messages
Calls
Files & media
```

Ledger rows preserve time, actor, event type, summary/detail and outcome/read/call state where relevant. It must remain readable at narrow dispatcher drawer widths and must not reuse chat-bubble CSS that causes collisions.

## Copy behavior

Human messages and attachment references can be copied from both Operations and Driver App. Copying a link copies its URL; copying a location/map item copies a useful textual reference.

## Communication persistence

Photos/files/links/locations, calls, voice notes, system route events and normal messages remain attached to the delivery/Round history after the live conversation is minimized or closed.

## Phase 1C4 · Post-Pickup Live Change Control

## Role-surface separation

The Dispatcher web app and Driver App are separate role-specific products. They may share the same delivery, manifest, route, communication and acknowledgement records, but neither application embeds a preview or role-switch simulation of the other application in production UX.

Canonical rule:

```text
shared operational record != shared screen
```

Operations sees driver-originated state and evidence. The Driver App sees Operations-originated instructions and route changes. Each role acts only from its own surface.

## Physical truth after pickup

Once pickup is verified, the pickup manifest is immutable custody evidence.

Operations may change the live delivery without rewriting that evidence. Allowed post-pickup operational changes include:

- destination address text;
- destination vehicle-arrival / delivery pin;
- entrance / access / handoff instruction;
- promised delivery window when merchant authority permits;
- route geometry caused by the destination change;
- future Stop sequence on the same own-fleet Round through the normal Round editor.

A post-pickup change does **not** silently:

- add/remove/change products or quantities;
- move custody to another driver;
- rewrite the pickup verification event;
- mark a current package as returned/transferred;
- bypass a required physical transfer or return workflow.

## Current Stop and route rule

If the physical destination of the current picked-up delivery changes, Rounds updates that Stop's operational destination and recalculates the route from the driver's current state.

The current Stop is not converted into another driver's Stop by a database-only edit. Reassignment after pickup requires a physical-custody workflow.

Future Stops on the same own-fleet Round remain editable through the canonical Round editor.

## New pin / access point

If the physical destination moves, Operations must confirm the new operational point (or explicitly state that only the textual entrance/address description changed while the physical point stays the same).

The original customer-supplied address and prior operational point remain in audit history.

## Mandatory consequence preview

Before applying a live post-pickup change, Operations sees the relevant consequences, including when available:

- old → new destination;
- whether the physical pin changes;
- added/reduced route distance;
- added/reduced route time;
- revised ETA for the current delivery;
- downstream Stop impact;
- revised Round finish / driver shift fit;
- delivery-window risk;
- handoff-instruction difference;
- custody/manifest lock.

Unsafe changes are never presented as harmless. Merchant policy may allow an operator to apply a risky change only after explicit acknowledgement; otherwise the change is blocked or escalated.

## Apply + acknowledgement

Applying the change creates a versioned operational event.

Conceptual event:

```text
live_delivery_changed
```

Minimum record:

```text
order_id
round_id
change_version
actor_user_id
applied_at
before
changes
after
route_impact
promise_impact
custody_driver_id
manifest_verification_id
driver_ack_status
acknowledged_at?
```

The Driver App receives one unmistakable route/delivery update. The driver must acknowledge it. Operations can see:

```text
Live update sent · awaiting driver
→ Driver acknowledged · 13:35
```

The acknowledgement becomes part of delivery history and the shared conversation/event ledger.

## Driver-state synchronization

After apply:

1. persist the versioned delivery change;
2. update the operational address/pin/instruction/window;
3. recalculate current route geometry and ETA;
4. recalculate affected downstream ETAs / Round finish;
5. update the Dispatcher map and drawer;
6. push the change to the assigned Driver App;
7. require driver acknowledgement;
8. retain both the previous and new state in history.

## Acceptance criteria

- No Driver App preview appears inside the Operations board.
- Pickup-confirmed manifest remains locked during every post-pickup edit.
- Operations can change address/pin, promised window and handoff instruction after pickup.
- A physical destination move can be placed on the map.
- Consequence preview appears before apply.
- Route/ETA/downstream/shift/promise impact is explicit when relevant.
- Future own-fleet Stops remain editable through the Round editor.
- Applying a change creates a versioned audit event.
- Driver acknowledgement is required and visible to Operations.
- Contact History retains the change + acknowledgement.

---

## Live Driver Availability, Contact Permission, and Privacy

**Controlling detailed spec:** `ROUNDS-SPEC-10-DRIVERS-LIVE-AVAILABILITY-CONTACT-v1.4.md`

Rounds must distinguish a driver's **identity**, **relationship**, **network eligibility**, **presence**, and **current work availability**. These are separate dimensions and must not be collapsed into one vague `online` flag.

### Business-side live visibility

A business should be able to understand, at a glance:

- which own drivers are on shift;
- which own drivers are available now;
- which own drivers are currently on a Round and when they are expected to become free;
- which eligible Network drivers have published `Open for jobs` availability;
- which known/preferred Network drivers are available now or projected to become available after an accepted commitment;
- whether a driver is not accepting work or has stale/offline presence.

`Available after HH:MM` is an operational projection, not a promise. It derives from accepted work, route state, shift/network availability policy and the driver's current published availability.

### Contact permission is relationship-scoped

Live availability does **not** mean every merchant may open a social chat with every visible driver.

Canonical contact boundaries:

- **Own team driver:** the business may Message / Call / Voice note according to normal team operating policy.
- **Network driver with active accepted work for the merchant:** the merchant may use the delivery/Round communication thread.
- **Preferred/known Network driver:** the merchant may use `Ask availability`; direct relationship messaging is available only where the driver has opted into direct merchant contact.
- **Unknown open-network driver:** the merchant may send a job Offer/Broadcast only. Open-for-jobs presence does not create a general-purpose chat permission.
- **External courier driver:** contact follows provider capability and the external-courier contract.

A pre-job availability inquiry is a **business-driver relationship interaction**, not a delivery message. It must not be injected into an unrelated order/Round conversation.

### Network availability is not performance

A Network driver choosing `Not accepting jobs`, going offline, or declining to publish availability is not a negative performance event.

Network performance starts with meaningful operating commitments such as:

- Offer response/acceptance behavior;
- cancellation/no-show after acceptance;
- pickup/delivery execution;
- custody/POD compliance;
- accepted-work incidents.

Own-team attendance may additionally use scheduled shift vs actual start/online evidence because an employment/team shift creates a different operating obligation.

### Location privacy before acceptance

Rounds may use driver location internally for matching, distance gating and ETA logic. A merchant must not receive unrestricted exact live coordinates for an unknown Network driver simply because the driver is open for jobs.

Before acceptance, merchant-facing Network visibility should be limited to the operational information required to evaluate supply, such as approximate distance/area, vehicle, relationship, availability and matching suitability. Exact job-linked live location becomes available according to the accepted-work tracking contract.

### Product-surface consequence

The Drivers surface must answer four questions without ambiguity:

1. **Who is working?**
2. **Who is available now?**
3. **Who becomes available soon?**
4. **Who am I allowed to contact, and how?**

These rules are behavior-locked before the dedicated premium Drivers visual phase.


## Drivers V5 · Command Surface Lock

The top-level `Drivers` product is a live fleet command surface with three stable sub-surfaces: **Own team / Network / Schedule**.

### Own team

The own-team surface prioritizes current operating state before durable history:

- current Round / loading state;
- projected next availability;
- shift and vehicle profile;
- current work / today throughput;
- Message / Call / Open Round when live work exists;
- compact 30-day evidence as context, with full reliability detail delegated to History.

The Drivers screen answers who is working and when capacity returns. It must not duplicate the full History evidence workspace.

### Network

Network rows combine live availability with merchant relationship context while preserving independence and privacy:

- `Open for jobs`, `On a Round`, `Not accepting jobs`, or stale/offline context;
- projected next availability where calculable;
- approximate area/distance before accepted work;
- vehicle and Preferred/Known relationship;
- accepted-work evidence only;
- only permitted contact actions are shown.

`Ask availability` is a structured relationship action. Relationship Message requires opt-in. Unknown Network drivers are reached through Offer/Broadcast rather than arbitrary chat. `Not accepting jobs` is not a performance penalty.

### Schedule

Schedule remains own-fleet capacity planning, not Network-driver shift management. It includes:

- recurring schedules;
- date exceptions;
- vehicle profile per shift;
- day-specific coverage;
- delivery-slot/time-window capacity effect.

The current day must be visually explicit and capacity summaries must be calculated from the actual current schedule date rather than a hard-coded first column.


---

## Settings Control Center S1

**Version:** Business Product Master v2.21  
**Controlling UX:** `ux/operations/rounds-operations-current-v45.html`

## Settings overview role

Settings is not merely a collection of configuration pages. Its Overview is the merchant's operating-control readout and must answer three questions immediately:

1. **What is Rounds allowed to do automatically?**
2. **Which systems/capacity sources are connected?**
3. **What setup gaps currently limit the operating model?**

The Overview must summarize current configuration without silently changing any rule. Detailed edits remain owned by their dedicated Settings pages.

## Operating posture

The Settings Overview exposes the current authority posture, including:

- automatic vs approval mode;
- own-fleet insertion authority and configured time/Stop limits;
- delivery exceptions that always require a person;
- Rounds Network enabled/disabled state and configured operating boundaries;
- external courier availability and booking authority.

The Overview may link to Dispatch settings but must not duplicate the full authority editor.

## Setup attention

A missing integration/provider may be shown as a setup gap only when it materially limits the configured operating model. Examples include:

- no commerce/store integration connected, meaning automatic order intake/writeback is not live;
- no external courier connected, meaning fallback ends after own fleet and Rounds Network.

These are configuration gaps, not Dispatch incidents, and must not be presented as urgent operational failures.

## Configuration map

The Overview groups settings into two conceptual areas:

- **Execution:** Dispatch authority, Delivery rules, Rounds Network.
- **Connections & customer:** External couriers, Integrations, Tracking & notifications.

Each row exposes current state, one or two meaningful boundary facts, and a real navigation action into the controlling page. No decorative/ghost controls are allowed.

## Protected-decision reminder

The Overview may summarize system protections that remain active across configuration, including custody immutability, exception escalation, Network consent boundaries and surprise-protection rules. These reminders are descriptive only; edits remain in the owning settings surfaces.

## Network Supply Map Layer

**Version:** Business Product Master v2.22  
**Date:** 30 August 2026

## Product role

Rounds may expose nearby **Rounds Network supply** as an optional Live Dispatch map layer so Operations can understand external capacity before starting a Broadcast.

This layer is a capacity signal, not unrestricted freelancer tracking.

## Supply states

The supply layer may represent:

- `Open for jobs` — Network capacity currently advertising availability;
- `Busy` — Network capacity currently committed elsewhere, with only an approximate next-available signal when Rounds can reasonably estimate one;
- accepted work for this merchant — no longer represented only as anonymous supply; the existing accepted-job driver/round tracking contract becomes authoritative.

## Privacy boundary

Before a Network driver accepts work for this merchant:

- map position is generalized/fuzzed rather than raw GPS;
- unknown drivers remain anonymous;
- known/preferred identity may be shown only when the merchant relationship and driver privacy/contact settings permit it;
- another merchant's identity, delivery, route, Stops, customer, destination and live work details are never exposed;
- busy capacity may remain fully anonymous while still contributing to aggregate supply/expected-availability signals.

After acceptance for this merchant, the normal job-linked live-tracking contract applies.

## Map behavior

- Network Supply is optional and off by default.
- It belongs to Live Dispatch, not the own-fleet Plan surface by default.
- Normal Dispatch remains operational truth: own drivers, this merchant's deliveries, accepted Network work and explicit exceptions stay visually dominant.
- Open supply uses restrained orange hollow points; busy supply is quieter and neutral.
- Supply clusters when zoomed out and resolves to small points when zoomed in.
- Supply availability is not a reservation or guarantee until an offer is accepted.

## Scale/performance contract

Production implementation should use a native Mapbox GeoJSON/vector source with clustering and viewport/radius filtering rather than one DOM marker per Network driver. Generalized supply may update on a slower cadence such as approximately 10–30 seconds; exact higher-frequency tracking remains reserved for accepted active work where permitted.

## External Courier Live Execution Finish

**Version:** Business Product Master v2.23  
**Date:** 31 August 2026

Rounds external fallback is one continuous operational record from quote through provider proof.

Canonical sequence:

```text
Own fleet unsuitable/exhausted
→ Rounds Network unsuitable/exhausted
→ external quote
→ booking committed under merchant authority
→ provider driver assigned
→ pickup
→ en route
→ delivered
→ provider POD normalized into Rounds
```

Rules:

- provider quotes expire and must be refreshed before booking when stale or mismatched to the current delivery scope;
- the external job remains inside normal Dispatch and History rather than opening a provider-specific product room;
- map identity may say `Lalamove` in a small subordinate provider label, but the map is still Rounds-owned and must not be dominated by provider branding;
- Operations may cancel an external booking before pickup; the delivery safely returns to Action because external custody has not begun;
- after provider pickup, cancellation/failure is a **custody exception**, not a normal reassignment trigger; Rounds preserves the external job and custody evidence until return, transfer or completion is explicitly resolved;
- external provider delivery/POD contributes to the same unified History/evidence system;
- standalone prototypes may simulate provider lifecycle events, but production truth must originate from server-side provider API/webhook integration.

## Operations Edge States & Device Scope

**Version:** Business Product Master v2.24  
**Date:** 31 August 2026

Rounds Operations must remain trustworthy when data is quiet, loading, stale, offline or partially degraded.

## State truth

- `Empty` means the requested dataset is known and contains no matching work; it must never be used as a substitute for loading or failed retrieval.
- `Offline` describes the current operator browser/session, not the whole Rounds backend and not a driver's presence.
- A browser losing connectivity must never relabel a driver `Offline` merely because Operations can no longer observe fresh presence. Show live status as paused/last-known instead.
- Already committed server-side automation, provider jobs and notifications may continue when an operator browser is offline. The browser must not claim that those workflows stopped unless the backend reports that state.
- A blocked offline action must not mutate Dispatch, create a fake message/call, create a fake Network Broadcast or pretend a provider quote/booking succeeded.
- Recovery must refresh live state before the UI resumes claiming current truth.

## Browser-offline authority

While the current Operations client is offline, it may continue to display locally available/last-known operating records, but new actions that require live coordination are blocked from that client, including:

- starting/expanding a Rounds Network Broadcast;
- requesting/refreshing/booking Lalamove or another external provider;
- sending new driver messages/voice/attachments or starting a live call;
- sending a Network availability request;
- switching into map modes that require new remote imagery/data.

Draft text and staged communication attachments may remain visible locally. No fake `Sent` event is created.

## Device scope

Full Rounds Operations is canonical on **laptop and iPad-class work surfaces**. A phone-sized full Dispatch/Plan workstation is intentionally out of scope because the product depends on simultaneous rail + map + route/timeline + contextual decision visibility.

A future phone companion may provide narrow functions such as alerts, urgent approval/rejection and record lookup, but it is not the canonical full Operations interface. The Driver App remains the phone-first field product.


## Driver App Final Board + Localization + Commerce API Closure

## Driver V1 board closure

The returned Driver App UX set dated 2026-09-01 contains 47 canonical English boards and closes the V1 screen library for product/build handoff.

The production Driver product is Thai-first and bilingual:

- `th-TH` primary Thailand locale;
- `en` secondary;
- first-run `A01 → A01B Choose Language → onboarding`;
- later change under `L01 Profile → Language`;
- one localized app / one behavior implementation;
- Thai design boards mirror English screen IDs and operational truth one-to-one.

See `ROUNDS-DRIVER-CANONICAL-MANIFEST-v6.md`, `ROUNDS-DRIVER-UX-BEHAVIOR-MASTER-v3.1.md`, `ROUNDS-DRIVER-UI-CONSTITUTION-v1.2.md` and `ROUNDS-SPEC-14-DRIVER-LOCALIZATION-LANGUAGE-v1.0.md`.

## UrbanFlowers proving-ground integration

UrbanFlowers should prove the canonical store → Rounds → Driver → POD → store-writeback loop before broad connector expansion.

Rounds must not become coupled to one commerce platform. Shopify, WooCommerce/WordPress and custom merchants all enter through one normalized Rounds delivery contract.

Product integration surfaces therefore include:

- Shopify App;
- WooCommerce extension;
- Public Rounds API + signed outbound webhooks;
- existing manual/AI/bulk intake.

A connector is an adapter and onboarding surface, not an alternate fulfillment engine.

## Build boundary

Exact REST/OpenAPI schemas, auth, idempotency keys, webhook signatures/retries and connector implementation are Engineering Build Spec work. Product behavior above is locked.

*End of ROUNDS — SPEC 2 · Business & Product Master Specification*
