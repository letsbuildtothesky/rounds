import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/rounds_harness_app.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';
import 'package:rounds_driver_harness/src/ui/pickup_confirmation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('pickup stays blocked until every manifest line is confirmed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'driver_locale': 'en',
      'driver_locale_selected': true,
    });
    final controller = await HarnessAppController.create();
    const round = DriverRoundModel(
      id: 'round-1',
      reference: 'ROUND-001',
      serviceDate: '2026-09-02',
      state: 'approved',
      version: 1,
      tenantName: 'UrbanFlowers',
      pickup: DriverPickupModel(
        displayName: 'Studio',
        rawAddress: 'Bangkok',
        contactName: 'Dispatch',
        contactPhone: '+66000000000',
      ),
      stops: [
        DriverRoundStopModel(
          id: 'stop-1',
          sequence: 1,
          state: 'assigned',
          destinationVersion: 1,
          manifestId: 'manifest-1',
          manifestVersion: 1,
          deliveryReference: 'UF-001',
          recipientName: 'Siriporn',
          recipientPhone: '+66999999999',
          rawAddress: 'Bangkok',
          latitude: 13.7,
          longitude: 100.5,
          windowStart: '2026-09-02T02:00:00Z',
          windowEnd: '2026-09-02T04:00:00Z',
          manifestItems: [
            DriverManifestItemModel(
              lineNumber: 1,
              description: 'Bouquet',
              quantity: 1,
            ),
            DriverManifestItemModel(
              lineNumber: 2,
              description: 'Cake',
              quantity: 1,
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PickupConfirmationScreen(controller: controller, round: round),
      ),
    );

    expect(find.text('0 / 2'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('confirm-pickup')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('manifest-stop-1-1')));
    await tester.pump();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('confirm-pickup')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('manifest-stop-1-2')));
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('confirm-pickup')))
          .onPressed,
      isNotNull,
    );
  });
}
