# P09 — Messages Calls and Notifications

Rounds specification set · Consolidated V2.3 · 8 September 2026

Feature scope: CM-01–05/09; DR-09. Database ownership: conversations, conversation_participants, messages, message_attachments, message_receipts, call_sessions, call_events, notifications.

Authority: this document defines the product workflow. Machine contracts in contracts/ define exact payloads, states and transitions; decisions/ records deliberate defaults and exclusions. All mutations use authenticated scoped authority, required versions, idempotency and an audit trail. Approved current screens remain the visual reference; sample data is not a tenant default.

## Context and surfaces

Click driver on map → driver actions → Message/Call. Message opens the appropriate existing authorized job or employer relationship thread directly; header inbox is secondary. Thread key is not simply driver name or current selected card. Delivery/stop references may be attached to a Round conversation; relationship messages are clearly separate. Unknown unaccepted freelancers cannot be contacted casually. After acceptance job participants receive limited authorized contact and historical access needed for that job.

Preserve open/minimized conversations, unread and draft/staged media per thread. Switching driver/city cannot send a draft to the previous or next driver accidentally. Mobile Driver H01 prioritizes current task context, concise messages and large input actions without a permanent explanatory field reducing map space.

## Persistent map communication

Normal driver click opens permitted Message, Call, Voice note, Center on driver and Show full Round actions. Center on driver centers the current geographic position at useful driver scale; Show full Round selects its route/stops and fits that scope. Neither requires a right-click shortcut.

Desktop keeps one expanded communication window and multiple minimized conversations. Minimize retains the thread in a compact tray; Close removes it from that tray without deleting messages or drafts. Overflow follows available space. Opening another delivery does not replace the current chat. Incoming replies update map marker, tray and header unread indicators together and never steal keyboard focus or force another thread open. Reading clears that thread across all surfaces. Typing does not clutter map markers.

On iPad, chat uses an overlay/bottom surface and may close the details drawer rather than squeezing permanent side panels. During calls keep useful map/route context; compact call controls reflect actual provider state. Drafts and staged attachments remain bound to the same thread across city/selection changes.

## Message composition and durable states

Support text, links in text, camera/photo, file/document, explicitly captured location and voice. Attachments stage before Send and can be reviewed/removed. Actual capture/recording occurs only after user action and permission; stop streams on cancel/background/leave. Late permission/decode callbacks cannot attach to a closed/new draft. Failed replacement retains valid prior media.

Client message ID is stable across retries. Server validates thread participant and attachment purpose, stores message and references, then emits outbox events. States: draft/local_saved, pending_send, service_received, delivered_to_device where acknowledged, read where explicitly observed, failed. Do not equate socket open or reconnection with message delivery/read. Partial attachment failure leaves explicit per-item retry. Plain text rendered safely; do not execute pasted HTML/links. Proposed per-message caps are 10 attachments and 20 MB/file, configurable by type; enforce consistently on client/API/storage.

Human content, system updates and manual call logs are visually/source-distinct. Copy applies to human text/authorized attachment references; signed links must not become permanent public references. Forward/share action uses the current permission/audience policy.

## Calling including missing incoming driver coverage

Outgoing caller selects Operations, recipient or pickup contact appropriate to context. Opening dialer is neither connected nor completed. Provider-connected state derives from authenticated provider events; manual outcomes are labelled user reports. Caller/callee, related Round/stop, timestamps and source are retained.

Incoming Driver call surface shows caller/business and relevant Round/stop, Answer and Decline, with safe interaction during navigation. Missed/declined call notification returns to the correct contact/context. Call waiting/busy, permission denial, connection lost and unavailable provider show useful fallback Message/Call via permitted phone method. Exact voice provider is an adapter decision; current HTML does not establish VoIP integration. Do not make caller context unavailable just because header inbox is closed.

In-call controls (mute, speaker, end) reflect actual supported state. End/cancel is idempotent. App background and external dialer return reconcile call status; elapsed UI timer cannot prove connection. Contact History combines message/system/call evidence chronologically with provenance and correct related work. Manual outcome edit appends a correction.

## In-app notifications and requests

Create notification from a committed event; push contains a minimal entity pointer/localized safe preview, not private full route or evidence. On tap fetch current authorized state. Handle loading, expired/withdrawn offer, resolved/superseded update, offline, retry and access revoked. Mark read is separate from acknowledging route change or accepting offer. Mark all read does not execute operational commands.

Availability request reply is an explicit structured response with deadline/version; it reserves no work and does not change open availability. In-app notification dedupe is event + recipient + kind. Channel delivery dedupe additionally includes channel; template_version is a snapshot, never part of retry identity. Retry of push cannot duplicate work or reopen expired offers. Driver preferred locale determines copy; customer notifications use their separate policy in P12.

### QA-BC-08

Actor: Authorized actor for OpenConversation,ConfirmArrival; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute OpenConversation,ConfirmArrival under the condition in expected outcome; query affected records and compare committed events..

Then: Accepted freelancer map selection opens its job conversation; pickup arrival is explicitly recorded and does not claim goods collected..

Status: written requirement; application execution pending.

### QA-IC-06

Actor: Authorized actor for OpenConversation; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute OpenConversation under the condition in expected outcome; query affected records and compare committed events..

Then: Linehaul trip chat and local Round chat have distinct context IDs/participants; a draft in one cannot send into the other..

Status: written requirement; application execution pending.

### QA-CM-01

Actor: Authorized actor for OpenConversation; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute OpenConversation under the condition in expected outcome; query affected records and compare committed events..

Then: Click driver marker then Message: open that authorized Round conversation directly without a mandatory header-inbox step..

Status: written requirement; application execution pending.

### QA-CM-02

Actor: Authorized actor for OpenConversation; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute OpenConversation under the condition in expected outcome; query affected records and compare committed events..

Then: Reopen same job: same conversation ID and unread count; switch context without losing the saved draft in original thread..

Status: written requirement; application execution pending.

### QA-CM-03

Actor: Authorized actor for SendMessage; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SendMessage under the condition in expected outcome; query affected records and compare committed events..

Then: Text plus two assets with one upload failure remains staged; retry sends only missing attachment and duplicate client_message_id creates one message..

Status: written requirement; application execution pending.

### QA-CM-04

Actor: Authorized actor for StartCall,RespondCall; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute StartCall,RespondCall under the condition in expected outcome; query affected records and compare committed events..

Then: Call events distinguish ringing/connected/missed/declined; dialer launch alone cannot become connected and manual outcome is labelled manual..

Status: written requirement; application execution pending.

### QA-CM-05

Actor: Authorized actor for GetConversation; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute GetConversation under the condition in expected outcome; query affected records and compare committed events..

Then: Conversation history lists messages/calls separately from operational custody events and preserves their exact supplied delivery context..

Status: written requirement; application execution pending.

### QA-CM-06

Actor: Authorized actor for SendMessage; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SendMessage under the condition in expected outcome; query affected records and compare committed events..

Then: Reassign driver while draft open: sending to obsolete participant is denied or requires explicit retarget; never silently changes recipient..

Status: written requirement; application execution pending.

### QA-CM-07

Actor: Authorized actor for ExchangeTrackingToken; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute ExchangeTrackingToken under the condition in expected outcome; query affected records and compare committed events..

Then: Recipient token excludes buyer identity/price/surprise text before allowed stage; buyer token does not expose unrelated deliveries..

Status: written requirement; application execution pending.

### QA-CM-09

Actor: Authorized actor for SendMessage; identity/tenant from fixture, with negative actor when specified.

Given: FIXTURES.md; A/B, D1–D5/DQ, T1, S/N/F1/F2, SL1/SL2 as named.

When: Set up named fixture; execute SendMessage under the condition in expected outcome; query affected records and compare committed events..

Then: Server receipt is Sent, provider/device delivery is Delivered, explicit read receipt is Read; timeout stays unknown/retryable..

Status: written requirement; application execution pending.

### QA-V21-CHAT-FOCUS

Actor: OA.

Given: S thread open with draft; N thread minimized.

When: Receive N reply while typing; switch threads; minimize/close.

Then: No focus stolen; draft remains S; unread syncs marker/tray/header; close does not delete history.

Status: written requirement; application execution pending.
