import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/app_strings.dart';
import 'package:rounds_driver_harness/src/app/rounds_harness_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'Thai is primary and the assigned Round survives language change',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = await HarnessAppController.create();
      await tester.pumpWidget(
        RoundsHarnessApp(controller: controller, enableNativeNavigation: false),
      );

      expect(find.text('เลือกภาษา'), findsOneWidget);
      await tester.tap(find.byKey(const Key('continue-language')));
      await tester.pumpAndSettle();
      expect(find.text('รอบที่ได้รับมอบหมาย'), findsOneWidget);
      expect(find.textContaining('STOP-001'), findsOneWidget);

      await controller.selectLocale(HarnessLocale.english);
      await tester.pumpAndSettle();
      expect(find.text('Assigned Round'), findsOneWidget);
      expect(find.textContaining('STOP-001'), findsOneWidget);
    },
  );

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
    await tester.tap(find.byKey(const Key('arrival-action')));
    await tester.pumpAndSettle();

    expect(find.text('Pending sync'), findsOneWidget);
    expect(find.text('Completed'), findsNothing);
  });
}
