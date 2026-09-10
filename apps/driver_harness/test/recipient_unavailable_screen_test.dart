import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/generated/driver_ui_metrics.g.dart';
import 'package:rounds_driver_harness/src/app/harness_app_controller.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';
import 'package:rounds_driver_harness/src/ui/assigned_round_screen.dart';
import 'package:rounds_driver_harness/src/ui/components/delivery_issue_flow.dart';
import 'package:rounds_driver_harness/src/ui/recipient_unavailable_screen.dart';
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

  testWidgets('delivery exception opens the canonical G01 screen', (
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
              key: const Key('open-flow'),
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

    await tester.tap(find.byKey(const Key('open-flow')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('delivery-issue-recipient-unavailable')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('continue-delivery-issue')),
    );
    await tester.tap(find.byKey(const Key('continue-delivery-issue')));
    await tester.pumpAndSettle();

    expect(find.byType(RecipientUnavailableScreen), findsOneWidget);
    expect(find.text('Recipient unavailable'), findsOneWidget);
    expect(find.text('No attempts yet'), findsOneWidget);
  });

  testWidgets('G01 geometry is sourced from the canonical metrics contract', (
    tester,
  ) async {
    await _pumpScreen(tester, controller: controller);

    final topbar = tester.getRect(
      find.byKey(const Key('recipient-unavailable-topbar')),
    );
    final footer = tester.getRect(
      find.byKey(const Key('recipient-unavailable-footer')),
    );

    expect(topbar.top, 0);
    expect(topbar.height, DriverG01Metrics.topBarHeight);
    expect(footer.bottom, DriverReferenceViewport.height);
    expect(
      footer.height,
      DriverG01Metrics.footerPaddingTop +
          DriverG01Metrics.primaryHeight +
          DriverG01Metrics.secondaryGap +
          DriverG01Metrics.secondaryHeight +
          DriverG01Metrics.footerPaddingBottom +
          1,
    );
  });

  testWidgets('G01 initial English state matches the canonical board', (
    tester,
  ) async {
    await _pumpCanonicalScreen(tester, controller: controller);

    expect(find.text('STOP 1 OF 4'), findsOneWidget);
    expect(find.text('K. Nattaporn'), findsNWidgets(2));
    expect(find.text('Fragile bouquet'), findsOneWidget);
    expect(find.text('1× Fragile bouquet'), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/g01-recipient-unavailable-initial-english-393x852.png',
      ),
    );
  });

  testWidgets('G01 call outcome uses the canonical bottom drawer', (
    tester,
  ) async {
    await _pumpCanonicalScreen(tester, controller: controller);

    await tester.tap(find.byKey(const Key('recipient-unavailable-primary')));
    await tester.pumpAndSettle();

    expect(find.text('Call outcome'), findsOneWidget);
    expect(find.text('Reached recipient'), findsOneWidget);
    expect(find.text('No answer'), findsOneWidget);
    expect(find.text('Busy / declined'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/g01-recipient-unavailable-call-outcome-english-393x852.png',
      ),
    );
  });

  for (final scenario in _attemptScenarios) {
    testWidgets(
      'G01 ${scenario.name} English state matches the canonical board',
      (tester) async {
        await _pumpCanonicalScreen(
          tester,
          controller: controller,
          attempts: scenario.attempts,
        );

        expect(find.text(scenario.primaryLabel), findsOneWidget);
        expect(
          find.byKey(const Key('recipient-unavailable-operations')),
          scenario.attempts.length < 2 ? findsOneWidget : findsNothing,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/${scenario.goldenName}'),
        );
      },
    );
  }

  testWidgets('unconfigured call outcomes never fabricate durable attempts', (
    tester,
  ) async {
    final launched = <Uri>[];
    await _pumpScreen(
      tester,
      controller: controller,
      launcher: (uri) async {
        launched.add(uri);
        return true;
      },
    );

    await tester.tap(find.byKey(const Key('recipient-unavailable-primary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recipient-outcome-no_answer')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing was sent or saved.'), findsOneWidget);
    expect(find.text('Call recipient again'), findsNothing);
    expect(find.byKey(const Key('recipient-attempt-0')), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('recipient-unavailable-primary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recipient-outcome-busy')));
    await tester.pumpAndSettle();

    expect(launched, hasLength(2));
    expect(launched.every((uri) => uri.scheme == 'tel'), isTrue);
    expect(find.textContaining('Nothing was sent or saved.'), findsOneWidget);
    expect(find.byKey(const Key('recipient-attempt-1')), findsNothing);
    expect(find.text('Waiting for Operations'), findsNothing);
    expect(find.textContaining('approved'), findsNothing);
  });

  testWidgets(
    'two recorded call attempts expose the Operations action drawer',
    (tester) async {
      // Explicit display fixture, not a claim that this widget recorded a call.
      // Durable contact records are covered by driver_command_outbox_test.dart.
      await _pumpCanonicalScreen(
        tester,
        controller: controller,
        attempts: _attemptScenarios.last.attempts,
      );
      expect(find.text('Contact Operations'), findsOneWidget);

      await tester.tap(find.byKey(const Key('recipient-unavailable-primary')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rounds-action-drawer')), findsOneWidget);
      expect(find.text('Call UrbanFlowers Dispatch'), findsOneWidget);
      expect(find.text('Message UrbanFlowers Dispatch'), findsOneWidget);
    },
  );
}

Future<void> _pumpCanonicalScreen(
  WidgetTester tester, {
  required HarnessAppController controller,
  List<DriverContactAttemptModel> attempts = const [],
}) async {
  await _setReferenceViewport(tester);
  final round = _canonicalRound(attempts);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildRoundsDriverTheme(),
      home: RecipientUnavailableScreen(
        controller: controller,
        round: round,
        stop: round.stops.first,
        launcher: (_) async => true,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required HarnessAppController controller,
  RecipientUnavailableLauncher? launcher,
}) async {
  await _setReferenceViewport(tester);
  final round = AssignedRoundScreen.demoRound;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildRoundsDriverTheme(),
      home: RecipientUnavailableScreen(
        controller: controller,
        round: round,
        stop: round.stops.first,
        launcher: launcher ?? (_) async => true,
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
    id: 'g01-stop-1',
    sequence: 1,
    state: 'arrived',
    version: 1,
    destinationVersion: 1,
    manifestId: 'g01-manifest',
    manifestVersion: 1,
    deliveryReference: 'UF-G01-001',
    recipientName: 'K. Nattaporn',
    recipientPhone: '+66999999999',
    rawAddress: 'The Emporio Place · Sukhumvit 24',
    latitude: 13.7246,
    longitude: 100.5669,
    windowStart: '2026-09-07T07:00:00Z',
    windowEnd: '2026-09-07T08:00:00Z',
    accessNote: 'Lobby entrance · Tower A',
    manifestItems: const [
      DriverManifestItemModel(
        lineNumber: 1,
        description: 'Fragile bouquet',
        quantity: 1,
      ),
    ],
    contactAttempts: attempts,
  );
  return DriverRoundModel(
    id: 'g01-round',
    reference: 'ROUND-G01',
    serviceDate: '2026-09-07',
    state: 'active',
    version: 1,
    tenantName: 'UrbanFlowers',
    pickup: const DriverPickupModel(
      id: 'g01-pickup',
      displayName: 'UrbanFlowers',
      rawAddress: 'Sukhumvit 39, Bangkok',
      contactName: 'UrbanFlowers Dispatch',
      contactPhone: '+66000000000',
    ),
    stops: List<DriverRoundStopModel>.filled(4, stop),
  );
}

final _attemptScenarios = [
  _AttemptScenario(
    name: 'one-attempt',
    primaryLabel: 'Call recipient again',
    goldenName: 'g01-recipient-unavailable-one-attempt-english-393x852.png',
    attempts: [
      DriverContactAttemptModel(
        id: 'attempt-1',
        target: 'recipient',
        channel: 'native_phone',
        outcome: 'no_answer',
        occurredAt: DateTime(2026, 9, 7, 14, 36),
      ),
    ],
  ),
  _AttemptScenario(
    name: 'two-attempt',
    primaryLabel: 'Contact Operations',
    goldenName: 'g01-recipient-unavailable-two-attempt-english-393x852.png',
    attempts: [
      DriverContactAttemptModel(
        id: 'attempt-1',
        target: 'recipient',
        channel: 'native_phone',
        outcome: 'no_answer',
        occurredAt: DateTime(2026, 9, 7, 14, 36),
      ),
      DriverContactAttemptModel(
        id: 'attempt-2',
        target: 'recipient',
        channel: 'native_phone',
        outcome: 'busy',
        occurredAt: DateTime(2026, 9, 7, 14, 38),
      ),
    ],
  ),
];

class _AttemptScenario {
  const _AttemptScenario({
    required this.name,
    required this.primaryLabel,
    required this.goldenName,
    required this.attempts,
  });

  final String name;
  final String primaryLabel;
  final String goldenName;
  final List<DriverContactAttemptModel> attempts;
}
