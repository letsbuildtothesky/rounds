import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

LocationSettings operationalLocationSettings(TargetPlatform platform) {
  if (platform == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 3),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Rounds live location',
        notificationText:
            'Location remains active while the current Round is running.',
        notificationChannelName: 'Rounds active delivery',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
  }

  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    return AppleSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      activityType: ActivityType.automotiveNavigation,
      distanceFilter: 0,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
    );
  }

  return const LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 0,
  );
}
