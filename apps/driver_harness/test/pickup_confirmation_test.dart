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
          version: 1,
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

    expect(find.text('UrbanFlowers'), findsOneWidget);
    expect(find.text('Studio'), findsNothing);
    expect(find.text('1 stop'), findsOneWidget);
    expect(find.text('Confirm pickup'), findsWidgets);
    expect(find.text('Confirm\npickup'), findsNothing);
    expect(find.text('Collect packages'), findsOneWidget);
    expect(find.text('0 of 2'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('confirm-pickup')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('manifest-stop-1-1-1')));
    await tester.pump();
    expect(find.text('1 of 2'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('confirm-pickup')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('manifest-stop-1-2-1')));
    await tester.pump();
    expect(find.text('2 of 2'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('confirm-pickup')))
          .onPressed,
      isNotNull,
    );

    // An unavailable real transport must not copy the prototype's timed success.
    await tester.tap(find.byKey(const Key('confirm-pickup')));
    await tester.pumpAndSettle();
    expect(find.byType(PickupConfirmationScreen), findsOneWidget);
    expect(find.text('Pickup confirmed'), findsNothing);
    expect(find.textContaining('Nothing was sent or saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Toggling back removes readiness without changing the manifest quantity.
    await tester.tap(find.byKey(const Key('manifest-stop-1-2-1')));
    await tester.pump();
    expect(find.text('1 of 2'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('confirm-pickup')))
          .onPressed,
      isNull,
    );

    // The new first-level drawer feeds the existing pickup issue command,
    // not the dropoff damage command or a prototype fake success.
    await tester.tap(find.byKey(const Key('pickup-problem')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Damaged package'));
    await tester.pumpAndSettle();
    expect(find.text('Damaged item'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('send-pickup-problem')))
          .onPressed,
      isNotNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOneWidget);

    // A new manifest/assignment snapshot cannot inherit checked packages.
    await tester.pumpWidget(
      MaterialApp(
        home: PickupConfirmationScreen(
          controller: controller,
          round: DriverRoundModel.fromJson({...round.toJson(), 'version': 2}),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('0 of 2'), findsOneWidget);
  });

  testWidgets('pickup and its problem drawer use the canonical Thai copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'driver_locale': 'th-TH',
      'driver_locale_selected': true,
    });
    final controller = await HarnessAppController.create();
    const round = DriverRoundModel(
      id: 'round-th',
      reference: 'ROUND-TH',
      serviceDate: '2026-09-04',
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
          id: 'stop-th',
          sequence: 1,
          state: 'assigned',
          version: 1,
          destinationVersion: 1,
          manifestId: 'manifest-th',
          manifestVersion: 1,
          deliveryReference: 'UF-TH-001',
          recipientName: 'คุณศิริพร',
          recipientPhone: '+66999999999',
          rawAddress: 'Bangkok',
          latitude: 13.7,
          longitude: 100.5,
          windowStart: '2026-09-04T02:00:00Z',
          windowEnd: '2026-09-04T04:00:00Z',
          manifestItems: [
            DriverManifestItemModel(
              lineNumber: 1,
              description: 'ช่อดอกไม้',
              quantity: 2,
              handlingNote: 'Fragile',
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

    expect(find.text('ถึงจุดรับของ'), findsOneWidget);
    expect(find.text('1 งานส่ง'), findsOneWidget);
    expect(find.text('ยืนยันรับของ'), findsWidgets);
    expect(find.text('2 แพ็กเกจ · ตรวจของจริง'), findsOneWidget);
    expect(find.text('ระวัง'), findsOneWidget);
    expect(find.text('Confirm pickup'), findsNothing);

    await tester.tap(find.byKey(const Key('pickup-problem')));
    await tester.pumpAndSettle();

    expect(find.text('ของไม่ครบ'), findsOneWidget);
    expect(find.text('ของไม่ตรง'), findsOneWidget);
    expect(find.text('ของเสียหาย'), findsOneWidget);
    expect(find.text('Missing item'), findsNothing);
  });
}
