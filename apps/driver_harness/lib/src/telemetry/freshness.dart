enum PositionFreshness { live, aging, stale, unknown }

class FreshnessPolicy {
  const FreshnessPolicy({
    this.liveThrough = const Duration(seconds: 20),
    this.agingThrough = const Duration(seconds: 45),
    this.staleThrough = const Duration(minutes: 5),
  });

  final Duration liveThrough;
  final Duration agingThrough;
  final Duration staleThrough;

  PositionFreshness classify(DateTime? sourceAt, DateTime now) {
    if (sourceAt == null) return PositionFreshness.unknown;
    final age = now.toUtc().difference(sourceAt.toUtc());
    if (age <= liveThrough) return PositionFreshness.live;
    if (age <= agingThrough) return PositionFreshness.aging;
    if (age <= staleThrough) return PositionFreshness.stale;
    return PositionFreshness.unknown;
  }
}
