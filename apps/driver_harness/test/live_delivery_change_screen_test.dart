import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/driver/driver_api.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';
import 'package:rounds_driver_harness/src/ui/assigned_round_screen.dart';
import 'package:rounds_driver_harness/src/ui/live_delivery_change_screen.dart';

void main() {
  testWidgets(
    'E04-E06 uses canonical geometry and actual server change truth',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var acknowledged = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildRoundsDriverTheme(),
          home: LiveDeliveryChangeScreen(
            round: AssignedRoundScreen.demoRound,
            stop: AssignedRoundScreen.demoRound.stops.single,
            change: _change,
            enableNativeMap: false,
            onAcknowledge: () async {
              acknowledged = true;
              return const DriverCommandOutcome(
                DriverCommandDisposition.committed,
              );
            },
            contactScreenBuilder: (_) =>
                const Scaffold(body: Text('Operations thread')),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(const Key('e04-topbar'))).height, 64);
      expect(tester.getSize(find.byKey(const Key('e04-map'))).height, 370);
      expect(
        tester.getTopLeft(find.byKey(const Key('e04-update-panel'))).dy,
        434,
      );
      expect(find.text('Entrance changed'), findsOneWidget);
      expect(find.text('Tower A lobby'), findsOneWidget);
      expect(find.text('Gate B'), findsAtLeastNWidgets(1));
      expect(find.text('+2 min'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('e04-acknowledge')));
      await tester.tap(find.byKey(const Key('e04-acknowledge')));
      await tester.pump();
      expect(acknowledged, isTrue);
    },
  );

  testWidgets('E04-E06 represents every changed field without interpretation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: LiveDeliveryChangeScreen(
          round: AssignedRoundScreen.demoRound,
          stop: AssignedRoundScreen.demoRound.stops.single,
          change: _multiChange,
          enableNativeMap: false,
          onAcknowledge: () async =>
              const DriverCommandOutcome(DriverCommandDisposition.committed),
          contactScreenBuilder: (_) => const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.text('Delivery updated'), findsOneWidget);
    expect(find.text('Next stop'), findsOneWidget);
    expect(find.text('Address'), findsOneWidget);
    expect(find.text('Window'), findsOneWidget);
    expect(find.text('Stop 1'), findsOneWidget);
    expect(find.text('Stop 2'), findsOneWidget);
  });
}

final _change = DriverLiveDeliveryChangeModel(
  id: 'change-1',
  changeVersion: 1,
  roundId: 'ROUND-DEMO',
  stopId: 'STOP-001',
  appliedAt: _appliedAt,
  before: const DriverLiveDeliveryValuesModel(
    sequence: 1,
    rawAddress: 'Sukhumvit 24',
    latitude: 13.7246,
    longitude: 100.5669,
    accessNote: 'Tower A lobby',
    windowStart: '2026-09-03T08:30:00Z',
    windowEnd: '2026-09-03T09:00:00Z',
  ),
  after: const DriverLiveDeliveryValuesModel(
    sequence: 1,
    rawAddress: 'Sukhumvit 24',
    latitude: 13.7246,
    longitude: 100.5669,
    accessNote: 'Gate B',
    windowStart: '2026-09-03T08:30:00Z',
    windowEnd: '2026-09-03T09:00:00Z',
  ),
  impact: const DriverLiveDeliveryImpactModel(
    distanceDeltaMeters: 0,
    durationDeltaSeconds: 120,
    downstreamStopCount: 0,
    promiseStatus: 'safe',
    shiftSafe: true,
  ),
);

final _multiChange = DriverLiveDeliveryChangeModel(
  id: 'change-2',
  changeVersion: 1,
  roundId: 'ROUND-DEMO',
  stopId: 'STOP-001',
  appliedAt: _appliedAt,
  before: const DriverLiveDeliveryValuesModel(
    sequence: 1,
    rawAddress: 'Old address',
    latitude: 13.7246,
    longitude: 100.5669,
    windowStart: '2026-09-03T08:30:00Z',
    windowEnd: '2026-09-03T09:00:00Z',
  ),
  after: const DriverLiveDeliveryValuesModel(
    sequence: 2,
    rawAddress: 'New address',
    latitude: 13.7254,
    longitude: 100.5686,
    windowStart: '2026-09-03T09:00:00Z',
    windowEnd: '2026-09-03T09:30:00Z',
  ),
  impact: const DriverLiveDeliveryImpactModel(
    distanceDeltaMeters: 420,
    durationDeltaSeconds: 180,
    downstreamStopCount: 1,
    promiseStatus: 'safe',
    shiftSafe: true,
  ),
);

final _appliedAt = DateTime.fromMillisecondsSinceEpoch(1788400000000);
