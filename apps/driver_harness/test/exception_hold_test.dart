import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/harness_app_controller.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';
import 'package:rounds_driver_harness/src/ui/assigned_round_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('exception Stop cannot return to navigation', (tester) async {
    SharedPreferences.setMockInitialValues({
      'driver_locale': 'en',
      'driver_locale_selected': true,
    });
    final controller = await HarnessAppController.create();
    const stop = DriverRoundStopModel(
      id: 'stop-1',
      sequence: 1,
      state: 'exception',
      version: 7,
      destinationVersion: 1,
      manifestId: 'manifest-1',
      manifestVersion: 1,
      deliveryReference: 'DEL-1',
      recipientName: 'Test Recipient',
      recipientPhone: '+66000000000',
      rawAddress: 'Bangkok',
      latitude: 13.7,
      longitude: 100.5,
      windowStart: '2026-09-02T10:00:00Z',
      windowEnd: '2026-09-02T12:00:00Z',
      manifestItems: [
        DriverManifestItemModel(
          lineNumber: 1,
          description: 'Flower package',
          quantity: 1,
        ),
      ],
    );
    const round = DriverRoundModel(
      id: 'round-1',
      reference: 'ROUND-1',
      serviceDate: '2026-09-02',
      state: 'active',
      version: 2,
      tenantName: 'UrbanFlowers',
      pickup: DriverPickupModel(
        displayName: 'UrbanFlowers',
        rawAddress: 'Bangkok',
        contactName: 'Operations',
        contactPhone: '+66000000000',
      ),
      stops: [stop],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AssignedRoundScreen(
          controller: controller,
          enableNativeNavigation: false,
          session: const DriverSessionModel(
            userName: 'Driver',
            driverId: 'driver-1',
            preferredLocale: 'en',
            currentRound: round,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hold'), findsOneWidget);
    expect(find.text('Damaged package · Operations reviewing'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('waiting-operations')),
    );
    expect(button.onPressed, isNull);
    expect(find.byKey(const Key('start-navigation')), findsNothing);
  });

  testWidgets('closed earlier Stop cannot become the navigation target', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'driver_locale': 'en',
      'driver_locale_selected': true,
    });
    final controller = await HarnessAppController.create();
    const closed = DriverRoundStopModel(
      id: 'stop-1',
      sequence: 1,
      state: 'cancelled',
      version: 8,
      destinationVersion: 1,
      manifestId: 'manifest-1',
      manifestVersion: 1,
      deliveryReference: 'DEL-1',
      recipientName: 'Returned package',
      recipientPhone: '+66000000000',
      rawAddress: 'Bangkok',
      latitude: 13.7,
      longitude: 100.5,
      windowStart: '2026-09-02T10:00:00Z',
      windowEnd: '2026-09-02T12:00:00Z',
      manifestItems: [],
    );
    const next = DriverRoundStopModel(
      id: 'stop-2',
      sequence: 2,
      state: 'assigned',
      version: 2,
      destinationVersion: 1,
      manifestId: 'manifest-2',
      manifestVersion: 1,
      deliveryReference: 'DEL-2',
      recipientName: 'Next Recipient',
      recipientPhone: '+66000000001',
      rawAddress: 'Sukhumvit',
      latitude: 13.71,
      longitude: 100.51,
      windowStart: '2026-09-02T12:00:00Z',
      windowEnd: '2026-09-02T14:00:00Z',
      manifestItems: [],
    );
    const round = DriverRoundModel(
      id: 'round-1',
      reference: 'ROUND-1',
      serviceDate: '2026-09-02',
      state: 'active',
      version: 3,
      tenantName: 'UrbanFlowers',
      pickup: DriverPickupModel(
        displayName: 'UrbanFlowers',
        rawAddress: 'Bangkok',
        contactName: 'Operations',
        contactPhone: '+66000000000',
      ),
      stops: [closed, next],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AssignedRoundScreen(
          controller: controller,
          enableNativeNavigation: false,
          session: const DriverSessionModel(
            userName: 'Driver',
            driverId: 'driver-1',
            preferredLocale: 'en',
            currentRound: round,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Next Recipient'), findsOneWidget);
    expect(find.text('Returned package'), findsNothing);
    expect(find.byKey(const Key('start-navigation')), findsOneWidget);
  });
}
