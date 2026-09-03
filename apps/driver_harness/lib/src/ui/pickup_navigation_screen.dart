import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_session.dart';
import '../navigation/google_navigation_surface.dart';
import 'components/delivery_issue_flow.dart';
import 'components/navigation_instruction_card.dart';
import 'components/navigation_pickup_dock.dart';
import 'components/navigation_road_controls.dart';
import 'components/operations_contact_flow.dart';
import 'components/rounds_action_drawer.dart';
import 'operations_chat_screen.dart';
import 'pickup_confirmation_screen.dart';

class PickupNavigationScreen extends StatefulWidget {
  const PickupNavigationScreen({
    required this.controller,
    required this.enableNativeNavigation,
    required this.round,
    this.launcher = _launchExternal,
    this.previewNearPickup = false,
    super.key,
  });

  final HarnessAppController controller;
  final bool enableNativeNavigation;
  final DriverRoundModel round;
  final RoundsExternalLauncher launcher;
  final bool previewNearPickup;

  @override
  State<PickupNavigationScreen> createState() => _PickupNavigationScreenState();
}

class _PickupNavigationScreenState extends State<PickupNavigationScreen> {
  NavigationRoadInstruction? _instruction;
  String? _navigationStatus;
  int? _remainingSeconds;
  int? _remainingMeters;
  bool _nearPickup = false;

  @override
  void initState() {
    super.initState();
    _nearPickup = !widget.enableNativeNavigation && widget.previewNearPickup;
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.round.pickup;
    final compact =
        MediaQuery.sizeOf(context).width <
        DriverReferenceViewport.compactBreakpoint;
    final outerMargin = compact
        ? DriverD01Metrics.compactOuterMargin
        : DriverD01Metrics.outerMargin;
    final rowHeight = compact
        ? DriverD01Metrics.compactDockRowHeight
        : DriverD01Metrics.dockRowHeight;
    final dockHeight =
        rowHeight +
        (_showArrivalAction
            ? DriverD01Metrics.arrivalHeight +
                  DriverD01Metrics.arrivalMarginBottom
            : 0);
    final mapBottomInset = outerMargin + dockHeight + outerMargin;

    return Scaffold(
      backgroundColor: RoundsColors.canvas,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: widget.enableNativeNavigation
                  ? GoogleNavigationSurface(
                      strings: widget.controller.strings,
                      onOperationalSample: (_) {},
                      onStatus: (status) {
                        if (!mounted) return;
                        setState(() => _navigationStatus = status);
                      },
                      onRemainingChanged: (seconds, meters) {
                        if (!mounted) return;
                        setState(() {
                          _remainingSeconds = seconds;
                          _remainingMeters = meters;
                          if (meters <= 100) _nearPickup = true;
                        });
                      },
                      onInstruction: (instruction) {
                        if (!mounted) return;
                        setState(() => _instruction = instruction);
                      },
                      onArrival: () {
                        if (!mounted) return;
                        setState(() => _nearPickup = true);
                      },
                      stopId:
                          'pickup:${pickup.id.isEmpty ? widget.round.id : pickup.id}',
                      destinationVersion: widget.round.version,
                      destinationTitle: pickup.displayName,
                      latitude: pickup.latitude!,
                      longitude: pickup.longitude!,
                      bottomOverlayInset: mapBottomInset,
                      showNativeNavigationUi: false,
                    )
                  : const _PickupNavigationPreview(),
            ),
            Positioned(
              top: outerMargin,
              left: outerMargin,
              right: outerMargin,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NavigationRoadControlButton(
                    key: const Key('pickup-navigation-back'),
                    tooltip: 'Back',
                    icon: Icons.arrow_back,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  SizedBox(
                    width: compact
                        ? DriverD01Metrics.compactRoadControlGap
                        : DriverD01Metrics.roadControlGap,
                  ),
                  Expanded(
                    child: NavigationInstructionCard(instruction: _instruction),
                  ),
                  SizedBox(
                    width: compact
                        ? DriverD01Metrics.compactRoadControlGap
                        : DriverD01Metrics.roadControlGap,
                  ),
                  NavigationRoadMenuButton(onPressed: _openPickupActions),
                ],
              ),
            ),
            Positioned(
              left: outerMargin,
              right: outerMargin,
              bottom: outerMargin,
              child: NavigationPickupDock(
                pickupName: pickup.displayName,
                address: pickup.rawAddress,
                etaLabel: _etaLabel,
                distanceLabel: _distanceLabel,
                showArrivalAction: _showArrivalAction,
                onArrival: _openPickupConfirmation,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _showArrivalAction => _nearPickup;

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

  void _openPickupConfirmation() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PickupConfirmationScreen(
          controller: widget.controller,
          round: widget.round,
        ),
      ),
    );
  }

  Future<void> _openPickupActions() async {
    final action = await showRoundsActionDrawer(
      context,
      actions: const [
        RoundsDrawerAction(
          value: 'call',
          label: 'Call pickup',
          icon: Icons.call_outlined,
        ),
        RoundsDrawerAction(
          value: 'message',
          label: 'Message Operations',
          icon: Icons.chat_bubble_outline,
        ),
        RoundsDrawerAction(
          value: 'issue',
          label: 'Report an issue',
          icon: Icons.warning_amber_rounded,
          destructive: true,
        ),
        RoundsDrawerAction(
          value: 'maps',
          label: 'Open in Maps',
          icon: Icons.open_in_new,
        ),
      ],
      showCancel: false,
      showChevrons: false,
      inset: true,
    );
    if (action == null || !mounted) return;
    await _onPickupAction(action);
  }

  Future<void> _onPickupAction(String action) async {
    final pickup = widget.round.pickup;
    final firstStop = widget.round.stops.first;
    switch (action) {
      case 'call':
        await _openExternal(
          Uri(scheme: 'tel', path: pickup.contactPhone.trim()),
          'The phone app could not be opened.',
        );
      case 'message':
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => OperationsChatScreen(
              controller: widget.controller,
              round: widget.round,
              stop: firstStop,
            ),
          ),
        );
      case 'issue':
        await openDeliveryIssueFlow(
          context,
          round: widget.round,
          stop: firstStop,
          damageEvidenceAvailable: false,
          controller: widget.controller,
          launcher: widget.launcher,
        );
      case 'maps':
        await _openExternal(
          Uri.https('www.google.com', '/maps/dir/', {
            'api': '1',
            'destination': '${pickup.latitude},${pickup.longitude}',
          }),
          'Maps could not be opened.',
        );
    }
  }

  Future<void> _openExternal(Uri uri, String errorMessage) async {
    final opened = uri.path.isNotEmpty && await widget.launcher(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }
}

Future<bool> _launchExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

class _PickupNavigationPreview extends StatelessWidget {
  const _PickupNavigationPreview();

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const Key('pickup-navigation-map-preview'),
    painter: const _PickupNavigationPreviewPainter(),
    child: const SizedBox.expand(),
  );
}

class _PickupNavigationPreviewPainter extends CustomPainter {
  const _PickupNavigationPreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF1F4F5),
    );
    final block = Paint()..color = const Color(0xFFE3E8EB);
    for (final rect in [
      Rect.fromLTWH(size.width * .05, size.height * .17, 82, 52),
      Rect.fromLTWH(size.width * .38, size.height * .15, 78, 60),
      Rect.fromLTWH(size.width * .10, size.height * .66, 78, 54),
      Rect.fromLTWH(size.width * .62, size.height * .59, 84, 62),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        block,
      );
    }
    final road = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawLine(
      Offset(-30, size.height * .42),
      Offset(size.width + 30, size.height * .35),
      road,
    );
    canvas.drawLine(
      Offset(size.width * .56, 0),
      Offset(size.width * .65, size.height),
      road,
    );
    final route = Path()
      ..moveTo(size.width * .22, size.height * .72)
      ..cubicTo(
        size.width * .31,
        size.height * .60,
        size.width * .39,
        size.height * .54,
        size.width * .42,
        size.height * .43,
      )
      ..cubicTo(
        size.width * .47,
        size.height * .32,
        size.width * .69,
        size.height * .30,
        size.width * .80,
        size.height * .24,
      );
    canvas.drawPath(
      route,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = RoundsColors.orange
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    final pickup = Offset(size.width * .80, size.height * .24);
    canvas.drawCircle(pickup, 18, Paint()..color = Colors.white);
    canvas.drawCircle(pickup, 14, Paint()..color = RoundsColors.orange);
    canvas.drawCircle(
      Offset(size.width * .22, size.height * .72),
      13,
      Paint()..color = RoundsColors.ink,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
