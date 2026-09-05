# Rounds Phase 0 Driver Harness

Thin Flutter field harness for validating embedded Google Navigation
`TWO_WHEELER` guidance and simultaneous Rounds operational telemetry.

The same pilot client now supports the canonical English Team-driver entry
flow: Thai mobile number, six-digit SMS OTP, driver-path choice, phone-bound
business invitation and explicit Team join. Supabase tokens remain in secure
storage; the app then retrieves the authenticated Round and server-provided
Stop/manifest truth. Assigned Team drivers can verify every
physical manifest line and commit pickup through the server-authoritative
custody command. The canonical My Rounds surface also shows the signed-in
Driver's real current and completed Team Rounds, including durable POD/return
evidence and explicitly planned route figures. The original no-configuration demo
fixture remains available for Phase 0 tests. The measured Team Profile surface
uses the authenticated Driver, active merchant relationship and assigned vehicle
from that same session. It provides the real persisted English/Thai selector,
Round-scoped Operations support and confirmed sign-out without presenting
unimplemented Network, payout, notification or verification claims.

Before assigned work begins, a scheduled Team Driver sees the measured English
or Thai B00 Start Shift board. Its button commits one durable, authenticated
attendance command against the server-resolved effective schedule. Active
custody is never hidden behind this gate. Notifications, Hours and shift-level
contact without a real Round remain inactive until their authoritative
capabilities are implemented.

The Profile permissions entry uses the canonical N01 measurements and inspects
the phone's actual location-service and app-permission state. Denied and
permanently blocked access lead to real OS permission/settings recovery, and
navigation shows that recovery instead of an indefinite loading spinner.
Camera permission remains contextual: a denied POD, damage or acceptance-photo
request opens a settings drawer without claiming that evidence was captured.
Notification permission is not requested until a real push channel is promoted.

Navigation also uses the measured canonical N03 recovery surface. A 30-second
absence of real position samples is treated as GPS signal loss, while disabled
device location or app access remains a separate permission state. The app only
offers a cached route when Google guidance was already running, and Retry GPS
probes a real fix and restarts the operational position stream before dismissing
the interruption.

The pickup screen never claims custody from local button state. Until the API
commit succeeds it remains unconfirmed; durable offline outboxes retain the
pending command and the canonical N02 surface reports it as local work until
the server commit succeeds.

## Local setup

1. Copy `android/local.properties.example` to `android/local.properties` and
   retain Android Studio's existing `sdk.dir` line.
2. Put an Android-restricted Google Maps Platform key in the copied file as
   `MAPS_API_KEY=...`.
3. For iOS, copy `ios/Flutter/Secrets.xcconfig.example` to
   `ios/Flutter/Secrets.xcconfig` and add the iOS-restricted key.
4. Run `flutter pub get`, then `flutter run` with a physical device.

To exercise the remote Phase 0 telemetry path, also pass the project URL and
publishable key as Dart defines. The publishable key is intentionally a client
credential; never use a Supabase secret/service-role key in the app.

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY \
  --dart-define=ROUNDS_API_URL=https://YOUR_API_HOST
```

For local secret handling, the same values may be placed in an ignored JSON
file and supplied with `--dart-define-from-file=.env.local`. Supabase Phone Auth
and an SMS provider must be configured before a real OTP can be delivered.
Team invitations are single-use, expiring, bound to the verified phone number
and stored only as a code digest. The canonical Operations board does not yet
define the merchant-side invitation issuing control, so the Driver app does
not pretend that an invitation was sent.

The real secret files are ignored by Git. The required APIs are Navigation SDK,
Maps SDK for Android, and Maps SDK for iOS. iOS requires Xcode, Swift Package
Manager, and a deployment target of iOS 16 or newer.

## Verification

```sh
flutter analyze
flutter test
flutter build apk --debug
```

Unit and widget tests use a non-native preview surface. A passing APK build is
not field evidence; record physical-device results in
`../../field/ROUNDS-PHASE-0-FIELD-RESULTS-v1.md`.
