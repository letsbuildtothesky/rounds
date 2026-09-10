# Rounds driver — Refresh 09

## Scope and fixed visual system
Read both original screens before refreshing H02 Call/contact and H03 Contact history. Preserve the approved blue/orange design, generous spacing, large touch controls and concise copy. Exactly these two screen files change from Refresh 08. All 45 other screen files, earlier review pages, maps/markers, design-tokens.css and the style guide stay byte-identical. The 47-screen pack now has 18 refreshed screens and 29 unchanged originals. Map-marker refinement remains deferred.

## H02 — Call/contact · refined
- Replace the generic Call contact heading with Call Operations or Call recipient, according to the selected contact. The browser title follows the same state.
- Remove the decorative phone tile and repeated role label. Make the 42px contact name the first content after the header (36px at narrow widths), with the recipient’s 26px phone number immediately below. Operations retains the concise Rounds voice label. The delivery address stays in the separate context row/details rather than repeating beside the recipient.
- Fix the discovered selector conflict: the ready screen previously reused call-session, so its later 32px h2 rule overrode the intended 40px contact name. The ready screen now uses a dedicated contact-view class. The actual calling screen retains its own typography.
- Use the existing white surface and flexible vertical spacing to center the contact identity within the available content area. Move the original pale-blue/orange delivery context below the identity and optional privacy/last-call sections, just above the pinned actions. This keeps the contact primary and the delivery secondary, without introducing extra color blocks or shrinking targets.
- Keep 52px header controls, the 64px blue call action and 60px Message Operations action. The content scrolls on short screens while those main actions remain pinned. Preserve the privacy warning and concise masking explanation.
- Retain both original contact modes, explicit Operations call preview, recipient dialer handoff, manual outcomes, local timestamped history and history navigation. The recipient number remains an unverified original sample; review boards block real dialing. No new Operations number or voice service is introduced. No timer claims a call has connected.
- Outcome success still waits for local transaction completion; failures retain the sheet for retry. Merely opening or cancelling a call does not create a record. Only a manually selected outcome is logged.

## H03 — Contact history
- Increase titles from about 13.5px to 18px, bodies from about 12px to 16px, and timestamps to 14px. Use a clear time/icon/text grid with 100px minimum rows and 21px vertical padding; long content expands and wraps. 17px row headings at the narrow breakpoint preserve space without shrinking the body text.
- Retain all nine original events in chronological order, including both full messages, gate update and acknowledgement, shared location, no-answer call, handoff approval and proof record. Shared location describes a historical sample rather than newly measured GPS. Initial scroll shows the latest activity, as in the original.
- Add two 56px filters: All activity and Calls. All nine entries remain available. Each entire row opens a detail sheet with readable text and a 64px Copy details button, replacing a copy feature discoverable only through long-press/right-click. Right-click also opens details. Keyboard activation works through native buttons. Copy failures leave selectable text and a clear message.
- New manually recorded H02 calls appear in a separate Added on this device section with real local date/time. This avoids mixing current local timestamps into the original fixed afternoon sample sequence. Details explicitly distinguish Sample history and Saved on this device.
- Replace automatic “synced”/Online claims with honest offline/local status. Existing fixed events are sample data, not server audit receipts. Reconnection does not mark local records as synchronized.
- Preserve Message Operations and direct Operations call navigation. Delivery context opens the same readable sheet as H02.

## Local behavior and review
Both refreshed screens share an IndexedDB contact log in rounds-driver-preview / drafts. Keys separate the review log from individual screen use. Append uses one read/write transaction to preserve concurrent writers; records are validated on both read and write. Duplicate IDs are ignored. BroadcastChannel and review-frame notifications refresh history after a successful write, with focus/visibility refresh as a fallback. The shared log does not rewrite the earlier independent exception-flow call ledgers.

The standalone review embeds both complete HTML screens. Review tabs cover Operations, Recipient, Connected, Outcome, All activity, Calls and Offline. Review companion routing validates frame sources. The extracted pack contains all 47 screens, all previous pair reviews, the fixed style guide, design tokens and notes. Storage and clipboard support for local HTML vary by browser. There is no backend, call service, contact verification, dispatch update or external messaging in this pair.

## Validation
The contact refinement additionally checks the effective CSS font-size at 393px and 320px widths, contact-before-context order, removal of the decorative tile and byte-identical H03 preservation. Source and Node logic checks cover both contact modes, explicit simulated connection, cancel/end and manual outcomes, blocked review dialing, storage completion/failure/retry, shared history and filtering, preserved sample chronology, safe text rendering, copying and keyboard focus, review switches and companion navigation. Also check JavaScript syntax, unique IDs, local targets, exact two-screen change scope, fixed guide/tokens, 47-screen inventory and ZIP integrity. Full browser rendering remains unavailable after the earlier browser security block. Phone layout, native dialer return, sunlight readability, gloves and assistive technology still need device review.

## Next pair
J01 My rounds and K00 Team hours. Read both originals first and keep the fixed style guide and two-screen cadence. I01 Round complete has already been refreshed. Map markers remain deferred.
