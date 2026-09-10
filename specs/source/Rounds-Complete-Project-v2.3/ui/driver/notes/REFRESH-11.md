# Rounds Driver — Refresh 11

7 September 2026 · Network Earnings (K01) and Driver Profile (L01).

## Progress

47 app HTML files: **22 refreshed, 25 still original**. This pair replaces only K01 and L01. All earlier screens, maps, review pairs, design tokens and the approved style guide are preserved. The coverage checklist is included as the historical Refresh 10 audit; its original 20/27 progress count remains dated to that baseline.

Open `index.html` for this pair, `pair-10.html` for My rounds / Hours, and earlier numbered pair files for the previous work. The standalone two-screen HTML embeds this pair without requiring the ZIP.

## K01 — Network Earnings

- Uses the approved Hours typography and pale-blue total panel with an orange rule. Daily earnings have exact amount labels, weekday/date labels and a 0/400/800 baht scale. Bar heights derive from the amounts. Daily breakdown gives large tap targets and a readable day total.
- Preserves the original seven values: 420, 515, 390, 610, 560, 385 and 740 baht; total **3,620**. Preserves 18 jobs for the period and today's four jobs, totaling **740**. No new job counts are invented for earlier days.
- The original Tue–Mon labels are given a consistent fixture range, **26 Aug–1 Sep 2025**. This is a dated example, separate from the 28 Aug Hours snapshot. It is not a live current-date dashboard.
- Preserves all four merchant/time/fare/distance/duration records. Each now opens a job record. Complete and Processing remain source record labels; they do not imply that the fare has been paid out. Guaranteed fare is shown in the detail.
- Keeps payments separate from job earnings. Preserves paid fixture payouts of 2,480 / 2,195 / 2,740 baht on 28 / 21 / 14 Aug, and the first payout's 12 jobs. Historical payment records do not change when a different local payout preference is selected.
- Payout method opens a readable sheet, with Manage payout method leading to the paired Profile sheet. Navigation explicitly carries Network context.

## L01 — Driver Profile

- Gives the driver's name, phone and verification room. Removes the decorative initials block to make space for the name and a 58×52 edit target. Long names wrap.
- Driver and App rows use 18px titles, 15px supporting text, 76–106px targets and flexible row heights. Content scrolls above a pinned navigation bar.
- Work accounts keep Team / Network / combined contexts distinct. Team-only hides Network payout/contact settings; Network navigation exposes Earnings; Team/combined navigation exposes Hours. Both accounts are accessible in the combined context.
- Preserves edit profile, vehicle selection, verification, payout method, Network contact, language, Notifications, help and sign-out confirmation.
- Edits use sheets with deliberate Save / Cancel behavior. Selecting a vehicle or payout option does not commit it. Contact preferences are independent, large toggle rows. Cancel/Escape discards unsaved changes. Save failure retains inputs and displays an error.
- Profile details and preferences save to local storage only. Name/phone input is validated; user-entered text is rendered as text. These edits do not update production identity, login credentials, vehicle eligibility or payment instructions. A production phone change needs the authentication/verification contract; the prototype does not implement it.
- Thai is first in the language chooser. The language preference is saved with the existing `rounds.language` key outside review mode. Review saves use a separate key. These two HTML boards remain English; full Thai rendering and cross-device preference sync remain required later.
- Help retains the original Operations companion links. Those companions contain the existing job fixture; a general account-support conversation is not implemented by this pair. Sign out navigates to the existing entry board and preserves local drafts; there is no server auth session here.

## Interaction and layout checks

- Inline JavaScript syntax, unique IDs, local navigation targets, expected file inventory, unchanged earlier screens and ZIP integrity.
- Node VM checks for chart totals/proportions, day/job/payout details, role context, transactional preference edits, persistence/reload, failed writes and retry, language isolation, modal focus and trusted review routing.
- CSS source inspection for the approved palette/type/control dimensions, flexible narrow-width rows, one content scroller, fixed-size controls and safe-area support. The chart retains 14px amounts/day labels at 320px; the numeric axis is 13px supporting information.
- No browser/device visual test was available. Sunlight, gloves, actual small-phone rendering, native account flows and Thai layout remain to be verified. This pair is a design prototype, not a live earnings or account-management service.

## Storage and sample-data boundaries

`rounds11-profile-v1` stores local profile edits; review uses `rounds11-profile-v1-review`. Language uses `rounds.language` / `rounds.language-review`. The review keys do not overwrite the existing standalone screen preferences. Earnings reads only the selected local payout preference; totals and past payments remain fixed fixture data.

No live payment, message, account update or verification request is sent. All existing screen IDs are retained. The broader coverage backlog remains open, including separate pre-job merchant chat and full Thai parity.
