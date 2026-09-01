enum RouteAttemptTrigger { automatic, manualTwoWheeler, drivingDiagnostic }

class RouteAttemptClaim {
  const RouteAttemptClaim({required this.number, required this.trigger});

  final int number;
  final RouteAttemptTrigger trigger;
}

/// Prevents a failed route request from being retried by every location update.
///
/// The first road-snapped location may claim one automatic attempt. Every later
/// attempt must be a deliberate user action.
class RouteAttemptGate {
  bool _automaticAttemptClaimed = false;
  bool _inFlight = false;
  int _attemptCount = 0;

  bool get inFlight => _inFlight;
  int get attemptCount => _attemptCount;

  RouteAttemptClaim? claimAutomatic() {
    if (_automaticAttemptClaimed || _inFlight) return null;
    _automaticAttemptClaimed = true;
    return _claim(RouteAttemptTrigger.automatic);
  }

  RouteAttemptClaim? claimManual(RouteAttemptTrigger trigger) {
    if (trigger == RouteAttemptTrigger.automatic || _inFlight) return null;
    return _claim(trigger);
  }

  void restoreActiveNavigation() {
    _automaticAttemptClaimed = true;
  }

  void complete() {
    _inFlight = false;
  }

  RouteAttemptClaim _claim(RouteAttemptTrigger trigger) {
    _inFlight = true;
    _attemptCount += 1;
    return RouteAttemptClaim(number: _attemptCount, trigger: trigger);
  }
}
