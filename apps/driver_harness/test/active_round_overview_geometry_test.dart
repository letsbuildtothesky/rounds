import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/generated/driver_ui_metrics.g.dart';
import 'package:rounds_driver_harness/src/app/rounds_harness_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('E01 uses exact canonical regions at 393px', (tester) async {
    await _pumpOverview(tester, const Size(393, 852));

    expect(
      tester.getRect(find.byKey(const Key('e01-topbar'))),
      const Rect.fromLTWH(0, 0, 393, 60),
    );
    expect(
      tester.getRect(find.byKey(const Key('e01-map'))),
      const Rect.fromLTWH(0, 60, 393, 568),
    );
    expect(
      tester.getRect(find.byKey(const Key('e01-next-dock'))),
      const Rect.fromLTWH(0, 628, 393, 224),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('e01-map-summary'))),
      const Offset(12, 74),
    );
    expect(
      tester.getSize(find.byKey(const Key('start-navigation'))).height,
      DriverE01Metrics.primaryHeight,
    );

    final kicker = tester.getRect(find.byKey(const Key('e01-next-kicker')));
    final name = tester.getRect(find.byKey(const Key('e01-next-name')));
    final place = tester.getRect(find.byKey(const Key('e01-next-place')));
    expect(name.top - kicker.bottom, closeTo(7, .01));
    expect(place.top - name.bottom, closeTo(7, .01));
  });

  testWidgets('E01 switches to the canonical compact dimensions', (
    tester,
  ) async {
    await _pumpOverview(tester, const Size(320, 720));

    expect(
      tester.getRect(find.byKey(const Key('e01-map'))),
      const Rect.fromLTWH(0, 60, 320, 444),
    );
    expect(
      tester.getRect(find.byKey(const Key('e01-next-dock'))),
      const Rect.fromLTWH(0, 504, 320, 216),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('e01-map-summary'))),
      const Offset(9, 71),
    );
    expect(tester.getSize(find.byTooltip('Back')), const Size(40, 40));
    expect(
      tester.getSize(find.byKey(const Key('start-navigation'))).height,
      DriverE01Metrics.compactPrimaryHeight,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpOverview(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'driver_locale': 'en',
    'driver_locale_selected': true,
  });
  final controller = await HarnessAppController.create();
  await tester.pumpWidget(
    RoundsHarnessApp(controller: controller, enableNativeNavigation: false),
  );
  await tester.pumpAndSettle();
}
