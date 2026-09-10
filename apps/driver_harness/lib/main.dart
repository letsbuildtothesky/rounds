import 'dart:async';

import 'package:flutter/material.dart';

import 'src/app/rounds_harness_app.dart';
import 'src/v23/driver_storage_startup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageStartup = await DriverStorageStartup.startNative();
  final HarnessAppController controller;
  try {
    controller = await HarnessAppController.create(
      storageStartup: storageStartup,
    );
  } catch (_) {
    await storageStartup?.dispose();
    rethrow;
  }
  runApp(RoundsHarnessApp(controller: controller));
  unawaited(controller.restoreDriverSession());
}
