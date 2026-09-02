import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/rounds_harness_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('round actions open as a bottom drawer', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('e01-round-actions')));
    await tester.pumpAndSettle();

    final drawer = find.byKey(const Key('rounds-action-drawer'));
    final rect = tester.getRect(drawer);
    expect(drawer, findsOneWidget);
    expect(rect.left, 0);
    expect(rect.right, 393);
    expect(rect.bottom, 852);
    expect(find.text('Round actions'), findsOneWidget);
    expect(find.text('Refresh Round'), findsOneWidget);
    expect(find.text('Choose language'), findsOneWidget);
    expect(find.text('Test camera + restart'), findsOneWidget);
    expect(find.byType(PopupMenuButton), findsNothing);
  });

  testWidgets('debug camera acceptance is isolated from delivery actions', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('e01-round-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test camera + restart'));
    await tester.pumpAndSettle();

    expect(find.text('Camera + restart test'), findsOneWidget);
    expect(
      find.text('DEVELOPMENT ACCEPTANCE · NOT A DELIVERY'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('complete-delivery')), findsNothing);
    expect(find.text('Confirm arrival'), findsNothing);
  });

  testWidgets('navigation actions use the same bottom drawer', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const Key('start-navigation')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('navigation-more')));
    await tester.pumpAndSettle();

    final drawer = find.byKey(const Key('rounds-action-drawer'));
    expect(drawer, findsOneWidget);
    expect(tester.getRect(drawer).bottom, 852);
    expect(find.text('Navigation actions'), findsOneWidget);
    expect(find.text('Contact Operations'), findsOneWidget);
    expect(find.text('Report exception'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rounds-action-contact')));
    await tester.pumpAndSettle();
    expect(drawer, findsOneWidget);
    expect(find.text('Contact Operations'), findsOneWidget);
    expect(find.text('Call UrbanFlowers Dispatch'), findsOneWidget);
    expect(find.text('Message UrbanFlowers Dispatch'), findsOneWidget);
  });

  testWidgets('report exception opens a structured bottom drawer', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const Key('start-navigation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('navigation-more')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rounds-action-exception')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delivery-issue-drawer')), findsOneWidget);
    expect(find.text('Report exception'), findsOneWidget);
    expect(find.text('Recipient unavailable'), findsOneWidget);
    expect(find.text('Address or entrance problem'), findsOneWidget);
    expect(find.text('Cannot complete delivery'), findsOneWidget);
    expect(find.text('Emergency or safety issue'), findsOneWidget);

    final continueButton = tester.widget<FilledButton>(
      find.byKey(const Key('continue-delivery-issue')),
    );
    expect(continueButton.onPressed, isNull);

    await tester.tap(
      find.byKey(const Key('delivery-issue-recipient-unavailable')),
    );
    await tester.pump();
    final enabledButton = tester.widget<FilledButton>(
      find.byKey(const Key('continue-delivery-issue')),
    );
    expect(enabledButton.onPressed, isNotNull);
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'driver_locale': 'en',
    'driver_locale_selected': true,
  });
  final controller = await HarnessAppController.create();
  await tester.pumpWidget(
    RoundsHarnessApp(controller: controller, enableNativeNavigation: false),
  );
  await tester.pumpAndSettle();
}
