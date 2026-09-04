import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/app_strings.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/harness_app_controller.dart';
import 'package:rounds_driver_harness/src/driver/driver_handoff_selection.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';
import 'package:rounds_driver_harness/src/ui/dropoff_handoff_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('English F01 follows the measured 393 layout and real data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller(HarnessLocale.english);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    expect(find.text('Who received it?'), findsOneWidget);
    expect(find.text('AT STOP 1'), findsOneWidget);
    expect(find.text('1 of 4'), findsOneWidget);
    expect(find.text('Nattaporn'), findsNWidgets(2));
    expect(find.text('Midnight Orchid + glass vase'), findsOneWidget);
    expect(find.text('Fragile'), findsOneWidget);
    expect(find.text('Reception · Security · Family · Staff'), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('handoff-top-bar'))).height, 60);
    expect(tester.getTopLeft(find.byKey(const Key('handoff-content'))).dx, 0);
    expect(
      (tester.widget(find.byType(Scaffold)) as Scaffold).backgroundColor,
      RoundsColors.surface,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/dropoff-handoff-english-393x852.png'),
    );
  });

  testWidgets('each direct handoff opens POD with the selected authority', (
    tester,
  ) async {
    final controller = await _controller(HarnessLocale.english);
    DriverHandoffSelection? captured;
    await tester.pumpWidget(
      _app(
        controller,
        podBuilder: (selection) {
          captured = selection;
          return const Scaffold(body: Text('POD destination'));
        },
      ),
    );

    await tester.tap(find.byKey(const Key('handoff-someone-else')));
    await tester.pumpAndSettle();
    expect(find.text('POD destination'), findsOneWidget);
    expect(captured?.handoffType, 'someone_else');
  });

  testWidgets('left at location uses the canonical bottom drawer', (
    tester,
  ) async {
    final controller = await _controller(HarnessLocale.english);
    DriverHandoffSelection? captured;
    await tester.pumpWidget(
      _app(
        controller,
        podBuilder: (selection) {
          captured = selection;
          return const Scaffold(body: Text('POD destination'));
        },
      ),
    );

    await tester.tap(find.byKey(const Key('handoff-left-at-location')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('left-location-drawer')), findsOneWidget);
    expect(find.text('Lobby / entrance'), findsOneWidget);
    expect(find.text('Other approved place'), findsOneWidget);

    await tester.tap(find.byKey(const Key('left-location-reception')));
    await tester.pumpAndSettle();
    expect(captured?.handoffType, 'left_at_location');
    expect(captured?.leftAtLocation, 'Reception');
    expect(find.text('POD destination'), findsOneWidget);
  });

  testWidgets('Thai compact F01 uses supplied Thai copy without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller(HarnessLocale.thai);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    expect(find.text('ใครรับของ?'), findsOneWidget);
    expect(find.text('ส่งมอบให้'), findsOneWidget);
    expect(find.text('ผู้รับ'), findsOneWidget);
    expect(find.text('คนอื่นรับแทน'), findsOneWidget);
    expect(find.text('วางไว้ที่จุดส่ง'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<HarnessAppController> _controller(HarnessLocale locale) async {
  SharedPreferences.setMockInitialValues({
    'driver_locale': locale.storageValue,
    'driver_locale_selected': true,
  });
  return HarnessAppController.create();
}

Widget _app(HarnessAppController controller, {HandoffPodBuilder? podBuilder}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildRoundsDriverTheme(),
      locale: controller.locale.locale,
      home: DropoffHandoffScreen(
        controller: controller,
        round: _round,
        stop: _stop,
        stopCount: 4,
        podBuilder: podBuilder,
      ),
    );

const _stop = DriverRoundStopModel(
  id: 'stop-1',
  sequence: 1,
  state: 'arrived',
  version: 5,
  destinationVersion: 1,
  manifestId: 'manifest-1',
  manifestVersion: 1,
  deliveryReference: 'UF-001',
  recipientName: 'Nattaporn',
  recipientPhone: '+66999999999',
  rawAddress: 'The Emporio Place, Sukhumvit 24',
  latitude: 13.7,
  longitude: 100.5,
  windowStart: '2026-09-02T02:00:00Z',
  windowEnd: '2026-09-02T04:00:00Z',
  manifestItems: [
    DriverManifestItemModel(
      lineNumber: 1,
      description: 'Midnight Orchid + glass vase',
      quantity: 1,
      handlingNote: 'Fragile',
    ),
  ],
);

const _round = DriverRoundModel(
  id: 'round-1',
  reference: 'ROUND-001',
  serviceDate: '2026-09-04',
  state: 'active',
  version: 1,
  tenantName: 'UrbanFlowers',
  pickup: DriverPickupModel(
    id: 'pickup-1',
    displayName: 'UrbanFlowers',
    rawAddress: 'Bangkok',
    contactName: 'Operations',
    contactPhone: '+66000000000',
  ),
  stops: [_stop],
);
