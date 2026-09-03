import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/generated/driver_ui_metrics.g.dart';
import 'package:rounds_driver_harness/src/app/harness_app_controller.dart';
import 'package:rounds_driver_harness/src/ui/assigned_round_screen.dart';
import 'package:rounds_driver_harness/src/ui/components/delivery_issue_flow.dart';
import 'package:rounds_driver_harness/src/ui/location_problem_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HarnessAppController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    controller = await HarnessAppController.create();
  });

  testWidgets('G02 uses the canonical 393px topbar and footer regions', (
    tester,
  ) async {
    await _pumpLocationProblem(tester, controller: controller);

    final topbar = tester.getRect(
      find.byKey(const Key('location-problem-topbar')),
    );
    final footer = tester.getRect(
      find.byKey(const Key('location-problem-footer')),
    );

    expect(topbar.top, 0);
    expect(topbar.height, DriverG02Metrics.topBarHeight);
    expect(footer.bottom, 852);
    expect(
      footer.height,
      DriverG02Metrics.footerPaddingTop +
          DriverG02Metrics.secondaryHeight +
          DriverG02Metrics.footerPaddingBottom +
          1,
    );
    expect(find.text('Location problem'), findsOneWidget);
    expect(find.text('Pin is wrong'), findsOneWidget);
    expect(find.text('Entrance / access is wrong'), findsOneWidget);
    expect(find.text('Address is wrong'), findsOneWidget);
    expect(find.text("Can't find location"), findsOneWidget);
  });

  testWidgets('a real current-position observation is never called confirmed', (
    tester,
  ) async {
    await _pumpLocationProblem(
      tester,
      controller: controller,
      locationProvider: () async => const DriverLocationEvidence(
        latitude: 13.730001,
        longitude: 100.568001,
        accuracyMeters: 7.6,
      ),
    );

    await tester.tap(find.byKey(const Key('location-problem-pin-is-wrong')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('location-problem-pin-evidence')),
      findsOneWidget,
    );
    expect(find.text('Current location · ±8 m'), findsOneWidget);

    await tester.tap(find.byKey(const Key('location-problem-send-current')));
    await tester.pumpAndSettle();

    expect(find.text('Saved locally'), findsOneWidget);
    expect(find.text('Waiting to sync'), findsNWidgets(2));
    expect(find.textContaining('confirmed'), findsNothing);
    expect(find.textContaining('Route update ready'), findsNothing);
  });

  testWidgets('delivery exception entry opens canonical G02', (tester) async {
    final round = AssignedRoundScreen.demoRound;
    await _pumpFlowLauncher(
      tester,
      onPressed: (context) => openDeliveryIssueFlow(
        context,
        round: round,
        stop: round.stops.first,
        controller: controller,
      ),
    );

    await tester.tap(find.byKey(const Key('open-flow')));
    await tester.pumpAndSettle();
    final addressChoice = find.byKey(
      const Key('delivery-issue-address-or-entrance-problem'),
    );
    await tester.ensureVisible(addressChoice);
    await tester.pumpAndSettle();
    await tester.tap(addressChoice);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('continue-delivery-issue')),
    );
    await tester.tap(find.byKey(const Key('continue-delivery-issue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('location-problem-title')), findsOneWidget);
    expect(find.text(round.stops.first.recipientName), findsOneWidget);
  });

  testWidgets('pickup context calls the authoritative pickup contact', (
    tester,
  ) async {
    Uri? launched;
    await _pumpLocationProblem(
      tester,
      controller: controller,
      problemContext: LocationProblemContext.pickup,
      launcher: (uri) async {
        launched = uri;
        return true;
      },
    );

    await tester.tap(find.byKey(const Key('location-problem-call')));
    await tester.pumpAndSettle();

    expect(launched?.scheme, 'tel');
    expect(launched?.path, AssignedRoundScreen.demoRound.pickup.contactPhone);
  });

  testWidgets('G02 has a stable visual baseline', (tester) async {
    await _pumpLocationProblem(tester, controller: controller);
    await expectLater(
      find.byType(LocationProblemScreen),
      matchesGoldenFile('goldens/location-problem-393x852.png'),
    );
  });
}

Future<void> _pumpLocationProblem(
  WidgetTester tester, {
  required HarnessAppController controller,
  LocationProblemContext problemContext = LocationProblemContext.delivery,
  DriverLocationProvider? locationProvider,
  LocationProblemLauncher? launcher,
}) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final round = AssignedRoundScreen.demoRound;
  return tester.pumpWidget(
    MaterialApp(
      theme: buildRoundsDriverTheme(),
      home: LocationProblemScreen(
        controller: controller,
        round: round,
        stop: round.stops.first,
        problemContext: problemContext,
        locationProvider:
            locationProvider ??
            () async => const DriverLocationEvidence(
              latitude: 13.73,
              longitude: 100.568,
              accuracyMeters: 8,
            ),
        launcher: launcher ?? (_) async => true,
      ),
    ),
  );
}

Future<void> _pumpFlowLauncher(
  WidgetTester tester, {
  required Future<void> Function(BuildContext context) onPressed,
}) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  return tester.pumpWidget(
    MaterialApp(
      theme: buildRoundsDriverTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const Key('open-flow'),
              onPressed: () => onPressed(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}
