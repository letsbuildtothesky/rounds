# Slice 2 · Checkpoint 32

**Status:** canonical English H01 URL and Copy behavior implemented

**Date:** 2026-09-04

## Implemented

- Detects HTTP, HTTPS and `www` URLs inside ordinary human message text.
- Renders the URL as an underlined action and opens it through the device's
  explicit external browser handoff.
- Preserves surrounding sentence punctuation instead of accidentally including
  it in the destination URL.
- Adds the canonical long-press Copy behavior for the original complete human
  message.
- Does not add a Link attachment action; the canonical specification explicitly
  treats links as ordinary message text.

## Verification

- Flutter static analysis passes with no issues.
- All 141 Driver tests pass.
- Parser tests cover HTTP(S), `www`, punctuation preservation and ordinary
  non-link text.
- Existing H01 draft and geometry tests continue to pass.
- The protected debug APK builds, installs and launches on the connected
  Samsung `SM-S928B`.

## Honest remaining boundary

- This is link detection and external opening, not a fetched rich-preview card.
- Photo, file, location and voice remain absent until their durable offline
  evidence/upload/server projection exists. GAP-009 still controls production
  retention.
- Physical Samsung URL-open and long-press Copy acceptance remains open.

## Next safe work

- Complete the real durable H01 location-attachment vertical slice, which does
  not require media-byte retention, before exposing Camera, Photo, File or Voice.
