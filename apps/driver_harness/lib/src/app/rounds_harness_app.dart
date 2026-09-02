import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../ui/assigned_round_screen.dart';
import '../ui/driver_login_screen.dart';
import '../ui/language_screen.dart';
import '../ui/pickup_confirmation_screen.dart';
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

  static const _previewScreen = String.fromEnvironment('ROUNDS_PREVIEW_SCREEN');

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
        home: _home(),
      ),
    );
  }

  Widget _home() {
    if (!kReleaseMode && _previewScreen == 'pickup') {
      return PickupConfirmationScreen(
        controller: controller,
        round: AssignedRoundScreen.demoRound,
      );
    }
    if (!controller.hasSelectedLanguage) {
      return LanguageScreen(controller: controller);
    }
    if (controller.driverConfigured && controller.driverLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (controller.driverConfigured && controller.driverSession == null) {
      return DriverLoginScreen(controller: controller);
    }
    return AssignedRoundScreen(
      controller: controller,
      enableNativeNavigation: enableNativeNavigation,
      session: controller.driverSession,
    );
  }
}
