import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/generated/driver_ui_metrics.g.dart';
import 'package:rounds_driver_harness/src/app/harness_app_controller.dart';
import 'package:rounds_driver_harness/src/driver/driver_api.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';
import 'package:rounds_driver_harness/src/ui/assigned_round_screen.dart';
import 'package:rounds_driver_harness/src/ui/cannot_complete_delivery_screen.dart';
import 'package:rounds_driver_harness/src/ui/components/delivery_issue_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late HarnessAppController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    controller = await HarnessAppController.create();
  });

  testWidgets('delivery exception opens the supplied G04 reason screen', (
    tester,
  ) async {
    final round = AssignedRoundScreen.demoRound;
    await _setReferenceViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              key: const Key('open-g04-flow'),
              onPressed: () => openDeliveryIssueFlow(
                context,
                round: round,
                stop: round.stops.first,
                controller: controller,
                launcher: (_) async => true,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-g04-flow')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('delivery-issue-cannot-complete-delivery')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('continue-delivery-issue')),
    );
    await tester.tap(find.byKey(const Key('continue-delivery-issue')));
    await tester.pumpAndSettle();

    expect(find.byType(CannotCompleteDeliveryScreen), findsOneWidget);
    expect(find.text('Can’t complete delivery'), findsOneWidget);
    expect(find.text('No access'), findsOneWidget);
    expect(find.text('Delivery refused'), findsOneWidget);
    expect(find.text('Location closed'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
  });

  testWidgets('G04 initial state locks canonical English geometry and visual', (
    tester,
  ) async {
    await _pumpCanonicalScreen(tester, controller: controller);

    expect(
      tester.getRect(find.byKey(const Key('cannot-complete-topbar'))).height,
      DriverG04Metrics.topBarHeight,
    );
    final footer = tester.getRect(
      find.byKey(const Key('cannot-complete-footer')),
    );
    expect(footer.bottom, DriverReferenceViewport.height);
    expect(
      footer.height,
      DriverG04Metrics.footerPaddingTop +
          DriverG04Metrics.secondaryHeight +
          DriverG04Metrics.footerPaddingBottom +
          1,
    );
    expect(find.text('K. Nattaporn'), findsOneWidget);
    expect(find.text('The Emporio Place · Sukhumvit 24'), findsOneWidget);
    expect(find.text('Midnight Orchid + glass vase'), findsOneWidget);
    expect(find.text('Fragile'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/g04-cannot-complete-initial-english-393x852.png',
      ),
    );
  });

  testWidgets('G04 action drawer is the supplied inset delivery problem menu', (
    tester,
  ) async {
    await _pumpCanonicalScreen(tester, controller: controller);

    await tester.tap(find.byKey(const Key('cannot-complete-more')));
    await tester.pumpAndSettle();

    expect(find.text('Delivery problem'), findsOneWidget);
    expect(find.text('Message Operations'), findsAtLeastNWidgets(1));
    expect(find.text('Address / entrance problem'), findsOneWidget);
    expect(find.text('Emergency'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/g04-cannot-complete-actions-english-393x852.png',
      ),
    );
  });

  testWidgets('G04 call-first action and call outcome match the supplied UX', (
    tester,
  ) async {
    final launched = <Uri>[];
    await _pumpCanonicalScreen(
      tester,
      controller: controller,
      launcher: (uri) async {
        launched.add(uri);
        return true;
      },
    );

    await tester.tap(find.byKey(const Key('cannot-complete-no_access')));
    await tester.pumpAndSettle();
    expect(find.text('Keep the package with you'), findsOneWidget);
    expect(find.text('Call recipient'), findsOneWidget);
    expect(
      find.byKey(const Key('cannot-complete-contact-operations')),
      findsOneWidget,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/g04-cannot-complete-no-access-english-393x852.png',
      ),
    );

    await tester.tap(find.byKey(const Key('cannot-complete-primary')));
    await tester.pumpAndSettle();
    expect(launched.single.scheme, 'tel');
    expect(find.text('Call outcome'), findsOneWidget);
    expect(find.text('Issue resolved'), findsOneWidget);
    expect(find.text('Reached · still blocked'), findsOneWidget);
    expect(find.text('No answer'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/g04-cannot-complete-call-outcome-english-393x852.png',
      ),
    );
  });

  testWidgets('G04 recorded call changes to one Operations action', (
    tester,
  ) async {
    await _pumpCanonicalScreen(
      tester,
      controller: controller,
      attempts: [
        DriverContactAttemptModel(
          id: 'g04-attempt-1',
          target: 'recipient',
          channel: 'native_phone',
          outcome: 'no_answer',
          occurredAt: DateTime(2026, 9, 7, 14, 51),
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('cannot-complete-no_access')));
    await tester.pumpAndSettle();

    expect(find.text('Contact Operations'), findsOneWidget);
    expect(find.text('Call recipient'), findsNothing);
    expect(find.text('No answer'), findsOneWidget);
    expect(find.byKey(const Key('cannot-complete-attempt-0')), findsOneWidget);
    expect(
      find.byKey(const Key('cannot-complete-contact-operations')),
      findsNothing,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/g04-cannot-complete-after-call-english-393x852.png',
      ),
    );
  });

  testWidgets('G04 Other uses the supplied structured note drawer', (
    tester,
  ) async {
    await _pumpCanonicalScreen(tester, controller: controller);

    await tester.tap(find.byKey(const Key('cannot-complete-other')));
    await tester.pumpAndSettle();

    expect(find.text('Other reason'), findsOneWidget);
    expect(find.text('Short note'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Use this reason'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/g04-cannot-complete-other-english-393x852.png',
      ),
    );
  });

  testWidgets('G04 sends the real structured report then waits honestly', (
    tester,
  ) async {
    var sentBody = '';
    await _pumpCanonicalScreen(
      tester,
      controller: controller,
      sendToOperations: (body) async {
        sentBody = body;
        return const DriverCommandOutcome(DriverCommandDisposition.committed);
      },
    );

    await tester.tap(find.byKey(const Key('cannot-complete-delivery_refused')));
    await tester.pumpAndSettle();
    expect(find.text('Contact Operations'), findsOneWidget);
    expect(
      find.byKey(const Key('cannot-complete-contact-operations')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('cannot-complete-primary')));
    await tester.pumpAndSettle();

    expect(sentBody, contains('CANNOT COMPLETE DELIVERY'));
    expect(sentBody, contains('Reason: Delivery refused (delivery_refused)'));
    expect(sentBody, contains('Custody: package remains with driver'));
    expect(find.text('Waiting for decision'), findsOneWidget);
    expect(find.text('Keep the delivery with you'), findsOneWidget);
    expect(find.text('Operations has the structured reason.'), findsOneWidget);
    expect(find.text('Waiting for Operations'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('cannot-complete-primary')),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Return this package'), findsNothing);
    expect(find.text('Continue Round'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/g04-cannot-complete-waiting-english-393x852.png',
      ),
    );
  });

  testWidgets('G04 distinguishes locally saved waiting truth', (tester) async {
    await _pumpCanonicalScreen(
      tester,
      controller: controller,
      sendToOperations: (_) async =>
          const DriverCommandOutcome(DriverCommandDisposition.pendingSync),
    );

    await tester.tap(find.byKey(const Key('cannot-complete-location_closed')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('cannot-complete-contact-operations')),
    );
    await tester.pumpAndSettle();

    expect(find.text('SAVED ON THIS PHONE'), findsOneWidget);
    expect(
      find.text('Saved locally. It will send when Rounds reconnects.'),
      findsOneWidget,
    );
    expect(find.text('Waiting to sync'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/g04-cannot-complete-waiting-offline-english-393x852.png',
      ),
    );
  });
}

Future<void> _pumpCanonicalScreen(
  WidgetTester tester, {
  required HarnessAppController controller,
  CannotCompleteLauncher? launcher,
  CannotCompleteSender? sendToOperations,
  List<DriverContactAttemptModel> attempts = const [],
}) async {
  await _setReferenceViewport(tester);
  final round = _canonicalRound(attempts);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildRoundsDriverTheme(),
      home: CannotCompleteDeliveryScreen(
        controller: controller,
        round: round,
        stop: round.stops.first,
        launcher: launcher ?? (_) async => true,
        sendToOperations: sendToOperations,
        pendingAttemptsLoader: (_) async => const [],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _setReferenceViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(
    DriverReferenceViewport.width,
    DriverReferenceViewport.height,
  );
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

DriverRoundModel _canonicalRound(List<DriverContactAttemptModel> attempts) {
  final stop = DriverRoundStopModel(
    id: 'g04-stop-1',
    sequence: 1,
    state: 'arrived',
    version: 1,
    destinationVersion: 1,
    manifestId: 'g04-manifest',
    manifestVersion: 1,
    deliveryReference: 'UF-G04-001',
    recipientName: 'K. Nattaporn',
    recipientPhone: '+66999999999',
    rawAddress: 'The Emporio Place · Sukhumvit 24',
    latitude: 13.7246,
    longitude: 100.5669,
    windowStart: '2026-09-07T07:00:00Z',
    windowEnd: '2026-09-07T08:00:00Z',
    manifestItems: const [
      DriverManifestItemModel(
        lineNumber: 1,
        description: 'Midnight Orchid + glass vase',
        quantity: 1,
        handlingNote: 'Fragile',
      ),
    ],
    contactAttempts: attempts,
  );
  return DriverRoundModel(
    id: 'g04-round',
    reference: 'ROUND-G04',
    serviceDate: '2026-09-07',
    state: 'active',
    version: 1,
    tenantName: 'UrbanFlowers',
    pickup: const DriverPickupModel(
      id: 'g04-pickup',
      displayName: 'UrbanFlowers',
      rawAddress: 'Sukhumvit 39, Bangkok',
      contactName: 'UrbanFlowers Dispatch',
      contactPhone: '+66000000000',
    ),
    stops: List<DriverRoundStopModel>.filled(4, stop),
  );
}
