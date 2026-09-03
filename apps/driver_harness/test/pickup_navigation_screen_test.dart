import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/generated/driver_ui_metrics.g.dart';
import 'package:rounds_driver_harness/src/app/harness_app_controller.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';
import 'package:rounds_driver_harness/src/ui/assigned_round_screen.dart';
import 'package:rounds_driver_harness/src/ui/components/navigation_pickup_dock.dart';
import 'package:rounds_driver_harness/src/ui/pickup_confirmation_screen.dart';
import 'package:rounds_driver_harness/src/ui/pickup_navigation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('D01 pickup dock uses the canonical 393px geometry', (
    tester,
  ) async {
    await _pumpDock(tester, showArrivalAction: false);

    expect(
      tester.getRect(find.byKey(const Key('pickup-navigation-dock'))),
      const Rect.fromLTWH(12, 748, 369, 92),
    );
    expect(
      tester.getSize(find.byKey(const Key('pickup-navigation-row'))).height,
      DriverD01Metrics.dockRowHeight,
    );
  });

  testWidgets('D01 near-pickup action has exact height and insets', (
    tester,
  ) async {
    await _pumpDock(tester, showArrivalAction: true);

    expect(
      tester.getRect(find.byKey(const Key('pickup-navigation-dock'))),
      const Rect.fromLTWH(12, 678, 369, 162),
    );
    expect(
      tester.getRect(find.byKey(const Key('pickup-arrival-action'))),
      const Rect.fromLTWH(22, 770, 349, 60),
    );
    expect(find.text("I'm at pickup"), findsOneWidget);
  });

  testWidgets('D01 follows the canonical instrument and action-drawer flow', (
    tester,
  ) async {
    Uri? launched;
    await _pumpScreen(
      tester,
      launcher: (uri) async {
        launched = uri;
        return true;
      },
    );

    expect(
      tester.getRect(find.byKey(const Key('pickup-navigation-instruction'))),
      const Rect.fromLTWH(64, 12, 265, 82),
    );
    expect(
      find.byKey(const Key('pickup-navigation-map-preview')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('navigation-more')));
    await tester.pumpAndSettle();
    expect(find.text('Pickup actions'), findsNothing);
    expect(find.text('Call pickup'), findsOneWidget);
    expect(find.text('Message Operations'), findsOneWidget);
    expect(find.text('Report an issue'), findsOneWidget);
    expect(find.text('Open in Maps'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);

    await tester.tap(find.byKey(const Key('rounds-action-maps')));
    await tester.pumpAndSettle();
    expect(launched?.host, 'www.google.com');
    expect(launched?.queryParameters['destination'], '13.7338,100.5766');
  });

  testWidgets(
    'D01 arrival continues to canonical D03/D04 pickup confirmation',
    (tester) async {
      await _pumpScreen(tester, previewNearPickup: true);

      await tester.tap(find.byKey(const Key('pickup-arrival-action')));
      await tester.pumpAndSettle();

      expect(find.byType(PickupConfirmationScreen), findsOneWidget);
      expect(find.text('Confirm pickup'), findsWidgets);
    },
  );

  testWidgets('an approved assigned Round enters D01 before confirmation', (
    tester,
  ) async {
    _setViewport(tester);
    SharedPreferences.setMockInitialValues({
      'driver_locale': 'en',
      'driver_locale_selected': true,
    });
    final controller = await HarnessAppController.create();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: AssignedRoundScreen(
          controller: controller,
          enableNativeNavigation: false,
          session: const DriverSessionModel(
            userName: 'Johannes',
            driverId: 'driver-1',
            preferredLocale: 'en',
            currentRound: _round,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Navigate to pickup'), findsOneWidget);
    await tester.tap(find.byKey(const Key('navigate-pickup')));
    await tester.pumpAndSettle();

    expect(find.byType(PickupNavigationScreen), findsOneWidget);
    expect(find.byType(PickupConfirmationScreen), findsNothing);
  });

  testWidgets('D01 visual baseline matches the canonical reference', (
    tester,
  ) async {
    await _pumpScreen(tester);

    final previousComparator = goldenFileComparator;
    final localComparator = previousComparator as LocalFileComparator;
    goldenFileComparator = _TolerantGoldenFileComparator(
      localComparator.basedir.resolve('pickup_navigation_screen_test.dart'),
      precisionTolerance: .05,
    );
    addTearDown(() => goldenFileComparator = previousComparator);

    await expectLater(
      find.byType(PickupNavigationScreen),
      matchesGoldenFile('goldens/pickup-navigation-393x852.png'),
    );
  });
}

Future<void> _pumpDock(
  WidgetTester tester, {
  required bool showArrivalAction,
}) async {
  _setViewport(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildRoundsDriverTheme(),
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              left: DriverD01Metrics.outerMargin,
              right: DriverD01Metrics.outerMargin,
              bottom: DriverD01Metrics.outerMargin,
              child: NavigationPickupDock(
                pickupName: 'UrbanFlowers',
                address: 'Sukhumvit 39',
                etaLabel: '6 min',
                distanceLabel: '1.2 km',
                showArrivalAction: showArrivalAction,
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

Future<void> _pumpScreen(
  WidgetTester tester, {
  Future<bool> Function(Uri uri)? launcher,
  bool previewNearPickup = false,
}) async {
  _setViewport(tester);
  SharedPreferences.setMockInitialValues({
    'driver_locale': 'en',
    'driver_locale_selected': true,
  });
  final controller = await HarnessAppController.create();
  final screen = launcher == null
      ? PickupNavigationScreen(
          controller: controller,
          enableNativeNavigation: false,
          round: _round,
          previewNearPickup: previewNearPickup,
        )
      : PickupNavigationScreen(
          controller: controller,
          enableNativeNavigation: false,
          round: _round,
          launcher: launcher,
          previewNearPickup: previewNearPickup,
        );
  await tester.pumpWidget(
    MaterialApp(theme: buildRoundsDriverTheme(), home: screen),
  );
  await tester.pumpAndSettle();
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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

const _round = DriverRoundModel(
  id: 'round-1',
  reference: 'ROUND-001',
  serviceDate: '2026-09-03',
  state: 'approved',
  version: 3,
  tenantName: 'UrbanFlowers',
  pickup: DriverPickupModel(
    id: 'pickup-1',
    displayName: 'UrbanFlowers',
    rawAddress: 'Sukhumvit 39',
    contactName: 'UrbanFlowers Dispatch',
    contactPhone: '+6625554400',
    latitude: 13.7338,
    longitude: 100.5766,
  ),
  stops: [
    DriverRoundStopModel(
      id: 'stop-1',
      sequence: 1,
      state: 'assigned',
      version: 1,
      destinationVersion: 1,
      manifestId: 'manifest-1',
      manifestVersion: 1,
      deliveryReference: 'UF-001',
      recipientName: 'Siriporn',
      recipientPhone: '+66999999999',
      rawAddress: 'Wireless Road, Bangkok',
      latitude: 13.7439,
      longitude: 100.547,
      windowStart: '2026-09-03T05:00:00Z',
      windowEnd: '2026-09-03T10:00:00Z',
      manifestItems: [
        DriverManifestItemModel(
          lineNumber: 1,
          description: 'Bouquet',
          quantity: 1,
        ),
      ],
    ),
  ],
);
