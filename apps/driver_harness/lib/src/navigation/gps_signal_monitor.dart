import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../permissions/location_access.dart';

/// Distinguishes loss of live GPS samples from location access being disabled.
enum GpsInterruptionKind { signalLost, locationAccessOff }

class GpsNavigationInterruption {
  const GpsNavigationInterruption({
    required this.kind,
    required this.cachedRouteAvailable,
  });

  final GpsInterruptionKind kind;
  final bool cachedRouteAvailable;
}

GpsInterruptionKind classifyGpsInterruption(
  DriverLocationAccessSnapshot access,
) => access.ready
    ? GpsInterruptionKind.signalLost
    : GpsInterruptionKind.locationAccessOff;

/// Reports a GPS interruption when a real position stream stops producing data.
///
/// This deliberately knows nothing about network connectivity. A routing or API
/// failure must not be presented as a GPS failure.
class GpsSignalMonitor {
  GpsSignalMonitor({required this.timeout, required this.onUnavailableChanged});

  final Duration timeout;
  final ValueChanged<bool> onUnavailableChanged;

  Timer? _timer;
  bool _running = false;
  bool _unavailable = false;

  bool get unavailable => _unavailable;

  void start() {
    _running = true;
    _arm();
  }

  void markSample() {
    if (!_running) return;
    _setUnavailable(false);
    _arm();
  }

  void markStreamError() {
    if (!_running) return;
    _timer?.cancel();
    _setUnavailable(true);
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(timeout, () => _setUnavailable(true));
  }

  void _setUnavailable(bool value) {
    if (_unavailable == value) return;
    _unavailable = value;
    onUnavailableChanged(value);
  }
}

Future<GpsNavigationInterruption?> probeGpsRecovery({
  required bool cachedRouteAvailable,
  Duration timeout = const Duration(seconds: 8),
  DriverLocationAccessGateway accessGateway =
      const GeolocatorLocationAccessGateway(),
}) async {
  final access = await accessGateway.inspect();
  if (!access.ready) {
    return GpsNavigationInterruption(
      kind: GpsInterruptionKind.locationAccessOff,
      cachedRouteAvailable: cachedRouteAvailable,
    );
  }
  try {
    await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        timeLimit: timeout,
      ),
    );
    return null;
  } on TimeoutException {
    return GpsNavigationInterruption(
      kind: GpsInterruptionKind.signalLost,
      cachedRouteAvailable: cachedRouteAvailable,
    );
  } catch (_) {
    return GpsNavigationInterruption(
      kind: GpsInterruptionKind.signalLost,
      cachedRouteAvailable: cachedRouteAvailable,
    );
  }
}
