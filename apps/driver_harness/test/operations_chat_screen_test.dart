import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/harness_app_controller.dart';
import 'package:rounds_driver_harness/src/driver/driver_operations_thread.dart';
import 'package:rounds_driver_harness/src/storage/operations_message_draft_store.dart';
import 'package:rounds_driver_harness/src/ui/assigned_round_screen.dart';
import 'package:rounds_driver_harness/src/ui/operations_chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('H01 restores its draft and uses canonical fixed geometry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final draftStore = OperationsMessageDraftStore(preferences: preferences);
    final round = AssignedRoundScreen.demoRound;
    final stop = round.stops.first;
    await draftStore.save(stop.id, 'Waiting at reception.');
    final controller = await HarnessAppController.create();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: OperationsChatScreen(
          controller: controller,
          round: round,
          stop: stop,
          draftStore: draftStore,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.getSize(find.byKey(const Key('h01-topbar'))).height, 64);
    expect(tester.getSize(find.byKey(const Key('h01-context'))).height, 58);
    expect(find.text('Waiting at reception.'), findsOneWidget);
    expect(find.text('Operations'), findsOneWidget);
    expect(find.text('View stop'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('H01 stages and persists a real structured location', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final draftStore = OperationsMessageDraftStore(preferences: preferences);
    final round = AssignedRoundScreen.demoRound;
    final controller = await HarnessAppController.create();
    await draftStore.saveLocation(
      round.stops.first.id,
      DriverMessageAttachmentModel.location(
        label: 'Current location',
        latitude: 13.7306,
        longitude: 100.5697,
        accuracyMeters: 8,
        capturedAt: DateTime.utc(2026, 9, 4, 3),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: OperationsChatScreen(
          controller: controller,
          round: round,
          stop: round.stops.first,
          draftStore: draftStore,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('h01-staged-location')), findsOneWidget);
    final restored = draftStore.restoreLocation(round.stops.first.id);
    expect(restored?.latitude, 13.7306);
    expect(restored?.longitude, 100.5697);

    controller.dispose();
  });

  testWidgets('H01 exposes the canonical attachment drawer and voice action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = await HarnessAppController.create();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildRoundsDriverTheme(),
        home: OperationsChatScreen(
          controller: controller,
          round: AssignedRoundScreen.demoRound,
          stop: AssignedRoundScreen.demoRound.stops.first,
          draftStore: OperationsMessageDraftStore(preferences: preferences),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('operations-chat-mic')), findsOneWidget);
    await tester.tap(find.byKey(const Key('h01-add-attachment')));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const Key('h01-add-camera')), findsOneWidget);
    expect(find.byKey(const Key('h01-add-photo')), findsOneWidget);
    expect(find.byKey(const Key('h01-add-file')), findsOneWidget);
    expect(find.byKey(const Key('h01-add-location')), findsOneWidget);

    controller.dispose();
  });
}
