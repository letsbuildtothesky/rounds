import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/rounds_harness_app.dart';
import 'package:rounds_driver_harness/src/driver/driver_handoff_selection.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';
import 'package:rounds_driver_harness/src/ui/proof_of_delivery_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('POD consumes the prior handoff and requires a photo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'driver_locale': 'en',
      'driver_locale_selected': true,
    });
    final controller = await HarnessAppController.create();
    const stop = DriverRoundStopModel(
      id: 'stop-1',
      sequence: 1,
      state: 'arrived',
      version: 5,
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
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ProofOfDeliveryScreen(
          controller: controller,
          stop: stop,
          handoff: const DriverHandoffSelection.someoneElse(),
        ),
      ),
    );

    expect(find.text('Proof of delivery'), findsOneWidget);
    expect(find.text('Received by someone else'), findsOneWidget);
    expect(find.text('Locked manifest · v1'), findsOneWidget);
    expect(find.text('1× Bouquet'), findsOneWidget);
    expect(find.text('Relationship or role'), findsOneWidget);
    expect(find.byKey(const Key('handoff-recipient')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('complete-delivery')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('complete-delivery')))
          .onPressed,
      isNull,
    );
  });
}
