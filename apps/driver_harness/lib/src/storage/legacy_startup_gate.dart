/// Isolate-local cold-start guard, NOT an old-client/process migration lock.
/// main prepares before creating the controller/UI. The two existing legacy
/// entry points claim use before any await, preventing a late/in-process copy.
class LegacyStartupGate {
  static final process = LegacyStartupGate();
  bool _used = false;
  bool _preparing = false;
  bool _failed = false;
  bool _prepared = false;

  void claimLegacyUse() {
    if (_preparing || _failed) {
      throw StateError('LEGACY_STARTUP_BLOCKED');
    }
    _used = true;
  }

  Future<T> prepare<T>(Future<T> Function() operation) async {
    if (_used || _preparing || _failed || _prepared) {
      throw StateError('COLD_START_REQUIRED');
    }
    _preparing = true;
    try {
      final result = await operation();
      _prepared = true;
      return result;
    } catch (_) {
      // No fallback to a running legacy controller after an incomplete copy.
      _failed = true;
      rethrow;
    } finally {
      _preparing = false;
    }
  }
}
