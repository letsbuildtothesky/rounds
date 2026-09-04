# ROUNDS — SPEC 3
## Driver + Broadcast Operating Model

**Status:** Canonical product operating model v1.9  
**Date:** 1 September 2026  
**Depends on:** ROUNDS — SPEC 2 · Business & Product Master  
**Purpose:** Define how Rounds behaves operationally from the moment delivery work exists until the work is completed, including driver work modes, broadcast waves, offers, multi-stop Rounds, arrival/pickup/delivery verification, proof of delivery, live changes, and exceptions.

## Changelog

- **v1.9 — 2026-09-04:** Consolidated the appended operating-model sections
  into the owning document, removed the premature end marker and aligned the
  buyer/recipient terminology with the canonical actor model. Product behavior
  is unchanged.

**Explicitly excluded from this specification:**
- visual styling;
- colors;
- typography;
- component design;
- screen layouts;
- animation language;
- gesture choices such as tap vs hold vs slide;
- Flutter, React, Supabase, database schemas, SDKs, or implementation libraries;
- technical API definitions.

Those are defined after the operating behavior is locked.

---

> **Implementation scope note:** This specification defines the product-complete Network operating model. Public/open Network, KYC/face-check, Network earnings/settlement and broad cross-tenant supply are **not Pilot/Slice 1 dependencies**. The active build scope is controlled by `ROUNDS-IMPLEMENTATION-SCOPE-LADDER-v1.0.md`.

# 1. The core operating idea

Rounds is not a sequence of independent courier jobs.

Rounds is a live delivery operating system built around **capacity**, **Rounds**, and **verified delivery events**.

The system should continuously answer four questions:

1. **What work needs to move?**
2. **Which available driver can do it best without damaging existing commitments?**
3. **Should the work be a single delivery or part of a multi-stop Round?**
4. **What must be verified before the work can advance to the next state?**

A delivery should therefore not jump from `assigned` to `delivered`.

The behavioral chain is:

**Work becomes ready**  
→ evaluate own capacity  
→ build or update a Round  
→ assign internally OR broadcast externally  
→ driver receives assignment/offer  
→ driver goes to pickup  
→ arrival is confirmed  
→ pickup is verified  
→ Round begins/continues  
→ driver goes to next stop  
→ arrival at stop is confirmed  
→ handoff is identified  
→ required proof is captured  
→ stop is completed  
→ next stop  
→ Round completes.

Every major transition should create an auditable operational event.

---

# 2. Key objects in the operating model

This specification uses the following product concepts.

## 2.1 Driver

A person with one global Rounds identity.

A driver may have relationships with multiple businesses and may perform different kinds of work at different times.

The driver is not permanently defined as “Team,” “Freelance,” or “Hybrid.”

Those are better understood as **work relationships and current modes**.

## 2.2 Business

A merchant or operator using Rounds to manage deliveries.

Examples:
- UrbanFlowers;
- restaurant;
- bakery;
- pharmacy;
- local ecommerce business.

## 2.3 Delivery

One pickup-to-recipient delivery commitment.

A Delivery contains the operational promise and recipient context, but it does not necessarily travel alone.

## 2.4 Stop

A physical action point inside a Round.

Examples:
- pickup at UrbanFlowers;
- dropoff at customer A;
- dropoff at customer B;
- return to merchant;
- secondary pickup if supported later.

## 2.5 Round

A driver work package containing one or more ordered Stops.

A Round may be:
- created for an own driver;
- offered to a network driver;
- modified while active if rules allow;
- completed when all required Stops resolve.

**Round is a first-class product object from V1.**

## 2.6 Assignment

Work pushed to a driver under a business relationship where the driver is expected to perform it.

Typical example: UrbanFlowers assigns its own team driver.

An Assignment is not a market offer.

## 2.7 Offer

Work proposed to a network-eligible driver who may accept or decline.

The driver must understand the scope and guaranteed fare before accepting.

## 2.8 Broadcast

The process of offering unfilled work to eligible drivers according to distance, relationship, requirements, and expansion rules.

## 2.9 Handoff

How the delivery physically ended at a Stop.

Examples:
- customer;
- concierge;
- security;
- relative/other person;
- reception;
- at door;
- other approved destination-specific handoff.

## 2.10 Proof of Delivery (POD)

The evidence required to verify completion of a Stop.

POD is adaptive. It depends on merchant policy, delivery risk, and handoff type.

---

# 3. Driver work modes

A driver can move through work modes during the day.

## 3.1 Off duty / unavailable

The driver is not available for new work.

No new network offers should be sent.

If the driver has an unfinished accepted Round, the app must not allow a simple unavailable state to abandon the Round; the driver must resolve or escalate the active work.

## 3.2 Team work mode

The driver is currently working for a business with which they have a team/employment relationship.

Behavior:
- business work has priority;
- the driver receives assignments rather than market offers;
- per-job network fare is normally not shown;
- employer rules determine whether outside network work is allowed during the active work period;
- background availability for open-network offers is normally disabled while team work is active unless explicitly permitted.

## 3.3 Merchant-linked network mode

The driver can receive work from a business that already knows or has invited them.

This is external paid work but with an existing merchant relationship.

Behavior:
- work arrives as an Offer unless an explicit direct-assignment relationship exists;
- the driver sees guaranteed fare and full scope;
- acceptance is optional;
- the business relationship affects broadcast priority inside the relevant distance.

## 3.4 Open-network mode

The driver is available to eligible Rounds businesses generally.

Behavior:
- receives network Offers;
- can accept or decline;
- must satisfy network verification/eligibility rules;
- guaranteed fare is shown before acceptance.

## 3.5 Busy / active Round

The driver has accepted or been assigned work that is currently in progress.

Being busy does not automatically make the driver ineligible for all additional work.

Rounds may consider another job if it can safely fit the active Round.

However:
- existing delivery promises take priority;
- vehicle capacity must remain safe;
- additional work cannot silently change a network driver's accepted scope if the change is material.

## 3.6 Temporarily unavailable

A short-lived state for reasons such as:
- break;
- fueling;
- mechanical issue;
- personal pause;
- waiting for current issue resolution.

The driver should stop receiving new offers without necessarily ending the overall workday/session.

---

# 4. Work-source behavior

The same driver may receive different kinds of work. Rounds must make the behavioral difference clear.

## 4.1 Team Assignment

Example:

UrbanFlowers → Somchai

The business assigns the work.

Driver needs to know:
- pickup;
- number of stops;
- route expectation;
- items/special handling;
- delivery windows;
- current priority;
- what action to take now.

The driver does not need a market countdown or delivery fare to decide whether the job is worthwhile.

The driver may still have an **Unable to take / Report problem** path for legitimate operational reasons.

## 4.2 Network Offer

Example:

UrbanFlowers → nearby preferred/network rider

Driver needs enough information to make an economic and operational decision.

The driver can Accept or Decline.

The offer must not hide information that materially changes the work.

## 4.3 Add-to-active-Round proposal

If new work can be inserted into a driver's active Round, behavior depends on work source.

### Team driver

If the employer has authority to modify the active Round, dispatch may insert the Stop provided:
- route constraints remain valid;
- capacity remains valid;
- promises remain safe or the business explicitly accepts the consequence.

The driver is notified of the change and the updated sequence.

### Network driver

If the additional Stop materially changes:
- total distance;
- total duration;
- number of stops;
- final destination;
- required handling;
- guaranteed fare;

the driver must receive a clear change proposal and explicitly accept it.

Example:

**Add 1 stop**  
+฿95  
+2.1 km  
+8 min  
Existing delivery windows remain safe.

The driver can accept or decline the addition without losing the already accepted Round.

---

# 5. Own-capacity check before broadcast

A business should not automatically buy external capacity while an efficient own-driver solution exists.

Before network broadcast, Rounds evaluates the business's own operating capacity.

The system asks:

1. Is an own driver available?
2. Can the delivery fit an existing Round?
3. Can a new Round be created for an own driver?
4. Would inserting the delivery cause another promise to be missed?
5. Does the delivery require a vehicle or capability the own fleet lacks?
6. Would external fulfillment actually be more operationally sensible?

Possible outcomes:

### A. Assign to own driver

The work is added to an own driver's Round or creates a new Round.

### B. Recommend own driver, require dispatch approval

Used when insertion is possible but has a meaningful tradeoff.

Example:

“Add to Nono's Round · +11 min · all windows remain safe.”

### C. Own capacity not suitable

Rounds moves to Broadcast.

---

# 6. Broadcast principle

The governing rule is:

## **Distance determines relevance. Relationship determines priority inside that distance.**

Rounds must not notify a preferred driver 9 km away before considering strong available supply 800 m from pickup.

The default first radius is **3 km from pickup**.

---

# 7. Broadcast waves

## 7.1 Wave 0 — Own capacity

Before external network broadcast:
- own team drivers;
- existing own-driver Rounds;
- own vehicle/capacity constraints.

If own capacity is appropriate, use it.

If not, external broadcast starts.

## 7.2 Wave 1 — Preferred / known drivers within 3 km

Eligible drivers who already have a relationship with the business receive the Offer first.

Examples:
- invited by the business;
- worked for the business before;
- marked preferred;
- repeat trusted rider;
- otherwise defined as priority by merchant relationship.

The relationship only gives priority **inside the active distance gate**.

## 7.3 Wave 2 — All qualified Rounds drivers within 3 km

If Wave 1 does not fill the work, Rounds opens the Offer to all qualified available network drivers within 3 km.

Drivers already notified in Wave 1 are not treated as new recipients but may remain eligible according to the broadcast timing rule.

## 7.4 Wave 3 — Preferred / known drivers in the next ring

Default next ring: **3–5 km**.

Preferred/known drivers in that ring are considered first.

## 7.5 Wave 4 — All qualified drivers in the next ring

All eligible network drivers within the expanded ring are included.

## 7.6 Further expansion

The merchant may permit expansion beyond the default next ring.

Examples:
- 5–8 km;
- custom maximum radius;
- no further automatic expansion.

Exact radii after 5 km are merchant/network configuration, not hard-coded product doctrine.

## 7.7 Broadcast timing

This specification does not lock exact seconds per wave.

The pilot should calibrate timing based on:
- driver density;
- push-delivery latency;
- category urgency;
- average acceptance time;
- pickup SLA.

The system must nevertheless feel continuous: one wave should flow into the next without requiring the merchant to manually restart the process.

---

# 8. Broadcast eligibility

A driver can only receive an Offer if the driver is suitable for the work.

Eligibility should consider at minimum:

- current availability;
- distance to pickup;
- merchant relationship;
- vehicle type;
- vehicle/package capacity;
- current active Round;
- existing accepted commitments;
- pickup window;
- delivery windows;
- special handling requirements;
- merchant block status;
- network suspension status;
- required verification level;
- merchant-specific restrictions;
- whether the route can realistically be completed.

Future matching can add:
- direction of travel;
- predicted traffic;
- return-route fit;
- building familiarity;
- category experience;
- driver reliability;
- pickup familiarity;
- learned local routing behavior.

---

# 9. Broadcast unit: Delivery or Round

Rounds must support broadcasting either:

## 9.1 One Delivery

Example:

UrbanFlowers → Sathorn  
1 stop

## 9.2 A bundled Round

Example:

UrbanFlowers  
4 stops  
18.6 km  
58 min  
Guaranteed fare ฿420

The business can broadcast several selected deliveries as one Round when they belong together operationally.

The driver accepts the Round as a package.

A bundled Round must not be presented as four independent accepts if the business requires one driver to complete all four.

---

# 10. What a network Offer must communicate

Before acceptance, the driver must understand the work without opening a complex detail flow.

Minimum material information:

- **guaranteed total fare**;
- merchant/business name;
- distance from driver to pickup;
- pickup area/location;
- number of delivery stops;
- total estimated route distance;
- estimated total duration;
- final destination/ending area for a multi-stop Round;
- delivery/pickup time constraints;
- vehicle requirement;
- material special handling;
- COD/payment handling if ever supported;
- whether this is a preferred-merchant Offer or general network Offer where useful;
- whether the work is a new Round or proposed addition to an active Round.

The driver should not need to calculate a per-km formula mentally.

The fare shown is the guaranteed fare for the accepted scope.

---

# 11. Offer acceptance behavior

## 11.1 One winner

If the same Offer is sent to multiple drivers, only one driver can successfully claim the work unless the business intentionally requests multiple drivers.

The first valid acceptance wins.

## 11.2 Race loss

If two drivers accept almost simultaneously:

Winner:
- receives confirmation;
- work becomes part of their active queue/Round.

Losing driver:
- receives an immediate clear state such as “Another driver accepted first.”
- is returned to availability without penalty.

This must not appear as a generic technical error.

## 11.3 Decline

Decline should be fast.

The system may optionally capture lightweight reasons later for network quality, but declining should not become a questionnaire.

## 11.4 Timeout

If the driver does not respond before the Offer expires:
- the Offer closes for that driver;
- the driver remains available;
- the broadcast engine continues according to wave logic.

## 11.5 Acceptance confirmation

Once accepted, the driver must immediately understand:
- the work is theirs;
- what the first action is;
- where the pickup is;
- the current expected Round scope;
- the guaranteed fare.

No ambiguous “pending” period should remain after successful claim.

---

# 12. Fare behavior

## 12.1 Guaranteed scope

A network driver's Offer fare applies to a defined scope.

Scope includes:
- pickup;
- stops;
- route/distance assumption;
- service requirements;
- relevant time requirement.

## 12.2 No silent reduction

Rounds must never reduce the driver's accepted fare after acceptance because the route happened to become shorter.

## 12.3 Material scope increase

If scope materially increases, fare adjustment must be explicit.

Examples:
- another stop added;
- major address change;
- significant wait requested;
- return trip added;
- new special handling.

## 12.4 Minor operational variation

Normal traffic variation or small route changes do not automatically renegotiate fare unless merchant policy explicitly uses time-based compensation.

---

# 13. Round creation

A Round is built from one or more Stops.

The system should consider:
- pickup location;
- delivery geography;
- time windows;
- priority;
- item compatibility;
- capacity;
- driver shift/availability horizon;
- estimated traffic;
- vehicle constraints;
- business rules.

A Round should expose at least:
- Round owner/driver;
- source business;
- stops in current sequence;
- completed/current/upcoming status;
- expected total duration;
- expected total distance;
- promised windows;
- network fare if applicable;
- active exceptions.

---

# 14. Multi-stop behavior

Multi-stop is fundamental in V1.

The active driver experience should always distinguish:

- **completed stops**;
- **current/next stop**;
- **remaining stops**.

The driver should not need to manage five independent jobs manually.

At any moment, the system should be able to answer:

**What do I do now?**

And secondarily:

**What comes after this?**

The driver should be able to review the remaining Round when stationary, but the active road state should prioritize the current instruction and next Stop.

---

# 15. Route sequence and re-optimization

Rounds should treat route order as live operational state, not a static morning plan.

A Round can change when:
- a new order arrives;
- traffic changes materially;
- a stop fails;
- a customer changes address;
- a driver becomes unavailable;
- another Round becomes more efficient;
- dispatch manually reorders work.

Any change must respect:
- existing accepted scope;
- network-driver consent rules;
- delivery promises;
- capacity;
- merchant authority.

The system should calculate the operational impact before applying a significant change.

Example:

**Insert order UF-9218 into Nono's Round**  
Adds 2.4 km  
Adds 9 min  
All existing windows remain safe.

Or:

**Not recommended**  
Would make Stop 4 approximately 18 min late.

---

# 16. Driver-originated route correction

Drivers have local knowledge the routing engine may not.

The product should eventually allow a driver to report or propose route corrections such as:
- road inaccessible;
- building entrance is on another soi;
- permanent gate closure;
- better access point;
- incorrect map pin;
- preferred stop sequence.

A driver should not casually reorder promised customer stops without rules, but Rounds should be able to learn from repeated driver corrections.

This can become a later intelligence layer without changing the V1 Round model.

---

# 17. Pickup approach

Once work is assigned/accepted, the first operational destination is the pickup.

The driver should have access to:
- pickup location;
- navigation;
- merchant contact path;
- pickup instructions;
- item/round summary;
- special handling;
- Issue path.

The driver is not considered physically arrived simply because GPS is nearby.

---

# 18. Arrival verification

Arrival is an explicit event at both pickup and delivery stops.

## 18.1 Why explicit arrival exists

It provides:
- operational truth;
- waiting-time measurement;
- merchant/customer visibility;
- structured exception handling;
- protection from GPS inaccuracies;
- a clear transition to pickup or POD tasks.

## 18.2 GPS assistance

Rounds can compare current driver location with the expected Stop location.

If the driver is within the merchant-configured/operational geofence, arrival can proceed normally.

If the driver is outside the geofence:
- warn, do not automatically hard-block;
- show approximate discrepancy;
- allow justified override where necessary;
- record the anomaly.

Bangkok high-rises, underground parking, dense buildings, and map-pin errors mean GPS cannot be treated as perfect truth.

## 18.3 Interaction is not defined here

The old product used slide gestures for arrival.

This specification intentionally does **not** require slide, tap, hold, or any specific gesture.

The new UX will choose the clearest interaction later.

---

# 19. Pickup verification

After arrival at pickup, the driver verifies that the correct work has been collected.

Rounds supports two primary pickup modes.

## 19.1 Itemized pickup

Used when the merchant provides structured items and wants item verification.

Examples:
- bouquet;
- cake;
- gift bag;
- hamper;
- multiple parcels.

The driver confirms each required item or group.

Merchant policy can define whether:
- every item must be checked;
- only count must be checked;
- pickup photo is required;
- fragile/special items need explicit acknowledgement.

## 19.2 Generic pickup

Used when item-level verification is unnecessary.

Examples:
- sealed restaurant order;
- generic parcel;
- one prepared bag.

The driver confirms the expected count/description and proceeds.

## 19.3 Pickup discrepancy

If something is wrong, the driver should not falsely mark pickup complete.

Possible discrepancy paths:
- item missing;
- wrong item;
- item damaged before pickup;
- order not ready;
- merchant cannot locate order;
- package too large for vehicle;
- merchant requests wait.

These create structured events and route to the appropriate resolution path.

---

# 20. Waiting at pickup

Waiting time should be measurable.

Once the driver has arrived but the order is not ready:
- driver can mark **Order not ready / Waiting**;
- business/dispatch sees the wait state;
- waiting duration begins;
- merchant-specific compensation rules may apply later;
- driver should not need to repeatedly press status buttons while waiting.

When pickup becomes ready, pickup verification continues.

---

# 21. Active Round execution

After pickup verification, the driver is in active Round execution.

For each Dropoff Stop, the loop is:

**Navigate**  
→ **Arrive**  
→ **Resolve handoff**  
→ **Capture required proof**  
→ **Complete Stop**  
→ **Advance to next Stop**.

The Round ends only when all Stops are completed, failed with a resolved outcome, transferred, or otherwise formally closed.

---

# 22. Stop context

The current Stop can carry context necessary for correct delivery, such as:
- recipient name;
- destination;
- phone/contact route;
- delivery window;
- special instructions;
- building/entrance notes;
- item warnings;
- buyer/recipient distinction;
- surprise/discreet instructions;
- merchant-specific handling policy;
- whether signature/photo/name is required;
- previous failed-attempt information where appropriate.

Commercial context should be available where it changes operational behavior, but the driver should not be distracted with unnecessary customer financial data while riding.

---

# 23. Buyer and recipient are separate parties

Rounds supports deliveries where the buyer is not the person receiving the
order. A gifting buyer may be described contextually as the gift sender, but
`sender` is not a generic delivery actor because courier providers may use it
for the pickup contact.

This is fundamental for:
- flowers;
- gifts;
- corporate gifting;
- family pharmacy orders;
- document delivery;
- ecommerce gifting.

A Delivery may therefore have:
- merchant;
- buyer;
- recipient;
- alternative receiver.

Different parties may have different:
- contact permissions;
- notification rules;
- visibility;
- authority to resolve a failed delivery.

Example:

A surprise gift may forbid revealing merchant/product details to the recipient before arrival.

---

# 24. Handoff model

At the destination, the driver identifies how the item was handed over.

The common handoff set should support at least:

- Customer / intended recipient;
- Reception;
- Concierge;
- Security;
- Relative / other person;
- Neighbor where merchant policy allows;
- At door / safe place where merchant policy allows;
- Other.

The exact enabled options can vary by business/category.

Example:

A pharmacy may disable “Neighbor.”

A restaurant may allow “At door.”

A premium gift may require a named person.

---

# 25. POD requirement engine

POD must be policy-driven rather than globally identical.

The required evidence depends on:
- merchant;
- category;
- order value/risk;
- delivery type;
- handoff type;
- buyer requirement;
- recipient requirement;
- previous exception state.

Possible evidence elements:

- photo;
- multiple photos;
- recipient signature;
- received-by name;
- role of receiver;
- GPS location;
- arrival/completion timestamp;
- contact-attempt history;
- optional note;
- barcode/QR scan later;
- age/ID verification later where legally appropriate;
- merchant-specific confirmation.

---

# 26. Example POD policies

These examples illustrate behavior only.

## 26.1 Restaurant hand-to-customer

Possible policy:
- handoff = Customer;
- no signature;
- optional photo or no photo depending on merchant policy;
- timestamp + location stored automatically.

## 26.2 Restaurant at door

Possible policy:
- handoff = At door;
- photo required;
- contact/permission confirmation according to merchant policy;
- timestamp + location.

## 26.3 UrbanFlowers premium bouquet

Possible policy:
- photo required;
- handoff selected;
- if intended recipient receives: signature may be required depending on order class;
- if concierge/security/reception receives: received-by name required;
- timestamp + GPS;
- call/contact history retained.

## 26.4 Pharmacy sensitive item

Possible policy:
- named receiver required;
- restricted handoff options;
- merchant-configured additional verification;
- no “leave at door” unless explicitly permitted.

---

# 27. Photo behavior

When a photo is required, the product should support:
- camera capture;
- one or multiple photos according to policy;
- photo retry/retake;
- adding another photo;
- offline-safe capture and later sync;
- timestamp/location metadata where permitted;
- clear indication when minimum photo requirements are satisfied.

The driver should not be able to complete a Stop while required photo evidence is missing.

---

# 28. Signature behavior

Signature is conditional, not universal.

It may be required when:
- merchant policy requires it;
- buyer requested signed delivery;
- delivery type is high-value;
- intended recipient handoff requires it.

If signature is required:
- the driver collects it after handoff;
- signer identity/name should be associated where required;
- signature becomes part of the delivery record.

If the delivery is handed to concierge/security/reception and policy only requires a received-by name, the app should not unnecessarily force a signature.

---

# 29. Contact and call history

Contact attempts should become part of the operational record where possible.

Examples:
- called recipient at 11:05 — no answer;
- called recipient at 11:08 — connected;
- messaged dispatch;
- merchant called driver.

This matters because failed-delivery decisions should be based on evidence, not only free-text claims.

The system should be able to use contact history automatically in exception workflows.

Example:

Before allowing “Customer not answering” to escalate to an at-door fallback, merchant policy may require one or two contact attempts.

---

# 30. Communication principle

Communication should support delivery completion, not become a separate social/chat product.

Driver should be able to contact:
- merchant/dispatch;
- recipient/customer according to phase and permissions;
- support/emergency path.

The exact communication methods can vary by launch implementation.

This specification does not require custom in-app VoIP.

Native phone, chat, LINE integration, masked calling, or later VoIP can be implementation choices provided the operating record remains reliable.

---

# 31. Structured exception system

Failure is a first-class operating state.

The driver should not need to invent the next step through free-text chat.

V1 must support structured paths for at least:

1. Customer not answering;
2. Address is wrong / cannot locate destination;
3. Items damaged / wrong / missing;
4. Cannot complete delivery / access denied / refused;
5. Pickup not ready / merchant delay;
6. Vehicle or mechanical problem;
7. Driver accident or emergency;
8. Merchant cancellation;
9. Recipient/buyer requests a change.

---

# 32. Customer not answering

Behavior should use evidence and merchant rules.

Possible flow:

1. Driver arrives.
2. Contact attempts are recorded.
3. Driver selects **Customer not answering**.
4. Rounds evaluates merchant policy and delivery type.
5. Driver receives a concrete instruction.

Possible next actions:
- wait X minutes;
- retry call;
- contact buyer;
- contact dispatch;
- leave with concierge/security;
- leave at door with photo if allowed;
- move to next Stop and retry later;
- return to merchant;
- reschedule.

The driver should not decide these commercial policies alone.

---

# 33. Wrong address / cannot locate

The driver can flag:
- map pin incorrect;
- written address inconsistent;
- building not found;
- recipient says different location.

Rounds should:
- preserve original address;
- capture proposed corrected location/address;
- involve merchant/recipient according to policy;
- calculate impact if destination changes;
- handle fare adjustment for network driver if the scope materially changes;
- update future routing only after appropriate confirmation.

A corrected location can later become learned merchant/customer address intelligence.

---

# 34. Damaged / missing / wrong items

The driver should be able to report whether the issue existed:
- at pickup;
- during transport;
- at delivery discovery.

Possible evidence:
- photo;
- note;
- merchant contact;
- item selection.

The system may resolve to:
- replacement;
- return;
- partial delivery;
- cancellation;
- continue with merchant approval.

The driver should not be forced to mark the delivery complete to escape the workflow.

---

# 35. Cannot complete delivery

Examples:
- access denied;
- recipient refuses item;
- building will not accept delivery;
- restricted delivery area;
- safe handoff impossible.

Rounds should create a structured unresolved state and obtain merchant/dispatch resolution.

Possible outcomes:
- retry;
- alternative receiver;
- next Stop first, return later;
- return to merchant;
- cancel delivery;
- transfer to another driver.

---

# 36. Accident or emergency

Emergency must immediately prioritize driver safety.

The flow should:
- create an emergency event;
- notify dispatch/support immediately;
- make emergency contact/call path obvious;
- freeze or protect active Round state;
- prevent automatic reassignment until the system understands what happened, unless safety rules require it;
- allow dispatch to recover undelivered items and reassign Stops.

The app should not require the driver to complete a long form during an emergency.

---

# 37. Merchant cancellation

A merchant can cancel:
- before assignment;
- during broadcast;
- after driver acceptance;
- after pickup.

Behavior differs by state.

## Before acceptance

Offer closes immediately.

## After acceptance but before pickup

Driver is notified. Cancellation compensation, if any, follows merchant/network policy.

## After pickup

This is not a normal cancellation.

Rounds must resolve what happens to the physical item:
- return to merchant;
- redirect;
- dispose/retain according to policy;
- deliver anyway with approval.

Network-driver fare may need adjustment.

---

# 38. Driver cancellation / unable to continue

A network driver cannot simply disappear from an accepted Round.

If the driver cannot continue:
- reason is captured;
- active location/state is preserved;
- dispatch is alerted;
- uncompleted Stops return to recovery planning;
- already-picked-up physical items must be accounted for;
- replacement driver/handoff may be arranged.

Driver reputation consequences, if any, are separate policy and not defined here.

---

# 39. Live Round changes

This is a core Rounds advantage and must be designed from the beginning.

New work can appear after a Round has started.

Rounds should evaluate whether the new work fits an active Round based on:
- pickup location;
- route geometry;
- promised windows;
- current driver position;
- capacity;
- additional duration;
- additional distance;
- driver relationship/work mode;
- fare impact.

Possible recommendation:

**Fits Nono's active Round**  
Pickup 1.1 km ahead  
Adds 7 min  
All existing promises remain safe.

Or:

**Do not insert**  
Would make existing Stop 3 late by 22 min.

---

# 40. “Job on your route”

Rounds should develop a matching concept for work that efficiently fits where a driver is already going.

Example:

Driver finishes in Sathorn and is heading toward Phrom Phong.

New pickup/dropoff follows approximately the same direction.

Offer can communicate:

**On your route**  
+฿145  
Adds 7 min

This can reduce empty return kilometers and raise driver earnings per hour.

It is not required for the first simple broadcast engine, but the data model and behavior should not block it.

---

# 41. Merchant control over live changes

Businesses can define authority levels such as:

- automatically insert safe Stops into own-driver Rounds;
- ask dispatch before any insert;
- never alter a Round after departure;
- allow automatic network-driver add-stop proposals;
- maximum added minutes without manual review;
- maximum Stop count per Round;
- category/VIP deliveries that can never be auto-inserted.

These controls belong to business operating rules, not driver preference alone.

---

# 42. Network-driver consent for changed work

A network driver's accepted economic scope must be respected.

Explicit consent is required when a proposed change materially modifies the job.

Examples:
- add another stop;
- change ending area significantly;
- increase expected duration significantly;
- require a different handling mode;
- require return-to-merchant;
- materially change distance.

The proposal must state:
- what changed;
- added fare;
- added distance;
- added time;
- resulting total scope.

Declining the modification should not cancel the already accepted work.

---

# 43. Broadcast failure

If no driver accepts after configured waves, Rounds should not silently pretend the work is solved.

The merchant receives a clear unresolved state.

Possible next actions:
- increase guaranteed fare;
- expand radius;
- rebroadcast preferred drivers;
- broadcast to all again;
- split a multi-stop Round;
- combine/rebatch differently;
- assign an own driver despite tradeoff;
- delay/rebook within merchant promise rules;
- use an external courier.

Automatic third-party courier fallback can be supported later as a merchant rule, but should not be mandatory system behavior.

---

# 44. Increase-fare behavior

A merchant may increase the guaranteed fare when a Broadcast is not filling.

If fare increases:
- currently active eligible recipients should receive the updated offer where appropriate;
- new recipients see the new guaranteed fare;
- the old lower fare should not remain ambiguously visible;
- accepted jobs are not repriced downward.

Rounds may later recommend a fare based on local acceptance data, but the merchant controls the actual offer within platform rules.

---

# 45. Splitting a Round

A multi-stop Round may fail to attract a driver because:
- too many Stops;
- wrong vehicle requirement;
- long final destination;
- low fare relative to scope;
- timing conflict.

Rounds should be able to suggest splitting it.

Example:

Original:
- 6 stops;
- 31 km;
- ฿480.

Suggested:
- Round A: 3 Sukhumvit stops;
- Round B: 3 Sathorn/Bangrak stops.

The business can accept or reject the split.

---

# 46. Reassignment and transfer

A Stop or remaining Round may move from one driver to another when:
- driver breaks down;
- schedule collapses;
- driver shift ends unexpectedly;
- merchant manually rebalances;
- delivery retry is better handled by another driver.

The system must distinguish:

## Before pickup

Reassignment is relatively simple.

## After pickup

Physical custody matters.

Rounds must know:
- who currently possesses the items;
- where the transfer happens;
- who confirms transfer;
- whether photo/signature/item verification is required;
- how fares adjust for network drivers.

No post-pickup reassignment should occur only as a database change without physical custody confirmation.

---

# 47. Delivery completion

A Stop can only become completed when:
- arrival requirement is satisfied/overridden with record;
- handoff outcome is selected;
- required POD is complete;
- required exception conditions are resolved;
- any mandatory recipient/receiver information exists.

Completion creates an immutable delivery event containing the relevant proof and timestamps.

The driver then advances immediately to the next unresolved Stop in the Round.

---

# 48. Round completion

A Round completes when every Stop is in a terminal resolved state.

Possible terminal Stop states include:
- delivered;
- returned;
- cancelled before custody;
- transferred;
- failed and formally closed according to merchant policy.

Round completion should record:
- actual start/end;
- completed Stops;
- unresolved/exception outcomes;
- actual distance/time where available;
- network fare and adjustments;
- performance metrics.

For a network driver, the completed Round creates an earned settlement entry.

---

# 49. Settlement trigger

For network work, completion should feed the settlement ledger.

The ledger must distinguish:
- accepted guaranteed fare;
- approved fare adjustments;
- waiting compensation if applicable;
- cancellation compensation if applicable;
- amount earned;
- business owing the amount;
- payout status.

The driver should not need to trust a disappearing offer card as the only record of what they were promised.

---

# 50. Driver history

The driver should have a durable record of completed work.

For network work, history should show at minimum:
- business;
- date/time;
- Round/delivery reference;
- Stops;
- earned amount;
- settlement status.

For team work, currency may be omitted unless the employer uses per-job compensation.

Operational history can still show:
- deliveries completed;
- on-time performance;
- hours/shift context where relevant.

---

# 51. Preferred-merchant relationship after completion

Every successful network delivery can strengthen a merchant-driver relationship.

A business can:
- mark driver preferred;
- keep driver neutral/used-before;
- block driver;
- add internal notes.

A driver can therefore become part of a merchant's preferred network through actual successful work.

That relationship influences future Broadcast priority inside the active radius.

---

# 52. Reputation principle

Rounds can maintain global reliability signals, but merchant-specific trust should remain important.

Possible global signals:
- completed jobs;
- completion rate;
- no-show/cancellation behavior;
- on-time performance;
- verification level;
- safety/incident status.

Possible merchant-specific signals:
- number of jobs completed for merchant;
- preferred status;
- blocked status;
- pickup familiarity;
- private operational notes.

Rounds should not expose an overly simplistic public score that replaces context.

---

# 53. Background location principle

Location is necessary for:
- distance-based broadcast eligibility;
- live Round position;
- ETA;
- arrival assistance;
- route fit.

Trust rule:

**Rounds should track a driver's operational location only while the driver is actively working/available under an authorized mode.**

When the driver is fully unavailable/off duty and has no active work, background operational tracking should stop.

Exact technical implementation belongs in the technical spec.

---

# 54. Offline behavior principle

A delivery product must survive poor connectivity.

The driver should still be able to perform critical already-accepted work when the connection degrades.

At minimum the eventual technical system must support offline-safe handling for:
- accepted Round information;
- current Stop data;
- arrival event;
- pickup confirmation;
- POD photo capture;
- signature/name capture;
- Stop completion queue;
- issue creation;
- later synchronization.

The UX should clearly distinguish “saved on device / syncing” from actual failure.

Exact offline architecture is deferred to the technical spec.

---

# 55. Notifications and attention

Rounds uses notifications to surface time-sensitive work and changes.

Important notification events include:
- new network Offer;
- team Assignment;
- Round updated;
- Stop added proposal;
- merchant cancellation;
- address update;
- dispatch message;
- issue resolution;
- network-driver settlement update.

Notifications should lead the driver directly to the relevant active state, not merely open a generic home screen.

---

# 56. Driver safety and interaction principle

The driver app is frequently used in bright daylight and around active road travel.

Therefore future UX must optimize for:
- minimal reading while moving;
- large, unmistakable current action;
- strong hierarchy;
- limited simultaneous decisions;
- no requirement to type while riding;
- no dense settings or secondary data on the active road surface;
- voice/navigation support where useful;
- richer details available when stationary.

This is a behavioral requirement, not a styling specification.

---

# 57. Business-side Broadcast states

The business should be able to understand what is happening without becoming a full-time dispatcher.

A Broadcast should move through clear states such as:

- evaluating own capacity;
- ready to broadcast;
- preferred drivers within 3 km;
- open network within 3 km;
- expanded radius;
- driver accepted;
- driver approaching pickup;
- no driver accepted;
- cancelled;
- externally fulfilled if merchant chooses fallback.

The business should not need to interpret raw driver-status rows.

---

# 58. Business visibility during active Broadcast

Useful operational information includes:
- current wave;
- active radius;
- preferred vs open network stage;
- number of eligible drivers;
- number notified;
- viewed/responded counts where useful;
- accepted driver;
- driver distance/ETA after acceptance;
- current offered fare;
- Round scope;
- next automatic action.

The business should be able to intervene by:
- stop Broadcast;
- increase fare;
- expand radius;
- split Round;
- assign own driver;
- choose external courier;
- cancel work.

---

# 59. Automation without a dedicated dispatcher

A small merchant should be able to configure rules so Broadcast progresses automatically.

Example operating rule:

1. Check own drivers.
2. If no safe own fit, broadcast to preferred drivers within 3 km.
3. If unfilled, open to all network drivers within 3 km.
4. Expand to 5 km.
5. If still unfilled, alert merchant with recommended next action.

A small restaurant employee should not need to sit and click each wave manually.

A larger operation can choose more manual control.

---

# 60. Product behavior that is intentionally NOT locked yet

The following should be decided after UX exploration and pilot learning:

- exact visual hierarchy;
- exact navigation layout;
- whether arrival uses tap, hold, slide, or another action;
- exact Offer expiration duration;
- exact timing between Broadcast waves;
- exact maximum default radius;
- whether preferred drivers remain eligible while the open 3 km wave starts;
- exact fare suggestion algorithm;
- whether drivers can freely reorder Stops in V1;
- which POD policies are default by category;
- whether native phone, masked calling, or VoIP ships first;
- exact waiting compensation policy;
- exact cancellation compensation policy;
- exact reputation weighting;
- exact route-optimization engine;
- exact third-party courier fallback integration.

These are implementation/UX/pilot decisions, not missing concepts.

---

# 61. V1 behavioral acceptance criteria

The initial product is behaviorally complete when the following can happen end-to-end.

## Scenario A — Own-driver multi-stop Round

1. UrbanFlowers has four deliveries ready.
2. Rounds groups them into a Round.
3. An own driver is assigned.
4. Driver arrives at UrbanFlowers.
5. Driver verifies pickup.
6. Driver completes all four Stops in sequence.
7. Each Stop has required POD.
8. Dispatch sees live state.
9. Round completes.

## Scenario B — Preferred-driver Broadcast

1. Own fleet cannot absorb a Delivery/Round.
2. Rounds identifies preferred eligible drivers within 3 km.
3. Offer is sent.
4. One preferred driver accepts.
5. Driver sees guaranteed fare and Round scope.
6. Driver completes pickup and delivery.
7. Merchant can mark/reuse the driver relationship.
8. Settlement entry is created.

## Scenario C — Open-network expansion

1. No preferred driver inside 3 km accepts.
2. Offer opens to all qualified network drivers within 3 km.
3. If still unfilled, radius expands according to rules.
4. One driver accepts.
5. Other offers close cleanly.
6. Driver completes the work.

## Scenario D — Broadcast failure

1. All configured waves fail.
2. Merchant sees clear failure state.
3. Merchant can increase fare, expand radius, split Round, assign internally, or use external courier.
4. No hidden automatic behavior occurs unless merchant configured it.

## Scenario E — Customer not answering

1. Driver arrives at Dropoff.
2. Contact attempts are recorded.
3. Driver selects Customer not answering.
4. Merchant policy provides next action.
5. Driver follows instruction without inventing an ad-hoc solution.
6. Stop resolves or remains formally pending.

## Scenario F — Adaptive POD

1. Driver arrives.
2. Selects handoff type.
3. Required POD fields change according to merchant policy and handoff.
4. Completion is blocked until required evidence exists.
5. POD is attached to the Stop record.

## Scenario G — Live Stop insertion

1. A new order becomes ready while an own driver is on a Round.
2. Rounds evaluates insertion impact.
3. System shows whether promises remain safe.
4. Dispatch inserts the Stop.
5. Driver receives updated Round.
6. Existing Stop state remains intact.

## Scenario H — Network add-stop proposal

1. Network driver is already on an accepted Round.
2. New Stop fits the route.
3. Rounds calculates additional fare/time/distance.
4. Driver receives an explicit proposal.
5. Driver accepts or declines.
6. Existing accepted work is preserved either way.

---

# 62. The golden loop to design first

The first UX work should focus only on the critical operating loop.

## Business side

1. Delivery/Round ready.
2. Own-capacity result.
3. Broadcast starts.
4. Broadcast wave expands.
5. Driver accepts.
6. Driver approaching pickup.

## Driver side

1. Available / working state.
2. Incoming network Offer OR team Assignment.
3. Accepted/assigned — go to pickup.
4. Arrived at pickup.
5. Pickup verified.
6. Active multi-stop Round.
7. Arrived at Dropoff.
8. Adaptive POD.
9. Stop complete / next Stop.
10. Round complete.

The UX should prove this loop before profile, settings, detailed earnings, or sophisticated onboarding receives design attention.

---

# 63. Source ideas preserved from the April work

The April prototypes/specs contained several operational concepts that remain valid and are intentionally preserved here while their visual design is discarded:

- explicit arrival state rather than GPS-only assumption;
- soft geofence warning/override for inaccurate GPS;
- itemized pickup verification with generic fallback;
- multi-stop current/remaining Stop model;
- Team Assignment versus network Offer distinction;
- guaranteed fare visibility for network work;
- adaptive POD based on handoff;
- photo evidence;
- conditional signature;
- received-by name for alternate receiver;
- automatic call/contact history as delivery evidence;
- structured issue paths;
- multi-order Broadcast as one grouped route;
- expanding Broadcast waves;
- individual recipient states such as notified/accepted/declined/timeout;
- atomic winner behavior when multiple drivers receive the same Offer;
- offline-safe delivery state as a production requirement.

The April visual language, layouts, color system, role styling, screen count, and interaction conventions are **not** part of this specification.

---

# 64. Non-negotiable operating principles

1. **Multi-stop is fundamental in V1.**
2. **Round is a first-class object.**
3. **Distance first, relationship second.**
4. **Preferred/known drivers within 3 km receive the first external Broadcast.**
5. **If unfilled, all qualified Rounds drivers within the same 3 km radius are next.**
6. **Radius then expands according to merchant/network rules.**
7. **Own capacity is checked before external network capacity.**
8. **Team work is an Assignment; network work is an Offer.**
9. **Network drivers see guaranteed fare before accepting.**
10. **Only one driver wins a normal Broadcasted Round/Delivery.**
11. **A network driver's accepted scope cannot be materially changed without explicit consent and fare clarity.**
12. **Arrival is an explicit operational event.**
13. **Pickup is verified before delivery begins.**
14. **POD adapts to merchant policy and handoff type.**
15. **Required proof blocks completion until satisfied.**
16. **Failure is a structured workflow, not a free-text afterthought.**
17. **Buyer and recipient can be separate parties.**
18. **Contact attempts can become part of delivery evidence.**
19. **Post-pickup reassignment must account for physical custody.**
20. **Broadcast failure is shown honestly with next actions.**
21. **Automatic external-courier fallback only happens if the merchant explicitly configures it.**
22. **Rounds should be able to insert live work into active Rounds when operationally safe.**
23. **Driver safety and glanceability outrank decorative UI during active road use.**
24. **Critical accepted work must be able to survive poor connectivity.**
25. **This specification defines behavior; visual UX is controlled by the
    canonical Operations artifact, Driver boards and their visual
    constitutions.**

---

# 65. Implementation sequence

The canonical UX and Engineering Build Specs now exist. Active implementation
scope is controlled by `CODEX-BUILD-ORDER.md`, the Implementation Scope Ladder
and the Implementation Coverage and Gap Control. This product-complete Network
model does not authorize implementation of later slices.

Design the Business Broadcast and Driver execution states together so both sides of the same event remain coherent.

After the golden loop is working visually and behaviorally, expand into:

1. Full multi-stop and live Round changes;
2. POD + exception UX;
3. Driver earnings/settlement/history;
4. Team / merchant-linked / open-network onboarding;
5. Business dashboard depth;
6. Technical architecture and implementation specification.

---

# 66. One-sentence operating definition

**Rounds continuously turns delivery demand into efficient driver Rounds, using own capacity first and then distance-gated preferred and open network capacity, while verifying every pickup, handoff, proof, exception, and live change from ready-to-deliver through completion.**

---

---

# 67. Wrong Address, Site Access & Learned Location

**Canonical detailed spec:** `ROUNDS-SPEC-4-MAPPING-ADDRESS-INTELLIGENCE-v1.8.md`

This extends §33 Wrong address / cannot locate.

## Required behavior

On wrong-address/cannot-locate:

1. preserve the original address;
2. record current driver GPS;
3. search known merchant location knowledge;
4. resolve/search provider data;
5. present proposed correction;
6. show impact on route/time/fare;
7. obtain buyer/recipient/merchant confirmation according to policy;
8. obtain Network driver consent if material accepted scope changes;
9. save correction as an observation;
10. promote to learned knowledge only with sufficient evidence.

## Driver evidence

Driver may confirm separately:

- vehicle stopped here;
- building entrance here;
- handoff here.

One driver's correction is evidence, not instant truth.

## Successful deliveries

Successful POD can reinforce existing knowledge when arrival/handoff evidence is compatible.

## Street/Satellite/3D

Dispatcher may use site inspection modes during exceptions. Street imagery availability is optional and cannot block resolution.

---

# 68. Traffic-aware Operating Decisions

**Canonical mapping rules:** `ROUNDS-SPEC-4-MAPPING-ADDRESS-INTELLIGENCE-v1.8.md`

Traffic is part of route safety.

Before own-Round insertion, Network progression, or a material live-route change, Rounds may consider:

- current traffic-aware route time;
- typical route time;
- traffic delta;
- predicted completion time for remaining Stops;
- promised-window risk;
- driver shift boundary.

Traffic by itself does not create Action. A decision-changing consequence does.

Examples:

- `+12 min · all promises safe` → continue automatically when within authority.
- `+12 min · #10421 likely 8 min late` → Action or automated re-optimization according to merchant authority.

For accepted Network work, traffic does not authorize Rounds to silently change economic scope. Existing material-change/consent rules still apply.

---

# 69. Weather, ETA and Communication During Live Operation

## Weather-aware operation

Broadcast/assignment safety checks may include weather when it changes:

- vehicle suitability;
- ETA/promise safety;
- handling risk;
- driver safety policy.

Weather never replaces the core distance → relationship → eligibility matching order unless a vehicle/safety rule makes a candidate ineligible.

## Communication

Dispatcher-to-driver chat/call is available throughout active work.

For accepted Network work, communication does not authorize a material scope change by itself. Scope/compensation consent rules still apply.

## ETA

Rounds ETA may include current traffic plus a separately explainable weather/handling buffer. Avoid double counting.

---

# 70. Route Mutation & Driver Contact

**Controlling detailed spec:** `ROUNDS-SPEC-6-DISPATCH-ROUTE-EDITING-COMMS-v1.11.md`

Own-fleet future Stop reordering may be direct.

Accepted Network Round material scope remains protected: reordering existing accepted Stops may be permitted only if it does not materially alter promised scope; adding/moving work into the Round follows the existing add-Stop proposal/consent rules.

Direct driver communication is available only once a driver has an operational relationship to the delivery/Round. Unassigned Broadcast candidates are not a general-purpose chat list.

---

# 71. External Capacity after Network

**Dedicated provider spec:** `ROUNDS-SPEC-7-EXTERNAL-COURIERS-v1.4.md`

The original non-negotiable remains:

**Rounds Network failure must never trigger a hidden third-party courier fallback.**

However, an explicit External Courier layer is now supported.

Canonical sequence:

```text
Own fleet
→ Rounds Network
→ External courier, if merchant policy allows
```

## Manual default

Default merchant rule:

```text
External courier authority = Ask before booking
```

After Network is exhausted, Action may show:

```text
External capacity available
Lalamove · Car
฿226
Pickup ~12 min
Promise safe
Use Lalamove
```

No retyping is required.

## Optional automatic authority

Merchant may explicitly configure:

```text
Own capacity unsafe
AND Rounds Network exhausted
AND promise at risk / capacity still uncovered
AND provider quote <= merchant fare limit
AND vehicle/handling requirement passes
→ external booking may execute automatically
```

Automatic external booking must create a clear audit event.

## Driver/network distinction

An external provider driver is **not** converted into a Rounds Network driver merely because they appear on the map.

Relationship remains:

```text
fulfillment_source = external
provider = lalamove
```

## Material changes

External provider booking changes must respect the provider's supported modification/cancellation semantics.

Rounds must not imply that Network-driver consent rules automatically apply to third-party providers; provider contract/API behavior controls the external booking.

---

# 72. Vehicle/Cargo Eligibility Contract

Rounds Network driver eligibility must use the merchant's current physical Round rules.

Before a Network driver is shown or notified, Rounds checks:

```text
accepted vehicle type/profile compatibility
cargo classes and quantities
maximum Stops on the offered Round
mixed-load restrictions
handling requirements
time-window feasibility
```

A driver is not eligible merely because their vehicle category name appears to match.

Example:

```text
Offer:
2 flower Stops
Motorbike + box compatible

Driver:
Motorbike without required delivery box

→ not eligible
```

The offered payout/boost applies to a defined physical Round scope. If cargo or Stop scope materially changes after acceptance, existing Network consent rules continue to apply.

---

# 73. Published Availability and Pre-Job Merchant Contact

**Controlling detailed spec:** `ROUNDS-SPEC-10-DRIVERS-LIVE-AVAILABILITY-CONTACT-v1.4.md`

This section defines how driver availability participates in Broadcast
eligibility and how merchant contact works before a Network job has been
accepted.

## Published Network availability

`Open for jobs` is a driver-controlled Network availability state. It is distinct from:

- network eligibility/verification;
- team-shift state;
- device presence/connection freshness;
- current accepted work;
- merchant relationship.

A driver may be eligible for the Network but not currently open for jobs.

A driver may also remain open for future work while completing accepted work when matching rules can project a realistic next-available time and no accepted-scope rule is violated.

Canonical merchant-facing states include:

- `Open for jobs`;
- `Open for jobs · available after HH:MM`;
- `On a Round` / accepted work active;
- `Not accepting jobs`;
- `Offline` / stale presence.

## Broadcast eligibility

A Network Offer requires current eligibility **and** a compatible availability state.

A driver who is not open for jobs must not receive new open-network Offers merely because the driver is nearby.

Team drivers follow employer/team policy while on shift. Open-network offers are normally suppressed during active team work unless the employer relationship and driver settings explicitly permit them.

## Pre-job contact boundary

The existing rule remains: **unassigned Broadcast candidates are not a general-purpose chat list.**

The only pre-job exception is an established merchant-driver relationship:

- a preferred/known driver may receive a structured `Ask availability` request;
- direct relationship messaging is allowed only when the driver has opted into direct merchant contact;
- an unknown open-network candidate receives the Offer/Broadcast, not casual merchant chat.

An availability request is not an accepted job, does not reserve the driver, and does not create delivery custody/scope.

## Acceptance transition

Once a Network driver accepts merchant work:

- the accepted delivery/Round becomes the operational relationship for that work;
- normal dispatcher-to-driver Message / Call / Voice note becomes available in the job-linked thread;
- accepted-scope and compensation-consent protections continue to apply.

## Visibility and privacy

Matching may use exact GPS internally. Before acceptance, merchant-facing visibility for unknown Network supply should use approximate distance/area and operational suitability rather than unrestricted exact driver coordinates.

## Performance treatment

A driver being offline, not open for jobs, or simply unavailable is not a negative reliability event.

Performance evidence begins at meaningful commitments: Offer response/acceptance, accepted-job cancellation/no-show, pickup/delivery execution, custody/POD and incidents.

# 74. Network Supply Visibility Before Broadcast

**Version:** 1.9  
**Date:** 30 August 2026

## Supply is informative, not accepted work

Before a Broadcast begins, Operations may optionally view nearby Network supply on the Live map.

- `Open for jobs` means a driver is currently willing to receive relevant Network work; it does not reserve that driver.
- `Busy` may expose an approximate next-available signal without exposing the other merchant or their job.
- Unknown open drivers are still reached through Offer/Broadcast, not arbitrary direct chat.
- Known/preferred direct-contact rules continue to follow the Drivers Live Availability & Contact contract.
- Broadcast ranking may use the same underlying availability/presence signals, but the visual supply layer does not itself change matching priority or create acceptance.

## Privacy and accepted-work transition

Pre-acceptance supply positions are generalized. When a Network driver accepts this merchant's work, the driver leaves the anonymous/generalized supply representation for that job and enters the normal accepted-work Round/tracking/communication contract.

*End of ROUNDS — SPEC 3 · Driver + Broadcast Operating Model*
