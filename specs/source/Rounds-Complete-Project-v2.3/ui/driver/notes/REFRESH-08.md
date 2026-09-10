# Rounds driver — Refresh 08

## Scope and design commitment
Read the original G05 Driver emergency and H01 Operations chat before updating. Keep the fixed Rounds design system, large surfaces and concise driver copy. All 45 other screen files, prior review pages, maps/markers, design-tokens.css and the style guide are byte-identical to Refresh 07. The cumulative 47-screen pack now contains 16 refreshed screens and 31 unchanged originals. Map marker refinement remains deferred.

## G05 — Driver emergency
- Retain the original large safety question (40px, 36px on narrow widths) and increase the already-generous safety choices from 112px to 120px. Keep 22px choice labels and enlarge the supporting text from 13px to 16px. This preserves emergency-screen emphasis instead of shrinking it to make space.
- Same blue/orange identity: contextual header, pale-blue heading and narrow orange rule. Operational green marks safe and red marks urgent assistance. No new palette.
- Medical and police assistance remains accessible from the initial state; urgent state exposes both large calling rows directly. Each number is visible beside its label. Operations contact stays reachable, without forcing geolocation first.
- Medical ambulance 1669 and police/immediate danger 191 verified against official sources on 7 September 2026. These are phone dialer handoffs on individual screen pages; the review boards intercept them and disable real calls. No emergency call was placed during testing.
- Replace unconditional “Current location recorded” with optional explicit browser location capture. Only real coordinates and reported accuracy are displayed after success. Location denial does not block help. Location is saved locally when possible; it is never automatically claimed as received by Operations.
- Remove automatic “Operations notified” assertions. Message Operations opens a prepared chat draft for the chosen safety status, including an explicitly captured location if stored successfully. It is never sent automatically.
- Preserve the paused-round concept as a review state. View paused round now opens a local list of the same four stops with On hold status and an Operations call action. It does not open E01's active navigation fixture or silently resume deliveries. Real dispatch pause/reassignment still requires backend integration.

## H01 — Operations chat
- Messages increase from 14px to 17px; metadata from about 11px to 13px. Blue outgoing messages, pale-blue Operations messages, 86% message width and 14–15px internal padding. Timestamps sit outside the colored bubble so they remain readable.
- Retain the original conversation and proof-photo instruction. Keep the original shared coordinate as a historical sample attachment, labelled Shared location rather than claiming it is a newly measured current/Gate B position. This sample point is not an independently verified entrance.
- Original pickup/entrance events remain accessible behind a 56px “2 delivery updates” control. This makes space for the conversation without deleting history. View stop opens readable delivery context instead of routing to a generic round overview.
- Context rows can wrap; the recipient and building are not truncated. Header buttons are 52px. Composer controls are 60px (56px wide at the narrow breakpoint); text input stays 16px. The microphone uses orange with dark ink for contrast; Send uses blue.
- Attachment staging is a scrollable vertical list with 52px remove controls and readable file names, replacing 138px chips with 24px remove controls. Camera, photo, file, location and voice are preserved. Files retain their real Blob and can be downloaded; images require successful decoding. Location access is explicit and reports actual accuracy.
- Voice uses the browser MediaRecorder API rather than a timer pretending to record. A large timer appears only after microphone access and recording starts. Stop produces real audio, native playback permits review, and Add to message stages it before the final Send action. Denied/unsupported microphone states explain the alternative. Closing, cancelling, changing the sheet or leaving stops microphone tracks; late permission responses are also cleaned up. No microphone was accessed by a tool during implementation/testing.
- Keep long-press/right-click copying and add keyboard access to a large copy sheet. Text and file names are rendered as text, with HTTP(S)-only link creation. Message audio/photos remain mounted when a later message arrives.
- Remove unverified Online presence and automatic reconnect “Synced” claims. The initial conversation is fixed sample data. New online messages are labelled Preview; offline messages are marked Saved · not sent only after a successful local write. Reconnection never falsely claims delivery. There is no external chat service connection.

## Local behavior and navigation
IndexedDB stores emergency state and optional location, chat drafts, staged attachments, new local messages and audio/photo/file Blobs. Review state uses isolated keys; normal pages restore their own stored draft. Writes are acknowledged only on transaction completion. Failed local writes show a keep-screen-open message. No remote messages, uploads, approvals, dispatch changes or calls are executed by this build.

Standalone review includes both full screens with Start/Safe/Urgent and Chat/Offline/Voice tabs. Voice opens ready-to-record; it does not request microphone access automatically. The two-screen review can carry the selected emergency status into the chat draft. Other companion links are explained outside the phone and work within the extracted cumulative ZIP. Browser permissions and local-file storage support vary by device.

## Validation
Source/logic checks cover safety states and calling targets, optional location success/failure/removal, pause-state navigation, shared emergency drafts, chat input and staging, safe text links, file/image validation, offline persistence without false syncing, microphone denial/cancellation and recording lifecycle, copying, modal focus, review switches and companion navigation. Script syntax, local links, 47-screen inventory, exact changed-file scope and ZIP integrity are checked. Full browser/device rendering remains unavailable following the earlier browser security block. Actual phone typography, keyboard/viewport resizing, native capture/recording and glove/sunlight use still need device testing.

## Sources for emergency numbers
- [Thai government: emergency contact numbers](https://thailand.go.th/issue-focus-detail/009-017)
- [Thai Government Public Relations Department: useful hotlines](https://thailand.prd.go.th/en/content/category/detail/id/2078/iid/382099)
- [UK government: emergency services in Thailand](https://www.gov.uk/foreign-travel-advice/thailand/getting-help)

## Next pair
H02 Call/contact and H03 Contact history. Read originals first and preserve the fixed visual system. Map markers remain deferred.
