import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rounds_driver_harness/src/telemetry/operational_location_settings.dart';

void main() {
  test('Android operational tracking uses a persistent foreground service', () {
    final settings = operationalLocationSettings(TargetPlatform.android);

    expect(settings, isA<AndroidSettings>());
    final android = settings as AndroidSettings;
    expect(android.accuracy, LocationAccuracy.bestForNavigation);
    expect(android.intervalDuration, const Duration(seconds: 3));
    expect(android.foregroundNotificationConfig, isNotNull);
    expect(android.foregroundNotificationConfig!.enableWakeLock, isTrue);
    expect(android.foregroundNotificationConfig!.setOngoing, isTrue);
  });

  test('iOS operational tracking does not pause automatically', () {
    final settings = operationalLocationSettings(TargetPlatform.iOS);

    expect(settings, isA<AppleSettings>());
    final apple = settings as AppleSettings;
    expect(apple.accuracy, LocationAccuracy.bestForNavigation);
    expect(apple.pauseLocationUpdatesAutomatically, isFalse);
    expect(apple.activityType, ActivityType.automotiveNavigation);
  });
}
