import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/generated/driver_ui_metrics.g.dart';
import 'package:rounds_driver_harness/src/app/harness_app_controller.dart';
import 'package:rounds_driver_harness/src/driver/driver_api.dart';
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

  testWidgets('G05 initial state locks canonical English geometry and visual', (
    tester,
  ) async {
    await _pumpEmergency(tester, controller: controller);

    expect(
      tester.getRect(find.byKey(const Key('driver-emergency-topbar'))).height,
      DriverG05Metrics.topBarHeight,
    );
    expect(find.text('ROUND PAUSED'), findsOneWidget);
    expect(find.text('Are you safe?'), findsOneWidget);
    expect(find.text('I’m safe'), findsOneWidget);
    expect(find.text('I need urgent help'), findsOneWidget);
    expect(
      find.text('I can wait safely while the Round is paused.'),
      findsOneWidget,
    );
    expect(find.text('Current location recorded'), findsOneWidget);
    expect(find.byKey(const Key('driver-emergency-footer')), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/g05-driver-emergency-initial-english-393x852.png',
      ),
    );
  });

  testWidgets('G05 safe committed state matches the supplied board', (
    tester,
  ) async {
    String? submittedStatus;
    DriverLocationEvidence? submittedPosition;
    await _pumpEmergency(
      tester,
      controller: controller,
      sender: (status, position) async {
        submittedStatus = status;
        submittedPosition = position;
        return const DriverCommandOutcome(DriverCommandDisposition.committed);
      },
    );

    await tester.tap(find.byKey(const Key('driver-emergency-safe')));
    await tester.pumpAndSettle();

    expect(submittedStatus, 'safe');
    expect(submittedPosition?.latitude, 13.73);
    expect(
      find.text('Operations has been notified. The Round remains paused.'),
      findsOneWidget,
    );
    expect(find.text('Round paused'), findsOneWidget);
    expect(find.text('Return to paused Round'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/g05-driver-emergency-safe-english-393x852.png',
      ),
    );
  });

  testWidgets('G05 urgent committed state matches the supplied board', (
    tester,
  ) async {
    await _pumpEmergency(
      tester,
      controller: controller,
      sender: _committedEmergency,
    );

    await tester.tap(find.byKey(const Key('driver-emergency-urgent')));
    await tester.pumpAndSettle();

    expect(find.text('URGENT HELP'), findsOneWidget);
    expect(
      find.text('Operations has been notified and the active Round is paused.'),
      findsOneWidget,
    );
    expect(find.text('Emergency assistance'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/g05-driver-emergency-urgent-english-393x852.png',
      ),
    );
  });

  testWidgets('G05 emergency assistance is the supplied inset drawer', (
    tester,
  ) async {
    final launched = <Uri>[];
    await _pumpEmergency(
      tester,
      controller: controller,
      sender: _committedEmergency,
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
    expect(
      find.text('Choose the help you need. Your Round stays paused.'),
      findsOneWidget,
    );
    expect(find.text('Medical emergency'), findsOneWidget);
    expect(find.text('Police / immediate danger'), findsOneWidget);
    expect(
      find.text('Open the device emergency call handoff'),
      findsNWidgets(2),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/g05-driver-emergency-assistance-english-393x852.png',
      ),
    );

    await tester.tap(find.byKey(const Key('emergency-medical')));
    await tester.pumpAndSettle();
    expect(launched.single, Uri(scheme: 'tel', path: '1669'));
  });

  testWidgets('G05 pending emergency stays honest and durable', (tester) async {
    await _pumpEmergency(
      tester,
      controller: controller,
      sender: (status, position) async =>
          const DriverCommandOutcome(DriverCommandDisposition.pendingSync),
    );

    await tester.tap(find.byKey(const Key('driver-emergency-safe')));
    await tester.pumpAndSettle();

    expect(
      find.text('Saved on this phone. Operations has not received it yet.'),
      findsOneWidget,
    );
    expect(find.text('Waiting to sync'), findsOneWidget);
    expect(find.textContaining('Operations has been notified'), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/g05-driver-emergency-safe-offline-english-393x852.png',
      ),
    );
  });

  testWidgets('G05 safe and urgent actions open the real phone handoffs', (
    tester,
  ) async {
    final launched = <Uri>[];
    await _pumpEmergency(
      tester,
      controller: controller,
      sender: _committedEmergency,
      launcher: (uri) async {
        launched.add(uri);
        return true;
      },
    );
    await tester.tap(find.byKey(const Key('driver-emergency-safe')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-emergency-primary')));
    await tester.pumpAndSettle();
    expect(launched.single.scheme, 'tel');
    expect(
      launched.single.path,
      AssignedRoundScreen.demoRound.pickup.contactPhone,
    );

    launched.clear();
    await _pumpEmergency(
      tester,
      controller: controller,
      sender: _committedEmergency,
      launcher: (uri) async {
        launched.add(uri);
        return true;
      },
    );
    await tester.tap(find.byKey(const Key('driver-emergency-urgent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-emergency-primary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('emergency-police')));
    await tester.pumpAndSettle();
    expect(launched.single, Uri(scheme: 'tel', path: '191'));
  });

  testWidgets('delivery exception entry opens canonical G05', (tester) async {
    final round = AssignedRoundScreen.demoRound;
    await _setViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
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
    await tester.tap(choice);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('continue-delivery-issue')),
    );
    await tester.tap(find.byKey(const Key('continue-delivery-issue')));
    await tester.pumpAndSettle();

    expect(find.byType(DriverEmergencyScreen), findsOneWidget);
  });
}

Future<DriverCommandOutcome?> _committedEmergency(
  String status,
  DriverLocationEvidence? position,
) async => const DriverCommandOutcome(DriverCommandDisposition.committed);

Future<void> _pumpEmergency(
  WidgetTester tester, {
  required HarnessAppController controller,
  DriverEmergencyLauncher? launcher,
  DriverEmergencySender? sender,
}) async {
  await _setViewport(tester);
  final round = AssignedRoundScreen.demoRound;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildRoundsDriverTheme(),
      home: DriverEmergencyScreen(
        key: UniqueKey(),
        controller: controller,
        round: round,
        stop: round.stops.first,
        locationProvider: () async => const DriverLocationEvidence(
          latitude: 13.73,
          longitude: 100.568,
          accuracyMeters: 8,
        ),
        launcher: launcher ?? (_) async => true,
        sendEmergency: sender,
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
