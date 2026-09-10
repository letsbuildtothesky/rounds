import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/rounds_harness_app.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';
import 'package:rounds_driver_harness/src/ui/pickup_confirmation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Source-CSS geometry checks, NOT source-render or physical-device acceptance.
// The previous pre-v2.3 golden remains in git as historical evidence only.
void main() {
  setUpAll(() async {
    // Use the SDK's existing Roboto test font as an explicitly labelled Android
    // fallback. It is not bundled/copied or claimed to match licensed Arial.
    final sdk = Platform.environment['ROUNDS_TEST_FLUTTER_SDK'];
    if (sdk != null) {
      for (final name in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf']) {
        final file = File(
          '$sdk/engine/src/flutter/txt/third_party/fonts/$name',
        );
        final loader = FontLoader('Roboto')
          ..addFont(
            Future.value(ByteData.sublistView(await file.readAsBytes())),
          );
        await loader.load();
      }
    }
  });

  testWidgets('Refresh02 fixed regions use source CSS at 393 logical px', (
    tester,
  ) async {
    await _pumpPickup(tester, const Size(393, 852));
    expect(
      tester.getRect(find.byKey(const Key('pickup-topbar'))),
      const Rect.fromLTWH(0, 0, 393, 64),
    );
    expect(
      tester.getRect(find.byKey(const Key('pickup-hero'))),
      const Rect.fromLTWH(0, 64, 393, 92),
    );
    expect(
      tester.getRect(find.byKey(const Key('pickup-content'))),
      const Rect.fromLTWH(0, 156, 393, 598),
    );
    expect(
      tester.getRect(find.byKey(const Key('pickup-footer'))),
      const Rect.fromLTWH(0, 754, 393, 98),
    );
    expect(
      tester.getSize(find.byKey(const Key('manifest-stop-1-1-1'))).height,
      92,
    );
    expect(
      tester.getRect(find.byKey(const Key('confirm-pickup'))),
      const Rect.fromLTWH(92, 767, 283, 68),
    );
    expect(find.text('0 of 6'), findsOneWidget);
    expect(find.textContaining('1 of 2'), findsOneWidget);
    expect(find.textContaining('2 of 2'), findsOneWidget);
    expect(find.byKey(const Key('pickup-manifest-head')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 720), const Size(360, 640)]) {
    testWidgets('Refresh02 compact/short flow $size remains scrollable', (
      tester,
    ) async {
      await _pumpPickup(tester, size);
      expect(
        tester.getSize(find.byKey(const Key('manifest-stop-1-1-1'))).height,
        88,
      );
      expect(
        tester.getSize(find.byKey(const Key('confirm-pickup'))).height,
        68,
      );
      expect(
        tester.getRect(find.byKey(const Key('pickup-footer'))).bottom,
        size.height,
      );
      await tester.drag(
        find.byKey(const Key('pickup-content')),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('manifest-stop-4-1-2')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('enlarged text wraps instead of disabling system text scaling', (
    tester,
  ) async {
    await _pumpPickup(tester, const Size(320, 852), textScale: 1.6);
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.text('Collect packages')),
      ).scale(10),
      16,
    );
    expect(
      tester.getSize(find.byKey(const Key('manifest-stop-1-1-1'))).height,
      greaterThan(92),
    );
    expect(tester.getRect(find.byKey(const Key('pickup-footer'))).bottom, 852);
    await tester.drag(
      find.byKey(const Key('pickup-content')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'actual Flutter captures: initial, selected and source action drawer',
    (tester) async {
      await _pumpPickup(tester, const Size(393, 852));
      await _capture(tester, 'pickup-initial.png');
      for (final key in [
        'manifest-stop-1-1-1',
        'manifest-stop-2-1-1',
        'manifest-stop-3-1-1',
        'manifest-stop-3-2-1',
        'manifest-stop-4-1-1',
        'manifest-stop-4-1-2',
      ]) {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.tap(find.byKey(Key(key)));
        await tester.pump();
      }
      expect(find.text('6 of 6'), findsOneWidget);
      expect(find.text('Confirm 6 packages'), findsOneWidget);
      await _capture(tester, 'pickup-selected.png');
      await tester.tap(find.byKey(const Key('pickup-problem')));
      await tester.pumpAndSettle();
      expect(find.text('Missing package'), findsOneWidget);
      expect(find.text('Wrong package'), findsOneWidget);
      expect(find.text('Damaged package'), findsOneWidget);
      expect(find.text('Message Operations'), findsOneWidget);
      expect(
        find.byType(DropdownButtonFormField<DriverRoundStopModel>),
        findsNothing,
      );
      await _capture(tester, 'pickup-drawer.png');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pickup-action-sheet')), findsNothing);
      expect(find.text('6 of 6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _capture(WidgetTester tester, String name) async {
  final output = Platform.environment['ROUNDS_PICKUP_CAPTURE_DIR'];
  if (output == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('pickup-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory(output);
    await directory.create(recursive: true);
    await File(
      '${directory.path}/$name',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _pumpPickup(
  WidgetTester tester,
  Size size, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'driver_locale': 'en',
    'driver_locale_selected': true,
  });
  final controller = await HarnessAppController.create();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('pickup-capture'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildRoundsDriverTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: PickupConfirmationScreen(
          controller: controller,
          round: _canonicalRound,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _canonicalRound = DriverRoundModel(
  id: 'round-pickup-reference',
  reference: 'ROUND-001',
  serviceDate: '2026-09-02',
  state: 'approved',
  version: 1,
  tenantName: 'UrbanFlowers',
  pickup: DriverPickupModel(
    displayName: 'UrbanFlowers',
    rawAddress: 'Bangkok',
    contactName: 'Dispatch',
    contactPhone: '+66000000000',
  ),
  stops: [
    DriverRoundStopModel(
      id: 'stop-1',
      sequence: 1,
      state: 'assigned',
      version: 1,
      destinationVersion: 1,
      manifestId: 'manifest-1',
      manifestVersion: 1,
      deliveryReference: '#8421',
      recipientName: 'K. Nattaporn',
      recipientPhone: '+66999999991',
      rawAddress: 'Bangkok',
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
    ),
    DriverRoundStopModel(
      id: 'stop-2',
      sequence: 2,
      state: 'assigned',
      version: 1,
      destinationVersion: 1,
      manifestId: 'manifest-2',
      manifestVersion: 1,
      deliveryReference: '#8422',
      recipientName: 'James T.',
      recipientPhone: '+66999999992',
      rawAddress: 'Bangkok',
      latitude: 13.71,
      longitude: 100.51,
      windowStart: '2026-09-02T02:00:00Z',
      windowEnd: '2026-09-02T04:00:00Z',
      manifestItems: [
        DriverManifestItemModel(
          lineNumber: 1,
          description: 'Signature hamper',
          quantity: 1,
        ),
      ],
    ),
    DriverRoundStopModel(
      id: 'stop-3',
      sequence: 3,
      state: 'assigned',
      version: 1,
      destinationVersion: 1,
      manifestId: 'manifest-3',
      manifestVersion: 1,
      deliveryReference: '#8423',
      recipientName: 'K. Ploy',
      recipientPhone: '+66999999993',
      rawAddress: 'Bangkok',
      latitude: 13.72,
      longitude: 100.52,
      windowStart: '2026-09-02T02:00:00Z',
      windowEnd: '2026-09-02T04:00:00Z',
      manifestItems: [
        DriverManifestItemModel(
          lineNumber: 1,
          description: 'Bouquet',
          quantity: 1,
          handlingNote: 'Fragile',
        ),
        DriverManifestItemModel(
          lineNumber: 2,
          description: '1 lb cake',
          quantity: 1,
          handlingNote: 'Keep cool',
        ),
      ],
    ),
    DriverRoundStopModel(
      id: 'stop-4',
      sequence: 4,
      state: 'assigned',
      version: 1,
      destinationVersion: 1,
      manifestId: 'manifest-4',
      manifestVersion: 1,
      deliveryReference: '#8424',
      recipientName: 'Anantara Siam',
      recipientPhone: '+66999999994',
      rawAddress: 'Bangkok',
      latitude: 13.73,
      longitude: 100.53,
      windowStart: '2026-09-02T02:00:00Z',
      windowEnd: '2026-09-02T04:00:00Z',
      manifestItems: [
        DriverManifestItemModel(
          lineNumber: 1,
          description: 'Floral arrangement',
          quantity: 2,
          handlingNote: 'Fragile',
        ),
      ],
    ),
  ],
);
