import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/app/driver_design_system.dart';
import 'package:rounds_driver_harness/src/app/harness_app_controller.dart';
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
}
