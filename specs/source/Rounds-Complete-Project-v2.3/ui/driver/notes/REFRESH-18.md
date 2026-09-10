# Refresh 18 — End shift confirmation

33 of 47 original HTML files refreshed; 14 remain original. This refresh updates B01F only. All other screens, prior review pages, style guide and tokens remain unchanged. The ZIP includes the complete 47-file app set.

## Design

The original screen already had a useful, simple hierarchy: last delivery complete, confirmation, hours and two choices. This refresh preserves that structure and aligns it with the approved design. The wordmark is blue with the orange square; the heading remains 40px; the hours become a clear 44px total on the pale-blue summary surface with an orange rule. Regular/overtime labels are 16px and values 20px. The header control is 52px. End shift is 68px; the explicit Stay on shift choice is 60px instead of the old 46px Not yet button.

Green identifies readiness/completion. The hours panel uses blue, and the overtime row uses the existing readable care color. White space is preserved. Content scrolls independently above pinned decisions and navigation. Short screens keep the control/type sizes instead of squeezing the page.

Original values are preserved in the main example: 17:22, UrbanFlowers, 8h 22m total, 8h 00m regular and 22m overtime. No assumptions about breaks, payable hours or overtime rates are added.

## Choices and state previews

The confirmation itself is the decision: End shift advances directly to the clearly labelled local completed example, without a second confirmation. The completed example retains the same 17:22 end time and 8h 22m total; View hours opens those same figures.

Stay on shift now stays in a completed-delivery, on-shift state. The original Not yet link opened B01E's unfinished delivery, contradicting Last delivery complete. The new choice does not resurrect that work. Review end shift returns to the confirmation.

Additional review states outside the phone:

- Ready: last delivery complete; End shift / Stay on shift.
- Stay on shift: the delivery remains complete; no clock-out.
- Work still open: End shift is disabled; Return to delivery opens the approved B01E delivery view. This separate example uses 17:14 / 8h 14m / 14m overtime to agree with that source's active-delivery timing.
- Offline: clock-out is unavailable. Staying on shift does not publish a state change. Reconnection requires a status check before confirmation is available.
- Unconfirmed: end time is not treated as known; Check status opens explicit sample result choices. No new End shift action is offered until the result is resolved.
- Ended: recorded completion is retained, including when the connection changes. It does not automatically enable Network availability.

Existing accepted work cannot be ended or abandoned through the confirmation. This does not invent a product-wide rule for proof-upload or payroll handling; those depend on the canonical operational service.

## Prototype boundary and flow continuity

These are design fixtures. The standalone review explains that End shift only changes the preview; the individual file shows Preview · Sample shift. No backend, clock-out, delivery, GPS, storage, message or Network request occurs. Local transitions are not service acknowledgements. Production must use authoritative shift eligibility, accepted-work state and durable clock-out outcomes, with idempotent requests and reconciliation after an uncertain response.

The separate B01C completed-shift/Network screen remains for the next refresh. B01F's completed preview does not jump into B01C's conflicting 17:04 / 08:00–17:00 example. Its local hours sheet preserves the correct values. Team Hours navigation remains available as the existing separate sample screen.

The screen uses accessible controls, visible focus, labelled modal views, an inert background, Tab trapping, Escape and return focus. Review companion navigation accepts only known local screen files and messages from its own frame.

## Validation

Checks cover original hour arithmetic and labels; Ready / Stay / Ended behavior; no resurrected delivery after staying; work-open guard and correct delivery target; offline and uncertain outcomes; no automatic confirmation on reconnection; modal focus; scripts/IDs/local links; and key row widths at 320/360/393px using font metrics. All non-target app screens and earlier guide/tokens/review pages are byte-compared. ZIP contents are checked against the current folder.

Browser/phone visual QA remains unavailable under the earlier security restriction. Font metrics and CSS sizes are not rendered layout measurements. Device/Thai layout and native shift lifecycle remain to be validated. No 10/10 or production-readiness claim.

Sources: original B01F v2 HTML; B01C v2 and approved B01E for return-flow context; current v42 Driver UX Behavior Master v3.0 B00–B03 and Team Hours semantics; Driver Canonical Manifest v6; approved style guide v1.
