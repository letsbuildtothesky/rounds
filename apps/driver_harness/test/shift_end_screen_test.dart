import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/generated/driver_ui_metrics.g.dart';
import 'package:rounds_driver_harness/src/app/rounds_harness_app.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';
import 'package:rounds_driver_harness/src/ui/assigned_round_screen.dart';
import 'package:rounds_driver_harness/src/ui/shift_end_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('B01D English uses the measured shift-ending board', (
    tester,
  ) async {
    await _pump(
      tester,
      locale: 'en',
      surface: DriverShiftSurface.endingSoon,
      session: _endingSession,
      now: DateTime.parse('2026-09-04T09:45:00.000Z'),
    );

    expect(find.text('Shift ending soon'), findsOneWidget);
    expect(find.text('15 min left'), findsOneWidget);
    expect(find.text('Ends at 17:00 · UrbanFlowers'), findsOneWidget);
    expect(find.text('Siriporn'), findsOneWidget);
    expect(find.text('18 min past shift'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('b01-return-to-delivery'))).height,
      DriverB01DefMetrics.footerPrimaryHeight,
    );
    expect(tester.getRect(find.byKey(const Key('b01-bottom-nav'))).bottom, 852);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/shift-ending-soon-english-393x852.png'),
    );
  });

  testWidgets('B01E Thai derives overtime and route timing from timestamps', (
    tester,
  ) async {
    await _pump(
      tester,
      locale: 'th-TH',
      surface: DriverShiftSurface.overtime,
      session: _workingSession,
      now: DateTime.parse('2026-09-04T10:14:00.000Z'),
    );

    expect(find.text('เกินเวลากะ'), findsOneWidget);
    expect(find.text('+14 นาที'), findsOneWidget);
    expect(find.text('เหลือ 8 นาที'), findsOneWidget);
    expect(find.text('กลับไปส่งงาน'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('B01F English shows factual hours and ends once', (tester) async {
    var ends = 0;
    await _pump(
      tester,
      locale: 'en',
      surface: DriverShiftSurface.endConfirmation,
      session: _completeSession,
      now: DateTime.parse('2026-09-04T10:22:00.000Z'),
      onEndShift: () async {
        ends += 1;
        return true;
      },
    );

    expect(find.text('Ready to end shift?'), findsOneWidget);
    expect(find.text('9h 22m'), findsOneWidget);
    expect(find.text('9h 00m'), findsOneWidget);
    expect(find.text('22m'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('b01-end-shift'))).height,
      DriverB01DefMetrics.actionsPrimaryHeight,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/end-shift-confirm-english-393x852.png'),
    );
    await tester.tap(find.byKey(const Key('b01-end-shift')));
    await tester.pumpAndSettle();
    expect(ends, 1);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required String locale,
  required DriverShiftSurface surface,
  required DriverSessionModel session,
  required DateTime now,
  Future<bool> Function()? onEndShift,
}) async {
  tester.view.physicalSize = const Size(393, 852);
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
      locale: Locale(locale.split('-').first),
      theme: ThemeData(fontFamily: 'Inter', useMaterial3: true),
      home: ShiftEndScreen(
        controller: controller,
        session: session,
        surface: surface,
        enableNativeNavigation: false,
        now: now,
        onEndShift: onEndShift,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _workingRound = DriverRoundModel(
  id: AssignedRoundScreen.demoRound.id,
  reference: AssignedRoundScreen.demoRound.reference,
  serviceDate: AssignedRoundScreen.demoRound.serviceDate,
  state: AssignedRoundScreen.demoRound.state,
  version: AssignedRoundScreen.demoRound.version,
  tenantName: AssignedRoundScreen.demoRound.tenantName,
  pickup: AssignedRoundScreen.demoRound.pickup,
  stops: AssignedRoundScreen.demoRound.stops,
  plannedStops: [
    DriverPlannedStopModel(
      stopId: AssignedRoundScreen.demoRound.stops.single.id,
      eta: DateTime.parse('2026-09-04T10:22:00.000Z'),
      departureAt: DateTime.parse('2026-09-04T10:23:00.000Z'),
      legDurationSeconds: 2220,
    ),
  ],
);

final _workingSession = DriverSessionModel(
  userName: 'Johannes',
  driverId: '97000000-0000-4000-8000-000000000002',
  preferredLocale: 'en',
  teamName: 'UrbanFlowers',
  shift: _shift,
  currentRound: _workingRound,
);

final _endingSession = DriverSessionModel(
  userName: 'Johannes',
  driverId: '97000000-0000-4000-8000-000000000002',
  preferredLocale: 'en',
  teamName: 'UrbanFlowers',
  shift: _shift,
  currentRound: DriverRoundModel(
    id: _workingRound.id,
    reference: _workingRound.reference,
    serviceDate: _workingRound.serviceDate,
    state: _workingRound.state,
    version: _workingRound.version,
    tenantName: _workingRound.tenantName,
    pickup: _workingRound.pickup,
    stops: _workingRound.stops,
    plannedStops: [
      DriverPlannedStopModel(
        stopId: _workingRound.stops.single.id,
        eta: DateTime.parse('2026-09-04T10:18:00.000Z'),
        departureAt: DateTime.parse('2026-09-04T10:19:00.000Z'),
        legDurationSeconds: 1980,
      ),
    ],
  ),
);

final _completeSession = DriverSessionModel(
  userName: 'Johannes',
  driverId: '97000000-0000-4000-8000-000000000002',
  preferredLocale: 'en',
  teamName: 'UrbanFlowers',
  shift: _shift,
);

final _shift = DriverShiftModel(
  effective: DriverEffectiveShiftModel(
    serviceDate: '2026-09-04',
    timezone: 'Asia/Bangkok',
    source: 'recurring',
    startAt: DateTime.parse('2026-09-04T01:00:00.000Z'),
    endAt: DateTime.parse('2026-09-04T10:00:00.000Z'),
    startLocal: '08:00',
    endLocal: '17:00',
    crossesMidnight: false,
  ),
  attendance: DriverShiftAttendanceModel(
    id: '97000000-0000-4000-8000-000000000003',
    version: 1,
    serviceDate: '2026-09-04',
    startedAt: DateTime.parse('2026-09-04T01:00:00.000Z'),
  ),
);
