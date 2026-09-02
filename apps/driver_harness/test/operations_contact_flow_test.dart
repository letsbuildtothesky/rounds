import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/ui/assigned_round_screen.dart';
import 'package:rounds_driver_harness/src/ui/components/delivery_issue_flow.dart';
import 'package:rounds_driver_harness/src/ui/components/operations_contact_flow.dart';

void main() {
  final round = AssignedRoundScreen.demoRound;
  final stop = round.stops.first;

  testWidgets('contact action launches the configured dispatch phone', (
    tester,
  ) async {
    Uri? launched;
    await _pumpLauncher(
      tester,
      onPressed: (context) => openOperationsContactFlow(
        context,
        round: round,
        stop: stop,
        launcher: (uri) async {
          launched = uri;
          return true;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('open-flow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rounds-action-call')));
    await tester.pumpAndSettle();

    expect(launched?.scheme, 'tel');
    expect(launched?.path, round.pickup.contactPhone);
  });

  testWidgets('exception message carries exact Round and Stop context', (
    tester,
  ) async {
    Uri? launched;
    await _pumpLauncher(
      tester,
      onPressed: (context) => openDeliveryIssueFlow(
        context,
        round: round,
        stop: stop,
        launcher: (uri) async {
          launched = uri;
          return true;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('open-flow')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('delivery-issue-cannot-complete-delivery')),
    );
    await tester.enterText(
      find.byKey(const Key('delivery-issue-note')),
      'Security will not allow entry.',
    );
    await tester.ensureVisible(
      find.byKey(const Key('continue-delivery-issue')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('continue-delivery-issue')));
    await tester.pumpAndSettle();

    expect(launched?.scheme, 'sms');
    expect(launched?.path, round.pickup.contactPhone);
    final body = launched?.queryParameters['body'] ?? '';
    expect(body, contains(round.reference));
    expect(body, contains(stop.deliveryReference));
    expect(body, contains('Cannot complete delivery'));
    expect(body, contains('Security will not allow entry.'));
  });

  testWidgets('delivery issue drawer exposes the native damage-photo path', (
    tester,
  ) async {
    await _pumpLauncher(
      tester,
      onPressed: (context) =>
          openDeliveryIssueFlow(context, round: round, stop: stop),
    );

    await tester.tap(find.byKey(const Key('open-flow')));
    await tester.pumpAndSettle();
    expect(find.text('Damaged package'), findsOneWidget);
    await tester.tap(find.byKey(const Key('delivery-issue-damaged-package')));
    await tester.pumpAndSettle();
    expect(find.text('Continue to damage photo'), findsOneWidget);
  });

  testWidgets('failed external handoff is visible and never claims success', (
    tester,
  ) async {
    await _pumpLauncher(
      tester,
      onPressed: (context) => openOperationsContactFlow(
        context,
        round: round,
        stop: stop,
        launcher: (_) async => false,
      ),
    );

    await tester.tap(find.byKey(const Key('open-flow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rounds-action-message')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('operations-contact-launch-error')),
      findsOneWidget,
    );
    expect(find.textContaining('sent'), findsNothing);
  });

  testWidgets('message action opens the persistent in-app thread', (
    tester,
  ) async {
    var openedThread = false;
    var launchedExternal = false;
    await _pumpLauncher(
      tester,
      onPressed: (context) => openOperationsContactFlow(
        context,
        round: round,
        stop: stop,
        onMessage: () async => openedThread = true,
        launcher: (_) async {
          launchedExternal = true;
          return true;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('open-flow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rounds-action-message')));
    await tester.pumpAndSettle();

    expect(openedThread, isTrue);
    expect(launchedExternal, isFalse);
  });
}

Future<void> _pumpLauncher(
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
