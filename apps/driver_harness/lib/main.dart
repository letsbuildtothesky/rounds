import 'dart:async';

import 'package:flutter/material.dart';

import 'src/app/rounds_harness_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await HarnessAppController.create();
  runApp(RoundsHarnessApp(controller: controller));
  unawaited(controller.restoreDriverSession());
}
