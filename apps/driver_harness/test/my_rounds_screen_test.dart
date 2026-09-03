import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/generated/driver_ui_metrics.g.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';
import 'package:rounds_driver_harness/src/ui/my_rounds_screen.dart';

void main() {
  test('J01 parses real completed Round evidence', () {
    final session = DriverSessionModel.fromJson({
      'user': {'id': 'user-1', 'displayName': 'Johannes'},
      'driver': {'id': 'driver-1', 'preferredLocale': 'en'},
      'completedRounds': [
        {
          'id': 'round-complete',
          'reference': 'ROUND-001',
          'serviceDate': '2026-09-03',
          'tenant': {
            'id': 'tenant-1',
            'displayName': 'UrbanFlowers',
            'timezone': 'Asia/Bangkok',
          },
          'completedAt': '2026-09-03T06:06:00.000Z',
          'stopCount': 1,
          'deliveredStopCount': 1,
          'formallyClosedStopCount': 0,
          'podCount': 1,
          'plannedDistanceMeters': 4800,
          'plannedDurationSeconds': 2460,
        },
      ],
    });

    expect(session.completedRounds.single.evidenceLabel, 'POD saved');
    expect(session.completedRounds.single.plannedDistanceMeters, 4800);
  });

  testWidgets('J01 follows canonical geometry and opens real evidence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var returned = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: MyRoundsScreen(
          session: _session,
          onReturnToRound: () => returned = true,
        ),
      ),
    );

    expect(
      tester.getRect(find.byKey(const Key('j01-topbar'))),
      const Rect.fromLTWH(0, 0, 393, DriverJ01Metrics.topBarHeight),
    );
    expect(
      tester.getRect(find.byKey(const Key('j01-bottom-nav'))),
      const Rect.fromLTWH(
        0,
        852 - DriverJ01Metrics.bottomNavHeight,
        393,
        DriverJ01Metrics.bottomNavHeight,
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('j01-return-round'))).height,
      DriverJ01Metrics.activeButtonHeight,
    );
    expect(find.text('Stop 1 of 1'), findsOneWidget);
    expect(find.text('POD saved'), findsOneWidget);
    expect(find.text('Khao Soi House'), findsNothing);
    expect(find.text('฿185'), findsNothing);

    await tester.tap(find.byKey(const Key('j01-completed-round-complete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('j01-evidence-sheet')), findsOneWidget);
    expect(find.text('Planned distance'), findsOneWidget);
    expect(find.text('4.8 km'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('j01-return-round')));
    expect(returned, isTrue);
  });
}

final _session = DriverSessionModel(
  userName: 'Johannes',
  driverId: 'driver-1',
  preferredLocale: 'en',
  currentRound: DriverRoundModel(
    id: 'round-active',
    reference: 'ROUND-ACTIVE',
    serviceDate: '2026-09-03',
    state: 'active',
    version: 3,
    tenantName: 'UrbanFlowers',
    plannedDistanceMeters: 3900,
    plannedDurationSeconds: 660,
    pickup: DriverPickupModel(
      displayName: 'UrbanFlowers',
      rawAddress: 'Sukhumvit 39',
      contactName: 'Operations',
      contactPhone: '+66000000000',
    ),
    stops: [
      DriverRoundStopModel(
        id: 'stop-active',
        sequence: 1,
        state: 'en_route',
        version: 2,
        destinationVersion: 1,
        manifestId: 'manifest-active',
        manifestVersion: 1,
        deliveryReference: 'UF-001',
        recipientName: 'Siriporn',
        recipientPhone: '+66999999999',
        rawAddress: 'Wireless Road',
        latitude: 13.73,
        longitude: 100.54,
        windowStart: '2026-09-03T05:00:00Z',
        windowEnd: '2026-09-03T07:00:00Z',
        manifestItems: [],
      ),
    ],
  ),
  completedRounds: [
    DriverCompletedRoundModel(
      id: 'round-complete',
      reference: 'ROUND-001',
      serviceDate: '2026-09-03',
      tenantName: 'UrbanFlowers',
      completedAt: DateTime.utc(2026, 9, 3, 6, 6),
      stopCount: 1,
      deliveredStopCount: 1,
      formallyClosedStopCount: 0,
      podCount: 1,
      plannedDistanceMeters: 4800,
      plannedDurationSeconds: 2460,
    ),
  ],
);
