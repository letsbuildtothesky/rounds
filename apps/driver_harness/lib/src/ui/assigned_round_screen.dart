import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_strings.dart';
import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_session.dart';
import 'components/round_overview_map.dart';
import 'components/rounds_action_drawer.dart';
import 'debug_pod_acceptance_screen.dart';
import 'navigation_harness_screen.dart';
import 'pickup_confirmation_screen.dart';

class AssignedRoundScreen extends StatelessWidget {
  const AssignedRoundScreen({
    required this.controller,
    required this.enableNativeNavigation,
    this.session,
    super.key,
  });

  final HarnessAppController controller;
  final bool enableNativeNavigation;
  final DriverSessionModel? session;

  static const demoRound = DriverRoundModel(
    id: 'ROUND-DEMO',
    reference: 'ROUND-DEMO-001',
    serviceDate: '2026-09-01',
    state: 'active',
    version: 1,
    tenantName: 'UrbanFlowers',
    pickup: DriverPickupModel(
      displayName: 'UrbanFlowers · Sukhumvit 39',
      rawAddress: 'Sukhumvit 39, Bangkok',
      contactName: 'UrbanFlowers Dispatch',
      contactPhone: '+66000000000',
    ),
    stops: [
      DriverRoundStopModel(
        id: 'STOP-001',
        sequence: 1,
        state: 'assigned',
        version: 1,
        destinationVersion: 1,
        manifestId: 'MANIFEST-DEMO-001',
        manifestVersion: 1,
        deliveryReference: 'UF-DEMO-001',
        recipientName: 'Siriporn',
        recipientPhone: '+66999999999',
        rawAddress: 'Interchange 21, Sukhumvit Road, Bangkok',
        latitude: 13.7367,
        longitude: 100.5612,
        windowStart: '2026-09-01T02:00:00Z',
        windowEnd: '2026-09-01T04:00:00Z',
        manifestItems: [
          DriverManifestItemModel(
            lineNumber: 1,
            description: 'Flower bouquet',
            quantity: 1,
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final round =
        session?.currentRound ??
        (controller.driverConfigured ? null : demoRound);
    return Scaffold(
      backgroundColor: RoundsColors.canvas,
      body: SafeArea(
        child: round == null
            ? _WaitingForRound(
                driverName: session?.userName,
                onRefresh: controller.driverConfigured
                    ? controller.refreshDriverSession
                    : null,
              )
            : _ActiveRoundOverview(
                controller: controller,
                round: round,
                enableNativeNavigation: enableNativeNavigation,
              ),
      ),
    );
  }
}

class _ActiveRoundOverview extends StatelessWidget {
  const _ActiveRoundOverview({
    required this.controller,
    required this.round,
    required this.enableNativeNavigation,
  });

  final HarnessAppController controller;
  final DriverRoundModel round;
  final bool enableNativeNavigation;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width <
        DriverReferenceViewport.compactBreakpoint;
    final dockHeight = compact
        ? DriverE01Metrics.compactDockHeight
        : DriverE01Metrics.dockHeight;
    final firstStop = round.stops.first;
    return MediaQuery.withNoTextScaling(
      child: Stack(
        children: [
          Positioned(
            key: const Key('e01-map'),
            left: 0,
            right: 0,
            top: DriverE01Metrics.topBarHeight,
            bottom: dockHeight,
            child: RoundOverviewMap(
              round: round,
              enableNativeMap: enableNativeNavigation,
            ),
          ),
          _RoundTopBar(controller: controller, round: round, compact: compact),
          Positioned(
            key: const Key('e01-map-summary'),
            left: compact
                ? DriverE01Metrics.compactMapSummaryLeft
                : DriverE01Metrics.mapSummaryLeft,
            top: compact
                ? DriverE01Metrics.compactMapSummaryTop
                : DriverE01Metrics.mapSummaryTop,
            child: _MapSummary(round: round),
          ),
          Positioned(
            key: const Key('e01-next-dock'),
            left: 0,
            right: 0,
            bottom: 0,
            height: dockHeight,
            child: _NextStopDock(
              round: round,
              stop: firstStop,
              compact: compact,
              onPrimary: () => _openPrimary(context, firstStop),
            ),
          ),
        ],
      ),
    );
  }

  void _openPrimary(BuildContext context, DriverRoundStopModel firstStop) {
    if (firstStop.state == 'exception') return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => round.state == 'active'
            ? NavigationHarnessScreen(
                controller: controller,
                enableNativeNavigation: enableNativeNavigation,
                round: round,
                stop: firstStop,
                stopCount: round.stops.length,
              )
            : PickupConfirmationScreen(controller: controller, round: round),
      ),
    );
  }
}

class _RoundTopBar extends StatelessWidget {
  const _RoundTopBar({
    required this.controller,
    required this.round,
    required this.compact,
  });

  final HarnessAppController controller;
  final DriverRoundModel round;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final buttonSize = compact
        ? DriverE01Metrics.compactTopButtonSize
        : DriverE01Metrics.topButtonSize;
    final padding = compact
        ? DriverE01Metrics.compactTopBarPaddingHorizontal
        : DriverE01Metrics.topBarPaddingHorizontal;
    final gap = compact
        ? DriverE01Metrics.compactTopColumnGap
        : DriverE01Metrics.topColumnGap;
    return Positioned(
      key: const Key('e01-topbar'),
      left: 0,
      right: 0,
      top: 0,
      height: DriverE01Metrics.topBarHeight,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFCFFFFFF),
          border: Border(bottom: BorderSide(color: RoundsColors.line)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Row(
            children: [
              _TopButton(
                size: buttonSize,
                icon: Icons.arrow_back,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              SizedBox(width: gap),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: DriverE01Metrics.topStateDotSize,
                          height: DriverE01Metrics.topStateDotSize,
                          decoration: const BoxDecoration(
                            color: RoundsColors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: DriverE01Metrics.topStateGap),
                        Text(
                          round.state == 'active'
                              ? 'ROUND ACTIVE'
                              : 'PICKUP READY',
                          key: const Key('e01-round-state'),
                          style: _e01Style(
                            color: RoundsColors.green,
                            size: DriverE01Metrics.topStateSize,
                            height: DriverE01Metrics.topStateHeight,
                            weight: DriverE01Metrics.topStateWeight,
                            tracking: DriverE01Metrics.topStateTracking,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DriverE01Metrics.topTitleGap),
                    Text(
                      '${round.tenantName} · ${round.stops.length} ${round.stops.length == 1 ? 'stop' : 'stops'}',
                      key: const Key('e01-round-title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _e01Style(
                        color: RoundsColors.ink,
                        size: compact
                            ? DriverE01Metrics.compactTopTitleSize
                            : DriverE01Metrics.topTitleSize,
                        height: DriverE01Metrics.topTitleHeight,
                        weight: DriverE01Metrics.topTitleWeight,
                        tracking: DriverE01Metrics.topTitleTracking,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: gap),
              SizedBox(
                width: buttonSize,
                height: buttonSize,
                child: IconButton(
                  key: const Key('e01-round-actions'),
                  tooltip: 'Round actions',
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_horiz,
                    size: DriverE01Metrics.topIconSize,
                  ),
                  onPressed: () => _openActions(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openActions(BuildContext context) async {
    final action = await showRoundsActionDrawer(
      context,
      title: 'Round actions',
      actions: [
        const RoundsDrawerAction(
          value: 'refresh',
          label: 'Refresh Round',
          icon: Icons.refresh,
        ),
        RoundsDrawerAction(
          value: 'language',
          label: controller.strings.chooseLanguage,
          icon: Icons.language,
        ),
        if (controller.driverConfigured)
          const RoundsDrawerAction(
            value: 'signout',
            label: 'Sign out',
            icon: Icons.logout,
            destructive: true,
          ),
        if (kDebugMode)
          const RoundsDrawerAction(
            value: 'pod-acceptance',
            label: 'Test camera + restart',
            icon: Icons.camera_alt_outlined,
          ),
      ],
    );
    if (action != null && context.mounted) _onAction(context, action);
  }

  void _onAction(BuildContext context, String value) {
    if (value == 'refresh') controller.refreshDriverSession();
    if (value == 'language') {
      controller.selectLocale(
        controller.locale == HarnessLocale.thai
            ? HarnessLocale.english
            : HarnessLocale.thai,
      );
    }
    if (value == 'signout') controller.signOutDriver();
    if (value == 'pod-acceptance') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DebugPodAcceptanceScreen(stop: round.stops.first),
        ),
      );
    }
  }
}

class _TopButton extends StatelessWidget {
  const _TopButton({
    required this.size,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final double size;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Icon(icon, size: DriverE01Metrics.topIconSize),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DriverE01Metrics.topButtonRadius),
        ),
      ),
    ),
  );
}

class _MapSummary extends StatelessWidget {
  const _MapSummary({required this.round});

  final DriverRoundModel round;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .96),
    elevation: 5,
    shadowColor: const Color(0x1F172238),
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: RoundsColors.line),
      borderRadius: BorderRadius.circular(DriverE01Metrics.mapSummaryRadius),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DriverE01Metrics.mapSummaryPaddingHorizontal,
        vertical: DriverE01Metrics.mapSummaryPaddingVertical,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stop 1 of ${round.stops.length}',
            key: const Key('e01-map-summary-title'),
            style: _e01Style(
              color: RoundsColors.ink,
              size: DriverE01Metrics.mapSummaryTitleSize,
              height: 1,
              weight: DriverE01Metrics.mapSummaryTitleWeight,
            ),
          ),
          const SizedBox(height: DriverE01Metrics.mapSummaryDetailGap),
          Text(
            round.stops.length == 1
                ? 'Final stop'
                : '${round.stops.length - 1} stops remaining after this',
            key: const Key('e01-map-summary-detail'),
            style: _e01Style(
              color: RoundsColors.muted,
              size: DriverE01Metrics.mapSummaryDetailSize,
              height: 1,
              weight: DriverE01Metrics.mapSummaryDetailWeight,
            ),
          ),
        ],
      ),
    ),
  );
}

class _NextStopDock extends StatelessWidget {
  const _NextStopDock({
    required this.round,
    required this.stop,
    required this.compact,
    required this.onPrimary,
  });

  final DriverRoundModel round;
  final DriverRoundStopModel stop;
  final bool compact;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final waitingForOperations = stop.state == 'exception';
    final padding = EdgeInsets.fromLTRB(
      compact
          ? DriverE01Metrics.compactDockPaddingHorizontal
          : DriverE01Metrics.dockPaddingLeft,
      compact
          ? DriverE01Metrics.compactDockPaddingTop
          : DriverE01Metrics.dockPaddingTop,
      compact
          ? DriverE01Metrics.compactDockPaddingHorizontal
          : DriverE01Metrics.dockPaddingRight,
      compact
          ? DriverE01Metrics.compactDockPaddingBottom
          : DriverE01Metrics.dockPaddingBottom,
    );
    final task = stop.manifestItems.firstOrNull;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFDFFFFFF),
        border: Border(top: BorderSide(color: RoundsColors.line)),
        boxShadow: [
          BoxShadow(
            color: Color(0x12172238),
            blurRadius: 30,
            offset: Offset(0, -12),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        waitingForOperations
                            ? 'STOP ${stop.sequence} OF ${round.stops.length} · OPERATIONS HOLD'
                            : 'NEXT STOP · ${stop.sequence} OF ${round.stops.length}',
                        key: const Key('e01-next-kicker'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _e01Style(
                          color: RoundsColors.orange,
                          size: DriverE01Metrics.kickerSize,
                          height: DriverE01Metrics.kickerHeight,
                          weight: DriverE01Metrics.kickerWeight,
                          tracking: DriverE01Metrics.kickerTracking,
                        ),
                      ),
                      const SizedBox(height: DriverE01Metrics.nameGap),
                      Text(
                        stop.recipientName,
                        key: const Key('e01-next-name'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _e01Style(
                          color: RoundsColors.ink,
                          size: compact
                              ? DriverE01Metrics.compactNameSize
                              : DriverE01Metrics.nameSize,
                          height: DriverE01Metrics.nameHeight,
                          weight: DriverE01Metrics.nameWeight,
                          tracking: DriverE01Metrics.nameTracking,
                        ),
                      ),
                      const SizedBox(height: DriverE01Metrics.placeGap),
                      Text(
                        stop.rawAddress,
                        key: const Key('e01-next-place'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _e01Style(
                          color: RoundsColors.muted,
                          size: DriverE01Metrics.placeSize,
                          height: DriverE01Metrics.placeHeight,
                          weight: DriverE01Metrics.placeWeight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DriverE01Metrics.dockColumnGap),
                Padding(
                  padding: const EdgeInsets.only(
                    top: DriverE01Metrics.etaPaddingTop,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        waitingForOperations ? 'Hold' : 'Ready',
                        key: const Key('e01-next-eta'),
                        style: _e01Style(
                          color: RoundsColors.ink,
                          size: compact
                              ? DriverE01Metrics.compactEtaSize
                              : DriverE01Metrics.etaSize,
                          height: DriverE01Metrics.etaHeight,
                          weight: DriverE01Metrics.etaWeight,
                          tracking: DriverE01Metrics.etaTracking,
                        ),
                      ),
                      const SizedBox(height: DriverE01Metrics.distanceGap),
                      Text(
                        stop.deliveryReference,
                        key: const Key('e01-next-distance'),
                        style: _e01Style(
                          color: RoundsColors.muted,
                          size: DriverE01Metrics.distanceSize,
                          height: 1,
                          weight: DriverE01Metrics.distanceWeight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(
              height: compact
                  ? DriverE01Metrics.compactTaskMarginTop
                  : DriverE01Metrics.taskMarginTop,
            ),
            Row(
              children: [
                Container(
                  width: DriverE01Metrics.taskDotSize,
                  height: DriverE01Metrics.taskDotSize,
                  decoration: const BoxDecoration(
                    color: RoundsColors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: DriverE01Metrics.taskGap),
                Expanded(
                  child: Text(
                    waitingForOperations
                        ? 'Damaged package · Operations reviewing'
                        : task == null
                        ? 'Manifest ready'
                        : '${task.quantity}× ${task.description}',
                    key: const Key('e01-task-line'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _e01Style(
                      color: RoundsColors.inkSecondary,
                      size: DriverE01Metrics.taskSize,
                      height: 1,
                      weight: DriverE01Metrics.taskWeight,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: compact
                  ? DriverE01Metrics.compactPrimaryMarginTop
                  : DriverE01Metrics.primaryMarginTop,
            ),
            SizedBox(
              height: compact
                  ? DriverE01Metrics.compactPrimaryHeight
                  : DriverE01Metrics.primaryHeight,
              child: FilledButton(
                key: Key(
                  waitingForOperations
                      ? 'waiting-operations'
                      : round.state == 'active'
                      ? 'start-navigation'
                      : 'verify-pickup',
                ),
                onPressed: waitingForOperations ? null : onPrimary,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: RoundsColors.ink,
                  disabledBackgroundColor: const Color(0xFFD9DFE5),
                  disabledForegroundColor: const Color(0xFF687381),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      DriverE01Metrics.primaryRadius,
                    ),
                  ),
                ),
                child: Text(
                  waitingForOperations
                      ? 'Waiting for Operations'
                      : round.state == 'active'
                      ? 'Navigate to Stop ${stop.sequence}'
                      : 'Verify pickup manifest',
                  style: _e01Style(
                    color: Colors.white,
                    size: DriverE01Metrics.primarySize,
                    height: 1,
                    weight: DriverE01Metrics.primaryWeight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _e01Style({
  required Color color,
  required double size,
  required double height,
  required double weight,
  double tracking = 0,
}) => TextStyle(
  color: color,
  fontSize: size,
  height: height,
  fontWeight: FontWeight.values[(weight / 100).round().clamp(1, 9) - 1],
  fontVariations: [FontVariation('wght', weight)],
  letterSpacing: tracking,
);

class _WaitingForRound extends StatelessWidget {
  const _WaitingForRound({this.driverName, this.onRefresh});

  final String? driverName;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.route_outlined, size: 58, color: RoundsColors.green),
          const SizedBox(height: 18),
          Text(
            'Waiting for a Round',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${driverName ?? 'Driver'}, Operations has not assigned current work yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: RoundsColors.muted),
          ),
          if (onRefresh != null) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Check for assigned work'),
            ),
          ],
        ],
      ),
    ),
  );
}
