import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/harness_app_controller.dart';
import 'package:rounds_driver_harness/src/driver/driver_handoff_selection.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';
import 'package:rounds_driver_harness/src/storage/pod_draft_photo_store.dart';
import 'package:rounds_driver_harness/src/ui/proof_of_delivery_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('F03/F04 follows the measured English 393 layout', (
    tester,
  ) async {
    await _pumpPod(tester, size: const Size(393, 852));

    expect(
      tester.getRect(find.byKey(const Key('pod-top-bar'))),
      const Rect.fromLTWH(0, 0, 393, 62),
    );
    expect(
      tester.getRect(find.byKey(const Key('pod-hero'))).topLeft,
      const Offset(18, 84),
    );
    expect(tester.getSize(find.byKey(const Key('pod-hero'))).width, 357);
    expect(
      tester.getSize(find.byKey(const Key('pod-manifest-line-1'))).height,
      78,
    );
    expect(
      tester.getSize(find.byKey(const Key('capture-delivery-photo'))).height,
      188,
    );
    expect(
      tester.getRect(find.byKey(const Key('complete-delivery'))),
      const Rect.fromLTWH(18, 770, 357, 64),
    );
    expect(find.text('Proof of delivery'), findsOneWidget);
    expect(find.text('Recipient · K. Nattaporn'), findsOneWidget);
    expect(find.text('0 / 2'), findsOneWidget);
    expect(find.textContaining('pickup verified'), findsOneWidget);
    expect(find.text('Delivery time'), findsOneWidget);
    expect(find.text('Server recorded'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ProofOfDeliveryScreen),
      matchesGoldenFile('goldens/proof-of-delivery-english-393x852.png'),
    );
  });

  testWidgets('manifest and retained photo are explicit completion gates', (
    tester,
  ) async {
    final fixture = await _fixture(locale: 'en');
    await tester.pumpWidget(fixture.app());
    await _finishAsyncBuild(tester);

    FilledButton complete() =>
        tester.widget<FilledButton>(find.byKey(const Key('complete-delivery')));
    expect(complete().onPressed, isNull);

    await tester.tap(find.byKey(const Key('pod-manifest-line-1')));
    await tester.pump();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(complete().onPressed, isNull);

    await tester.tap(find.byKey(const Key('capture-delivery-photo')));
    await _finishAsyncBuild(tester);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.textContaining('Photo added'), findsOneWidget);
    expect(complete().onPressed, isNotNull);
    expect(await fixture.store.restore(_stop.id), isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('someone else uses the canonical receiver bottom drawer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = await _fixture(locale: 'en');
    await tester.pumpWidget(
      fixture.app(handoff: const DriverHandoffSelection.someoneElse()),
    );
    await _finishAsyncBuild(tester);

    expect(find.text('Someone else · receiver required'), findsOneWidget);
    expect(find.text('0 / 3'), findsOneWidget);
    expect(find.byKey(const Key('pod-receiver-name')), findsNothing);
    await tester.tap(find.byKey(const Key('pod-receiver-role')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Received by'), findsNWidgets(2));
    expect(find.text('Reception'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pod-receiver-reception')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('pod-receiver-name')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('pod-receiver-name')),
      'Johannes',
    );
    await tester.pump();
    expect(find.text('1 / 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Thai compact F03/F04 uses the supplied Thai copy', (
    tester,
  ) async {
    await _pumpPod(
      tester,
      size: const Size(320, 700),
      locale: 'th',
      handoff: const DriverHandoffSelection.leftAt('รีเซปชัน'),
    );

    expect(find.text('หลักฐานการส่ง'), findsOneWidget);
    expect(find.text('แพ็กเกจ'), findsOneWidget);
    expect(find.text('รูปยืนยันการส่ง'), findsOneWidget);
    expect(find.text('ถ่ายรูปจุดที่วางของ'), findsOneWidget);
    expect(find.text('ยืนยันส่งจุด 1'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('capture-delivery-photo'))).height,
      164,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPod(
  WidgetTester tester, {
  required Size size,
  String locale = 'en',
  DriverHandoffSelection handoff = const DriverHandoffSelection.recipient(),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final fixture = await _fixture(locale: locale);
  await tester.pumpWidget(fixture.app(handoff: handoff));
  await _finishAsyncBuild(tester);
}

Future<void> _finishAsyncBuild(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump();
}

Future<_PodFixture> _fixture({required String locale}) async {
  SharedPreferences.setMockInitialValues({
    'driver_locale': locale,
    'driver_locale_selected': true,
  });
  final controller = await HarnessAppController.create();
  final preferences = await SharedPreferences.getInstance();
  final directory = Directory.systemTemp.createTempSync('rounds-pod-test-');
  final capture = File('${directory.path}/capture.png');
  capture.writeAsBytesSync(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
  return _PodFixture(
    controller: controller,
    store: _ImmediatePodPhotoStore(
      preferences: preferences,
      supportDirectory: directory,
    ),
    capture: capture,
  );
}

class _ImmediatePodPhotoStore extends PodDraftPhotoStore {
  _ImmediatePodPhotoStore({
    required super.preferences,
    required super.supportDirectory,
  });

  PodDraftPhoto? retained;

  @override
  Future<PodDraftPhoto?> restore(String stopId) => Future.value(retained);

  @override
  Future<PodDraftPhoto> retain(String stopId, String capturedPath) {
    retained = PodDraftPhoto(
      path: capturedPath,
      capturedAt: DateTime.utc(2026, 9, 4),
    );
    return Future.value(retained!);
  }

  @override
  Future<void> clear(String stopId) {
    retained = null;
    return Future.value();
  }
}

class _PodFixture {
  const _PodFixture({
    required this.controller,
    required this.store,
    required this.capture,
  });

  final HarnessAppController controller;
  final PodDraftPhotoStore store;
  final File capture;

  Widget app({
    DriverHandoffSelection handoff = const DriverHandoffSelection.recipient(),
  }) => MaterialApp(
    theme: buildRoundsDriverTheme(),
    home: ProofOfDeliveryScreen(
      controller: controller,
      stop: _stop,
      stopCount: 4,
      handoff: handoff,
      photoStore: store,
      capturePhoto: () async => XFile(capture.path),
    ),
  );
}

const _stop = DriverRoundStopModel(
  id: 'stop-pod-reference',
  sequence: 1,
  state: 'arrived',
  version: 5,
  destinationVersion: 1,
  manifestId: 'manifest-1',
  manifestVersion: 1,
  deliveryReference: '8421',
  recipientName: 'K. Nattaporn',
  recipientPhone: '+66999999999',
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
);
