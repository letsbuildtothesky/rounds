import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/generated/driver_ui_metrics.g.dart';
import 'package:rounds_driver_harness/src/app/rounds_harness_app.dart';
import 'package:rounds_driver_harness/src/driver/driver_entry.dart';
import 'package:rounds_driver_harness/src/ui/driver_entry_flow_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('A02 uses the canonical open phone-number instrument', (
    tester,
  ) async {
    final controller = await _pump(tester, DriverEntryStage.phone);
    expect(find.text('Your phone number'), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('entry-topbar'))).height, 68);
    expect(
      tester.getSize(find.byKey(const Key('a02-phone-line'))).height,
      DriverA02A05Metrics.phoneLineHeight,
    );
    expect(find.byKey(const Key('entry-primary-phone')), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/driver-entry-a02-phone-english-393x852.png'),
    );

    await tester.enterText(
      find.byKey(const Key('a02-phone-input')),
      '0812345678',
    );
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('a02-phone-input')))
          .controller
          ?.text,
      '81 234 5678',
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('entry-primary-phone')),
    );
    expect(button.onPressed, isNotNull);
    controller.dispose();
  });

  testWidgets('A03 presents six provider-compatible OTP slots', (tester) async {
    final controller = await _pump(tester, DriverEntryStage.otp);
    expect(find.text('Enter the code'), findsOneWidget);
    final slots = find.descendant(
      of: find.byKey(const Key('a03-otp-slots')),
      matching: find.byType(Container),
    );
    expect(slots, findsWidgets);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/driver-entry-a03-otp-english-393x852.png'),
    );
    await tester.enterText(find.byKey(const Key('a03-otp-input')), '123456');
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('entry-primary-otp')),
    );
    expect(button.onPressed, isNotNull);
    controller.dispose();
  });

  testWidgets(
    'A04 keeps both canonical lanes and opens a bottom invite drawer',
    (tester) async {
      final controller = await _pump(tester, DriverEntryStage.path);
      expect(find.text('How do you drive?'), findsOneWidget);
      expect(find.text('I drive for a business'), findsOneWidget);
      expect(find.text('I drive independently'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/driver-entry-a04-path-english-393x852.png'),
      );

      await tester.tap(find.byKey(const Key('a04-team')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('a05-code-sheet')), findsOneWidget);
      expect(find.text('Enter invite code'), findsOneWidget);
      controller.dispose();
    },
  );

  testWidgets('A05 renders only resolved merchant invitation data', (
    tester,
  ) async {
    final controller = await _pump(
      tester,
      DriverEntryStage.teamInvite,
      invite: _invite,
    );
    expect(find.text('Join UrbanFlowers'), findsNWidgets(2));
    expect(find.text('Bangkok · Delivery team'), findsOneWidget);
    expect(find.text('Invite verified'), findsOneWidget);
    expect(find.text('Use another invite code'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('a05-invite-hero'))).height,
      greaterThan(150),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/driver-entry-a05-invite-english-393x852.png'),
    );
    controller.dispose();
  });
}

Future<HarnessAppController> _pump(
  WidgetTester tester,
  DriverEntryStage stage, {
  DriverTeamInviteModel? invite,
}) async {
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
      debugShowCheckedModeBanner: false,
      theme: buildRoundsDriverTheme(),
      home: DriverEntryFlowScreen(
        controller: controller,
        previewStage: stage,
        previewInvite: invite,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

const _invite = DriverTeamInviteModel(
  id: 'a5000000-0000-4000-8000-000000000001',
  tenantId: 'a5000000-0000-4000-8000-000000000002',
  businessName: 'UrbanFlowers',
  businessInitials: 'UF',
  locationLabel: 'Bangkok · Delivery team',
);
