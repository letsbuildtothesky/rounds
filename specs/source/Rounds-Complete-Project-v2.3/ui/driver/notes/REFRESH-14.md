# Refresh 14 — Offline / Reconnecting + GPS Unavailable

26 of 47 original HTML files refreshed; 21 remain original. The cumulative ZIP contains all 47 app files, previous review pages, the unchanged guide and tokens, and the historical coverage audit. N02 and N03 are existing boards; review tabs are states, not extra screen IDs.

## Design

The established blue #1754a6 / orange #ff6420 palette, white canvas, restrained corners and Arial type remain. N02 uses a 40px main heading, 18px body, a pale blue saved-Round band and 94px item rows. N03 keeps a 300px map viewport, a 36px heading, 22px destination and 18px recovery text. Main actions are at least 64px; second actions 60px; header/map enlargement controls 52px. Content scrolls independently of the pinned actions. Narrow screens keep the control sizes and allow text to wrap.

The original N02 used small 11.5–14px status text and a timer that asserted successful sync. The refresh separates local durability, pending uploads, failures and actual receipt. A connection indicator never doubles as an upload acknowledgement.

The original N03 put James T. / Stop 2 over a schematic map of Emporio / Stop 1. This refresh reuses the exact embedded real Bangkok map from approved F08. No map pixels, route geometry, or markers were changed. The main 300px view crops centrally to show the four stops; explicit Mapbox / OpenStreetMap attribution remains outside the crop. The enlarged sheet shows the complete original image. No live-location dot is fabricated. The target is consistently Stop 2, The Sukhothai Residences, Sathorn. The saved map is a fixed example, and delivery coordinates remain approximate/unverified.

## Review

Open the standalone HTML or extract the ZIP and open index.html. Both show N02 and N03 side by side, with state buttons above each phone. Retry buttons expose explicitly labelled sample-result sheets. Review mode never requests device location, sends work, or opens real navigation.

N02 states: Offline, Connecting, Uploading, Partial, Failed, Sent, Save failed, Empty. The example queue contains a Stop 1 proof bundle and a message to Operations. These are fixture records, not prior prototypes' real saved blobs.

N03 states: Signal lost, Access off, No fix, Location received. Receiving a position does not restore a live ETA or change the saved map. Opening navigation is a separate driver action. Cached-route actions stay within the correct Stop 2 sheet instead of jumping to the fixed Stop 1 E02 board.

## N02 implementation boundary

Without an adapter, the individual N02 HTML is explicitly labelled “Preview · Sample saved work”. Review mode uses fixtures even if an adapter is injected. All preview receipts are explicitly sample results. No localStorage, IndexedDB, real uploads, synthetic automatic acknowledgements or backend mutations are performed here.

Optional native interface: window.RoundsSyncBridge.

- getSnapshot(): read-only snapshot.
- retry(itemIdOrNull): explicitly requested retry of eligible pending items; the service must be idempotent.
- retryLocalSave(itemId): explicitly requested local durability retry. Must not silently convert a failed save into an upload.
- Each method returns {connection, round, items}; connection is offline, online, checking or unknown. round is null or {id, merchant, cached, savedAt}; savedAt is an already-localized label, not fabricated by HTML.
- Items: {id, kind, title, context, localDurable, state, receipt?}. kind is proof or message; state is queued, uploading, failed, sent or save_failed. Queue IDs must be unique.
- A sent item requires receipt {id, itemId, accepted:true}. Proof also requires evidenceDurable:true, meaning all required evidence bytes are durable and associated with the intended server record. Missing or mismatched receipts are rendered pending. If localDurable is false without a confirmed receipt, the item is unsaved.
- Native services own authentication, storage transactions, record revisions, evidence completeness, upload progress, connectivity health, local preservation, retry deduplication and receipt authenticity. A correctly shaped JavaScript object is not a security boundary.
- An online event only reads the snapshot. It never sends a command or marks an item sent. Late results after page exit or offline transition are ignored.
- Invalid snapshots/read failures retain the last known items and show an error. The driver can retry. Unsaved items take priority and remove the normal “Return to Round” action from this board.

Current fixture return: E01 (fixed Stop 1), with offline=1 when appropriate; from=home preserves Team/Network home context. A generalized native current-stop router is still needed. The historical COV03 gap is narrowed by honest recovery states here; actual durable evidence replay and the F03/F08 completion contract remain implementation work.

## N03 implementation boundary

The individual HTML requests browser geolocation only on an explicit Check/Retry action, using maximumAge:0 and a 10-second timeout. It discards coordinates after validating the result and only displays reported accuracy. It never stores or transmits coordinates or infers arrival.

Optional window.RoundsLocationBridge.requestFix({timeoutMs:10000}) returns a browser-shaped {coords:{latitude,longitude,accuracy}} result; errors use code 1 for access denied, otherwise unavailable. Native services must enforce freshness, cancellation and navigation-quality gates. The board deliberately says “Location received”, not “Navigation restored”.

Optional RoundsLocationBridge.openSettings('location'), falling back to the existing RoundsPermissionBridge.openSettings('location'), opens settings. Otherwise the sheet tells the driver to open phone settings. Settings launch is never treated as permission granted. Check again explicitly requests a fresh fix. Failed/unsupported access remains recoverable.

After an actual position result, Open navigation uses the existing sample Google Maps destination for Stop 2 (13.7204,100.5332). It does not send the acquired origin. Review mode intercepts this action. Production must use the canonical assigned destination and approved native navigation implementation.

Route review or page exit invalidates outstanding position callbacks. No callback auto-opens navigation. Saved map loading failure exposes an honest fallback with the destination still available.

## Checks and limits

Source checks and Node VM interaction checks cover script syntax, unique IDs, relative targets, fixed tokens, unchanged earlier screens and map bytes, all 47 ZIP entries, queue receipt requirements, local-save failure, partial retry, offline/read failure, duplicate click protection, late results, explicit GPS outcomes, permission/settings recovery, no review device requests, no coordinate persistence, focus trapping and trusted review messages.

The saved map itself was inspected. Full browser visual QA remains unavailable under the earlier browser security restriction. Phone layout, Thai wrapping, sunlight/glove use, native permission lifecycle, offline durability and actual navigation still require device validation. No production-readiness claim.

Canonical references: v42 ROUNDS-DRIVER-UX-BEHAVIOR-MASTER-v3.0.md, especially lines 423–424, 444–446 and 481–486. Older phase examples of automatic GPS confirmation do not override the current requirement for driver confirmation.

## Final copy polish

Removed redundant normal-state lead and bottom sync explanation. Each row now carries one short state: Waiting to send, Uploading, Sending, Retry needed, Evidence received, Message received or Not saved. The unsaved-work instruction and meaningful errors remain. Sent-item details no longer repeat the receipt state. The recovery model and GPS board are unchanged.
