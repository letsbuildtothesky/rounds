import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/generated/driver_ui_metrics.g.dart';
import 'package:rounds_driver_harness/src/app/rounds_harness_app.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';
import 'package:rounds_driver_harness/src/ui/start_shift_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('B00 English follows the measured 393px board and starts once', (
    tester,
  ) async {
    var starts = 0;
    await _pump(
      tester,
      size: const Size(393, 852),
      locale: 'en',
      onStartShift: () async {
        starts += 1;
        return true;
      },
    );

    expect(
      tester.getRect(find.byKey(const Key('b00-topbar'))),
      const Rect.fromLTWH(0, 0, 393, DriverB00Metrics.topBarHeight),
    );
    expect(
      tester.getRect(find.byKey(const Key('b00-bottom-nav'))),
      const Rect.fromLTWH(
        0,
        852 - DriverB00Metrics.bottomNavHeight,
        393,
        DriverB00Metrics.bottomNavHeight,
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('b00-dispatch'))).height,
      DriverB00Metrics.dispatchHeight,
    );
    expect(
      tester.getSize(find.byKey(const Key('b00-start-shift'))).height,
      DriverB00Metrics.startButtonHeight,
    );
    expect(find.text('Starts in 8 min'), findsOneWidget);
    expect(find.text('08:00–17:00'), findsOneWidget);
    expect(find.text('9h scheduled'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/start-shift-english-393x852.png'),
    );

    await tester.tap(find.byKey(const Key('b00-start-shift')));
    await tester.pumpAndSettle();
    expect(starts, 1);
  });

  testWidgets('B00 Thai uses canonical copy and compact geometry', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(320, 720),
      locale: 'th-TH',
      onStartShift: () async => true,
    );

    expect(find.text('ยังไม่เริ่มกะ · UrbanFlowers'), findsOneWidget);
    expect(find.text('เริ่มกะใน 8 นาที'), findsOneWidget);
    expect(find.text('9 ชม. ตามตาราง'), findsOneWidget);
    expect(find.text('กะทีม'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('b00-start-shift'))).height,
      DriverB00Metrics.startButtonHeight,
    );
    expect(tester.getRect(find.byKey(const Key('b00-bottom-nav'))).bottom, 720);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required String locale,
  required Future<bool> Function() onStartShift,
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
      theme: ThemeData(fontFamily: 'Inter', useMaterial3: true),
      home: StartShiftScreen(
        controller: controller,
        session: _session,
        now: DateTime.parse('2026-09-03T00:52:00.000Z'),
        onStartShift: onStartShift,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _session = DriverSessionModel(
  userName: 'Johannes',
  driverId: '98000000-0000-4000-8000-000000000002',
  preferredLocale: 'en',
  teamName: 'UrbanFlowers',
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
  ),
);
