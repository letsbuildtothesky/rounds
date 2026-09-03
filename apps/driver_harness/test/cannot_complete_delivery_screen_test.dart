import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/generated/driver_ui_metrics.g.dart';
import 'package:rounds_driver_harness/src/app/harness_app_controller.dart';
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

  testWidgets('G04 geometry is generated from the canonical HTML metrics', (
    tester,
  ) async {
    await _pumpScreen(tester, controller: controller);

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
  });

  testWidgets('blocked delivery keeps custody and waits for a real decision', (
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

    await tester.tap(find.byKey(const Key('cannot-complete-no_access')));
    await tester.pumpAndSettle();
    expect(find.text('Keep the package with you'), findsOneWidget);
    expect(find.text('Call recipient'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cannot-complete-primary')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('cannot-complete-outcome-no_answer')),
    );
    await tester.pumpAndSettle();

    expect(launched, hasLength(1));
    expect(launched.single.scheme, 'tel');
    expect(find.byKey(const Key('cannot-complete-attempt-0')), findsOneWidget);
    expect(find.text('Send to Operations'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cannot-complete-primary')));
    await tester.pumpAndSettle();

    expect(find.text('Waiting for decision'), findsOneWidget);
    expect(find.text('Keep the delivery with you'), findsOneWidget);
    expect(find.text('No next step has been approved yet'), findsOneWidget);
    expect(find.text('Return this package'), findsNothing);
    expect(find.text('Continue Round'), findsNothing);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required HarnessAppController controller,
  CannotCompleteLauncher? launcher,
}) async {
  await _setReferenceViewport(tester);
  final round = AssignedRoundScreen.demoRound;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildRoundsDriverTheme(),
      home: CannotCompleteDeliveryScreen(
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
