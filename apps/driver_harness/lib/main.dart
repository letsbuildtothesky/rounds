import 'package:flutter/material.dart';

import 'src/app/rounds_harness_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await HarnessAppController.create();
  await controller.restoreDriverSession();
  runApp(RoundsHarnessApp(controller: controller));
}
