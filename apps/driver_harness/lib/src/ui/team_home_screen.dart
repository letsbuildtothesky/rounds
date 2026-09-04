import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../app/app_strings.dart';
import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_session.dart';
import 'call_contact_screen.dart';
import 'driver_profile_screen.dart';
import 'my_rounds_screen.dart';
import 'operations_chat_screen.dart';
import 'pickup_navigation_screen.dart';

/// Canonical B01/B01B Team Home. A null [round] renders the waiting state;
/// an approved/loading [round] renders the assigned pickup state.
class TeamHomeScreen extends StatelessWidget {
  const TeamHomeScreen({
    required this.controller,
    required this.session,
    required this.enableNativeNavigation,
    this.round,
    this.now,
    this.pickupDistanceMeters,
    this.pickupEtaMinutes,
    super.key,
  });

  final HarnessAppController controller;
  final DriverSessionModel session;
  final DriverRoundModel? round;
  final bool enableNativeNavigation;
  final DateTime? now;

  /// Reserved for an authoritative driver-to-pickup route result. These are
  /// intentionally null in the live root until that route is available.
  final int? pickupDistanceMeters;
  final int? pickupEtaMinutes;

  bool get _thai => controller.locale == HarnessLocale.thai;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: RoundsColors.surface,
    body: SafeArea(
      child: MediaQuery.withNoTextScaling(
        child: Column(
          children: [
            const _TeamHomeTopBar(),
            Expanded(
              child: round == null
                  ? _WaitingHome(
                      session: session,
                      thai: _thai,
                      now: now ?? DateTime.now(),
                    )
                  : _AssignedHome(
                      round: round!,
                      thai: _thai,
                      enableNativeMap: enableNativeNavigation,
                      pickupDistanceMeters: pickupDistanceMeters,
                      pickupEtaMinutes: pickupEtaMinutes,
                      onMessage: () => _openMessage(context),
                      onCall: () => _openCall(context),
                      onNavigate: () => _openPickupNavigation(context),
                    ),
            ),
            _TeamHomeBottomNav(
              thai: _thai,
              onJobs: () => _openJobs(context),
              onProfile: () => _openProfile(context),
            ),
          ],
        ),
      ),
    ),
  );

  DriverRoundStopModel? get _contactStop {
    final stops = round?.stops;
    return stops == null || stops.isEmpty ? null : stops.first;
  }

  void _openMessage(BuildContext context) {
    final activeRound = round;
    final stop = _contactStop;
    if (activeRound == null || stop == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OperationsChatScreen(
          controller: controller,
          round: activeRound,
          stop: stop,
        ),
      ),
    );
  }

  void _openCall(BuildContext context) {
    final activeRound = round;
    final stop = _contactStop;
    if (activeRound == null || stop == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CallContactScreen(
          controller: controller,
          round: activeRound,
          stop: stop,
          target: CallContactTarget.operations,
        ),
      ),
    );
  }

  void _openPickupNavigation(BuildContext context) {
    final activeRound = round;
    if (activeRound == null ||
        activeRound.pickup.latitude == null ||
        activeRound.pickup.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _thai
                ? 'ยังไม่มีพิกัดจุดรับของ กรุณาติดต่อฝ่ายจัดงาน'
                : 'Pickup coordinates are unavailable. Contact Dispatch.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PickupNavigationScreen(
          controller: controller,
          round: activeRound,
          enableNativeNavigation: enableNativeNavigation,
        ),
      ),
    );
  }

  void _openJobs(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (screenContext) => MyRoundsScreen(
          session: session,
          onReturnToRound: () =>
              Navigator.of(screenContext).popUntil((route) => route.isFirst),
          onProfile: () => _openProfile(screenContext),
        ),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (screenContext) => DriverProfileScreen(
          controller: controller,
          session: session,
          onHome: () =>
              Navigator.of(screenContext).popUntil((route) => route.isFirst),
          onJobs: () => _openJobs(screenContext),
        ),
      ),
    );
  }
}

class _TeamHomeTopBar extends StatelessWidget {
  const _TeamHomeTopBar();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('b01-topbar'),
    height: DriverB01HomeMetrics.topBarHeight,
    padding: const EdgeInsets.symmetric(
      horizontal: DriverB01HomeMetrics.topBarPaddingHorizontal,
    ),
    decoration: const BoxDecoration(
      color: RoundsColors.surface,
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Rounds',
              style: TextStyle(
                color: RoundsColors.ink,
                fontSize: DriverB01HomeMetrics.brandSize,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: DriverB01HomeMetrics.brandTracking,
              ),
            ),
            Container(
              width: DriverB01HomeMetrics.brandDotSize,
              height: DriverB01HomeMetrics.brandDotSize,
              margin: const EdgeInsets.only(left: 3, bottom: 2),
              decoration: const BoxDecoration(
                color: RoundsColors.orange,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(
          width: DriverB01HomeMetrics.notificationSize,
          height: DriverB01HomeMetrics.notificationSize,
          child: Icon(
            Icons.notifications_none,
            color: RoundsColors.inkSecondary,
            size: DriverB01HomeMetrics.notificationIconSize,
          ),
        ),
      ],
    ),
  );
}

class _WaitingHome extends StatelessWidget {
  const _WaitingHome({
    required this.session,
    required this.thai,
    required this.now,
  });

  final DriverSessionModel session;
  final bool thai;
  final DateTime now;

  DriverEffectiveShiftModel get shift => session.shift!.effective;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 340;
    final horizontal = compact
        ? 16.0
        : DriverB01HomeMetrics.waitingPaddingHorizontal;
    final remaining = shift.endAt.difference(now);
    final remainingMinutes = math.max(0, remaining.inMinutes);
    final totalSeconds = math.max(
      1,
      shift.endAt.difference(shift.startAt).inSeconds,
    );
    final elapsedSeconds = now.difference(shift.startAt).inSeconds;
    final progress = (elapsedSeconds / totalSeconds).clamp(0.0, 1.0);
    final hours = remainingMinutes ~/ 60;
    final minutes = remainingMinutes.remainder(60);
    final remainingLabel = thai
        ? '$hours ชม. $minutes นาที'
        : '${hours}h ${minutes}m left';

    return Column(
      children: [
        Container(
          key: const Key('b01-waiting-hero'),
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            horizontal,
            thai
                ? compact
                      ? DriverB01HomeMetrics.thaiCompactWaitingHeroPaddingTop
                      : DriverB01HomeMetrics.thaiWaitingHeroPaddingTop
                : DriverB01HomeMetrics.englishWaitingHeroPaddingTop,
            horizontal,
            thai
                ? compact
                      ? DriverB01HomeMetrics.thaiCompactWaitingHeroPaddingBottom
                      : DriverB01HomeMetrics.thaiWaitingHeroPaddingBottom
                : DriverB01HomeMetrics.englishWaitingHeroPaddingBottom,
          ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: RoundsColors.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StateLine(
                color: RoundsColors.green,
                text: thai
                    ? 'อยู่ในกะ · ${session.teamName ?? 'UrbanFlowers'}'
                    : 'On shift · ${session.teamName ?? 'UrbanFlowers'}',
                fontSize: thai
                    ? compact
                          ? DriverB01HomeMetrics.thaiCompactWaitingStateSize
                          : DriverB01HomeMetrics.thaiWaitingStateSize
                    : DriverB01HomeMetrics.englishWaitingStateSize,
                bottom: thai
                    ? DriverB01HomeMetrics.thaiWaitingStateBottom
                    : DriverB01HomeMetrics.englishWaitingStateBottom,
                dotSize: DriverB01HomeMetrics.waitingStateDotSize,
                gap: DriverB01HomeMetrics.waitingStateGap,
                thai: thai,
              ),
              Text(
                thai ? 'รอรับงาน' : 'Waiting for assignment',
                style: TextStyle(
                  color: RoundsColors.ink,
                  fontSize: thai
                      ? compact
                            ? DriverB01HomeMetrics.thaiCompactWaitingTitleSize
                            : DriverB01HomeMetrics.thaiWaitingTitleSize
                      : DriverB01HomeMetrics.englishWaitingTitleSize,
                  height: thai ? 1.14 : 1.01,
                  fontWeight: thai ? FontWeight.w800 : FontWeight.w800,
                  letterSpacing: thai ? 0 : -1.7,
                ),
              ),
            ],
          ),
        ),
        Container(
          key: const Key('b01-shift'),
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            horizontal,
            thai
                ? compact
                      ? DriverB01HomeMetrics.thaiCompactWaitingShiftPaddingTop
                      : DriverB01HomeMetrics.thaiWaitingShiftPaddingTop
                : DriverB01HomeMetrics.englishWaitingShiftPaddingTop,
            horizontal,
            thai
                ? compact
                      ? DriverB01HomeMetrics
                            .thaiCompactWaitingShiftPaddingBottom
                      : DriverB01HomeMetrics.thaiWaitingShiftPaddingBottom
                : DriverB01HomeMetrics.englishWaitingShiftPaddingBottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                thai ? 'กะวันนี้' : 'SHIFT',
                style: TextStyle(
                  color: RoundsColors.muted,
                  fontSize: thai
                      ? DriverB01HomeMetrics.thaiWaitingShiftLabelSize
                      : DriverB01HomeMetrics.englishWaitingShiftLabelSize,
                  height: thai ? 1.45 : 1,
                  fontWeight: thai ? FontWeight.w700 : FontWeight.w800,
                  letterSpacing: thai ? 0 : 1.04,
                ),
              ),
              SizedBox(
                height: thai
                    ? DriverB01HomeMetrics.thaiWaitingShiftLabelBottom
                    : DriverB01HomeMetrics.englishWaitingShiftLabelBottom,
              ),
              if (thai)
                const Text(
                  'เหลือในกะ',
                  style: TextStyle(
                    color: RoundsColors.muted,
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (thai) const SizedBox(height: 6),
              Text(
                remainingLabel,
                key: const Key('b01-time-left'),
                style: TextStyle(
                  color: RoundsColors.ink,
                  fontSize: thai && compact
                      ? 31
                      : DriverB01HomeMetrics.waitingTimeSize,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: thai ? -1.2 : -1.5,
                ),
              ),
              const SizedBox(height: DriverB01HomeMetrics.waitingTimeBottom),
              _ShiftProgress(progress: progress),
              const SizedBox(height: DriverB01HomeMetrics.waitingTrackBottom),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ShiftTime(
                    prefix: thai ? 'เริ่ม ' : '',
                    time: shift.startLocal,
                    suffix: thai ? '' : ' start',
                  ),
                  _ShiftTime(
                    prefix: thai ? 'สิ้นสุด ' : 'ends ',
                    time: shift.endLocal,
                  ),
                ],
              ),
            ],
          ),
        ),
        const Expanded(child: SizedBox(key: Key('b01-breathing-space'))),
        _DispatchRow(
          thai: thai,
          teamName: session.teamName ?? 'UrbanFlowers',
          enabled: false,
          waiting: true,
        ),
      ],
    );
  }
}

class _AssignedHome extends StatelessWidget {
  const _AssignedHome({
    required this.round,
    required this.thai,
    required this.enableNativeMap,
    required this.pickupDistanceMeters,
    required this.pickupEtaMinutes,
    required this.onMessage,
    required this.onCall,
    required this.onNavigate,
  });

  final DriverRoundModel round;
  final bool thai;
  final bool enableNativeMap;
  final int? pickupDistanceMeters;
  final int? pickupEtaMinutes;
  final VoidCallback onMessage;
  final VoidCallback onCall;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 340;
    final horizontal = compact
        ? DriverB01HomeMetrics.compactAssignedPaddingHorizontal
        : DriverB01HomeMetrics.assignedPaddingHorizontal;
    final area = round.pickup.rawAddress.split(',').first.trim();
    return Column(
      children: [
        Container(
          key: const Key('b01b-hero'),
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            horizontal,
            thai
                ? compact
                      ? DriverB01HomeMetrics.thaiCompactAssignedHeroPaddingTop
                      : DriverB01HomeMetrics.thaiAssignedHeroPaddingTop
                : DriverB01HomeMetrics.englishAssignedHeroPaddingTop,
            horizontal,
            thai
                ? compact
                      ? DriverB01HomeMetrics
                            .thaiCompactAssignedHeroPaddingBottom
                      : DriverB01HomeMetrics.thaiAssignedHeroPaddingBottom
                : DriverB01HomeMetrics.englishAssignedHeroPaddingBottom,
          ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: RoundsColors.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StateLine(
                color: RoundsColors.orange,
                text: thai ? 'ได้รับรอบแล้ว' : 'Round assigned',
                fontSize: thai
                    ? compact
                          ? DriverB01HomeMetrics.thaiCompactAssignedStateSize
                          : DriverB01HomeMetrics.thaiAssignedStateSize
                    : DriverB01HomeMetrics.englishAssignedStateSize,
                bottom: thai
                    ? DriverB01HomeMetrics.thaiAssignedStateBottom
                    : DriverB01HomeMetrics.englishAssignedStateBottom,
                dotSize: DriverB01HomeMetrics.assignedStateDotSize,
                gap: DriverB01HomeMetrics.assignedStateGap,
                thai: thai,
              ),
              Text(
                thai ? 'ไปรับของ' : 'Pickup next',
                style: TextStyle(
                  color: RoundsColors.ink,
                  fontSize: thai
                      ? compact
                            ? DriverB01HomeMetrics.thaiCompactAssignedTitleSize
                            : DriverB01HomeMetrics.thaiAssignedTitleSize
                      : DriverB01HomeMetrics.englishAssignedTitleSize,
                  height: thai ? 1.14 : 1.01,
                  fontWeight: FontWeight.w800,
                  letterSpacing: thai ? 0 : -1.7,
                ),
              ),
              SizedBox(
                height: thai
                    ? DriverB01HomeMetrics.thaiAssignedAreaTop
                    : DriverB01HomeMetrics.assignedAreaTop,
              ),
              Text(
                area.isEmpty ? '—' : area,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: RoundsColors.muted,
                  fontSize: compact
                      ? DriverB01HomeMetrics.compactAssignedAreaSize
                      : DriverB01HomeMetrics.assignedAreaSize,
                  height: thai ? 1.45 : 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        _PickupSummary(
          round: round,
          thai: thai,
          compact: compact,
          horizontal: horizontal,
          pickupDistanceMeters: pickupDistanceMeters,
          pickupEtaMinutes: pickupEtaMinutes,
        ),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: DriverB01HomeMetrics.assignedMapMinHeight,
            ),
            child: _PickupAssignmentMap(
              pickup: round.pickup,
              enableNativeMap: enableNativeMap,
              thai: thai,
            ),
          ),
        ),
        _RoundContext(round: round, thai: thai, compact: compact),
        Container(
          key: const Key('b01b-task-footer'),
          padding: EdgeInsets.fromLTRB(
            horizontal,
            DriverB01HomeMetrics.assignedFooterPaddingTop,
            horizontal,
            DriverB01HomeMetrics.assignedFooterPaddingBottom,
          ),
          child: Column(
            children: [
              _DispatchRow(
                thai: thai,
                teamName: round.tenantName,
                enabled: true,
                waiting: false,
                onMessage: onMessage,
                onCall: onCall,
              ),
              const SizedBox(
                height: DriverB01HomeMetrics.assignedFooterUtilityBottom,
              ),
              SizedBox(
                width: double.infinity,
                height: DriverB01HomeMetrics.assignedPrimaryHeight,
                child: FilledButton(
                  key: const Key('b01b-navigate'),
                  onPressed: onNavigate,
                  style: FilledButton.styleFrom(
                    backgroundColor: RoundsColors.ink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DriverB01HomeMetrics.assignedPrimaryRadius,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        thai ? 'นำทางไปรับของ' : 'Navigate to pickup',
                        style: TextStyle(
                          fontSize: thai
                              ? compact
                                    ? DriverB01HomeMetrics
                                          .compactAssignedPrimarySize
                                    : DriverB01HomeMetrics
                                          .thaiAssignedPrimarySize
                              : DriverB01HomeMetrics.englishAssignedPrimarySize,
                          height: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 9),
                      const Icon(Icons.navigation_outlined, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickupSummary extends StatelessWidget {
  const _PickupSummary({
    required this.round,
    required this.thai,
    required this.compact,
    required this.horizontal,
    required this.pickupDistanceMeters,
    required this.pickupEtaMinutes,
  });

  final DriverRoundModel round;
  final bool thai;
  final bool compact;
  final double horizontal;
  final int? pickupDistanceMeters;
  final int? pickupEtaMinutes;

  @override
  Widget build(BuildContext context) {
    final metrics = _MetricPair(
      thai: thai,
      compact: compact,
      distanceMeters: pickupDistanceMeters,
      etaMinutes: pickupEtaMinutes,
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          thai ? 'จุดรับของ' : 'PICKUP',
          style: TextStyle(
            color: RoundsColors.muted,
            fontSize: thai
                ? DriverB01HomeMetrics.thaiAssignedEyebrowSize
                : DriverB01HomeMetrics.englishAssignedEyebrowSize,
            height: thai ? 1.4 : 1,
            fontWeight: thai ? FontWeight.w700 : FontWeight.w800,
            letterSpacing: thai ? 0 : 1.04,
          ),
        ),
        SizedBox(
          height: thai
              ? DriverB01HomeMetrics.thaiAssignedEyebrowBottom
              : DriverB01HomeMetrics.englishAssignedEyebrowBottom,
        ),
        Text(
          round.pickup.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: RoundsColors.ink,
            fontSize: compact
                ? DriverB01HomeMetrics.compactAssignedMerchantSize
                : thai
                ? DriverB01HomeMetrics.thaiAssignedMerchantSize
                : DriverB01HomeMetrics.englishAssignedMerchantSize,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
      ],
    );
    return Container(
      key: const Key('b01b-pickup-summary'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        horizontal,
        thai
            ? DriverB01HomeMetrics.thaiAssignedSummaryPaddingTop
            : DriverB01HomeMetrics.englishAssignedSummaryPaddingTop,
        horizontal,
        thai
            ? DriverB01HomeMetrics.thaiAssignedSummaryPaddingBottom
            : DriverB01HomeMetrics.englishAssignedSummaryPaddingBottom,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: RoundsColors.line)),
      ),
      child: thai
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                SizedBox(
                  height: compact
                      ? 11
                      : DriverB01HomeMetrics.thaiAssignedMetricTop,
                ),
                metrics,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: copy),
                const SizedBox(width: 20),
                metrics,
              ],
            ),
    );
  }
}

class _MetricPair extends StatelessWidget {
  const _MetricPair({
    required this.thai,
    required this.compact,
    required this.distanceMeters,
    required this.etaMinutes,
  });

  final bool thai;
  final bool compact;
  final int? distanceMeters;
  final int? etaMinutes;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _Metric(
        value: distanceMeters == null
            ? '—'
            : thai
            ? '${_km(distanceMeters!)} กม.'
            : '${_km(distanceMeters!)} km',
        label: thai ? 'ระยะ' : 'away',
        thai: thai,
        compact: compact,
      ),
      SizedBox(
        width: thai
            ? DriverB01HomeMetrics.thaiAssignedMetricGap
            : DriverB01HomeMetrics.englishAssignedMetricGap,
      ),
      _Metric(
        value: etaMinutes == null
            ? '—'
            : thai
            ? '$etaMinutes นาที'
            : '$etaMinutes min',
        label: thai ? 'ถึงใน' : 'ETA',
        thai: thai,
        compact: compact,
      ),
    ],
  );

  static String _km(int meters) {
    final value = meters / 1000;
    return value < 10 ? value.toStringAsFixed(1) : value.round().toString();
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.thai,
    required this.compact,
  });

  final String value;
  final String label;
  final bool thai;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: thai
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.end,
    children: [
      Text(
        value,
        style: TextStyle(
          color: RoundsColors.ink,
          fontSize: compact
              ? DriverB01HomeMetrics.compactAssignedMetricSize
              : thai
              ? DriverB01HomeMetrics.thaiAssignedMetricSize
              : DriverB01HomeMetrics.englishAssignedMetricSize,
          height: 1,
          fontWeight: FontWeight.w800,
          letterSpacing: -.7,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        label,
        style: TextStyle(
          color: RoundsColors.muted,
          fontSize: thai
              ? DriverB01HomeMetrics.thaiAssignedMetricLabelSize
              : DriverB01HomeMetrics.englishAssignedMetricLabelSize,
          height: thai ? 1.35 : 1,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _PickupAssignmentMap extends StatelessWidget {
  const _PickupAssignmentMap({
    required this.pickup,
    required this.enableNativeMap,
    required this.thai,
  });

  final DriverPickupModel pickup;
  final bool enableNativeMap;
  final bool thai;

  @override
  Widget build(BuildContext context) {
    final latitude = pickup.latitude;
    final longitude = pickup.longitude;
    if (enableNativeMap && latitude != null && longitude != null) {
      return Semantics(
        label: thai ? 'แผนที่เส้นทางไปจุดรับของ' : 'Route preview to pickup',
        child: GoogleMapsMapView(
          initialCameraPosition: CameraPosition(
            target: LatLng(latitude: latitude, longitude: longitude),
            zoom: 14.5,
          ),
          initialCompassEnabled: false,
          initialMapToolbarEnabled: false,
          initialZoomControlsEnabled: false,
          onViewCreated: (mapController) => unawaited(
            _configurePickupMap(mapController, pickup, latitude, longitude),
          ),
        ),
      );
    }
    if (enableNativeMap) {
      return Container(
        key: const Key('b01b-map-unavailable'),
        color: const Color(0xFFF3F6F7),
        alignment: Alignment.center,
        child: Text(
          thai ? 'ยังไม่มีพิกัดจุดรับของ' : 'Pickup location unavailable',
          style: const TextStyle(
            color: RoundsColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return CustomPaint(
      key: const Key('b01b-map-preview'),
      painter: const _PickupMapPainter(),
      child: Stack(
        children: [
          Positioned(
            right: 20,
            top: 88,
            child: Text(
              '${pickup.displayName}\n${thai ? 'จุดรับของ' : 'Pickup'}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: RoundsColors.ink,
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _configurePickupMap(
    GoogleMapViewController controller,
    DriverPickupModel pickup,
    double latitude,
    double longitude,
  ) async {
    try {
      await controller.setMyLocationEnabled(true);
      await controller.addMarkers([
        MarkerOptions(
          position: LatLng(latitude: latitude, longitude: longitude),
          infoWindow: InfoWindow(
            title: pickup.displayName,
            snippet: pickup.rawAddress,
          ),
        ),
      ]);
    } catch (_) {
      // Native view may be disposed before asynchronous configuration finishes.
    }
  }
}

class _PickupMapPainter extends CustomPainter {
  const _PickupMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF3F6F7),
    );
    final block = Paint()..color = const Color(0xFFE8EDEF);
    for (final rect in [
      Rect.fromLTWH(24, 20, 66, 36),
      Rect.fromLTWH(113, 27, 82, 50),
      Rect.fromLTWH(size.width - 96, 18, 75, 44),
      Rect.fromLTWH(25, size.height - 71, 83, 45),
      Rect.fromLTWH(131, size.height - 79, 75, 58),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        block,
      );
    }
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-24, size.height * .45),
      Offset(size.width + 24, size.height * .36),
      road,
    );
    canvas.drawLine(
      Offset(size.width * .47, -30),
      Offset(size.width * .78, size.height + 30),
      road,
    );
    final route = Path()
      ..moveTo(84, size.height * .62)
      ..cubicTo(
        145,
        size.height * .50,
        240,
        size.height * .34,
        size.width - 73,
        43,
      );
    canvas.drawPath(
      route,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = RoundsColors.orange
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      Offset(84, size.height * .62),
      9,
      Paint()..color = const Color(0xFF2F6FBD),
    );
    canvas.drawCircle(
      Offset(size.width - 73, 43),
      16,
      Paint()..color = RoundsColors.orange,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoundContext extends StatelessWidget {
  const _RoundContext({
    required this.round,
    required this.thai,
    required this.compact,
  });

  final DriverRoundModel round;
  final bool thai;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('b01b-round-context'),
    height: DriverB01HomeMetrics.assignedRoundContextHeight,
    padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 20),
    decoration: const BoxDecoration(
      color: RoundsColors.surface,
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            _primary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: RoundsColors.inkSecondary,
              fontSize: compact
                  ? DriverB01HomeMetrics.compactAssignedRoundContextSize
                  : thai
                  ? DriverB01HomeMetrics.thaiAssignedRoundContextSize
                  : DriverB01HomeMetrics.assignedRoundContextSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          flex: 2,
          child: Text(
            _handling,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: RoundsColors.muted,
              fontSize: compact
                  ? DriverB01HomeMetrics.compactAssignedRoundContextSize
                  : thai
                  ? DriverB01HomeMetrics.thaiAssignedRoundContextSize
                  : DriverB01HomeMetrics.assignedRoundContextSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  String get _primary {
    final stops = thai
        ? '${round.stops.length} จุด'
        : '${round.stops.length} stops';
    final distance = round.plannedDistanceMeters;
    final duration = round.plannedDurationSeconds;
    final parts = <String>[stops];
    if (distance != null) {
      final km = distance / 1000;
      parts.add('${km.toStringAsFixed(1)} ${thai ? 'กม.' : 'km'}');
    }
    if (duration != null) {
      parts.add('~${(duration / 60).round()} ${thai ? 'นาที' : 'min'}');
    }
    return parts.join(' · ');
  }

  String get _handling {
    final values = <String>[];
    for (final stop in round.stops) {
      for (final item in stop.manifestItems) {
        final label = item.handlingNote?.trim().isNotEmpty == true
            ? item.handlingNote!.trim()
            : item.description.trim();
        if (label.isNotEmpty && !values.contains(label)) values.add(label);
        if (values.length == 2) return values.join(' · ');
      }
    }
    return values.isEmpty ? '—' : values.join(' · ');
  }
}

class _StateLine extends StatelessWidget {
  const _StateLine({
    required this.color,
    required this.text,
    required this.fontSize,
    required this.bottom,
    required this.dotSize,
    required this.gap,
    required this.thai,
  });

  final Color color;
  final String text;
  final double fontSize;
  final double bottom;
  final double dotSize;
  final double gap;
  final bool thai;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: bottom),
    child: Row(
      children: [
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: gap),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              height: thai ? 1.45 : 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ShiftProgress extends StatelessWidget {
  const _ShiftProgress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SizedBox(
      height:
          DriverB01HomeMetrics.waitingProgressDotSize +
          DriverB01HomeMetrics.waitingProgressHalo * 2,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(
            height: DriverB01HomeMetrics.waitingTrackHeight,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EDF0),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Container(
            width: constraints.maxWidth * progress,
            height: DriverB01HomeMetrics.waitingTrackHeight,
            decoration: BoxDecoration(
              color: RoundsColors.orange,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Positioned(
            left: math.max(
              0,
              constraints.maxWidth * progress -
                  DriverB01HomeMetrics.waitingProgressDotSize / 2,
            ),
            child: Container(
              width: DriverB01HomeMetrics.waitingProgressDotSize,
              height: DriverB01HomeMetrics.waitingProgressDotSize,
              decoration: BoxDecoration(
                color: RoundsColors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: RoundsColors.orange.withValues(alpha: .22),
                    spreadRadius: DriverB01HomeMetrics.waitingProgressHalo,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ShiftTime extends StatelessWidget {
  const _ShiftTime({
    required this.prefix,
    required this.time,
    this.suffix = '',
  });

  final String prefix;
  final String time;
  final String suffix;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: prefix),
        TextSpan(
          text: time,
          style: const TextStyle(
            color: RoundsColors.inkSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
        TextSpan(text: suffix),
      ],
    ),
    style: const TextStyle(
      color: RoundsColors.muted,
      fontSize: DriverB01HomeMetrics.waitingShiftTimesSize,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _DispatchRow extends StatelessWidget {
  const _DispatchRow({
    required this.thai,
    required this.teamName,
    required this.enabled,
    required this.waiting,
    this.onMessage,
    this.onCall,
  });

  final bool thai;
  final String teamName;
  final bool enabled;
  final bool waiting;
  final VoidCallback? onMessage;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final actionSize = waiting
        ? DriverB01HomeMetrics.waitingDispatchActionSize
        : DriverB01HomeMetrics.assignedFooterActionSize;
    final row = SizedBox(
      height: waiting
          ? DriverB01HomeMetrics.waitingDispatchHeight - 1
          : DriverB01HomeMetrics.assignedFooterUtilityHeight,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thai ? 'ฝ่ายจัดงาน' : 'DISPATCH',
                  style: TextStyle(
                    color: RoundsColors.muted,
                    fontSize: thai
                        ? DriverB01HomeMetrics.thaiWaitingDispatchLabelSize
                        : DriverB01HomeMetrics.englishWaitingDispatchLabelSize,
                    height: thai ? 1.4 : 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: thai ? 0 : .92,
                  ),
                ),
                SizedBox(
                  height: waiting
                      ? thai
                            ? DriverB01HomeMetrics
                                  .thaiWaitingDispatchLabelBottom
                            : DriverB01HomeMetrics
                                  .englishWaitingDispatchLabelBottom
                      : thai
                      ? 3
                      : 4,
                ),
                Text(
                  teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: RoundsColors.ink,
                    fontSize: waiting
                        ? thai
                              ? DriverB01HomeMetrics.thaiWaitingDispatchNameSize
                              : DriverB01HomeMetrics
                                    .englishWaitingDispatchNameSize
                        : 14,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          _UtilityButton(
            size: actionSize,
            icon: Icons.chat_bubble_outline,
            tooltip: thai ? 'ส่งข้อความถึงฝ่ายจัดงาน' : 'Message Dispatch',
            onPressed: enabled ? onMessage : null,
          ),
          SizedBox(
            width: waiting
                ? DriverB01HomeMetrics.waitingDispatchActionGap
                : DriverB01HomeMetrics.assignedFooterActionGap,
          ),
          _UtilityButton(
            size: actionSize,
            icon: Icons.phone_outlined,
            tooltip: thai ? 'โทรหาฝ่ายจัดงาน' : 'Call Dispatch',
            onPressed: enabled ? onCall : null,
          ),
        ],
      ),
    );
    if (!waiting) return row;
    return Container(
      key: const Key('b01-dispatch'),
      padding: const EdgeInsets.symmetric(
        horizontal: DriverB01HomeMetrics.waitingPaddingHorizontal,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: RoundsColors.line)),
      ),
      child: row,
    );
  }
}

class _UtilityButton extends StatelessWidget {
  const _UtilityButton({
    required this.size,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final double size;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 19),
      color: RoundsColors.inkSecondary,
      disabledColor: RoundsColors.lineStrong,
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: RoundsColors.line),
          borderRadius: BorderRadius.circular(7),
        ),
      ),
    ),
  );
}

class _TeamHomeBottomNav extends StatelessWidget {
  const _TeamHomeBottomNav({
    required this.thai,
    required this.onJobs,
    required this.onProfile,
  });

  final bool thai;
  final VoidCallback onJobs;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('b01-bottom-nav'),
    height: DriverB01HomeMetrics.bottomNavHeight,
    padding: const EdgeInsets.fromLTRB(4, 7, 4, 9),
    decoration: const BoxDecoration(
      color: RoundsColors.surface,
      border: Border(top: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: _NavItem(
            icon: Icons.home_outlined,
            label: thai ? 'หน้าแรก' : 'Home',
            active: true,
          ),
        ),
        Expanded(
          child: _NavItem(
            icon: Icons.location_on_outlined,
            label: thai ? 'งาน' : 'Jobs',
            onTap: onJobs,
          ),
        ),
        Expanded(
          child: _NavItem(
            icon: Icons.schedule_outlined,
            label: thai ? 'ชั่วโมง' : 'Hours',
          ),
        ),
        Expanded(
          child: _NavItem(
            icon: Icons.person_outline,
            label: thai ? 'โปรไฟล์' : 'Profile',
            onTap: onProfile,
          ),
        ),
      ],
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final thai = Localizations.localeOf(context).languageCode == 'th';
    final color = active ? RoundsColors.orange : RoundsColors.muted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: DriverB01HomeMetrics.bottomNavIconSize,
            color: color,
          ),
          const SizedBox(height: DriverB01HomeMetrics.bottomNavGap),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: thai
                  ? DriverB01HomeMetrics.thaiBottomNavLabelSize
                  : DriverB01HomeMetrics.englishBottomNavLabelSize,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
