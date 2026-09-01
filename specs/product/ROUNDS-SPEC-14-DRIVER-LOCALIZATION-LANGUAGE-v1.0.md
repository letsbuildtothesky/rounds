# Rounds · Driver Localization & Language Specification

**Version:** 1.0  
**Date:** 2026-09-01  
**Status:** Canonical product specification  
**Scope:** Driver App localization, Thailand launch, language selection, notification/navigation locale behavior

## 1. Product decision

Rounds Driver launches as a **Thai-first bilingual app** in Thailand.

Initial locales:

- `th-TH` — primary Thailand locale;
- `en` — first-class secondary locale.

Production uses **one application and one behavior/state implementation**. Separate EN/TH HTML board folders are design/QA artifacts only.

## 2. First-run language flow

Canonical entry:

`A01 Splash → A01B Choose Language → A02–A05 Entry Flow`

Rules:

- language is selected before onboarding content;
- Thailand presents Thai prominently/first;
- English is always available;
- onboarding inherits the selected locale;
- do not repeat an EN/TH switch in every onboarding header;
- choice can be changed later without restarting onboarding/account identity.

## 3. Settings

Canonical path:

`L01 Profile → Language → ไทย / English`

Changing language:

- applies UI copy immediately or at the nearest safe screen transition;
- does not change driver role, merchant relationship, Network availability, assignment or permissions;
- does not clear active Round/navigation/outbox/drafts;
- does not mutate server state enums or audit semantics.

## 4. Persistence model

The preference must work before and after auth.

Product requirement:

- local preference exists before login for first-run/onboarding;
- authenticated driver profile stores `preferred_locale` for cross-device persistence;
- local preference remains available offline;
- profile sync is conflict-safe and never blocks active work.

Exact storage implementation belongs to Build Specs.

## 5. Translation architecture

- UI strings use stable translation keys.
- Domain enums/events/API fields remain language-neutral.
- Do not store translated copies of domain truth merely for display.
- System event copy can be localized at presentation/delivery time.
- Merchant/recipient free text is preserved as entered.
- Future machine translation, if added, must be an explicit feature and must preserve original text.

## 6. Thai UX quality

Thai is not a mechanical string replacement.

QA must check:

- natural Thai phrasing for riders;
- Thai line breaking and line height;
- long labels in buttons/sheets;
- 320 px phone width;
- lower-cost Android typography/rendering;
- accessibility/tap target preservation;
- Thai recipient names and addresses;
- Thai exception/POD notes;
- mixed Thai/English order/product names;
- numeric, date and time conventions.

Critical type must not be shrunk below Driver UI Constitution minimums just to force translation into an English-sized box.

## 7. Navigation language

Embedded navigation follows the Driver's effective app/navigation locale where supported.

Phase 0 must explicitly test:

- Thai spoken guidance;
- Thai maneuver/road labels where provided by Google;
- switching EN ↔ TH between runs;
- whether locale changes require navigation-session restart and how that is handled safely.

Navigation vendor content and Rounds chrome may have different localization mechanisms; the UX must still read as one coherent experience.

## 8. Notifications

Driver push/local notification content should use the driver's preferred locale when the system knows it.

Push is a wake-up/attention channel, not state truth. Opening a notification must fetch authoritative domain state.

## 9. Operations interoperability

Operations may launch English-first, but must:

- render Thai driver names/content safely;
- render Thai addresses/notes without corruption;
- preserve original Thai text in evidence/history;
- never assume driver-language UI copy is the persisted domain value.

## 10. Board contract

The canonical 2026-09-01 English board set defines screen IDs/behavior/layout hierarchy. The Thai design pass must preserve one-to-one:

- screen ID;
- action count and meaning;
- state transitions;
- evidence requirements;
- role/permission boundaries;
- exception/custody semantics.

Thai may reflow height/line breaks to remain natural and readable.

## 11. Acceptance criteria

- first run can choose Thai/English before onboarding;
- Thai is treated as primary Thailand locale;
- Profile can change language later;
- preference survives relaunch/offline/auth transition;
- active work is not reset by language change;
- all field-critical V1 screens have complete Thai translations before pilot;
- no critical 320 px overflow/clipping;
- Thai Navigation voice is field-tested;
- one production codebase serves both locales.
