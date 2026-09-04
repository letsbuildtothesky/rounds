import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/app_strings.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/generated/driver_ui_metrics.g.dart';
import 'package:rounds_driver_harness/src/app/rounds_harness_app.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';
import 'package:rounds_driver_harness/src/ui/driver_profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('L01 parses authoritative Team and vehicle profile truth', () {
    final session = DriverSessionModel.fromJson({
      'user': {'id': 'user-1', 'displayName': 'Johannes'},
      'driver': {
        'id': 'driver-1',
        'preferredLocale': 'en',
        'vehicleLabel': 'Motorbike + box',
        'vehiclePlate': '1กข 4821',
      },
      'team': {
        'tenantId': 'tenant-1',
        'displayName': 'UrbanFlowers',
        'status': 'active',
      },
    });

    expect(session.teamName, 'UrbanFlowers');
    expect(session.vehicleLabel, 'Motorbike + box');
    expect(session.vehiclePlate, '1กข 4821');
  });

  testWidgets('L01 matches canonical regions and changes real app language', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'driver_locale': 'en',
      'driver_locale_selected': true,
    });
    final controller = await HarnessAppController.create();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: DriverProfileScreen(
          controller: controller,
          session: _session,
          onHome: () {},
          onJobs: () {},
        ),
      ),
    );

    expect(
      tester.getRect(find.byKey(const Key('l01-topbar'))),
      const Rect.fromLTWH(0, 0, 393, DriverL01Metrics.topBarHeight),
    );
    expect(
      tester.getRect(find.byKey(const Key('l01-bottom-nav'))),
      const Rect.fromLTWH(
        0,
        852 - DriverL01Metrics.bottomNavHeight,
        393,
        DriverL01Metrics.bottomNavHeight,
      ),
    );
    expect(find.text('Johannes'), findsOneWidget);
    expect(find.text('UrbanFlowers'), findsOneWidget);
    expect(find.text('Motorbike + box · 1กข 4821'), findsOneWidget);
    expect(find.text('Verified driver'), findsNothing);
    expect(find.text('Payout method'), findsNothing);
    expect(find.text('Network contact'), findsNothing);

    await tester.tap(find.byKey(const Key('l01-language')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('l01-sheet')), findsOneWidget);
    await tester.tap(find.text('ไทย'));
    await tester.pumpAndSettle();
    expect(controller.locale.storageValue, 'th-TH');
    expect(find.text('โปรไฟล์'), findsNWidgets(2));
    expect(find.text('คนขับ'), findsOneWidget);
    expect(find.text('ยานพาหนะ'), findsOneWidget);
    expect(find.text('การอนุญาต'), findsOneWidget);
    expect(find.text('ออกจากระบบ'), findsOneWidget);
    expect(find.text('Profile'), findsNothing);
  });

  testWidgets('L01 Thai board stays usable at the canonical compact width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'driver_locale': 'th-TH',
      'driver_locale_selected': true,
    });
    final controller = await HarnessAppController.create();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: DriverProfileScreen(
          controller: controller,
          session: _session,
          onHome: () {},
          onJobs: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(DriverL01Metrics.sourceThai, contains('DRIVER-PROFILE-TH'));
    expect(
      tester.getRect(find.byKey(const Key('l01-topbar'))),
      const Rect.fromLTWH(0, 0, 320, DriverL01Metrics.topBarHeight),
    );
    expect(find.text('โปรไฟล์'), findsNWidgets(2));
    expect(find.text('UrbanFlowers'), findsOneWidget);
    expect(find.text('คนขับทีม · ใช้งานอยู่'), findsOneWidget);
    expect(find.text('หน้าแรก'), findsOneWidget);
    expect(find.text('งาน'), findsOneWidget);
    expect(find.text('ชั่วโมง'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byKey(const Key('l01-body')), const Offset(0, -520));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('l01-sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('ออกจากระบบ?'), findsOneWidget);
    expect(find.text('ยกเลิก'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('L01 sign-out requires explicit confirmation', (tester) async {
    SharedPreferences.setMockInitialValues({
      'driver_locale': 'en',
      'driver_locale_selected': true,
    });
    final controller = await HarnessAppController.create();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: DriverProfileScreen(
          controller: controller,
          session: _session,
          onHome: () {},
          onJobs: () {},
        ),
      ),
    );

    await tester.drag(find.byKey(const Key('l01-body')), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('l01-sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    expect(find.byKey(const Key('l01-confirm-sign-out')), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('l01-sheet')), findsNothing);
  });
}

const _session = DriverSessionModel(
  userName: 'Johannes',
  driverId: 'driver-1',
  preferredLocale: 'en',
  teamName: 'UrbanFlowers',
  vehicleLabel: 'Motorbike + box',
  vehiclePlate: '1กข 4821',
);
