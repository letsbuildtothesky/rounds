import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_strings.dart';
import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_session.dart';
import 'call_contact_screen.dart';
import 'driver_profile_screen.dart';
import 'my_rounds_screen.dart';
import 'operations_chat_screen.dart';

class StartShiftScreen extends StatefulWidget {
  const StartShiftScreen({
    required this.controller,
    required this.session,
    this.now,
    this.onStartShift,
    super.key,
  });

  final HarnessAppController controller;
  final DriverSessionModel session;
  final DateTime? now;
  final Future<bool> Function()? onStartShift;

  @override
  State<StartShiftScreen> createState() => _StartShiftScreenState();
}

class _StartShiftScreenState extends State<StartShiftScreen> {
  bool _starting = false;

  DriverEffectiveShiftModel get _shift => widget.session.shift!.effective;
  bool get _thai => widget.controller.locale == HarnessLocale.thai;
  bool get _compact => MediaQuery.sizeOf(context).width <= 340;
  _StartShiftCopy get _copy => _StartShiftCopy(_thai);

  int get _minutesUntilStart {
    final seconds = _shift.startAt
        .difference(widget.now ?? DateTime.now())
        .inSeconds;
    return math.max(0, (seconds / 60).ceil());
  }

  String get _scheduledDuration {
    final minutes = _shift.scheduledMinutes;
    final hours = minutes ~/ 60;
    final remainder = minutes.remainder(60);
    if (_thai) {
      return remainder == 0 ? '$hours ชม.' : '$hours ชม. $remainder นาที';
    }
    return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
  }

  Future<void> _startShift() async {
    if (_starting) return;
    setState(() => _starting = true);
    final success = widget.onStartShift != null
        ? await widget.onStartShift!()
        : await widget.controller.startShift() != null;
    if (!mounted) return;
    setState(() => _starting = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.controller.driverError ?? _copy.startFailed),
        ),
      );
    }
  }

  DriverRoundStopModel? get _contactStop {
    final stops = widget.session.currentRound?.stops;
    return stops == null || stops.isEmpty ? null : stops.first;
  }

  void _messageDispatch() {
    final round = widget.session.currentRound;
    final stop = _contactStop;
    if (round == null || stop == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OperationsChatScreen(
          controller: widget.controller,
          round: round,
          stop: stop,
        ),
      ),
    );
  }

  void _callDispatch() {
    final round = widget.session.currentRound;
    final stop = _contactStop;
    if (round == null || stop == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CallContactScreen(
          controller: widget.controller,
          round: round,
          stop: stop,
          target: CallContactTarget.operations,
        ),
      ),
    );
  }

  void _openJobs() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (screenContext) => MyRoundsScreen(
          session: widget.session,
          onReturnToRound: () =>
              Navigator.of(screenContext).popUntil((route) => route.isFirst),
          onProfile: _openProfile,
        ),
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (screenContext) => DriverProfileScreen(
          controller: widget.controller,
          session: widget.session,
          onHome: () =>
              Navigator.of(screenContext).popUntil((route) => route.isFirst),
          onJobs: _openJobs,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: RoundsColors.surface,
    body: SafeArea(
      child: MediaQuery.withNoTextScaling(
        child: Column(
          children: [
            _TopBar(copy: _copy),
            Expanded(
              child: Column(
                children: [
                  _Hero(
                    copy: _copy,
                    teamName: widget.session.teamName ?? 'UrbanFlowers',
                    minutesUntilStart: _minutesUntilStart,
                    compact: _compact,
                  ),
                  _ShiftDetails(
                    copy: _copy,
                    shift: _shift,
                    duration: _scheduledDuration,
                    compact: _compact,
                  ),
                  const Expanded(
                    child: SizedBox(
                      key: Key('b00-breathing-space'),
                      height: 32,
                    ),
                  ),
                  _Dispatch(
                    copy: _copy,
                    teamName: widget.session.teamName ?? 'UrbanFlowers',
                    compact: _compact,
                    contactAvailable: _contactStop != null,
                    onMessage: _messageDispatch,
                    onCall: _callDispatch,
                  ),
                  _StartAction(
                    copy: _copy,
                    compact: _compact,
                    starting: _starting || widget.controller.driverLoading,
                    onPressed: _startShift,
                  ),
                ],
              ),
            ),
            _BottomNav(
              copy: _copy,
              compact: _compact,
              onJobs: _openJobs,
              onProfile: _openProfile,
            ),
          ],
        ),
      ),
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.copy});

  final _StartShiftCopy copy;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('b00-topbar'),
    height: DriverB00Metrics.topBarHeight,
    padding: const EdgeInsets.symmetric(
      horizontal: DriverB00Metrics.topBarPaddingHorizontal,
    ),
    decoration: const BoxDecoration(
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
                fontSize: DriverB00Metrics.brandSize,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: DriverB00Metrics.brandTracking,
              ),
            ),
            Container(
              width: DriverB00Metrics.brandDotSize,
              height: DriverB00Metrics.brandDotSize,
              margin: const EdgeInsets.only(left: 3, bottom: 2),
              decoration: const BoxDecoration(
                color: RoundsColors.orange,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        Semantics(
          label: copy.notifications,
          enabled: false,
          child: const SizedBox(
            width: DriverB00Metrics.notificationSize,
            height: DriverB00Metrics.notificationSize,
            child: Icon(
              Icons.notifications_none,
              size: DriverB00Metrics.notificationIconSize,
              color: RoundsColors.lineStrong,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.copy,
    required this.teamName,
    required this.minutesUntilStart,
    required this.compact,
  });

  final _StartShiftCopy copy;
  final String teamName;
  final int minutesUntilStart;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final thai = copy.thai;
    return Container(
      key: const Key('b00-hero'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        DriverB00Metrics.heroPaddingHorizontal,
        thai
            ? compact
                  ? DriverB00Metrics.thaiCompactHeroPaddingTop
                  : DriverB00Metrics.thaiHeroPaddingTop
            : DriverB00Metrics.englishHeroPaddingTop,
        DriverB00Metrics.heroPaddingHorizontal,
        thai
            ? compact
                  ? DriverB00Metrics.thaiCompactHeroPaddingBottom
                  : DriverB00Metrics.thaiHeroPaddingBottom
            : DriverB00Metrics.englishHeroPaddingBottom,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: RoundsColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              bottom: thai
                  ? DriverB00Metrics.thaiStateBottom
                  : DriverB00Metrics.englishStateBottom,
            ),
            child: Row(
              children: [
                Container(
                  width: DriverB00Metrics.heroStateDotSize,
                  height: DriverB00Metrics.heroStateDotSize,
                  decoration: const BoxDecoration(
                    color: RoundsColors.muted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: DriverB00Metrics.heroStateGap),
                Text(
                  '${copy.offShift} · $teamName',
                  style: TextStyle(
                    color: RoundsColors.muted,
                    fontSize: thai
                        ? compact
                              ? DriverB00Metrics.thaiCompactStateSize
                              : DriverB00Metrics.thaiStateSize
                        : DriverB00Metrics.englishStateSize,
                    height: thai ? 1.45 : 1,
                    fontWeight: thai ? FontWeight.w700 : FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            copy.startsIn(minutesUntilStart),
            key: const Key('b00-countdown'),
            style: TextStyle(
              color: RoundsColors.ink,
              fontSize: thai
                  ? compact
                        ? DriverB00Metrics.thaiCompactTitleSize
                        : DriverB00Metrics.thaiTitleSize
                  : DriverB00Metrics.englishTitleSize,
              height: thai ? (compact ? 1.14 : 1.12) : 1.01,
              fontWeight: FontWeight.w800,
              letterSpacing: thai ? 0 : -1.705,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftDetails extends StatelessWidget {
  const _ShiftDetails({
    required this.copy,
    required this.shift,
    required this.duration,
    required this.compact,
  });

  final _StartShiftCopy copy;
  final DriverEffectiveShiftModel shift;
  final String duration;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final thai = copy.thai;
    return Container(
      key: const Key('b00-shift'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        DriverB00Metrics.shiftPaddingHorizontal,
        thai
            ? compact
                  ? DriverB00Metrics.thaiCompactShiftPaddingTop
                  : DriverB00Metrics.thaiShiftPaddingTop
            : DriverB00Metrics.englishShiftPaddingTop,
        DriverB00Metrics.shiftPaddingHorizontal,
        thai
            ? compact
                  ? DriverB00Metrics.thaiCompactShiftPaddingBottom
                  : DriverB00Metrics.thaiShiftPaddingBottom
            : DriverB00Metrics.englishShiftPaddingBottom,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: RoundsColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              bottom: thai
                  ? DriverB00Metrics.thaiShiftLabelBottom
                  : DriverB00Metrics.englishShiftLabelBottom,
            ),
            child: Text(
              copy.today,
              style: TextStyle(
                color: RoundsColors.muted,
                fontSize: thai
                    ? compact
                          ? DriverB00Metrics.thaiCompactShiftLabelSize
                          : DriverB00Metrics.thaiShiftLabelSize
                    : DriverB00Metrics.englishShiftLabelSize,
                height: thai ? 1.45 : 1,
                fontWeight: thai ? FontWeight.w700 : FontWeight.w800,
                letterSpacing: thai ? 0 : 1.035,
              ),
            ),
          ),
          Text(
            '${shift.startLocal}–${shift.endLocal}',
            key: const Key('b00-shift-time'),
            style: TextStyle(
              color: RoundsColors.ink,
              fontSize: thai
                  ? compact
                        ? DriverB00Metrics.thaiCompactShiftTimeSize
                        : DriverB00Metrics.thaiShiftTimeSize
                  : DriverB00Metrics.englishShiftTimeSize,
              height: thai ? 1 : .98,
              fontWeight: FontWeight.w800,
              letterSpacing: thai ? -1.71 : -2.145,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: thai
                  ? DriverB00Metrics.thaiShiftMetaTop
                  : DriverB00Metrics.englishShiftMetaTop,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: duration,
                        style: const TextStyle(
                          color: RoundsColors.inkSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(text: ' ${copy.scheduled}'),
                    ],
                  ),
                  style: TextStyle(
                    color: RoundsColors.muted,
                    fontSize: thai
                        ? compact
                              ? DriverB00Metrics.thaiCompactShiftMetaSize
                              : DriverB00Metrics.thaiShiftMetaSize
                        : DriverB00Metrics.englishShiftMetaSize,
                    height: thai ? 1.4 : 1,
                    fontWeight: thai ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
                Text(
                  copy.teamShift,
                  style: TextStyle(
                    color: RoundsColors.muted,
                    fontSize: thai
                        ? compact
                              ? DriverB00Metrics.thaiCompactShiftMetaSize
                              : DriverB00Metrics.thaiShiftMetaSize
                        : DriverB00Metrics.englishShiftMetaSize,
                    height: thai ? 1.4 : 1,
                    fontWeight: thai ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dispatch extends StatelessWidget {
  const _Dispatch({
    required this.copy,
    required this.teamName,
    required this.compact,
    required this.contactAvailable,
    required this.onMessage,
    required this.onCall,
  });

  final _StartShiftCopy copy;
  final String teamName;
  final bool compact;
  final bool contactAvailable;
  final VoidCallback onMessage;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('b00-dispatch'),
    height: DriverB00Metrics.dispatchHeight,
    padding: EdgeInsets.symmetric(
      horizontal: compact
          ? DriverB00Metrics.compactDispatchPaddingHorizontal
          : DriverB00Metrics.dispatchPaddingHorizontal,
    ),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(
                bottom: copy.thai
                    ? DriverB00Metrics.thaiDispatchLabelBottom
                    : DriverB00Metrics.englishDispatchLabelBottom,
              ),
              child: Text(
                copy.dispatch,
                style: TextStyle(
                  color: RoundsColors.muted,
                  fontSize: copy.thai
                      ? DriverB00Metrics.thaiDispatchLabelSize
                      : DriverB00Metrics.englishDispatchLabelSize,
                  height: copy.thai ? 1.4 : 1,
                  fontWeight: copy.thai ? FontWeight.w700 : FontWeight.w800,
                  letterSpacing: copy.thai ? 0 : .92,
                ),
              ),
            ),
            Text(
              teamName,
              style: TextStyle(
                color: RoundsColors.ink,
                fontSize: copy.thai
                    ? DriverB00Metrics.thaiDispatchNameSize
                    : DriverB00Metrics.englishDispatchNameSize,
                height: 1.12,
                fontWeight: FontWeight.w800,
                letterSpacing: copy.thai ? -.15 : -.32,
              ),
            ),
          ],
        ),
        Row(
          children: [
            _UtilityButton(
              tooltip: copy.messageDispatch,
              icon: Icons.chat_bubble_outline,
              enabled: contactAvailable,
              onPressed: onMessage,
            ),
            const SizedBox(width: DriverB00Metrics.dispatchActionGap),
            _UtilityButton(
              tooltip: copy.callDispatch,
              icon: Icons.phone_outlined,
              enabled: contactAvailable,
              onPressed: onCall,
            ),
          ],
        ),
      ],
    ),
  );
}

class _UtilityButton extends StatelessWidget {
  const _UtilityButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: DriverB00Metrics.dispatchActionSize,
    height: DriverB00Metrics.dispatchActionSize,
    child: IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: RoundsColors.line),
          borderRadius: BorderRadius.circular(7),
        ),
        foregroundColor: RoundsColors.inkSecondary,
        disabledForegroundColor: RoundsColors.lineStrong,
      ),
      icon: Icon(icon, size: DriverB00Metrics.dispatchActionIconSize),
    ),
  );
}

class _StartAction extends StatelessWidget {
  const _StartAction({
    required this.copy,
    required this.compact,
    required this.starting,
    required this.onPressed,
  });

  final _StartShiftCopy copy;
  final bool compact;
  final bool starting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('b00-start-wrap'),
    padding: EdgeInsets.fromLTRB(
      compact
          ? DriverB00Metrics.compactStartPaddingHorizontal
          : DriverB00Metrics.startPaddingHorizontal,
      DriverB00Metrics.startPaddingTop,
      compact
          ? DriverB00Metrics.compactStartPaddingHorizontal
          : DriverB00Metrics.startPaddingHorizontal,
      DriverB00Metrics.startPaddingBottom,
    ),
    child: SizedBox(
      width: double.infinity,
      height: DriverB00Metrics.startButtonHeight,
      child: FilledButton(
        key: const Key('b00-start-shift'),
        onPressed: starting ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: RoundsColors.orange,
          disabledBackgroundColor: RoundsColors.orange.withValues(alpha: .62),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              DriverB00Metrics.startButtonRadius,
            ),
          ),
        ),
        child: starting
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_upward,
                    size: DriverB00Metrics.startButtonIconSize,
                  ),
                  const SizedBox(width: DriverB00Metrics.startButtonGap),
                  Text(
                    copy.startShift,
                    style: TextStyle(
                      fontSize: compact
                          ? DriverB00Metrics.compactStartButtonSize
                          : DriverB00Metrics.startButtonSize,
                      height: copy.thai ? 1.35 : 1,
                      fontWeight: copy.thai ? FontWeight.w700 : FontWeight.w800,
                      letterSpacing: copy.thai ? 0 : -.255,
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.copy,
    required this.compact,
    required this.onJobs,
    required this.onProfile,
  });

  final _StartShiftCopy copy;
  final bool compact;
  final VoidCallback onJobs;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('b00-bottom-nav'),
    height: DriverB00Metrics.bottomNavHeight,
    padding: const EdgeInsets.fromLTRB(
      DriverB00Metrics.bottomNavPaddingHorizontal,
      DriverB00Metrics.bottomNavPaddingTop,
      DriverB00Metrics.bottomNavPaddingHorizontal,
      DriverB00Metrics.bottomNavPaddingBottom,
    ),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: _NavItem(
            copy: copy,
            compact: compact,
            icon: Icons.home_outlined,
            label: copy.home,
            active: true,
          ),
        ),
        Expanded(
          child: _NavItem(
            copy: copy,
            compact: compact,
            icon: Icons.location_on_outlined,
            label: copy.jobs,
            onTap: onJobs,
          ),
        ),
        Expanded(
          child: _NavItem(
            copy: copy,
            compact: compact,
            icon: Icons.schedule,
            label: copy.hours,
          ),
        ),
        Expanded(
          child: _NavItem(
            copy: copy,
            compact: compact,
            icon: Icons.person_outline,
            label: copy.profile,
            onTap: onProfile,
          ),
        ),
      ],
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.copy,
    required this.compact,
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final _StartShiftCopy copy;
  final bool compact;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: DriverB00Metrics.bottomNavIconSize,
          color: active ? RoundsColors.orange : RoundsColors.muted,
        ),
        const SizedBox(height: DriverB00Metrics.bottomNavGap),
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: active ? RoundsColors.orange : RoundsColors.muted,
            fontSize: copy.thai
                ? compact
                      ? DriverB00Metrics.thaiCompactBottomNavLabelSize
                      : DriverB00Metrics.thaiBottomNavLabelSize
                : DriverB00Metrics.englishBottomNavLabelSize,
            height: copy.thai ? 1.3 : 1,
            fontWeight: copy.thai ? FontWeight.w600 : FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _StartShiftCopy {
  const _StartShiftCopy(this.thai);

  final bool thai;

  String get notifications => thai ? 'การแจ้งเตือน' : 'Notifications';
  String get offShift => thai ? 'ยังไม่เริ่มกะ' : 'Off shift';
  String startsIn(int minutes) =>
      thai ? 'เริ่มกะใน $minutes นาที' : 'Starts in $minutes min';
  String get today => thai ? 'กะวันนี้' : 'TODAY';
  String get scheduled => thai ? 'ตามตาราง' : 'scheduled';
  String get teamShift => thai ? 'กะทีม' : 'Team shift';
  String get dispatch => thai ? 'ติดต่อทีม' : 'DISPATCH';
  String get messageDispatch => thai ? 'ส่งข้อความหาทีม' : 'Message dispatch';
  String get callDispatch => thai ? 'โทรหาทีม' : 'Call dispatch';
  String get startShift => thai ? 'เริ่มกะ' : 'Start shift';
  String get startFailed =>
      thai ? 'ไม่สามารถเริ่มกะได้' : 'Shift could not be started';
  String get home => thai ? 'หน้าแรก' : 'Home';
  String get jobs => thai ? 'งาน' : 'Jobs';
  String get hours => thai ? 'ชั่วโมง' : 'Hours';
  String get profile => thai ? 'โปรไฟล์' : 'Profile';
}
