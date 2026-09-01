# Rounds Phase 0 Driver Harness

Thin Flutter field harness for validating embedded Google Navigation
`TWO_WHEELER` guidance and simultaneous Rounds operational telemetry.

The same pilot client now supports an English Slice 1 Team-driver sign-in,
secure token/refresh-token persistence, authenticated Round retrieval and
server-provided Stop/manifest rendering. Assigned Team drivers can verify every
physical manifest line and commit pickup through the server-authoritative
custody command. The original no-configuration demo
fixture remains available for Phase 0 tests.

The pickup screen never claims custody from local button state. Until the API
commit succeeds it remains unconfirmed; durable offline outbox support is the
next Driver reliability checkpoint.

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

The current pilot entry method is email/password for controlled Team accounts.
The production Thailand authentication method remains a pre-pilot decision;
phone OTP can replace the entry method without changing Round contracts or
assignment state.

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
