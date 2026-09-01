import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/navigation/navigation_intent.dart';

class MemoryIntentStore implements NavigationIntentStore {
  final Map<String, NavigationIntent> values = {};

  @override
  Future<NavigationIntent?> find(String stopId, int destinationVersion) async =>
      values['$stopId:$destinationVersion'];

  @override
  Future<void> save(NavigationIntent intent) async {
    values[intent.logicalKey] = intent;
  }
}

void main() {
  test(
    'same Stop version reattaches without a new destination intent',
    () async {
      final store = MemoryIntentStore();
      final ledger = NavigationIntentLedger(store);
      var sessionsCreated = 0;

      final first = await ledger.attachOrCreate(
        stopId: 'stop-1',
        destinationVersion: 1,
        destinationFingerprint: '13.7,100.5',
        createSessionId: () => 'session-${++sessionsCreated}',
        now: DateTime.utc(2026, 9, 1, 1),
      );
      final recovered = await ledger.attachOrCreate(
        stopId: 'stop-1',
        destinationVersion: 1,
        destinationFingerprint: '13.7,100.5',
        createSessionId: () => 'session-${++sessionsCreated}',
        now: DateTime.utc(2026, 9, 1, 2),
      );

      expect(first.isNew, isTrue);
      expect(recovered.isNew, isFalse);
      expect(recovered.intent.navSessionId, first.intent.navSessionId);
      expect(sessionsCreated, 1);
    },
  );

  test('new destination version creates a new logical intent', () async {
    final store = MemoryIntentStore();
    final ledger = NavigationIntentLedger(store);
    var sessionsCreated = 0;

    await ledger.attachOrCreate(
      stopId: 'stop-1',
      destinationVersion: 1,
      destinationFingerprint: 'old',
      createSessionId: () => 'session-${++sessionsCreated}',
      now: DateTime.utc(2026, 9, 1),
    );
    final changed = await ledger.attachOrCreate(
      stopId: 'stop-1',
      destinationVersion: 2,
      destinationFingerprint: 'new',
      createSessionId: () => 'session-${++sessionsCreated}',
      now: DateTime.utc(2026, 9, 2),
    );

    expect(changed.isNew, isTrue);
    expect(sessionsCreated, 2);
  });
}
