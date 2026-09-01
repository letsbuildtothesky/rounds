class NavigationIntent {
  const NavigationIntent({
    required this.stopId,
    required this.destinationVersion,
    required this.navSessionId,
    required this.destinationFingerprint,
    required this.createdAt,
    required this.lastAttachedAt,
  });

  final String stopId;
  final int destinationVersion;
  final String navSessionId;
  final String destinationFingerprint;
  final DateTime createdAt;
  final DateTime lastAttachedAt;

  String get logicalKey => '$stopId:$destinationVersion';

  NavigationIntent reattachedAt(DateTime time) => NavigationIntent(
    stopId: stopId,
    destinationVersion: destinationVersion,
    navSessionId: navSessionId,
    destinationFingerprint: destinationFingerprint,
    createdAt: createdAt,
    lastAttachedAt: time,
  );
}

abstract interface class NavigationIntentStore {
  Future<NavigationIntent?> find(String stopId, int destinationVersion);
  Future<void> save(NavigationIntent intent);
}

class NavigationIntentLedger {
  const NavigationIntentLedger(this.store);

  final NavigationIntentStore store;

  Future<({NavigationIntent intent, bool isNew})> attachOrCreate({
    required String stopId,
    required int destinationVersion,
    required String destinationFingerprint,
    required String Function() createSessionId,
    required DateTime now,
  }) async {
    final existing = await store.find(stopId, destinationVersion);
    if (existing != null &&
        existing.destinationFingerprint == destinationFingerprint) {
      final reattached = existing.reattachedAt(now);
      await store.save(reattached);
      return (intent: reattached, isNew: false);
    }

    final created = NavigationIntent(
      stopId: stopId,
      destinationVersion: destinationVersion,
      navSessionId: createSessionId(),
      destinationFingerprint: destinationFingerprint,
      createdAt: now,
      lastAttachedAt: now,
    );
    await store.save(created);
    return (intent: created, isNew: true);
  }
}
