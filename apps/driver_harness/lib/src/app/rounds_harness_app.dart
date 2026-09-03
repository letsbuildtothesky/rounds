import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../ui/assigned_round_screen.dart';
import '../ui/driver_login_screen.dart';
import '../ui/language_screen.dart';
import '../ui/live_delivery_change_screen.dart';
import '../ui/operations_chat_screen.dart';
import '../ui/pickup_confirmation_screen.dart';
import '../connectivity/offline_reconnecting_screen.dart';
import '../driver/driver_session.dart';
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
        builder: (context, child) => Stack(
          children: [
            ExcludeSemantics(
              excluding: controller.showConnectionSurface,
              child: child ?? const SizedBox.shrink(),
            ),
            if (controller.showConnectionSurface)
              Positioned.fill(
                child: OfflineReconnectingScreen(
                  snapshot: controller.syncSnapshot,
                  onReturnToRound: controller.returnToRound,
                  onRetry: controller.retryConnection,
                ),
              ),
          ],
        ),
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
    if (controller.driverConfigured &&
        controller.driverLoading &&
        controller.driverSession == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (controller.driverConfigured && controller.driverSession == null) {
      return DriverLoginScreen(controller: controller);
    }
    final session = controller.driverSession;
    final round = session?.currentRound;
    final change = session?.pendingLiveChange;
    if (round != null && change != null) {
      DriverRoundStopModel? stop;
      for (final candidate in round.stops) {
        if (candidate.id == change.stopId) {
          stop = candidate;
          break;
        }
      }
      if (stop != null) {
        final changedStop = stop;
        return LiveDeliveryChangeScreen(
          round: round,
          stop: changedStop,
          change: change,
          enableNativeMap: enableNativeNavigation,
          onAcknowledge: () => controller.acknowledgeLiveDeliveryChange(change),
          contactScreenBuilder: (_) => OperationsChatScreen(
            controller: controller,
            round: round,
            stop: changedStop,
          ),
        );
      }
    }
    return AssignedRoundScreen(
      controller: controller,
      enableNativeNavigation: enableNativeNavigation,
      session: session,
    );
  }
}
