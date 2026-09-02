import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/generated/driver_ui_metrics.g.dart';
import 'package:rounds_driver_harness/src/app/rounds_harness_app.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';
import 'package:rounds_driver_harness/src/ui/pickup_confirmation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('D03/D04 uses exact canonical regions at 393px', (tester) async {
    await _pumpPickup(tester, const Size(393, 852));

    expect(
      tester.getRect(find.byKey(const Key('pickup-topbar'))),
      const Rect.fromLTWH(0, 0, 393, 60),
    );
    expect(
      tester.getRect(find.byKey(const Key('pickup-content'))),
      const Rect.fromLTWH(0, 60, 393, 792),
    );
    expect(
      tester.getRect(find.byKey(const Key('pickup-footer'))),
      const Rect.fromLTWH(0, 759, 393, 93),
    );
    expect(
      tester.getRect(find.byKey(const Key('pickup-hero'))).topLeft,
      const Offset(18, 84),
    );
    expect(tester.getSize(find.byKey(const Key('pickup-hero'))).width, 357);
    expect(
      tester.getSize(find.byKey(const Key('pickup-manifest-head'))).height,
      DriverD03D04Metrics.manifestHeadHeight,
    );
    expect(
      tester.getSize(find.byKey(const Key('manifest-stop-1-1'))).height,
      DriverD03D04Metrics.manifestLineHeight,
    );
    expect(
      tester.getSize(find.byKey(const Key('pickup-problem'))).height,
      DriverD03D04Metrics.problemHeight,
    );
    expect(
      tester.getRect(find.byKey(const Key('confirm-pickup'))),
      const Rect.fromLTWH(18, 770, 357, 64),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('D03/D04 switches to the canonical compact dimensions', (
    tester,
  ) async {
    await _pumpPickup(tester, const Size(320, 720));

    expect(
      tester.getRect(find.byKey(const Key('pickup-footer'))),
      const Rect.fromLTWH(0, 627, 320, 93),
    );
    expect(
      tester.getRect(find.byKey(const Key('pickup-hero'))).topLeft,
      const Offset(16, 84),
    );
    expect(tester.getSize(find.byKey(const Key('pickup-hero'))).width, 288);
    expect(
      tester.getSize(find.byKey(const Key('manifest-stop-1-1'))).height,
      DriverD03D04Metrics.compactManifestLineHeight,
    );
    expect(
      tester.getRect(find.byKey(const Key('confirm-pickup'))),
      const Rect.fromLTWH(16, 638, 288, 64),
    );
    expect(find.text('Confirm pickup'), findsWidgets);
    expect(find.text('Confirm\npickup'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('D03/D04 visual baseline matches the canonical reference', (
    tester,
  ) async {
    await _pumpPickup(tester, const Size(393, 852));

    await expectLater(
      find.byType(PickupConfirmationScreen),
      matchesGoldenFile('goldens/pickup-confirmation-393x852.png'),
    );
  });
}

Future<void> _pumpPickup(WidgetTester tester, Size size) async {
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
    MaterialApp(
      theme: buildRoundsDriverTheme(),
      home: PickupConfirmationScreen(
        controller: controller,
        round: _canonicalRound,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _canonicalRound = DriverRoundModel(
  id: 'round-pickup-reference',
  reference: 'ROUND-001',
  serviceDate: '2026-09-02',
  state: 'approved',
  version: 1,
  tenantName: 'UrbanFlowers',
  pickup: DriverPickupModel(
    displayName: 'UrbanFlowers',
    rawAddress: 'Bangkok',
    contactName: 'Dispatch',
    contactPhone: '+66000000000',
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
      deliveryReference: '#8421',
      recipientName: 'K. Nattaporn',
      recipientPhone: '+66999999991',
      rawAddress: 'Bangkok',
      latitude: 13.7,
      longitude: 100.5,
      windowStart: '2026-09-02T02:00:00Z',
      windowEnd: '2026-09-02T04:00:00Z',
      manifestItems: [
        DriverManifestItemModel(
          lineNumber: 1,
          description: 'Midnight Orchid + glass vase',
          quantity: 1,
          handlingNote: 'Fragile',
        ),
      ],
    ),
    DriverRoundStopModel(
      id: 'stop-2',
      sequence: 2,
      state: 'assigned',
      version: 1,
      destinationVersion: 1,
      manifestId: 'manifest-2',
      manifestVersion: 1,
      deliveryReference: '#8422',
      recipientName: 'James T.',
      recipientPhone: '+66999999992',
      rawAddress: 'Bangkok',
      latitude: 13.71,
      longitude: 100.51,
      windowStart: '2026-09-02T02:00:00Z',
      windowEnd: '2026-09-02T04:00:00Z',
      manifestItems: [
        DriverManifestItemModel(
          lineNumber: 1,
          description: 'Signature hamper',
          quantity: 1,
        ),
      ],
    ),
    DriverRoundStopModel(
      id: 'stop-3',
      sequence: 3,
      state: 'assigned',
      version: 1,
      destinationVersion: 1,
      manifestId: 'manifest-3',
      manifestVersion: 1,
      deliveryReference: '#8423',
      recipientName: 'K. Ploy',
      recipientPhone: '+66999999993',
      rawAddress: 'Bangkok',
      latitude: 13.72,
      longitude: 100.52,
      windowStart: '2026-09-02T02:00:00Z',
      windowEnd: '2026-09-02T04:00:00Z',
      manifestItems: [
        DriverManifestItemModel(
          lineNumber: 1,
          description: 'Bouquet',
          quantity: 1,
          handlingNote: 'Fragile',
        ),
        DriverManifestItemModel(
          lineNumber: 2,
          description: '1 lb cake',
          quantity: 1,
          handlingNote: 'Keep cool',
        ),
      ],
    ),
    DriverRoundStopModel(
      id: 'stop-4',
      sequence: 4,
      state: 'assigned',
      version: 1,
      destinationVersion: 1,
      manifestId: 'manifest-4',
      manifestVersion: 1,
      deliveryReference: '#8424',
      recipientName: 'Anantara Siam',
      recipientPhone: '+66999999994',
      rawAddress: 'Bangkok',
      latitude: 13.73,
      longitude: 100.53,
      windowStart: '2026-09-02T02:00:00Z',
      windowEnd: '2026-09-02T04:00:00Z',
      manifestItems: [
        DriverManifestItemModel(
          lineNumber: 1,
          description: 'Floral arrangements',
          quantity: 2,
          handlingNote: 'Fragile',
        ),
      ],
    ),
  ],
);
