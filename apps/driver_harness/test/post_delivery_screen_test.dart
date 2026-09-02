import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/generated/driver_ui_metrics.g.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';
import 'package:rounds_driver_harness/src/ui/post_delivery_screen.dart';

void main() {
  test('next operational Stop ignores committed custody work', () {
    expect(nextOperationalStop(_activeRound)?.id, 'stop-2');
    expect(nextOperationalStop(null), isNull);
    expect(
      nextOperationalStop(
        _roundWithStops([
          _stop1,
          _stop2.copyWithState('completed'),
          _stop3.copyWithState('cancelled'),
        ]),
      ),
      isNull,
    );
  });

  testWidgets('F08 uses canonical completion, map and next-Stop regions', (
    tester,
  ) async {
    await _setViewport(tester);
    var navigated = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: StopCompleteNextStopScreen(
          round: _activeRound,
          completedStop: _stop1,
          nextStop: _stop2,
          enableNativeMap: false,
          onNavigate: (_) => navigated = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(const Key('f08-complete-bar'))),
      const Rect.fromLTWH(0, 0, 393, 74),
    );
    expect(
      tester.getRect(find.byKey(const Key('f08-map'))),
      const Rect.fromLTWH(0, 74, 393, 546),
    );
    expect(
      tester.getRect(find.byKey(const Key('f08-next-dock'))),
      const Rect.fromLTWH(0, 620, 393, 232),
    );
    expect(
      tester.getSize(find.byKey(const Key('f08-navigate-next'))).height,
      DriverF08Metrics.primaryHeight,
    );
    expect(find.text('Stop 1 complete'), findsOneWidget);
    expect(find.text('Navigate to Stop 2'), findsOneWidget);
    await expectLater(
      find.byType(StopCompleteNextStopScreen),
      matchesGoldenFile('goldens/stop-complete-next-stop-393x852.png'),
    );

    await tester.tap(find.byKey(const Key('f08-navigate-next')));
    expect(navigated, isTrue);
  });

  testWidgets('F08 remaining work opens the canonical bottom drawer', (
    tester,
  ) async {
    await _setViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: StopCompleteNextStopScreen(
          round: _activeRound,
          completedStop: _stop1,
          nextStop: _stop2,
          enableNativeMap: false,
          onNavigate: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('f08-remaining-stops')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rounds-action-drawer')), findsOneWidget);
    expect(find.text('Remaining stops'), findsOneWidget);
    expect(find.textContaining('3. Anong'), findsOneWidget);
  });

  testWidgets('I01 confirms committed completion and returns to shift', (
    tester,
  ) async {
    await _setViewport(tester);
    var continued = false;
    final completedRound = _roundWithStops([
      _stop1,
      _stop2.copyWithState('completed'),
      _stop3.copyWithState('completed'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: RoundCompleteScreen(
          round: completedRound,
          onContinue: (_) => continued = true,
        ),
      ),
    );

    expect(
      tester.getRect(find.byKey(const Key('i01-topbar'))),
      const Rect.fromLTWH(0, 0, 393, 56),
    );
    expect(
      tester.getSize(find.byKey(const Key('i01-continue'))).height,
      DriverI01Metrics.primaryHeight,
    );
    expect(find.text('3 of 3 delivered'), findsOneWidget);
    expect(find.text('All deliveries committed'), findsOneWidget);
    expect(find.text('Ready for next assignment'), findsOneWidget);
    await expectLater(
      find.byType(RoundCompleteScreen),
      matchesGoldenFile('goldens/round-complete-393x852.png'),
    );

    await tester.tap(find.byKey(const Key('i01-continue')));
    expect(continued, isTrue);
  });

  testWidgets('I01 reports terminal returned or cancelled work truthfully', (
    tester,
  ) async {
    await _setViewport(tester);
    final resolvedRound = _roundWithStops([
      _stop1,
      _stop2.copyWithState('cancelled'),
      _stop3.copyWithState('cancelled'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: RoundCompleteScreen(round: resolvedRound, onContinue: (_) {}),
      ),
    );

    expect(find.text('3 of 3 resolved'), findsOneWidget);
    expect(find.text('1 delivered · 2 formally closed'), findsOneWidget);
    expect(find.text('3 of 3 delivered'), findsNothing);
  });
}

Future<void> _setViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const _stop1 = DriverRoundStopModel(
  id: 'stop-1',
  sequence: 1,
  state: 'completed',
  version: 7,
  destinationVersion: 1,
  manifestId: 'manifest-1',
  manifestVersion: 1,
  deliveryReference: 'UF-001',
  recipientName: 'Siriporn',
  recipientPhone: '+661',
  rawAddress: 'Sukhumvit 39, Bangkok',
  latitude: 13.735,
  longitude: 100.57,
  windowStart: '2026-09-02T02:00:00Z',
  windowEnd: '2026-09-02T03:00:00Z',
  manifestItems: [
    DriverManifestItemModel(lineNumber: 1, description: 'Bouquet', quantity: 1),
  ],
);

const _stop2 = DriverRoundStopModel(
  id: 'stop-2',
  sequence: 2,
  state: 'active',
  version: 4,
  destinationVersion: 1,
  manifestId: 'manifest-2',
  manifestVersion: 1,
  deliveryReference: 'UF-002',
  recipientName: 'James T.',
  recipientPhone: '+662',
  rawAddress: 'The Sukhothai Residences, Sathorn',
  latitude: 13.72,
  longitude: 100.533,
  windowStart: '2026-09-02T03:00:00Z',
  windowEnd: '2026-09-02T04:00:00Z',
  manifestItems: [
    DriverManifestItemModel(
      lineNumber: 1,
      description: 'Signature hamper',
      quantity: 1,
    ),
  ],
);

const _stop3 = DriverRoundStopModel(
  id: 'stop-3',
  sequence: 3,
  state: 'assigned',
  version: 3,
  destinationVersion: 1,
  manifestId: 'manifest-3',
  manifestVersion: 1,
  deliveryReference: 'UF-003',
  recipientName: 'Anong',
  recipientPhone: '+663',
  rawAddress: 'Silom, Bangkok',
  latitude: 13.727,
  longitude: 100.529,
  windowStart: '2026-09-02T04:00:00Z',
  windowEnd: '2026-09-02T05:00:00Z',
  manifestItems: [
    DriverManifestItemModel(lineNumber: 1, description: 'Cake', quantity: 1),
  ],
);

final _activeRound = _roundWithStops([_stop1, _stop2, _stop3]);

DriverRoundModel _roundWithStops(List<DriverRoundStopModel> stops) =>
    DriverRoundModel(
      id: 'round-1',
      reference: 'ROUND-18',
      serviceDate: '2026-09-02',
      state: 'active',
      version: 8,
      tenantName: 'UrbanFlowers',
      pickup: const DriverPickupModel(
        displayName: 'UrbanFlowers · Sukhumvit 39',
        rawAddress: 'Sukhumvit 39, Bangkok',
        contactName: 'Operations',
        contactPhone: '+660',
      ),
      stops: stops,
    );

extension on DriverRoundStopModel {
  DriverRoundStopModel copyWithState(String nextState) => DriverRoundStopModel(
    id: id,
    sequence: sequence,
    state: nextState,
    version: version,
    destinationVersion: destinationVersion,
    manifestId: manifestId,
    manifestVersion: manifestVersion,
    deliveryReference: deliveryReference,
    recipientName: recipientName,
    recipientPhone: recipientPhone,
    rawAddress: rawAddress,
    latitude: latitude,
    longitude: longitude,
    windowStart: windowStart,
    windowEnd: windowEnd,
    manifestItems: manifestItems,
  );
}
