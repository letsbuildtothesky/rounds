import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/generated/driver_ui_metrics.g.dart';
import 'package:rounds_driver_harness/src/ui/components/navigation_stop_dock.dart';

void main() {
  testWidgets('E02 stop dock uses the canonical 393px geometry', (
    tester,
  ) async {
    await _pumpDock(tester, size: const Size(393, 852));

    final dock = tester.getRect(find.byKey(const Key('navigation-stop-dock')));
    final row = tester.getRect(find.byKey(const Key('navigation-stop-row')));
    final kicker = tester.getRect(
      find.byKey(const Key('navigation-stop-kicker')),
    );
    final title = tester.getRect(
      find.byKey(const Key('navigation-stop-title')),
    );
    final place = tester.getRect(
      find.byKey(const Key('navigation-stop-place')),
    );
    final eta = tester.getRect(find.byKey(const Key('navigation-stop-eta')));
    final distance = tester.getRect(
      find.byKey(const Key('navigation-stop-distance')),
    );

    expect(dock, const Rect.fromLTWH(12, 744, 369, 96));
    expect(row, dock);
    expect(title.top - kicker.bottom, closeTo(6, .01));
    expect(place.top - title.bottom, closeTo(6, .01));
    expect(distance.top - eta.bottom, closeTo(6, .01));
    expect(kicker.left, 28);
    expect(eta.right, 365);
  });

  testWidgets('E02 stop dock switches to the canonical compact geometry', (
    tester,
  ) async {
    await _pumpDock(tester, size: const Size(320, 720));

    final dock = tester.getRect(find.byKey(const Key('navigation-stop-dock')));
    final row = tester.getRect(find.byKey(const Key('navigation-stop-row')));
    final title = tester.widget<Text>(
      find.byKey(const Key('navigation-stop-title')),
    );
    final eta = tester.widget<Text>(
      find.byKey(const Key('navigation-stop-eta')),
    );

    expect(dock, const Rect.fromLTWH(9, 625, 302, 86));
    expect(row.height, 86);
    expect(title.style?.fontSize, DriverE02Metrics.compactTitleSize);
    expect(eta.style?.fontSize, DriverE02Metrics.compactEtaSize);
  });

  testWidgets('E02 near-arrival action has exact height and insets', (
    tester,
  ) async {
    await _pumpDock(
      tester,
      size: const Size(393, 852),
      showArrivalAction: true,
    );

    final dock = tester.getRect(find.byKey(const Key('navigation-stop-dock')));
    final row = tester.getRect(find.byKey(const Key('navigation-stop-row')));
    final action = tester.getRect(find.byKey(const Key('arrival-action')));

    expect(dock, const Rect.fromLTWH(12, 674, 369, 166));
    expect(row.height, 96);
    expect(action, const Rect.fromLTWH(22, 770, 349, 60));
    expect(dock.bottom - action.bottom, 10);
  });
}

Future<void> _pumpDock(
  WidgetTester tester, {
  required Size size,
  bool showArrivalAction = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final compact = size.width < DriverReferenceViewport.compactBreakpoint;
  final margin = compact
      ? DriverE02Metrics.compactOuterMargin
      : DriverE02Metrics.outerMargin;

  await tester.pumpWidget(
    MaterialApp(
      theme: buildRoundsDriverTheme(),
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              left: margin,
              right: margin,
              bottom: margin,
              child: NavigationStopDock(
                sequence: 1,
                stopCount: 4,
                recipientName: 'K. Nattaporn',
                address: 'Sukhumvit 24 · The Emporio Place',
                etaLabel: '12 min',
                distanceLabel: '4.1 km',
                showArrivalAction: showArrivalAction,
                arrivalLabel: 'I’m at Stop 1',
                onArrival: () {},
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
