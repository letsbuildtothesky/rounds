import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/app_strings.dart';
import 'package:rounds_driver_harness/src/app/rounds_harness_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the assigned Round survives language change', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = await HarnessAppController.create();
    await tester.pumpWidget(
      RoundsHarnessApp(controller: controller, enableNativeNavigation: false),
    );

    expect(find.text('เลือกภาษา'), findsOneWidget);
    await tester.tap(find.byKey(const Key('continue-language')));
    await tester.pumpAndSettle();
    expect(find.text('ROUND ASSIGNED'), findsOneWidget);
    expect(find.text('ROUND-DEMO-001'), findsOneWidget);

    await controller.selectLocale(HarnessLocale.english);
    await tester.pumpAndSettle();
    expect(find.text('ROUND ASSIGNED'), findsOneWidget);
    expect(find.text('ROUND-DEMO-001'), findsOneWidget);
  });

  testWidgets('arrival remains pending and never claims server completion', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'driver_locale': 'en',
      'driver_locale_selected': true,
    });
    final controller = await HarnessAppController.create();
    await tester.pumpWidget(
      RoundsHarnessApp(controller: controller, enableNativeNavigation: false),
    );

    await tester.tap(find.byKey(const Key('start-navigation')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('navigation-back')), findsOneWidget);
    expect(find.byKey(const Key('navigation-more')), findsOneWidget);
    expect(find.text('STOP 1 OF 1'), findsOneWidget);
    expect(find.text('Contact Operations'), findsNothing);
    await tester.tap(find.byKey(const Key('arrival-action')));
    await tester.pumpAndSettle();

    expect(find.text('Pending sync'), findsOneWidget);
    expect(find.text('Completed'), findsNothing);
  });

  testWidgets('navigation instrument remains usable at narrow large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    SharedPreferences.setMockInitialValues({
      'driver_locale': 'en',
      'driver_locale_selected': true,
    });
    final controller = await HarnessAppController.create();
    await tester.pumpWidget(
      RoundsHarnessApp(controller: controller, enableNativeNavigation: false),
    );
    await tester.tap(find.byKey(const Key('start-navigation')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('navigation-back')), findsOneWidget);
    expect(find.byKey(const Key('navigation-more')), findsOneWidget);
    expect(find.byKey(const Key('arrival-action')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation instrument matches its canonical visual baseline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final previousComparator = goldenFileComparator;
    final localComparator = previousComparator as LocalFileComparator;
    goldenFileComparator = _TolerantGoldenFileComparator(
      localComparator.basedir.resolve('widget_test.dart'),
      precisionTolerance: .025,
    );
    addTearDown(() => goldenFileComparator = previousComparator);

    SharedPreferences.setMockInitialValues({
      'driver_locale': 'en',
      'driver_locale_selected': true,
    });
    final controller = await HarnessAppController.create();
    await tester.pumpWidget(
      RoundsHarnessApp(controller: controller, enableNativeNavigation: false),
    );
    await tester.tap(find.byKey(const Key('start-navigation')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/navigation-instrument-393x852.png'),
    );
  });
}

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  }) : assert(precisionTolerance >= 0 && precisionTolerance <= 1),
       _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _precisionTolerance) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
