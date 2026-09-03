import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/app_strings.dart';
import 'package:rounds_driver_harness/src/app/generated/driver_ui_metrics.g.dart';
import 'package:rounds_driver_harness/src/app/rounds_harness_app.dart';
import 'package:rounds_driver_harness/src/ui/driver_splash_screen.dart';
import 'package:rounds_driver_harness/src/ui/language_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('A01 uses the canonical timing and proceeds to Thai-first A01B', (
    tester,
  ) async {
    await _setViewport(tester, const Size(393, 852));
    SharedPreferences.setMockInitialValues({});
    final controller = await HarnessAppController.create();

    await tester.pumpWidget(
      RoundsHarnessApp(controller: controller, enableNativeNavigation: false),
    );

    expect(find.byType(DriverSplashScreen), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('a01-splash'))),
      const Rect.fromLTWH(0, 0, 393, 852),
    );
    final brandCenter = tester
        .getRect(find.byKey(const Key('a01-brand')))
        .center;
    expect(brandCenter.dx, closeTo(393 / 2, .5));
    expect(brandCenter.dy, closeTo(852 / 2, .5));

    await tester.pump(
      const Duration(milliseconds: DriverA01Metrics.proceedAfterMs - 1),
    );
    expect(find.byType(DriverSplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(find.byType(LanguageScreen), findsOneWidget);
    expect(find.text('เลือกภาษา'), findsOneWidget);
    expect(find.text('ต่อไป'), findsOneWidget);
    expect(controller.locale, HarnessLocale.thai);
    expect(controller.hasSelectedLanguage, isFalse);
  });

  testWidgets('A01 can be skipped by the explicit full-screen tap', (
    tester,
  ) async {
    await _setViewport(tester, const Size(393, 852));
    SharedPreferences.setMockInitialValues({});
    final controller = await HarnessAppController.create();
    await tester.pumpWidget(
      RoundsHarnessApp(controller: controller, enableNativeNavigation: false),
    );

    await tester.tap(find.byKey(const Key('a01-splash')));
    await tester.pump();

    expect(find.byType(LanguageScreen), findsOneWidget);
  });

  testWidgets('A01B follows canonical geometry and persists English choice', (
    tester,
  ) async {
    await _setViewport(tester, const Size(393, 852));
    SharedPreferences.setMockInitialValues({});
    final controller = await HarnessAppController.create();
    await tester.pumpWidget(
      RoundsHarnessApp(
        controller: controller,
        enableNativeNavigation: false,
        splashDuration: Duration.zero,
      ),
    );

    expect(
      tester.getRect(find.byKey(const Key('a01b-topbar'))).height,
      DriverA01BMetrics.topBarHeight,
    );
    expect(
      tester.getRect(find.byKey(const Key('a01b-thai'))).height,
      DriverA01BMetrics.rowHeight,
    );
    expect(
      tester.getRect(find.byKey(const Key('a01b-footer'))).height,
      DriverA01BMetrics.footerPaddingTop +
          DriverA01BMetrics.buttonHeight +
          DriverA01BMetrics.footerPaddingBottom,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/language-thai-393x852.png'),
    );

    await tester.tap(find.byKey(const Key('a01b-english')));
    await tester.pumpAndSettle();
    expect(find.text('Rounds'), findsOneWidget);
    expect(find.text('Choose your language'), findsOneWidget);
    expect(find.text('Continue in English'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/language-english-393x852.png'),
    );
    await tester.tap(find.byKey(const Key('continue-language')));
    await tester.pumpAndSettle();

    expect(controller.locale, HarnessLocale.english);
    expect(controller.hasSelectedLanguage, isTrue);
    final restored = await HarnessAppController.create();
    expect(restored.locale, HarnessLocale.english);
    expect(restored.hasSelectedLanguage, isTrue);
  });

  testWidgets('A01B Thai board stays usable at the canonical compact width', (
    tester,
  ) async {
    await _setViewport(tester, const Size(320, 720));
    SharedPreferences.setMockInitialValues({});
    final controller = await HarnessAppController.create();
    await tester.pumpWidget(
      RoundsHarnessApp(
        controller: controller,
        enableNativeNavigation: false,
        splashDuration: Duration.zero,
      ),
    );

    expect(find.text('เลือกภาษา'), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('a01b-thai'))).height,
      DriverA01BMetrics.thaiCompactRowHeight,
    );
    expect(find.byKey(const Key('continue-language')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a returning Driver sees A01 then bypasses A01B', (tester) async {
    await _setViewport(tester, const Size(393, 852));
    SharedPreferences.setMockInitialValues({
      'driver_locale': 'en',
      'driver_locale_selected': true,
    });
    final controller = await HarnessAppController.create();
    await tester.pumpWidget(
      RoundsHarnessApp(controller: controller, enableNativeNavigation: false),
    );

    expect(find.byType(DriverSplashScreen), findsOneWidget);
    await tester.pump(
      const Duration(milliseconds: DriverA01Metrics.proceedAfterMs),
    );
    await tester.pump();

    expect(find.byType(LanguageScreen), findsNothing);
    expect(find.text('ROUND ACTIVE'), findsOneWidget);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
