import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_session.dart';
import '../driver/driver_api.dart';
import '../navigation/gps_signal_monitor.dart';
import '../navigation/gps_unavailable_screen.dart';
import '../navigation/google_navigation_surface.dart';
import '../permissions/driver_permissions_screen.dart';
import 'components/navigation_instruction_card.dart';
import 'components/navigation_pickup_dock.dart';
import 'components/navigation_road_controls.dart';
import 'components/operations_contact_flow.dart';
import 'components/rounds_action_drawer.dart';
import 'location_problem_screen.dart';
import 'operations_chat_screen.dart';
import 'pickup_confirmation_screen.dart';

/// Explicit non-production values for deterministic HTML-to-Flutter review.
///
/// Production navigation must continue to use live Google Navigation events;
/// this state is accepted only while the native navigation surface is off.
class PickupNavigationReviewState {
  const PickupNavigationReviewState({
    required this.instruction,
    required this.remainingSeconds,
    required this.remainingMeters,
    required this.nearPickup,
    required this.pickupAddress,
  });

  static const enRoute = PickupNavigationReviewState(
    instruction: NavigationRoadInstruction(
      maneuver: Maneuver.turnLeft,
      text: 'Turn left into Sukhumvit 39',
      distanceMeters: 320,
    ),
    remainingSeconds: 360,
    remainingMeters: 1200,
    nearPickup: false,
    pickupAddress: 'Sukhumvit 39',
  );

  static const near = PickupNavigationReviewState(
    instruction: NavigationRoadInstruction(
      maneuver: Maneuver.destinationLeft,
      text: 'UrbanFlowers entrance ahead',
      distanceMeters: 80,
    ),
    remainingSeconds: 60,
    remainingMeters: 80,
    nearPickup: true,
    pickupAddress: 'Entrance on your left',
  );

  final NavigationRoadInstruction instruction;
  final int remainingSeconds;
  final int remainingMeters;
  final bool nearPickup;
  final String pickupAddress;
}

typedef PickupArrivalRecorder =
    Future<DriverCommandOutcome?> Function(
      DriverRoundModel round,
      Map<String, Object?>? position,
    );
typedef PickupArrivalPositionProvider =
    Future<Map<String, Object?>?> Function();

class PickupNavigationScreen extends StatefulWidget {
  const PickupNavigationScreen({
    required this.controller,
    required this.enableNativeNavigation,
    required this.round,
    this.launcher = _launchExternal,
    this.previewNearPickup = false,
    this.reviewState,
    this.arrivalRecorder,
    this.arrivalPositionProvider = _currentPickupArrivalPosition,
    super.key,
  }) : assert(
         !enableNativeNavigation || reviewState == null,
         'Review values must never replace live native navigation events.',
       );

  final HarnessAppController controller;
  final bool enableNativeNavigation;
  final DriverRoundModel round;
  final RoundsExternalLauncher launcher;
  final bool previewNearPickup;
  final PickupNavigationReviewState? reviewState;
  final PickupArrivalRecorder? arrivalRecorder;
  final PickupArrivalPositionProvider arrivalPositionProvider;

  @override
  State<PickupNavigationScreen> createState() => _PickupNavigationScreenState();
}

class _PickupNavigationScreenState extends State<PickupNavigationScreen> {
  NavigationRoadInstruction? _instruction;
  final GoogleNavigationSurfaceController _navigationController =
      GoogleNavigationSurfaceController();
  String? _navigationStatus;
  int? _remainingSeconds;
  int? _remainingMeters;
  bool _nearPickup = false;
  GpsNavigationInterruption? _gpsInterruption;
  bool _arrivalPending = false;

  PickupNavigationReviewState? get _reviewState =>
      kReleaseMode ? null : widget.reviewState;

  @override
  void initState() {
    super.initState();
    final reviewState = _reviewState;
    _instruction = reviewState?.instruction;
    _remainingSeconds = reviewState?.remainingSeconds;
    _remainingMeters = reviewState?.remainingMeters;
    _nearPickup =
        !widget.enableNativeNavigation &&
        (reviewState?.nearPickup ?? widget.previewNearPickup);
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
                      controller: _navigationController,
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
                      onGpsInterruptionChanged: (interruption) {
                        if (!mounted) return;
                        setState(() => _gpsInterruption = interruption);
                      },
                      onGuidanceAvailabilityChanged:
                          widget.controller.reportCurrentRouteAvailability,
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
                  : _PickupNavigationPreview(pickupName: pickup.displayName),
            ),
            if (_gpsInterruption == null)
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
                      child: NavigationInstructionCard(
                        instruction: _instruction,
                      ),
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
            if (_gpsInterruption == null)
              Positioned(
                left: outerMargin,
                right: outerMargin,
                bottom: outerMargin,
                child: NavigationPickupDock(
                  pickupName: pickup.displayName,
                  address: _reviewState?.pickupAddress ?? pickup.rawAddress,
                  etaLabel: _etaLabel,
                  distanceLabel: _distanceLabel,
                  showArrivalAction: _showArrivalAction,
                  arrivalPending: _arrivalPending,
                  onArrival: _confirmPickupArrival,
                ),
              ),
            if (_gpsInterruption case final interruption?)
              Positioned.fill(
                child: GpsUnavailableScreen(
                  interruption: interruption,
                  contextLabel: '${widget.round.tenantName} · Pickup',
                  onBack: () => Navigator.of(context).pop(),
                  onContinue: () => setState(() => _gpsInterruption = null),
                  onRetry: () => unawaited(_retryGps()),
                  onReviewLocationAccess: _reviewLocationAccess,
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool get _showArrivalAction => _nearPickup;

  Future<void> _reviewLocationAccess() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            DriverPermissionsScreen(locale: widget.controller.locale),
      ),
    );
    if (mounted) await _retryGps();
  }

  Future<void> _retryGps() async {
    await _navigationController.retryGps();
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

  Future<void> _confirmPickupArrival() async {
    if (_arrivalPending) return;
    setState(() => _arrivalPending = true);
    Map<String, Object?>? position;
    try {
      position = await widget.arrivalPositionProvider();
    } catch (_) {
      // Arrival remains explicit even when the OS cannot provide a fresh fix.
    }
    final outcome =
        await (widget.arrivalRecorder?.call(widget.round, position) ??
            widget.controller.confirmPickupArrival(
              widget.round,
              position: position,
            ));
    if (!mounted) return;
    if (outcome == null) {
      setState(() => _arrivalPending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.driverError ??
                'Pickup arrival could not be saved. Try again.',
          ),
        ),
      );
      return;
    }
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
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => LocationProblemScreen(
              controller: widget.controller,
              round: widget.round,
              stop: firstStop,
              problemContext: LocationProblemContext.pickup,
            ),
          ),
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

Future<Map<String, Object?>?> _currentPickupArrivalPosition() async {
  final permission = await Geolocator.checkPermission();
  if (permission != LocationPermission.whileInUse &&
      permission != LocationPermission.always) {
    return null;
  }
  if (!await Geolocator.isLocationServiceEnabled()) return null;
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 12),
    ),
  );
  return {
    'latitude': position.latitude,
    'longitude': position.longitude,
    'accuracyMeters': position.accuracy,
    'source': 'rounds_os',
  };
}

class _PickupNavigationPreview extends StatelessWidget {
  const _PickupNavigationPreview({required this.pickupName});

  final String pickupName;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const Key('pickup-navigation-map-preview'),
    painter: _PickupNavigationPreviewPainter(pickupName: pickupName),
    child: const SizedBox.expand(),
  );
}

class _PickupNavigationPreviewPainter extends CustomPainter {
  const _PickupNavigationPreviewPainter({required this.pickupName});

  final String pickupName;

  static const _referenceSize = Size(393, 824);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(
      size.width / _referenceSize.width,
      size.height / _referenceSize.height,
    );
    canvas.drawRect(
      Offset.zero & _referenceSize,
      Paint()..color = const Color(0xFFF1F4F5),
    );

    _drawBlock(canvas, const Rect.fromLTWH(18, 155, 82, 52));
    _drawBlock(canvas, const Rect.fromLTWH(119, 153, 78, 60));
    _drawBlock(canvas, const Rect.fromLTWH(293, 162, 80, 48));
    _drawBlock(canvas, const Rect.fromLTWH(25, 600, 78, 54));
    _drawBlock(
      canvas,
      const Rect.fromLTWH(277, 572, 88, 70),
      color: const Color(0xFFE3EFE6),
    );
    _drawBlock(canvas, const Rect.fromLTWH(143, 606, 78, 60));

    _drawRoad(canvas, const Rect.fromLTWH(-30, 310, 460, 13), -7);
    _drawRoad(canvas, const Rect.fromLTWH(205, 90, 520, 13), 79);
    _drawRoad(canvas, const Rect.fromLTWH(6, 222, 360, 7), 10);
    _drawRoad(canvas, const Rect.fromLTWH(52, 592, 310, 7), -2);
    _drawRoad(canvas, const Rect.fromLTWH(78, 96, 470, 7), 88);

    final route = Path()
      ..moveTo(86, 610)
      ..cubicTo(104, 560, 140, 512, 154, 455)
      ..cubicTo(167, 400, 190, 357, 233, 328)
      ..cubicTo(267, 305, 300, 276, 322, 234);
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

    _drawMapLabel(canvas, 'PHROM PHONG', const Offset(19, 235));
    _drawMapLabel(canvas, 'SUKHUMVIT 39', const Offset(292, 285));
    _drawDriver(canvas);
    _drawPickup(canvas);
    canvas.restore();
  }

  void _drawBlock(Canvas canvas, Rect rect, {Color? color}) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = color ?? const Color(0xFFE3E8EB),
    );
  }

  void _drawRoad(Canvas canvas, Rect rect, double degrees) {
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(degrees * math.pi / 180);
    final centered = Rect.fromCenter(
      center: Offset.zero,
      width: rect.width,
      height: rect.height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        centered.inflate(1),
        Radius.circular(rect.height),
      ),
      Paint()..color = const Color(0xFFDCE3E8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(centered, Radius.circular(rect.height)),
      Paint()..color = Colors.white,
    );
    canvas.restore();
  }

  void _drawMapLabel(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF8792A0),
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: .22,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _drawDriver(Canvas canvas) {
    final path = Path()
      ..moveTo(84, 571.5)
      ..lineTo(99, 609.5)
      ..lineTo(84, 603.5)
      ..lineTo(69, 609.5)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(path, Paint()..color = RoundsColors.ink);
  }

  void _drawPickup(Canvas canvas) {
    const center = Offset(327, 238);
    canvas.drawCircle(center, 18, Paint()..color = Colors.white);
    canvas.drawCircle(center, 14, Paint()..color = RoundsColors.orange);

    final home = Path()
      ..moveTo(319, 237)
      ..lineTo(327, 230.5)
      ..lineTo(335, 237)
      ..moveTo(321, 235.8)
      ..lineTo(321, 246)
      ..lineTo(333, 246)
      ..lineTo(333, 235.8);
    canvas.drawPath(
      home,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final label = TextPainter(
      text: TextSpan(
        text: pickupName,
        style: const TextStyle(
          color: RoundsColors.ink,
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelRect = Rect.fromCenter(
      center: Offset(center.dx, 275),
      width: label.width + 16,
      height: 27,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(5)),
      Paint()..color = const Color(0xFFFEFEFE),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(5)),
      Paint()
        ..color = const Color(0xFFE1E6EA)
        ..style = PaintingStyle.stroke,
    );
    label.paint(
      canvas,
      Offset(
        labelRect.center.dx - label.width / 2,
        labelRect.center.dy - label.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _PickupNavigationPreviewPainter oldDelegate) =>
      pickupName != oldDelegate.pickupName;
}
