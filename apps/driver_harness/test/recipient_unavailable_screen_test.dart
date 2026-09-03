import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/generated/driver_ui_metrics.g.dart';
import 'package:rounds_driver_harness/src/app/harness_app_controller.dart';
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

  testWidgets('two failed calls become a durable Operations escalation CTA', (
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

    expect(find.text('Call recipient again'), findsOneWidget);
    expect(find.byKey(const Key('recipient-attempt-0')), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('recipient-unavailable-primary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recipient-outcome-busy')));
    await tester.pumpAndSettle();

    expect(launched, hasLength(2));
    expect(launched.every((uri) => uri.scheme == 'tel'), isTrue);
    expect(find.text('Contact Operations'), findsOneWidget);
    expect(find.byKey(const Key('recipient-attempt-1')), findsOneWidget);
    expect(find.text('Waiting for Operations'), findsNothing);
    expect(find.textContaining('approved'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('recipient-unavailable-primary')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rounds-action-drawer')), findsOneWidget);
    expect(find.text('Call UrbanFlowers Dispatch'), findsOneWidget);
    expect(find.text('Message UrbanFlowers Dispatch'), findsOneWidget);
  });
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
