import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/app_strings.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/harness_app_controller.dart';
import 'package:rounds_driver_harness/src/storage/delivery_problem_photo_store.dart';
import 'package:rounds_driver_harness/src/ui/assigned_round_screen.dart';
import 'package:rounds_driver_harness/src/ui/delivery_package_problem_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory supportDirectory;
  late SharedPreferences preferences;
  late DeliveryProblemPhotoStore store;
  late HarnessAppController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    supportDirectory = await Directory.systemTemp.createTemp(
      'rounds-g03-test-',
    );
    store = DeliveryProblemPhotoStore(
      preferences: preferences,
      supportDirectory: supportDirectory,
    );
    controller = await HarnessAppController.create();
    await controller.selectLocale(HarnessLocale.english);
  });

  tearDown(() async {
    controller.dispose();
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  testWidgets('initial G03 follows the canonical three-choice structure', (
    tester,
  ) async {
    await _pump(tester, controller, store);

    expect(find.text('Package problem'), findsOneWidget);
    expect(find.text('What is wrong?'), findsOneWidget);
    expect(find.text('Damaged'), findsOneWidget);
    expect(find.text('Missing'), findsOneWidget);
    expect(find.text('Wrong package'), findsOneWidget);
    expect(find.byKey(const Key('message-operations')), findsOneWidget);
  });

  testWidgets('English G03 geometry is generated from the canonical board', (
    tester,
  ) async {
    await _pump(tester, controller, store);

    expect(
      tester.getRect(find.byKey(const Key('package-problem-topbar'))).height,
      64,
    );
    expect(
      tester.getRect(find.byKey(const Key('package-problem-damaged'))).height,
      70,
    );
    expect(
      tester.getRect(find.byKey(const Key('package-problem-missing'))).height,
      70,
    );
    expect(
      tester.getRect(find.byKey(const Key('package-problem-footer'))).height,
      77,
    );

    await tester.tap(find.byKey(const Key('package-problem-damaged')));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('package-problem-photo'))).height,
      226,
    );
    expect(
      tester.getRect(find.byKey(const Key('package-problem-photo'))).width,
      349,
    );
    expect(find.byKey(const Key('package-problem-summary')), findsOneWidget);
  });

  testWidgets('more actions use the canonical bottom drawer', (tester) async {
    await _pump(tester, controller, store);

    await tester.tap(find.byKey(const Key('package-problem-more')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rounds-action-drawer')), findsOneWidget);
    expect(find.text('Message Operations'), findsWidgets);
    expect(find.text('Return to handoff'), findsOneWidget);
    expect(find.text('Emergency'), findsOneWidget);
  });

  testWidgets('damage and wrong package require a photo', (tester) async {
    await _pump(tester, controller, store);
    await tester.tap(find.byKey(const Key('package-problem-damaged')));
    await tester.pumpAndSettle();

    expect(find.text('Damage photo'), findsOneWidget);
    expect(
      find.byKey(const Key('capture-package-problem-photo')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('submit-package-problem')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('change-package-problem')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('package-problem-wrong')));
    await tester.pumpAndSettle();
    expect(find.text('Package photo'), findsOneWidget);
  });

  testWidgets('missing package sends without fabricated photo evidence', (
    tester,
  ) async {
    await _pump(tester, controller, store);
    await tester.tap(find.byKey(const Key('package-problem-missing')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('capture-package-problem-photo')),
      findsNothing,
    );
    final send = tester.widget<FilledButton>(
      find.byKey(const Key('submit-package-problem')),
    );
    expect(send.onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('submit-package-problem')));
    await tester.pumpAndSettle();
    expect(find.text('Waiting to sync'), findsWidgets);
    expect(find.textContaining('Saved locally'), findsOneWidget);
  });

  testWidgets('Thai G03 fits a 393 by 852 phone without overflow', (
    tester,
  ) async {
    await controller.selectLocale(HarnessLocale.thai);
    await _pump(tester, controller, store);

    expect(find.text('ของมีปัญหา'), findsOneWidget);
    expect(find.text('ปัญหาอะไร?'), findsOneWidget);
    expect(find.text('เสียหาย'), findsOneWidget);
    expect(find.text('ของไม่ครบ'), findsOneWidget);
    expect(find.text('ของไม่ตรง'), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('package-problem-damaged'))).height,
      77,
    );
    expect(
      tester.getRect(find.byKey(const Key('package-problem-footer'))).height,
      79,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  HarnessAppController controller,
  DeliveryProblemPhotoStore store,
) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final round = AssignedRoundScreen.demoRound;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildRoundsDriverTheme(),
      locale: controller.locale.locale,
      home: DeliveryPackageProblemScreen(
        controller: controller,
        round: round,
        stop: round.stops.first,
        photoStore: store,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
