import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/telemetry/freshness.dart';

void main() {
  test('freshness never claims an old sample is live', () {
    const policy = FreshnessPolicy();
    final now = DateTime.utc(2026, 9, 1, 7, 10);

    expect(policy.classify(null, now), PositionFreshness.unknown);
    expect(
      policy.classify(now.subtract(const Duration(seconds: 10)), now),
      PositionFreshness.live,
    );
    expect(
      policy.classify(now.subtract(const Duration(seconds: 30)), now),
      PositionFreshness.aging,
    );
    expect(
      policy.classify(now.subtract(const Duration(minutes: 2)), now),
      PositionFreshness.stale,
    );
    expect(
      policy.classify(now.subtract(const Duration(minutes: 10)), now),
      PositionFreshness.unknown,
    );
  });
}
