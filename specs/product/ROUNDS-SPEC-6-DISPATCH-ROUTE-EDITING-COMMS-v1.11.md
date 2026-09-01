# Rounds · Dispatch Route Editing & Driver Communications Specification

**Version:** 1.11
**Status:** Canonical controlling specification  
**Scope:** Dispatcher web UX, Driver app communication contract, Realtime, VoIP, route-edit interaction  
**UX reference:** `rounds-edge-states-v45.html` (inherits current Dispatch/communications behavior from the canonical Operations build)

---

# 1. Product principle

Dispatch has two different jobs:

1. **Operate the delivery** — route, Stop, capacity, ETA, exception, custody, promise risk.
2. **Talk to the human doing the work** — message, voice note, call, presence, unread replies.

These must not be collapsed into one drawer.

Canonical separation:

```text
Round / Order drawer = operate the delivery
Communications widget = talk to the driver
```

On desktop, both may remain visible at the same time.

On iPad/smaller operational widths, opening Communications may replace/close the right contextual drawer rather than squeeze two side panels onto the screen.

---

# 2. Route editing — own fleet

## 2.1 Editable scope

Only Stops that are all of the following may be reordered directly:

- future;
- not a pickup/custody Stop;
- on an own-fleet Round;
- not already completed/current;
- not protected by external-driver accepted scope.

Delivered Stops are immutable.

The current Stop is immutable.

Pickup/custody Stops are immutable.

## 2.2 Desktop drag behavior

The entire Stop row is **not draggable**.

Drag begins only from the dedicated drag handle.

Reason:

- prevents accidental movement while selecting a Stop;
- makes tablet/mouse behavior predictable;
- separates open/select from reorder.

Implementation identity must use a stable `stop_id`, never a transient array index.

## 2.3 Drop targets

While dragging:

- display explicit insertion zones between movable future Stops;
- insertion line visibly activates on hover/dragover;
- label may say `Drop here` during drag;
- invalid positions do not accept drop.

A reorder operation is therefore:

```text
source_stop_id
round_id
insert_before_stop_id | END
```

not:

```text
source_array_index → target_array_index
```

## 2.4 iPad / touch

Tap a future Stop to reveal:

- Move up;
- Move down;
- Move to another Round.

These actions must call the same canonical reorder logic as desktop drag.

Long-press is reserved for driver/map quick-contact, not Stop reorder.

## 2.5 After reorder

After a reorder:

1. persist new sequence;
2. recalculate route geometry;
3. recalculate ETA of affected future Stops;
4. recalculate Round distance/duration;
5. recalculate delivery-window risk;
6. recalculate traffic/weather impact if relevant;
7. refresh map route;
8. refresh Round drawer;
9. emit audit event.

The demo may use simplified calculations; production must use the routing/ETA engine.

Recommended event:

```text
round_stop_sequence_changed
```

with:

```json
{
  "round_id": "...",
  "moved_stop_id": "...",
  "previous_sequence": [],
  "new_sequence": [],
  "actor_user_id": "..."
}
```

---

# 3. Route editing — Network / external drivers

Accepted Network work is economically protected.

Do not directly drag a new/material Stop into an accepted Network Round.

A material change is a proposal containing at minimum:

- added Stop(s);
- added distance;
- added expected time;
- fare change;
- revised ending area if material;
- revised promise risk.

Driver must accept according to the Network operating model before scope changes.

External courier routes follow provider capability and contract rules; Rounds must never imply that it can reorder provider work if the external provider does not permit it.

---

# 4. Driver contact from the map

## 4.1 Primary click / tap

Click or tap a driver marker opens a **compact driver action popover** anchored to that driver.

This is the normal interaction on desktop and touch. No critical action may require right-click.

Popover shows at minimum:

```text
Driver name
Driver type · active Round
Presence / communication state

Message
Call
Voice note
Open Round
Center on map
```

Selecting the driver may also highlight the driver's active Round on the map, but it does not force-open the Round drawer.

## 4.2 Power-user shortcuts

Desktop right-click may open the same driver action popover as a shortcut.

Touch long-press may also open the same popover, but normal tap must already provide full access.

Right-click/long-press are enhancements, never required interactions.

## 4.3 Quick-contact actions

For an active assigned driver:

- Message driver;
- Call driver;
- Voice note;
- Center on driver / active Round;
- Open Round.

Do not place these as permanent large controls on the map.

## 4.4 Driver type language

The contact surface must identify:

- Own driver;
- Rounds Network driver;
- External courier driver where applicable.

Visual treatment differs by type, but communication behavior remains conceptually consistent where the relationship permits messaging/calling.

Do not permit direct messaging to an unassigned Network candidate merely because they are visible in a Broadcast search.

---

# 5. Persistent Communications widget

## 5.1 Desktop

Communications opens as a persistent compact window over the map.

It does **not** replace the Round/Order drawer.

User may:

- continue inspecting the map;
- open another Stop/Round;
- keep the driver thread visible;
- minimize the thread;
- reopen instantly.

### Active conversation tray

Minimizing a conversation does not close it. It becomes a persistent chip in the **conversation tray at the bottom of the map**.

Rules:

- multiple driver conversations may remain active/minimized;
- only one full communications window is expanded at a time;
- switching tray chips swaps the expanded conversation without losing state;
- `−` means keep conversation active/minimized;
- `×` means remove the conversation from the active tray;
- show approximately four conversations before collapsing additional threads behind an overflow count such as `+3`;
- incoming replies never force-open a different conversation.

A tray chip can show:

- driver initials/name;
- unread count;
- voice-message indicator;
- incoming/active call indicator;
- missed-call indicator.

## 5.2 iPad / smaller widths

At constrained operational widths, Communications becomes a bottom/overlay surface.

It may close the right drawer when opened.

This is intentional and preserves the existing Rounds rule against squeezing multiple permanent side panels onto iPad.

## 5.3 Header

Show:

- driver identity;
- driver type;
- current Round/delivery;
- presence state;
- Call action;
- Minimize;
- Close.

Presence states:

```text
Online
Typing…
Last seen …
Offline
On call
```

---

# 6. Messages

Messages are attached to delivery context and tenant-scoped.

Canonical message types:

```text
text
voice
image
file
location
url_card
system
```

Existing Driver Master schema remains valid.

## 6.1 Message bubbles

Human messages use conversational bubbles.

System events are visually quieter and centered/neutral.

Do not render system log rows as if they are human messages.

Each human message can show:

- time;
- sent/delivered/read state.

## 6.2 Composer

Canonical composer:

```text
[ Mic ] [ Message…                    ] [ Send ]
```

Mic is first-class and immediately visible.

Enter sends.

Shift+Enter adds a line break on desktop.

---

# 7. Voice notes

Voice notes are first-class because driver/dispatcher work is frequently faster by voice.

## 7.1 Recording UX

Tap/hold or tap-to-record according to final implementation platform.

While recording show:

- live timer;
- waveform/activity visualization;
- Stop action.

After recording show preview:

- Play;
- waveform;
- duration;
- Delete;
- Send voice.

Never auto-send immediately when recording stops.

## 7.2 Storage

Use the existing Rounds voice-note storage/message architecture.

Production:

- media captured locally;
- uploaded to Rounds storage;
- message references storage object;
- offline queue applies;
- sync on reconnect.

---

# 8. Realtime and unread behavior

The dispatcher must be able to work elsewhere and still notice a reply.

If a driver responds while Communications is minimized/closed:

- increment unread count;
- ensure that driver's conversation remains in the bottom conversation tray;
- update the driver's **map marker** with unread/message state;
- update the top-bar communication badge;
- optionally show a brief incoming-message toast;
- do not steal keyboard focus or open the full thread automatically.

Communication state must be synchronized across:

```text
map driver marker
conversation tray
top communications icon
```

Opening/reading the thread clears that thread's unread state everywhere.

Map marker states may include:

- unread message count;
- voice message waiting;
- incoming call;
- active call;
- missed call.

Do not show low-value states such as `Typing…` on the map.

Recommended Realtime subscription scope:

```text
account_id + delivery/order/thread
```

No cross-tenant events.

---

# 9. Driver calling

Driver ↔ dispatcher calling remains in-app VoIP according to the existing Phase 5 architecture.

The call does not need to take over the entire Dispatch screen.

## 9.1 Compact call surface

Inside Communications show a **compact** call state rather than a full-height call takeover:

```text
Driver name · Round
On call · 00:42
Mute · Speaker · End
```

The Communications window should shrink vertically during the call so the operator can see more of the map while speaking.

Map and delivery context remain available.

## 9.1.1 Incoming driver call

A driver calling Dispatch must be visible immediately without requiring the dispatcher to open a chat:

- driver's map marker pulses/rings;
- map marker displays phone state;
- bottom tray shows `Calling…`;
- top communications icon indicates live call activity;
- a small map-overlay call card shows **Answer / Decline**.

If unanswered/expired, convert the state to **missed call** and leave that signal on the driver marker/tray until acknowledged.

Answering opens/activates the existing driver conversation and transitions it into the compact call state.

## 9.2 Call lifecycle

```text
connecting
ringing (when implementation supports it)
on_call
ended
failed
```

## 9.3 History

On end, append call record to delivery/contact history:

- driver;
- start/end;
- duration;
- outcome;
- delivery/order reference;
- dispatcher actor.

Also add a quiet system message to the communication thread.

---

# 10. Customer/sender calls are different

Do not confuse dispatcher↔driver VoIP with driver/dispatcher calls to sender or recipient.

The existing native-dialer/privacy rule for customer calls remains controlling until a later masked-calling spec explicitly replaces it.

---

# 11. Keyboard / interaction rules

Desktop:

- Click/tap driver → driver action popover;
- Right-click driver → optional shortcut to the same popover;
- Enter → send message;
- Shift+Enter → newline;
- Esc → close contact menu first, then contextual surface as applicable.

Critical actions must have tap alternatives.

No critical workflow may depend on hover.

---

# 12. Map context while communicating

Communications must not visually sever the operator from the driver.

When a thread opens, the dispatcher can still:

- center on driver;
- highlight active Round;
- inspect traffic/weather;
- inspect selected Stop;
- keep route decision drawer visible on desktop.

This is why Communications is a separate widget.

---

# 13. Data / backend additions

Existing `messages` schema remains the base.

Recommended thread abstraction:

```sql
create table communication_threads (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id),
  order_id uuid references orders(id),
  round_id uuid,
  driver_id uuid references drivers(id),
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

If messages remain order-scoped in V1, a separate thread table may be deferred, but the API should expose a thread abstraction so the dispatcher UX is not coupled to database layout.

Recommended dispatcher read-state table:

```sql
create table communication_read_state (
  account_id uuid not null references accounts(id),
  thread_id uuid not null,
  user_id uuid not null references auth.users(id),
  last_read_at timestamptz,
  primary key (thread_id, user_id)
);
```

---

# 14. Audit / analytics events

Recommended:

```text
driver_contact_menu_opened
driver_message_sent
driver_message_read
driver_voice_note_recorded
driver_voice_note_sent
driver_call_started
driver_call_connected
driver_call_ended
communication_thread_minimized
communication_thread_reopened
round_stop_drag_started
round_stop_sequence_changed
round_stop_move_to_other_round_started
```

---

# 15. Acceptance criteria

## Route editing

- Whole Stop row does not drag.
- Handle-only drag works.
- Stable Stop IDs drive reorder.
- Drop line makes insertion point obvious.
- Current/delivered/pickup Stops cannot move.
- Desktop and iPad produce the same resulting sequence.
- Map + ETA refresh after reorder.

## Quick contact

- Click/tap own active driver opens the driver action popover.
- Right-click/long-press may open the same popover as optional shortcuts.
- `Open Round` is available inside the popover.
- Message/Call/Voice note actions reach the correct assigned driver.

## Communications

- Communication window coexists with Round drawer on desktop.
- Multiple minimized threads remain visible in the bottom conversation tray.
- Only one conversation is expanded at a time.
- New reply creates synchronized unread state on map marker, tray and top bar.
- Message composer never overlaps messages.
- Voice recording has preview-before-send.
- Call persists without replacing map context.
- Call surface compacts vertically while active.
- Incoming call pulses the driver marker and provides Answer/Decline on the map.
- Missed call remains visible until acknowledged.
- Call record appears in history.

## iPad

- No permanent double-side-panel squeeze.
- Long-press contact works.
- Composer controls meet touch target requirements.
- Voice/call controls remain reachable without hover.

---

# 16. Non-goals

This spec does not add:

- driver-to-driver chat;
- arbitrary chat with unassigned Network candidates;
- customer support inbox;
- CRM messaging;
- customer SMS/email tracking notification UX (covered by Spec 5);
- WhatsApp/LINE driver chat unless separately integrated later.

*End of specification.*


---

# v1.1 · Canonical Communications Visual Contract

The v6 Communications surface supersedes earlier chat-drawer layouts.

## Separation of concerns

- Round drawer = operate the Round.
- Communications widget = talk to the driver.
- On wide desktop both may coexist.
- At constrained/iPad widths, Communications may replace the contextual drawer to preserve map usability.

## Canonical structure

1. Driver identity / online state / Call / minimize / close.
2. Delivery context bar.
3. Scrollable conversation thread.
4. Fixed composer: `Message field | Microphone | Send`.

Quick action buttons must not sit inside the message stream.

## Thread

- driver left;
- dispatch right;
- system events centered as quiet separators;
- timestamp/read state below body, never overlapping;
- max bubble width constrained;
- composer and header never scroll with messages;
- new messages scroll into view.

## Voice note

Voice is a primary action.

- microphone always beside Send;
- tap mic starts recording;
- normal composer is replaced by recording bar;
- recording bar shows live red state, waveform, timer and Stop;
- Stop opens preview;
- preview supports Play / Delete / Send;
- sent voice notes render as normal messages with waveform + duration;
- minimized conversation exposes incoming voice message state.

Production records real audio; UX study can simulate audio and timing.

## Calling

- Call is available from the Communications header and map quick-contact menu.
- Call state remains in Communications with Connecting / On call / timer / Mute / Speaker / End.
- Ending writes call evidence to delivery contact history.

## Map shortcuts

- click driver = open Round;
- right-click = Message / Call / Voice note / Center / Open Round;
- long-press on touch = same quick-contact menu.

## Acceptance

- zero overlap at supported breakpoints;
- composer always usable;
- microphone and Send always visible;
- conversation independent-scroll;
- no critical hover-only interactions;
- Round context is not unnecessarily lost when communication opens.

---

# v1.2 · Canonical Dispatcher Communications Surface

This version supersedes earlier visual implementations of dispatcher chat/call while preserving their backend contracts and history.

## Architectural rule

**Round drawer = operate the delivery.**  
**Communications window = talk to the driver.**

On desktop both may remain visible simultaneously. Opening a driver conversation must not replace the selected Round or delivery drawer.

On constrained/iPad layouts, Communications becomes the dominant contextual surface and the competing right drawer closes/minimizes rather than being squeezed beside it.

## Communications window

The canonical desktop window is a compact persistent work surface over the map, approximately 400–430 px wide.

Header:
- driver avatar / initials;
- driver name;
- own / Rounds Network identity;
- current Round;
- online / typing / offline state;
- Call;
- Minimize;
- Close.

Context row:
- current Round;
- order reference + recipient/area;
- `Open Round` action.

The window may be minimized while remaining live. Incoming replies create an unread count and can reopen the same conversation instantly.

## Message thread

Human messages use proper conversation bubbles:
- driver left;
- dispatcher right;
- timestamps/read state below the bubble;
- no quick-action buttons inside the message stream.

System events are quiet separators, not chat bubbles. Examples:
- `Round 19 assigned · 11:47`
- `Call ended · 1:14`
- `Route updated · 12:02`

The conversation is independently scrollable. The composer remains fixed to the bottom.

## Composer

Canonical composer:

```text
[ + ]  Message driver…  [ mic ] [ send ]
```

Rules:
- textarea grows only to a bounded height;
- Enter sends;
- Shift+Enter inserts line break;
- Send disabled when empty;
- mic is always first-class and adjacent to Send;
- `+` contains secondary context actions such as Share Map Context and Contact History.

## Voice notes

Voice notes are a primary dispatch interaction.

Tap mic:

```text
● Recording voice note    waveform    0:08    Stop
```

Stop:

```text
Play    waveform    0:08    Delete    Send
```

Sent and received voice notes render as playable audio bubbles with duration.

The UX must never represent voice as a generic quick-action button floating inside the thread.

Production implementation:
- actual microphone permission/capture;
- local preview before send;
- upload to Supabase Storage;
- message row references audio object;
- realtime delivery;
- offline queueing where supported.

## Driver call

Call is launched directly from the Communications header, Round drawer, map quick-contact menu, or contact history.

During a call, the same Communications window transitions into a focused call surface while the business map stays visible:

```text
Driver Call
Nattawut P.
On call
00:42
Mute   Speaker   End call
```

Ending the call returns immediately to the same thread and inserts a quiet system event. Call metadata is attached to delivery history.

Only one active dispatcher-driver voice call is supported per communications surface in this UX. Opening another driver while a call is active preserves the active call instead of silently switching context.

## Map quick contact

Desktop:
- left click driver → open Round;
- right click → Message / Call / Voice note / Center / Open Round.

Touch/iPad:
- long press → same quick-contact menu.

Communication access must not require navigating away from Dispatch.

## Acceptance criteria

- no overlapping text, controls or composer elements;
- no message/quick-action collisions;
- thread scroll and composer are independent;
- Round drawer stays usable on wide desktop;
- right-click/long-press driver contact works;
- voice record → preview → delete/send works;
- sent voice bubble works;
- Call → connected timer → mute/speaker → end works;
- call event appears in conversation/history;
- minimize preserves live conversation and unread count;
- incoming response can be surfaced while dispatcher is working elsewhere;
- no communications CSS/DOM from superseded implementations remains active.

---

# v1.3 Addendum · First-class Round Driver Contact

Driver communications must not depend on the current Stop being present in the visible Dispatch order collection.

Required behavior:

- A Round always resolves to its assigned driver independently of queue/filter state.
- `Message driver` and `Call driver` on a Round must work even when the current Stop is not loaded as a full order record in the current client view.
- Map quick-contact (right-click / long-press) uses the same driver/Round resolver.
- Communications may display the current or next Stop as context, but the communication identity is the driver/Round relationship, not the existence of that order card.
- Contact history opened from a Round returns to the Round, not to a missing order drawer.
- Missing/partial Stop data must degrade to Round-level context instead of silently doing nothing.

Acceptance test:

1. Open a Round whose current Stop is absent from the visible/demo order collection.
2. Message driver opens Communications immediately.
3. Call driver opens the call surface immediately.
4. Right-click/long-press driver exposes both actions.
5. Driver name, Round, Stop context and history remain correct.
---

# v1.4 Addendum · Persistent Conversation Tray & Map Communication State

This addendum supersedes earlier communications interaction statements where they conflict.

## Canonical driver-marker interaction

Normal click/tap on a driver opens the compact action popover. `Open Round` is one action in that popover. Right-click is a shortcut only.

## Canonical persistence model

- A dispatcher may keep many driver conversations active.
- Minimized conversations stay in the bottom tray.
- Only one full thread is expanded at once.
- Switching conversations does not discard drafts/history/unread state.
- Closing with `×` removes that thread from the active tray but does not delete communication history.

## Canonical map signals

The assigned driver marker is a communication-notification surface. It may show:

```text
unread count
voice note
incoming call
active call
missed call
```

The marker, bottom tray and top communications icon are three representations of one shared state and must update atomically from the same realtime event.

## Incoming calls

Incoming driver calls must never be discoverable only inside chat. Dispatch receives an on-map signal and a compact Answer/Decline overlay.

## Realtime implementation rule

Supabase Realtime (or equivalent production realtime channel) should update a single dispatcher communication store. UI surfaces subscribe to that store; map/tray/topbar must not maintain independent unread counters.

---

# ADDENDUM · Final Driver Contact Interaction Lock

This addendum supersedes any earlier rule that a normal driver-marker click directly opens the Round.

## Driver marker click/tap

Canonical:

```text
click / tap driver
→ driver action popover
```

Popover actions:

- Message;
- Call;
- Voice note;
- Center on driver;
- Show full Round.

Right-click is an optional desktop shortcut to the same actions.

No required functionality depends on right-click or long-press.

## Center on driver vs Show full Round

These are separate operations.

### Center on driver

- center camera on the driver's current GPS position;
- use a useful driver-scale zoom;
- select/emphasize the driver;
- do **not** automatically fit the whole Round.

### Show full Round

- open/focus the Round;
- fit route/stops as appropriate.

Button labels must match these behaviors.

## Persistent conversations

Dispatcher may keep multiple active driver conversations.

Rules:

- multiple conversations can remain active/minimized;
- only one conversation is fully expanded at a time;
- minimized conversations live in the bottom conversation tray;
- `−` means keep active/minimize;
- `×` means remove from active tray;
- incoming messages do not steal focus from the current conversation;
- newest/unread state remains visible.

## Synchronized communication state

The same state is reflected across:

1. driver marker;
2. bottom conversation tray;
3. top communications indicator.

Marker/tray states may include:

- unread message count;
- unread voice note;
- incoming call;
- active call;
- missed/declined call where applicable.

Do not show low-value states such as `Typing…` on the map.

## Incoming calls

Incoming driver call:

- visually identifies the driver on the map;
- conversation tray reflects the call;
- top communications indicator reflects live call state;
- dispatcher can Answer / Decline;
- answering transitions into the compact call state;
- declining creates a contact-history event.

## Call footprint

During a call the communications surface becomes more compact so the map remains useful.

The dispatcher must still be able to inspect:

- driver position;
- traffic;
- route;
- affected delivery;
- destination

while speaking to the driver.

# v1.6 Addendum · Physical Verification + Rich Communication Cleanup

This addendum is controlling where it conflicts with earlier composer/history language.

## Physical manifest visibility on Dispatch

Dispatch consumes the same structured manifest used by the Driver App.

For live work the drawer may expose:

```text
Physical manifest
Red velvet cake ×2       ✓
Rose bouquet ×1          ✓
Cookie box ×1            ✓
Pickup verified          4 / 4
Custody                  Driver
```

The board must distinguish:

- manifest exists;
- driver is checking;
- pickup verified;
- handoff verification pending;
- handoff verified;
- mismatch/exception.

The manifest is editable by Operations before pickup and locked after pickup unless a formal physical-work event is created.

## POD visibility on Dispatch

Completed delivery history shows the evidence generated by the Driver App: photo, GPS/geofence, received-by/handoff, signature when required, item verification and communication evidence.

A transient map success treatment may appear after committed completion, but it does not replace history/POD state.

## Canonical composer — v1.6

Desktop:

```text
[ + ]  Message driver…  [ mic ] [ send ]
      Drop files or links here · paste images or links
```

`+` contains sendable secondary objects only:

```text
Photo
File
Location
Map context
```

The previous requirement placing Contact History inside `+` is superseded.

Contact History is a navigation action in the conversation context/header beside Driver view / Open Round where space permits.

## Drag/drop and paste

The Operations conversation surface is a desktop drop target for:

- image files;
- PDFs/documents/other ordinary files;
- dragged URLs.

When a valid drag enters, reveal a clear drop affordance naming the driver. Never rely on an invisible drop target.

Clipboard image paste stages the image. Plain URLs pasted into the message are handled as text and auto-detected on Send.

## Staged attachments

Selecting, dropping or pasting an attachment does not send immediately.

Attachments enter a staged composer area. The dispatcher can remove items, add text or additional attachments, then Send once.

Multiple staged attachments are allowed.

## URL auto-detection

Typed/pasted `http(s)`/`www` URLs are detected from ordinary message text and render with a link card/preview. There is no dedicated Link button in the attachment menu.

## Contact History

Contact History is a purpose-built chronological ledger. It must not reuse the legacy `.chat-thread/.chat-msg` layout.

Required filters:

- All;
- Messages;
- Calls;
- Files & media.

Each row exposes a stable audit form: time, actor, type, event content/reference and outcome/status.

## Driver App parity

The same conversation record is visible in the Driver App. Driver mobile actions are contextual:

```text
Camera
Photo
File
Location
```

Links are pasted/typed into the normal message field and auto-detected. On capable desktop/tablet driver surfaces, drop may be supported as an accelerator; mobile tap actions remain canonical.

## Copy

Both surfaces support Copy for human messages and useful attachment references.

## Acceptance criteria — v1.6

- Attachment menu contains no Contact History or Link pseudo-action.
- Dragging a file/link over desktop chat reveals a named drop target.
- Dropped/selected files are staged before Send.
- Multiple attachments can be staged and removed independently.
- Clipboard images stage correctly.
- Pasted URLs render as link content after Send.
- Contact History uses its own non-overlapping ledger component.
- Files/media can be filtered separately from messages/calls.
- Operations and Driver App show the same persisted conversation history.

# Addendum · Post-Pickup Live Change Control

## Operations-only UX

The Dispatcher surface must never embed a Driver App preview, role switch, or simulated Driver App screen. Operations consumes driver events; it does not impersonate the driver.

## Entry

For a live delivery whose pickup manifest has been fully verified, the normal action becomes:

```text
Change live delivery
```

rather than a generic manifest edit.

## Editable post-pickup fields

Operations may edit:

- destination/address description;
- confirmed operational pin / vehicle arrival point;
- delivery promise/window subject to merchant authority;
- handoff / entrance / recipient instruction;
- future Stop sequence via Open Round.

The physical manifest is displayed as locked custody evidence.

## Preview

The preview must keep custody truth visible and show decision-relevant operational consequences:

```text
Package: 4/4 verified · Somchai custody
Destination: old → new
Route: +4.2 km
ETA: 12:20 → 12:38
Downstream: 2 Stops · +18m
Promise: safe / conflict
Shift: 16:18 → 16:36
Driver action: acknowledge update
```

When an actual physical destination moves, route calculation uses the new confirmed pin. If only entrance/address text changes at the same physical point, Operations may explicitly retain the existing pin.

## Apply

Apply is atomic from the user's point of view:

- commit change version;
- update Stop destination;
- reroute;
- recalculate affected ETAs/finish;
- emit audit/system message;
- push driver update;
- show acknowledgement pending.

If the preview contains a configured risk that still falls within human override authority, the operator must explicitly acknowledge the risk before Apply.

## Driver acknowledgement

Operations does not click a fake Driver App acknowledgement. The acknowledgement arrives as a Driver App event.

The board state transitions from:

```text
Awaiting driver
```

to:

```text
Driver acknowledged
```

and the shared communication/history ledger records the event.

## Custody boundary

Changing the destination is not a custody transfer. The same driver continues to hold the same pickup-verified manifest unless an explicit return/transfer/reassignment workflow is performed.

---

# v1.9 Addendum · Availability Contact vs Delivery Communications

**Controlling availability/contact spec:** `ROUNDS-SPEC-10-DRIVERS-LIVE-AVAILABILITY-CONTACT-v1.4.md`

This addendum separates three different communication contexts that must not be conflated.

## A. Team relationship contact

For an own team driver, the merchant may Message / Call / Voice note through the normal Drivers/Dispatch contact surfaces according to business policy, whether or not a specific delivery drawer is currently open.

The current work/shift/Round context should still be attached when relevant.

## B. Pre-job Network relationship contact

For a preferred/known Network driver with an established merchant relationship:

- `Ask availability` is the canonical pre-job action;
- where the driver has explicitly enabled direct merchant contact, the business may open a relationship-level message thread;
- this relationship thread is not a delivery/Round thread and must not create fake job context.

Unknown Network candidates do not expose a Message/Call action merely because they are `Open for jobs`. The merchant reaches them through Offer/Broadcast.

## C. Accepted-job contact

Once Network work is accepted, the merchant and driver use the normal job-linked Communications contract:

- Message;
- Call;
- Voice note;
- attachments/location according to the rich-communications rules;
- Contact History/audit attached to the operational work.

## Availability display in contact surfaces

Driver actions may show concise state such as:

- `Available now`;
- `On Round 18`;
- `Available after 16:20`;
- `Open for jobs`;
- `Not accepting jobs`;
- `Offline`.

Presence must be freshness-aware. A stale connection must not masquerade as live availability.

## Privacy

Do not reveal unrestricted exact pre-acceptance Network-driver location in a contact popover. Approximate distance/area and matching suitability are sufficient until an accepted-work tracking relationship exists.

## No-ghost-control extension

A driver contact action is visible only when the current relationship/state actually permits it. Do not show disabled-looking-but-clickable `Message` or `Call` controls for unknown Network candidates.

# v1.9 Addendum · External Courier Live Lifecycle

The Dispatch board must treat a booked external courier as live operational work, not as a detached provider link.

Normalized visible lifecycle:

```text
Booking requested
Driver assigned / arriving pickup
Picked up
En route
Delivered
POD received
```

- Provider-specific webhooks normalize into these Rounds states.
- The delivery rail, map, drawer and History use the normalized Rounds state.
- External driver location is shown only when the provider supplies operationally relevant coordinates.
- The external map marker is distinct from Own and Network markers and may carry the small provider label `Lalamove`; do not use a large provider logo.
- Pre-pickup Operations cancellation returns the delivery to Action and clears the external assignment.
- Post-pickup provider failure/cancellation does **not** clear custody or permit silent reassignment; it creates an external-custody exception.
- Quote expiry is enforced before booking; stale/mismatched quotes require requote.
- Delivered external work may not be considered evidence-complete until provider POD is normalized/imported where the provider supplies proof.

# v1.10 Addendum · Offline / Loading / Quiet-State Dispatch Contract

The Dispatch workstation must preserve operational truth under partial connectivity.

## Browser offline

When the operator browser is offline:

- existing locally available/last-known delivery, route, custody and History records may remain readable;
- the client must not create a Network Broadcast, external quote/booking, outbound driver message/call or availability request that cannot reach the backend;
- the blocked action shows an explicit offline state and leaves the operational record unchanged;
- draft message text and staged attachments remain in the composer;
- a driver's last observed presence is not converted into a driver-offline event; Communications should say that live status is paused/last-known;
- server-side work already committed may continue independently and must be reconciled when connectivity returns.

## Map degradation

A Mapbox/map dependency failure must not blank or disable the rest of Dispatch. The rail, planning data and non-map records remain usable. The map area shows a focused degraded-state explanation and a real Retry action.

## Quiet/no-match states

- Action with no unresolved work = positive `Nothing needs attention`, not an error.
- Search/filter no-match is distinct from an empty operating day and exposes a clear/reset action.
- Live with no moving work is a neutral quiet state.
- Plan with no unplanned deliveries is a `quiet planning day`; Generate Plan is visibly disabled and must not look actionable.
- A proposed plan with zero uncovered deliveries states that all deliveries are covered.

Never show a success/empty state while a live request is still loading.
