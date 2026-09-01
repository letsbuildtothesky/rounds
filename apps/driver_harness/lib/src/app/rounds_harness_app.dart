import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../ui/assigned_round_screen.dart';
import '../ui/driver_login_screen.dart';
import '../ui/language_screen.dart';
import 'app_strings.dart';
import 'driver_design_system.dart';
import 'harness_app_controller.dart';

export 'harness_app_controller.dart';

class RoundsHarnessApp extends StatelessWidget {
  const RoundsHarnessApp({
    required this.controller,
    this.enableNativeNavigation = true,
    super.key,
  });

  final HarnessAppController controller;
  final bool enableNativeNavigation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: controller.locale.locale,
        supportedLocales: const [Locale('th', 'TH'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildRoundsDriverTheme(),
        home: !controller.hasSelectedLanguage
            ? LanguageScreen(controller: controller)
            : controller.driverConfigured && controller.driverLoading
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : controller.driverConfigured && controller.driverSession == null
            ? DriverLoginScreen(controller: controller)
            : AssignedRoundScreen(
                controller: controller,
                enableNativeNavigation: enableNativeNavigation,
                session: controller.driverSession,
              ),
      ),
    );
  }
}
