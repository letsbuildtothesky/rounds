# P14 — Approved UX Driver Coverage and Localization

Rounds specification set · Consolidated V2.3 · 8 September 2026

Feature scope: WS; DR-01–12; complete current visual reference. Database ownership: .

Authority: this document defines the product workflow. Machine contracts in contracts/ define exact payloads, states and transitions; decisions/ records deliberate defaults and exclusions. All mutations use authenticated scoped authority, required versions, idempotency and an audit trail. Approved current screens remain the visual reference; sample data is not a tenant default.

## Approved visual baseline

Dispatch Phase 39 is the approved operator reference; Driver Refresh 26 is the cumulative app reference. Preserve spacious white surfaces, dark readable type and restrained #1754A6 blue for identity/actions/selection, with #FF6420 orange accent and semantic issue/success colors. Do not recolor all routes/statuses blue or add decorative banners that consume map/task space. The original wordmark geometry remains; driver-square versus Dispatch-dot discrepancy is an explicit review decision, not silently changed here.

Operator header, City/Intercity scope, Now/Plan delivery rail, map/timeline, fleet and contextual drawers remain coherent. Driver marker opens direct actions/chat; global inbox is secondary. Delivery card priority shows the actionable issue and real next step. Sidebar filters/counts are readable and date/city-consistent. Timeline retains drag plus keyboard/touch move alternative. Full map focus can return to prior workspace without losing selected work or drafts.

## All canonical Driver tasks

The 47-file task inventory and 25 paired presentations plus an index (historical reference in the Complete v1 archive) is the complete source index. A file may contain several screens/sheets/variants. Production review selectors such as Accepted sample, Connected sample or Save succeeded preview must not ship as app controls. Dynamic execution is parameterized by actual job/stop IDs; fixed sample Stop 1 cannot be used as a router for every delivery.

A entry covers splash/language/phone/OTP/role/invite, profiles, vehicle, ID/face/payout and correction. B covers shift and Network availability/verification states. C shows single/multistop offers and all race/expiry/unknown outcomes. D/E cover arrival/pickup/current work and versioned changes. F/I cover handoff/evidence/next work/completion. G contains typed issues and emergency. H communications, J work history, K hours/earnings, L profile, M notifications and N permissions/offline/GPS all retain their function. Intercity transport/receiver tasks extend this set explicitly under P08.

Remaining original designs: A02–A05 and E04–E06. Required targeted completion includes incoming calls, pickup waiting, proof recovery journey, post-pickup cancellation/return and latest-version ack/consent. P05/P07/P09 define their behavior; designs must reuse approved components and prioritize task clarity. Optional location observations stay optional, not another required completion page.

## Localization

One Flutter application with language-neutral IDs/enums and externalized strings. Thailand defaults Thai-first but respects a valid stored English preference. Select+Continue commits first-run choice; Profile changes preference without changing work/permissions/outbox. Local device preference is available before auth and synchronizes after auth under documented conflict rule (proposed latest explicit user choice wins). Merchant/recipient free text is preserved, not silently translated. Error, push, help, permission and recovery copy need complete Thai/English coverage, not just happy-path headings.

Thai shaping/line breaks, Unicode input/composition, dates/currency and names/addresses are first-class. Do not shrink critical text to force layout. Short screens scroll content with safe-area pinned actions; keyboard resizes usable content. Driver copy is concise and task-oriented, without explaining actions already clear from the visible state.

## Responsive and accessibility acceptance

Operator target: laptop/desktop plus iPad portrait/landscape; Driver App: phones including low-cost Android. Test 320px narrow driver layout, enlarged system text, screen readers, keyboard focus, modal focus trap/return and touch targets with real device input. Do not copy driver 64–68px action sizes to every operator table control. Routes and instructions remain usable while sheets/dialogs open; map controls cannot collide with attribution or OS safe areas.

Prefer labeled icon actions or accessible names and visible focus. Color never carries state alone. No critical interaction requires hover; Map focus/review/drag alternatives work on iPad. Reduced motion preserves meaning without animated delays. Face scanning motion responds to actual provider lifecycle in production, never a timer claiming verification. Splash never automatically authenticates or advances into work.

## Responsive workstation behavior

Check 1366×768, 1180×820, 1024×768, 820×1180 and 768×1024. Keep Dispatch, Drivers, History and Settings directly accessible. Compress gaps and rail width before reducing legibility. On portrait iPad a compact navigation row may preserve all destinations; do not convert the entire dispatch workstation into a phone-style stack.

Details overlay the map rather than creating an unreadable third column. Keep focus-map available. Plan has sticky driver/vehicle/shift labels and local horizontal scrolling; resizing works with touch. Reconcile map dimensions and floating-chat bounds after rotation. No document-wide horizontal overflow; local timeline/table scrolling is intentional. Keep current approved typography and restrained blue branding; old color tokens do not override the current design.

## Loading, quiet, stale and recovery behavior

Distinguish loading, true empty, filtered no-match, operator browser offline, stale last-known state, failed dependency, domain failure and recovering. Do not display zero/All clear before truth is loaded. Operator connectivity does not establish driver presence or provider health.

Map failure stays in the map area; delivery list, planning and navigation remain usable, with actual Retry. Keep cached map context labelled last-known where available. Never draw decorative fake live movement. Quiet Plan has a non-primary disabled Generate action; no-match offers Clear search/filters without erasing real surrounding metrics.

Offline operator coordination actions are blocked honestly while drafts/attachments remain. Do not emit fake sent/call/broadcast events. Existing server workflows may continue. On reconnect reconcile current facts before restoring live labels or replaying any permitted idempotent action. Use one compact service-state strip; no permanent debug footer consuming board area.

## Completion criteria

Approve complete journeys for Team and freelance, in both languages, including offline/unknown/permission errors and real navigation/camera/mic/dialer return. Static HTML/syntax checks are useful but not phone QA or service integration. Maintain a screen-to-command-to-state checklist; no design-complete label substitutes for those acceptance results.

### QA-V21-IPAD-ROTATION

Actor: OH.

Given: Plan open with chat at 1024×768.

When: Rotate to768×1024; scroll timeline and open driver actions.

Then: All four primary nav destinations reachable; no page overflow; sticky driver labels and map dimensions reconcile.

Status: written requirement; application execution pending.
