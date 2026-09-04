import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/app_strings.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/generated/driver_ui_metrics.g.dart';
import 'package:rounds_driver_harness/src/app/rounds_harness_app.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';
import 'package:rounds_driver_harness/src/ui/pickup_navigation_screen.dart';
import 'package:rounds_driver_harness/src/ui/team_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('root lifecycle selects B01, B01B, then E01 from server state', () {
    expect(driverOperationalHome(_session()), DriverOperationalHome.waiting);
    expect(
      driverOperationalHome(_session(round: _round)),
      DriverOperationalHome.assigned,
    );
    expect(
      driverOperationalHome(_session(round: _copyRound(state: 'loading'))),
      DriverOperationalHome.assigned,
    );
    expect(
      driverOperationalHome(_session(round: _copyRound(state: 'active'))),
      DriverOperationalHome.activeRound,
    );
  });

  testWidgets('B01 waiting home follows the measured English board', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(393, 852),
      locale: 'en',
      screen: (controller) => TeamHomeScreen(
        controller: controller,
        session: _session(),
        enableNativeNavigation: false,
        now: DateTime.parse('2026-09-03T02:41:00.000Z'),
      ),
    );

    expect(
      tester.getRect(find.byKey(const Key('b01-topbar'))),
      const Rect.fromLTWH(0, 0, 393, DriverB01HomeMetrics.topBarHeight),
    );
    expect(
      tester.getRect(find.byKey(const Key('b01-bottom-nav'))),
      const Rect.fromLTWH(
        0,
        852 - DriverB01HomeMetrics.bottomNavHeight,
        393,
        DriverB01HomeMetrics.bottomNavHeight,
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('b01-dispatch'))).height,
      DriverB01HomeMetrics.waitingDispatchHeight,
    );
    expect(find.text('On shift · UrbanFlowers'), findsOneWidget);
    expect(find.text('Waiting for assignment'), findsOneWidget);
    expect(find.text('7h 19m left'), findsOneWidget);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/team-home-waiting-english-393x852.png'),
    );
  });

  testWidgets('B01B assigned home uses real data and enters D01 on demand', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(393, 852),
      locale: 'en',
      screen: (controller) => TeamHomeScreen(
        controller: controller,
        session: _session(round: _round),
        round: _round,
        enableNativeNavigation: false,
      ),
    );

    expect(find.text('Round assigned'), findsOneWidget);
    expect(find.text('Pickup next'), findsOneWidget);
    expect(find.text('Sukhumvit 39'), findsOneWidget);
    expect(find.text('2.8 km'), findsNothing);
    expect(find.text('9 min'), findsNothing);
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('4 stops · 18.6 km · ~58 min'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('b01b-navigate'))).height,
      DriverB01HomeMetrics.assignedPrimaryHeight,
    );
    expect(
      tester.getRect(find.byKey(const Key('b01-bottom-nav'))),
      const Rect.fromLTWH(
        0,
        852 - DriverB01HomeMetrics.bottomNavHeight,
        393,
        DriverB01HomeMetrics.bottomNavHeight,
      ),
    );
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/team-home-assigned-english-393x852.png'),
    );

    await tester.tap(find.byKey(const Key('b01b-navigate')));
    await tester.pumpAndSettle();
    expect(find.byType(PickupNavigationScreen), findsOneWidget);
  });

  testWidgets('B01B Thai is canonical and usable at compact width', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(320, 720),
      locale: 'th-TH',
      screen: (controller) => TeamHomeScreen(
        controller: controller,
        session: _session(round: _round),
        round: _round,
        enableNativeNavigation: false,
      ),
    );

    expect(find.text('ได้รับรอบแล้ว'), findsOneWidget);
    expect(find.text('ไปรับของ'), findsOneWidget);
    expect(find.text('นำทางไปรับของ'), findsOneWidget);
    expect(find.text('หน้าแรก'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required String locale,
  required Widget Function(HarnessAppController controller) screen,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'driver_locale': locale,
    'driver_locale_selected': true,
  });
  final controller = await HarnessAppController.create();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: controller.locale.locale,
      theme: buildRoundsDriverTheme(),
      home: screen(controller),
    ),
  );
  await tester.pumpAndSettle();
}

DriverSessionModel _session({DriverRoundModel? round}) => DriverSessionModel(
  userName: 'Johannes',
  driverId: 'driver-1',
  preferredLocale: 'en',
  teamName: 'UrbanFlowers',
  currentRound: round,
  shift: DriverShiftModel(
    effective: DriverEffectiveShiftModel(
      serviceDate: '2026-09-03',
      timezone: 'Asia/Bangkok',
      source: 'recurring',
      startAt: DateTime.parse('2026-09-03T01:00:00.000Z'),
      endAt: DateTime.parse('2026-09-03T10:00:00.000Z'),
      startLocal: '08:00',
      endLocal: '17:00',
      crossesMidnight: false,
    ),
    attendance: DriverShiftAttendanceModel(
      id: 'attendance-1',
      version: 1,
      serviceDate: '2026-09-03',
      startedAt: DateTime.parse('2026-09-03T01:00:00.000Z'),
    ),
  ),
);

DriverRoundModel _copyRound({required String state}) => DriverRoundModel(
  id: _round.id,
  reference: _round.reference,
  serviceDate: _round.serviceDate,
  state: state,
  version: _round.version,
  tenantName: _round.tenantName,
  pickup: _round.pickup,
  stops: _round.stops,
  plannedDistanceMeters: _round.plannedDistanceMeters,
  plannedDurationSeconds: _round.plannedDurationSeconds,
);

const _round = DriverRoundModel(
  id: 'round-1',
  reference: 'ROUND-001',
  serviceDate: '2026-09-03',
  state: 'approved',
  version: 3,
  tenantName: 'UrbanFlowers',
  plannedDistanceMeters: 18600,
  plannedDurationSeconds: 3480,
  pickup: DriverPickupModel(
    id: 'pickup-1',
    displayName: 'UrbanFlowers',
    rawAddress: 'Sukhumvit 39, Bangkok',
    contactName: 'UrbanFlowers Dispatch',
    contactPhone: '+6625554400',
    latitude: 13.7338,
    longitude: 100.5766,
  ),
  stops: [
    DriverRoundStopModel(
      id: 'stop-1',
      sequence: 1,
      state: 'assigned',
      version: 1,
      destinationVersion: 1,
      manifestId: 'manifest-1',
      manifestVersion: 1,
      deliveryReference: 'UF-001',
      recipientName: 'Siriporn',
      recipientPhone: '+66999999999',
      rawAddress: 'Wireless Road, Bangkok',
      latitude: 13.7439,
      longitude: 100.547,
      windowStart: '2026-09-03T05:00:00Z',
      windowEnd: '2026-09-03T10:00:00Z',
      manifestItems: [
        DriverManifestItemModel(
          lineNumber: 1,
          description: 'Flowers',
          quantity: 1,
        ),
        DriverManifestItemModel(
          lineNumber: 2,
          description: 'Cake',
          quantity: 1,
        ),
      ],
    ),
    DriverRoundStopModel(
      id: 'stop-2',
      sequence: 2,
      state: 'assigned',
      version: 1,
      destinationVersion: 1,
      manifestId: 'manifest-2',
      manifestVersion: 1,
      deliveryReference: 'UF-002',
      recipientName: 'Anong',
      recipientPhone: '+66999999998',
      rawAddress: 'Sathorn Road, Bangkok',
      latitude: 13.72,
      longitude: 100.53,
      windowStart: '2026-09-03T06:00:00Z',
      windowEnd: '2026-09-03T11:00:00Z',
      manifestItems: [],
    ),
    DriverRoundStopModel(
      id: 'stop-3',
      sequence: 3,
      state: 'assigned',
      version: 1,
      destinationVersion: 1,
      manifestId: 'manifest-3',
      manifestVersion: 1,
      deliveryReference: 'UF-003',
      recipientName: 'Mali',
      recipientPhone: '+66999999997',
      rawAddress: 'Silom Road, Bangkok',
      latitude: 13.73,
      longitude: 100.52,
      windowStart: '2026-09-03T07:00:00Z',
      windowEnd: '2026-09-03T12:00:00Z',
      manifestItems: [],
    ),
    DriverRoundStopModel(
      id: 'stop-4',
      sequence: 4,
      state: 'assigned',
      version: 1,
      destinationVersion: 1,
      manifestId: 'manifest-4',
      manifestVersion: 1,
      deliveryReference: 'UF-004',
      recipientName: 'Nok',
      recipientPhone: '+66999999996',
      rawAddress: 'Rama IV Road, Bangkok',
      latitude: 13.74,
      longitude: 100.51,
      windowStart: '2026-09-03T08:00:00Z',
      windowEnd: '2026-09-03T13:00:00Z',
      manifestItems: [],
    ),
  ],
);
