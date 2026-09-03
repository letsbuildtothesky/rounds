import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/connectivity/driver_sync_state.dart';
import 'package:rounds_driver_harness/src/connectivity/offline_reconnecting_screen.dart';

void main() {
  testWidgets('N02 uses canonical geometry and truthful local queue counts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    var returned = false;
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: OfflineReconnectingScreen(
          snapshot: DriverSyncSnapshot(
            phase: DriverConnectionPhase.offline,
            currentRouteAvailable: true,
            pendingProofCount: 1,
            pendingMessageCount: 2,
            pendingStatusCount: 1,
            pendingTelemetryCount: 3,
            lastSyncedAt: DateTime(2026, 9, 3, 16, 46),
          ),
          onReturnToRound: () => returned = true,
          onRetry: () => retried = true,
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('n02-topbar'))).height, 58);
    expect(
      tester.getSize(find.byKey(const Key('n02-state-icon'))),
      const Size(72, 72),
    );
    expect(find.text('You’re offline'), findsOneWidget);
    expect(
      find.text('5 proof or status items saved on this phone'),
      findsOneWidget,
    );
    expect(find.text('2 messages saved on this phone'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);

    await tester.tap(find.byKey(const Key('n02-return')));
    await tester.tap(find.byKey(const Key('n02-retry')));
    expect(returned, isTrue);
    expect(retried, isTrue);
  });

  testWidgets('N02 only says Back online when measured queues are empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: OfflineReconnectingScreen(
          snapshot: const DriverSyncSnapshot(
            phase: DriverConnectionPhase.online,
            currentRouteAvailable: true,
            pendingProofCount: 0,
            pendingMessageCount: 0,
            pendingStatusCount: 0,
            pendingTelemetryCount: 0,
          ),
          onReturnToRound: () {},
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('Back online'), findsOneWidget);
    expect(find.text('Synced'), findsNWidgets(2));
    expect(find.byKey(const Key('n02-retry')), findsNothing);
  });

  testWidgets('N02 does not claim a cached route when none exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: OfflineReconnectingScreen(
          snapshot: const DriverSyncSnapshot(
            phase: DriverConnectionPhase.offline,
            currentRouteAvailable: false,
            pendingProofCount: 0,
            pendingMessageCount: 0,
            pendingStatusCount: 0,
            pendingTelemetryCount: 0,
          ),
          onReturnToRound: () {},
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('No route is cached on this phone'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
  });

  testWidgets('N02 scrolls cleanly on a short 360px Android viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 711);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: OfflineReconnectingScreen(
          snapshot: const DriverSyncSnapshot(
            phase: DriverConnectionPhase.offline,
            currentRouteAvailable: true,
            pendingProofCount: 0,
            pendingMessageCount: 0,
            pendingStatusCount: 0,
            pendingTelemetryCount: 0,
          ),
          onReturnToRound: () {},
          onRetry: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('n02-scroll')), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('n02-scroll')),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('n02-retry')), findsOneWidget);
  });
}
