import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/generated/driver_ui_metrics.g.dart';
import 'package:rounds_driver_harness/src/app/harness_app_controller.dart';
import 'package:rounds_driver_harness/src/ui/assigned_round_screen.dart';
import 'package:rounds_driver_harness/src/ui/components/delivery_issue_flow.dart';
import 'package:rounds_driver_harness/src/ui/driver_emergency_screen.dart';
import 'package:rounds_driver_harness/src/ui/location_problem_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HarnessAppController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    controller = await HarnessAppController.create();
  });

  testWidgets('G05 initial geometry and safety choices follow the HTML board', (
    tester,
  ) async {
    await _pumpEmergency(tester, controller: controller);

    expect(
      tester.getRect(find.byKey(const Key('driver-emergency-topbar'))).height,
      DriverG05Metrics.topBarHeight,
    );
    expect(find.text('Are you safe?'), findsOneWidget);
    expect(find.text('I’m safe'), findsOneWidget);
    expect(find.text('I need urgent help'), findsOneWidget);
    expect(find.text('Round paused'), findsNothing);
    expect(find.byKey(const Key('driver-emergency-footer')), findsNothing);
  });

  testWidgets(
    'safe status is durable before the screen claims Operations truth',
    (tester) async {
      await _pumpEmergency(tester, controller: controller);
      await tester.tap(find.byKey(const Key('driver-emergency-safe')));
      await tester.pumpAndSettle();

      expect(find.text('I’m safe'), findsOneWidget);
      expect(find.text('Waiting to sync'), findsOneWidget);
      expect(find.textContaining('Operations has received'), findsNothing);
      expect(find.text('Return to Round'), findsOneWidget);
    },
  );

  testWidgets('urgent status opens real emergency call choices', (
    tester,
  ) async {
    final launched = <Uri>[];
    await _pumpEmergency(
      tester,
      controller: controller,
      launcher: (uri) async {
        launched.add(uri);
        return true;
      },
    );
    await tester.tap(find.byKey(const Key('driver-emergency-urgent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-emergency-primary')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('emergency-assistance-sheet')), findsOneWidget);
    expect(find.text('Medical emergency'), findsOneWidget);
    expect(find.text('Police / immediate danger'), findsOneWidget);

    await tester.tap(find.byKey(const Key('emergency-medical')));
    await tester.pumpAndSettle();
    expect(launched.single, Uri(scheme: 'tel', path: '1669'));
  });

  testWidgets('delivery exception entry opens canonical G05', (tester) async {
    final round = AssignedRoundScreen.demoRound;
    await _setViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              key: const Key('open-g05'),
              onPressed: () => openDeliveryIssueFlow(
                context,
                round: round,
                stop: round.stops.first,
                controller: controller,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-g05')));
    await tester.pumpAndSettle();
    final choice = find.byKey(
      const Key('delivery-issue-emergency-or-safety-issue'),
    );
    await tester.ensureVisible(choice);
    await tester.pumpAndSettle();
    await tester.tap(choice);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('continue-delivery-issue')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('continue-delivery-issue')));
    await tester.pumpAndSettle();

    expect(find.byType(DriverEmergencyScreen), findsOneWidget);
  });
}

Future<void> _pumpEmergency(
  WidgetTester tester, {
  required HarnessAppController controller,
  DriverEmergencyLauncher? launcher,
}) async {
  await _setViewport(tester);
  final round = AssignedRoundScreen.demoRound;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildRoundsDriverTheme(),
      home: DriverEmergencyScreen(
        controller: controller,
        round: round,
        stop: round.stops.first,
        locationProvider: () async => const DriverLocationEvidence(
          latitude: 13.73,
          longitude: 100.568,
          accuracyMeters: 8,
        ),
        launcher: launcher ?? (_) async => true,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _setViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(
    DriverReferenceViewport.width,
    DriverReferenceViewport.height,
  );
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
