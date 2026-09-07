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
          debugShowCheckedModeBanner: false,
          theme: buildRoundsDriverTheme(),
          home: LiveDeliveryChangeScreen(
            round: AssignedRoundScreen.demoRound,
            stop: AssignedRoundScreen.demoRound.stops.single,
            change: _change,
            now: _now,
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
      expect(find.text('Use Gate B for this delivery.'), findsOneWidget);
      expect(find.text('Tower A lobby'), findsOneWidget);
      expect(find.text('Gate B'), findsAtLeastNWidgets(1));
      expect(find.text('14 min'), findsOneWidget);
      expect(find.text('+2 min'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/live-delivery-change-entrance-english-393x852.png',
        ),
      );

      await tester.tap(find.byKey(const Key('e04-contact-operations')));
      await tester.pumpAndSettle();
      expect(find.text('Operations thread'), findsOneWidget);
      Navigator.of(tester.element(find.text('Operations thread'))).pop();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('e04-acknowledge')));
      await tester.tap(find.byKey(const Key('e04-acknowledge')));
      await tester.pump();
      expect(acknowledged, isTrue);
    },
  );

  for (final scenario in _canonicalVariants) {
    testWidgets('E04-E06 locks the canonical ${scenario.name} English state', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final round = _roundWithStopCount(scenario.stopCount);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildRoundsDriverTheme(),
          home: LiveDeliveryChangeScreen(
            round: round,
            stop: round.stops.first,
            change: scenario.change,
            now: _now,
            enableNativeMap: false,
            onAcknowledge: () async =>
                const DriverCommandOutcome(DriverCommandDisposition.committed),
            contactScreenBuilder: (_) => const SizedBox.shrink(),
          ),
        ),
      );

      expect(find.text(scenario.headline), findsOneWidget);
      expect(find.text(scenario.subline), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/${scenario.goldenName}'),
      );
    });
  }

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
    etaAfter: '2026-09-03T06:20:00Z',
  ),
);

final _canonicalVariants = [
  _CanonicalVariant(
    name: 'destination',
    headline: 'Destination changed',
    subline: 'Navigate to the new delivery point.',
    goldenName: 'live-delivery-change-address-english-393x852.png',
    change: DriverLiveDeliveryChangeModel(
      id: 'change-address',
      changeVersion: 1,
      roundId: 'ROUND-DEMO',
      stopId: 'STOP-001',
      appliedAt: _appliedAt,
      before: const DriverLiveDeliveryValuesModel(
        sequence: 1,
        rawAddress: 'The Emporio Place',
        latitude: 13.7246,
        longitude: 100.5669,
        windowStart: '2026-09-03T08:30:00Z',
        windowEnd: '2026-09-03T09:00:00Z',
      ),
      after: const DriverLiveDeliveryValuesModel(
        sequence: 1,
        rawAddress: 'Sukhumvit 24 · Gate B',
        latitude: 13.7254,
        longitude: 100.5686,
        windowStart: '2026-09-03T08:30:00Z',
        windowEnd: '2026-09-03T09:00:00Z',
      ),
      impact: const DriverLiveDeliveryImpactModel(
        distanceDeltaMeters: 420,
        durationDeltaSeconds: 240,
        downstreamStopCount: 0,
        promiseStatus: 'safe',
        shiftSafe: true,
        etaAfter: '2026-09-03T06:22:00Z',
      ),
    ),
  ),
  _CanonicalVariant(
    name: 'stop-order',
    headline: 'Stop order changed',
    subline: 'Siriporn is now your next stop.',
    goldenName: 'live-delivery-change-sequence-english-393x852.png',
    stopCount: 4,
    change: DriverLiveDeliveryChangeModel(
      id: 'change-sequence',
      changeVersion: 1,
      roundId: 'ROUND-DEMO',
      stopId: 'STOP-001',
      appliedAt: _appliedAt,
      before: const DriverLiveDeliveryValuesModel(
        sequence: 2,
        rawAddress: 'Sukhumvit 24',
        latitude: 13.7246,
        longitude: 100.5669,
        windowStart: '2026-09-03T08:30:00Z',
        windowEnd: '2026-09-03T09:00:00Z',
      ),
      after: const DriverLiveDeliveryValuesModel(
        sequence: 1,
        rawAddress: 'Sukhumvit 24',
        latitude: 13.7246,
        longitude: 100.5669,
        windowStart: '2026-09-03T08:30:00Z',
        windowEnd: '2026-09-03T09:00:00Z',
      ),
      impact: const DriverLiveDeliveryImpactModel(
        distanceDeltaMeters: 300,
        durationDeltaSeconds: 180,
        downstreamStopCount: 3,
        promiseStatus: 'safe',
        shiftSafe: true,
        etaAfter: '2026-09-03T06:21:00Z',
      ),
    ),
  ),
  _CanonicalVariant(
    name: 'delivery-window',
    headline: 'Delivery window changed',
    subline: 'The promised window is now later.',
    goldenName: 'live-delivery-change-window-english-393x852.png',
    change: DriverLiveDeliveryChangeModel(
      id: 'change-window',
      changeVersion: 1,
      roundId: 'ROUND-DEMO',
      stopId: 'STOP-001',
      appliedAt: _appliedAt,
      before: const DriverLiveDeliveryValuesModel(
        sequence: 1,
        rawAddress: 'Sukhumvit 24',
        latitude: 13.7246,
        longitude: 100.5669,
        windowStart: '2026-09-03T08:30:00Z',
        windowEnd: '2026-09-03T09:00:00Z',
      ),
      after: const DriverLiveDeliveryValuesModel(
        sequence: 1,
        rawAddress: 'Sukhumvit 24',
        latitude: 13.7246,
        longitude: 100.5669,
        windowStart: '2026-09-03T09:00:00Z',
        windowEnd: '2026-09-03T09:30:00Z',
      ),
      impact: const DriverLiveDeliveryImpactModel(
        distanceDeltaMeters: 0,
        durationDeltaSeconds: 0,
        downstreamStopCount: 0,
        promiseStatus: 'safe',
        shiftSafe: true,
        etaAfter: '2026-09-03T06:20:00Z',
      ),
    ),
  ),
];

final _now = DateTime.parse('2026-09-03T06:06:00Z');

DriverRoundModel _roundWithStopCount(int count) {
  final source = AssignedRoundScreen.demoRound;
  return DriverRoundModel(
    id: source.id,
    reference: source.reference,
    serviceDate: source.serviceDate,
    state: source.state,
    version: source.version,
    tenantName: source.tenantName,
    pickup: source.pickup,
    stops: List<DriverRoundStopModel>.filled(count, source.stops.single),
  );
}

class _CanonicalVariant {
  const _CanonicalVariant({
    required this.name,
    required this.headline,
    required this.subline,
    required this.goldenName,
    required this.change,
    this.stopCount = 1,
  });

  final String name;
  final String headline;
  final String subline;
  final String goldenName;
  final DriverLiveDeliveryChangeModel change;
  final int stopCount;
}

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
