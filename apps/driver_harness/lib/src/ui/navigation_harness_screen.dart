import 'package:flutter/material.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_session.dart';
import '../navigation/google_navigation_surface.dart';
import 'components/navigation_road_controls.dart';
import 'components/navigation_stop_dock.dart';
import 'components/delivery_issue_flow.dart';
import 'components/operations_contact_flow.dart';
import 'components/rounds_action_drawer.dart';
import 'proof_of_delivery_screen.dart';
import 'post_delivery_screen.dart';
import 'operations_chat_screen.dart';

class NavigationHarnessScreen extends StatefulWidget {
  const NavigationHarnessScreen({
    required this.controller,
    required this.enableNativeNavigation,
    required this.round,
    required this.stop,
    required this.stopCount,
    super.key,
  });

  final HarnessAppController controller;
  final bool enableNativeNavigation;
  final DriverRoundModel round;
  final DriverRoundStopModel stop;
  final int stopCount;

  @override
  State<NavigationHarnessScreen> createState() =>
      _NavigationHarnessScreenState();
}

class _NavigationHarnessScreenState extends State<NavigationHarnessScreen> {
  late bool _arrived;
  bool _nearArrival = false;
  bool _arrivalPendingSync = false;
  bool _submittingArrival = false;
  String? _navigationStatus;
  int? _remainingSeconds;
  int? _remainingMeters;

  @override
  void initState() {
    super.initState();
    _arrived = widget.stop.state == 'arrived';
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.controller.strings;
    final showArrivalAction =
        _nearArrival ||
        !widget.enableNativeNavigation ||
        _arrived ||
        _arrivalPendingSync;
    final compact =
        MediaQuery.sizeOf(context).width <
        DriverReferenceViewport.compactBreakpoint;
    final outerMargin = compact
        ? DriverE02Metrics.compactOuterMargin
        : DriverE02Metrics.outerMargin;
    final controlSize = compact
        ? DriverE02Metrics.compactRoadControlSize
        : DriverE02Metrics.roadControlSize;
    final rowHeight = compact
        ? DriverE02Metrics.compactDockRowHeight
        : DriverE02Metrics.dockRowHeight;
    final dockHeight =
        rowHeight +
        (showArrivalAction
            ? DriverE02Metrics.arrivalHeight +
                  DriverE02Metrics.arrivalMarginBottom
            : 0) +
        (_arrivalPendingSync ? DriverE02Metrics.pendingStatusHeight : 0);
    final controlsBottom =
        outerMargin + dockHeight + DriverE02Metrics.vendorSafeBottomGap;
    final mapBottomInset =
        controlsBottom + controlSize + DriverE02Metrics.vendorSafeBottomGap;

    return Scaffold(
      backgroundColor: RoundsColors.canvas,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: widget.enableNativeNavigation
                  ? GoogleNavigationSurface(
                      strings: strings,
                      onOperationalSample: (_) {},
                      onStatus: (status) {
                        if (!mounted) return;
                        setState(() => _navigationStatus = status);
                      },
                      onRemainingChanged: (remainingSeconds, remainingMeters) {
                        if (!mounted) return;
                        setState(() {
                          _remainingSeconds = remainingSeconds;
                          _remainingMeters = remainingMeters;
                        });
                      },
                      onArrival: () {
                        if (!mounted) return;
                        setState(() => _nearArrival = true);
                      },
                      stopId: widget.stop.id,
                      destinationVersion: widget.stop.destinationVersion,
                      destinationTitle:
                          '${widget.stop.deliveryReference} · ${widget.stop.recipientName}',
                      latitude: widget.stop.latitude,
                      longitude: widget.stop.longitude,
                      bottomOverlayInset: mapBottomInset,
                    )
                  : _NavigationPreview(label: strings.navigationReady),
            ),
            Positioned(
              left: outerMargin,
              right: outerMargin,
              bottom: controlsBottom,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  NavigationRoadControlButton(
                    key: const Key('navigation-back'),
                    tooltip: 'Back',
                    icon: Icons.arrow_back,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  NavigationRoadMenuButton(onPressed: _openNavigationActions),
                ],
              ),
            ),
            Positioned(
              left: outerMargin,
              right: outerMargin,
              bottom: outerMargin,
              child: NavigationStopDock(
                sequence: widget.stop.sequence,
                stopCount: widget.stopCount,
                recipientName: widget.stop.recipientName,
                address: widget.stop.rawAddress,
                etaLabel: _etaLabel,
                distanceLabel: _distanceLabel,
                showArrivalAction: showArrivalAction,
                arrivalLabel: _arrivalLabel,
                onArrival: _arrivalPendingSync || _submittingArrival
                    ? null
                    : _arrived
                    ? _openPod
                    : _confirmArrival,
                pendingSyncLabel: _arrivalPendingSync
                    ? widget.controller.strings.pendingSync
                    : null,
                pendingSyncDetail: _arrivalPendingSync
                    ? 'Arrival is not committed yet'
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _etaLabel {
    final seconds = _remainingSeconds;
    if (seconds == null) return '—';
    return '${(seconds / 60).ceil().clamp(1, 999)} min';
  }

  String get _distanceLabel {
    final meters = _remainingMeters;
    if (meters == null) {
      return _navigationStatus?.contains('active') ?? false
          ? 'Routing'
          : 'Locating';
    }
    if (meters < 1000) return '$meters m';
    final kilometers = meters / 1000;
    return '${kilometers.toStringAsFixed(kilometers >= 10 ? 0 : 1)} km';
  }

  String get _arrivalLabel => _arrived
      ? widget.controller.strings.podPlaceholder
      : _submittingArrival
      ? 'Confirming with server…'
      : _arrivalPendingSync
      ? 'Pending sync — not arrived'
      : 'I’m at Stop ${widget.stop.sequence}';

  Future<void> _openNavigationActions() async {
    final action = await showRoundsActionDrawer(
      context,
      title: 'Navigation actions',
      actions: [
        RoundsDrawerAction(
          value: 'contact',
          label: widget.controller.strings.contactOperations,
          icon: Icons.support_agent,
        ),
        RoundsDrawerAction(
          value: 'exception',
          label: widget.controller.strings.reportException,
          icon: Icons.warning_amber_rounded,
          destructive: true,
        ),
      ],
    );
    if (action != null && mounted) await _onMenuSelected(action);
  }

  Future<void> _onMenuSelected(String action) async {
    if (action == 'contact') {
      await openOperationsContactFlow(
        context,
        round: widget.round,
        stop: widget.stop,
        onMessage: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => OperationsChatScreen(
              controller: widget.controller,
              round: widget.round,
              stop: widget.stop,
            ),
          ),
        ),
      );
    } else {
      final reported = await openDeliveryIssueFlow(
        context,
        round: widget.round,
        stop: widget.stop,
        controller: widget.controller,
      );
      if (reported && mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _confirmArrival() async {
    setState(() => _submittingArrival = true);
    final outcome = await widget.controller.confirmArrival(widget.stop);
    if (!mounted) return;
    setState(() {
      _submittingArrival = false;
      _arrived = outcome?.committed ?? false;
      _arrivalPendingSync = outcome?.pendingSync ?? false;
    });
    if (outcome == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.driverError ?? 'Arrival could not be confirmed',
          ),
        ),
      );
    } else if (outcome.pendingSync) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Arrival saved on this phone. Pending sync — server state is unchanged.',
          ),
        ),
      );
    }
  }

  Future<void> _openPod() async {
    final currentStop = widget.controller.driverSession?.currentRound?.stops
        .where((stop) => stop.id == widget.stop.id)
        .firstOrNull;
    if (currentStop == null) return;
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProofOfDeliveryScreen(
          controller: widget.controller,
          stop: currentStop,
        ),
      ),
    );
    if (completed != true || !mounted) return;
    final refreshedRound = widget.controller.driverSession?.currentRound;
    final nextStop = nextOperationalStop(refreshedRound);
    if (refreshedRound != null && nextStop != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => StopCompleteNextStopScreen(
            round: refreshedRound,
            completedStop: widget.stop,
            nextStop: nextStop,
            enableNativeMap: widget.enableNativeNavigation,
            onNavigate: (nextContext) {
              Navigator.of(nextContext).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => NavigationHarnessScreen(
                    controller: widget.controller,
                    enableNativeNavigation: widget.enableNativeNavigation,
                    round: refreshedRound,
                    stop: nextStop,
                    stopCount: refreshedRound.stops.length,
                  ),
                ),
              );
            },
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RoundCompleteScreen(
          round: widget.round,
          onContinue: (completeContext) => Navigator.of(completeContext).pop(),
        ),
      ),
    );
  }
}

class _NavigationPreview extends StatelessWidget {
  const _NavigationPreview({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFD7DDD7),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.two_wheeler, size: 64, color: Color(0xFF17453B)),
          const SizedBox(height: 16),
          Text(label, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    ),
  );
}
