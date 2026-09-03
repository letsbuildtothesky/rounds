import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/navigation/gps_signal_monitor.dart';
import 'package:rounds_driver_harness/src/navigation/gps_unavailable_screen.dart';
import 'package:rounds_driver_harness/src/permissions/location_access.dart';

void main() {
  test(
    'GPS classification keeps disabled services separate from signal loss',
    () {
      expect(
        classifyGpsInterruption(
          const DriverLocationAccessSnapshot(
            DriverLocationAccessState.serviceDisabled,
          ),
        ),
        GpsInterruptionKind.locationAccessOff,
      );
      expect(
        classifyGpsInterruption(
          const DriverLocationAccessSnapshot(
            DriverLocationAccessState.whileInUse,
          ),
        ),
        GpsInterruptionKind.signalLost,
      );
    },
  );

  testWidgets('GPS monitor reports stale samples and real recovery', (
    tester,
  ) async {
    final states = <bool>[];
    final monitor = GpsSignalMonitor(
      timeout: const Duration(seconds: 30),
      onUnavailableChanged: states.add,
    );

    monitor.start();
    await tester.pump(const Duration(seconds: 31));
    expect(states, [true]);

    monitor.markSample();
    expect(states, [true, false]);
    monitor.stop();
  });

  testWidgets('N03 uses canonical geometry and honest cached-route copy', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var continued = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: GpsUnavailableScreen(
          interruption: const GpsNavigationInterruption(
            kind: GpsInterruptionKind.signalLost,
            cachedRouteAvailable: true,
          ),
          contextLabel: 'UrbanFlowers · Stop 2',
          onBack: () {},
          onContinue: () => continued = true,
          onRetry: () {},
          onReviewLocationAccess: () {},
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('n03-topbar'))).height, 58);
    expect(tester.getTopLeft(find.byKey(const Key('n03-panel'))).dy, 408);
    expect(find.text('Cached route ready'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('Continue with cached route'), findsOneWidget);

    await tester.tap(find.byKey(const Key('n03-primary')));
    expect(continued, isTrue);
  });

  testWidgets('N03 never claims a cached route before guidance exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: GpsUnavailableScreen(
          interruption: const GpsNavigationInterruption(
            kind: GpsInterruptionKind.signalLost,
            cachedRouteAvailable: false,
          ),
          contextLabel: 'UrbanFlowers · Stop 1',
          onBack: () {},
          onContinue: () {},
          onRetry: () {},
          onReviewLocationAccess: () {},
        ),
      ),
    );

    expect(find.text('Waiting for GPS'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('Continue with cached route'), findsNothing);
    expect(find.text('Retry GPS'), findsOneWidget);
  });

  testWidgets('N03 keeps location access failure distinct from signal loss', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: GpsUnavailableScreen(
          interruption: const GpsNavigationInterruption(
            kind: GpsInterruptionKind.locationAccessOff,
            cachedRouteAvailable: false,
          ),
          contextLabel: 'UrbanFlowers · Pickup',
          onBack: () {},
          onContinue: () {},
          onRetry: () {},
          onReviewLocationAccess: () {},
        ),
      ),
    );

    expect(find.text('LOCATION ACCESS OFF'), findsOneWidget);
    expect(find.text('Turn location back on'), findsOneWidget);
    expect(find.text('Location settings'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
  });
}
