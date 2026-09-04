import 'dart:async';

import 'package:flutter/material.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_session.dart';
import 'call_contact_screen.dart';
import 'navigation_harness_screen.dart';
import 'operations_chat_screen.dart';
import 'post_delivery_screen.dart';

enum DriverShiftSurface { endingSoon, overtime, endConfirmation }

class ShiftEndScreen extends StatefulWidget {
  const ShiftEndScreen({
    required this.controller,
    required this.session,
    required this.surface,
    required this.enableNativeNavigation,
    this.now,
    this.onNotYet,
    this.onEndShift,
    super.key,
  });

  final HarnessAppController controller;
  final DriverSessionModel session;
  final DriverShiftSurface surface;
  final bool enableNativeNavigation;
  final DateTime? now;
  final VoidCallback? onNotYet;
  final Future<bool> Function()? onEndShift;

  @override
  State<ShiftEndScreen> createState() => _ShiftEndScreenState();
}

class _ShiftEndScreenState extends State<ShiftEndScreen> {
  Timer? _clock;
  bool _submitting = false;

  DateTime get _now => widget.now ?? DateTime.now();
  bool get _thai => widget.controller.strings.isThai;
  _ShiftCopy get _copy => _ShiftCopy(_thai);
  DriverEffectiveShiftModel get _effective => widget.session.shift!.effective;
  DriverShiftAttendanceModel get _attendance =>
      widget.session.shift!.attendance!;

  @override
  void initState() {
    super.initState();
    if (widget.now == null) {
      _clock = Timer.periodic(
        const Duration(minutes: 1),
        (_) => mounted ? setState(() {}) : null,
      );
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _endShift() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final succeeded = widget.onEndShift != null
        ? await widget.onEndShift!()
        : await widget.controller.endShift() != null;
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!succeeded) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_copy.endFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RoundsColors.surface,
      body: SafeArea(
        child: MediaQuery.withNoTextScaling(
          child: Column(
            children: [
              _TopBar(copy: _copy),
              Expanded(
                child: widget.surface == DriverShiftSurface.endConfirmation
                    ? _confirmationBody()
                    : _workingBody(),
              ),
              _BottomNav(copy: _copy),
            ],
          ),
        ),
      ),
    );
  }

  Widget _workingBody() {
    final round = widget.session.currentRound!;
    final stop = nextOperationalStop(round)!;
    final plan = round.plannedStop(stop.id);
    final overtime = widget.surface == DriverShiftSurface.overtime;
    final minutes = overtime
        ? _now.difference(_effective.endAt).inMinutes.clamp(0, 999)
        : _effective.endAt.difference(_now).inMinutes.clamp(0, 15);
    final eta = plan?.eta;
    final etaDelta = eta == null
        ? null
        : overtime
        ? eta.difference(_now).inMinutes
        : eta.difference(_effective.endAt).inMinutes;
    final area = stop.rawAddress.split(',').first.trim();
    return Column(
      children: [
        _EndingHero(
          copy: _copy,
          overtime: overtime,
          minutes: minutes,
          endLocal: _effective.endLocal,
          teamName: widget.session.teamName ?? round.tenantName,
        ),
        _ActiveDelivery(
          copy: _copy,
          overtime: overtime,
          stop: stop,
          totalStops: round.stops.length,
          area: area,
          eta: eta,
          etaDeltaMinutes: etaDelta,
        ),
        const Spacer(),
        _TaskFooter(
          copy: _copy,
          teamName: widget.session.teamName ?? round.tenantName,
          onMessage: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OperationsChatScreen(
                controller: widget.controller,
                round: round,
                stop: stop,
              ),
            ),
          ),
          onCall: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CallContactScreen(
                controller: widget.controller,
                round: round,
                stop: stop,
                target: CallContactTarget.operations,
              ),
            ),
          ),
          onReturn: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => NavigationHarnessScreen(
                controller: widget.controller,
                enableNativeNavigation: widget.enableNativeNavigation,
                round: round,
                stop: stop,
                stopCount: round.stops.length,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _confirmationBody() {
    final worked = _now
        .difference(_attendance.startedAt)
        .inMinutes
        .clamp(0, 24 * 60);
    final pastEnd = _now
        .difference(_effective.endAt)
        .inMinutes
        .clamp(0, worked);
    final regular = worked - pastEnd;
    return Column(
      children: [
        _ConfirmHero(copy: _copy, teamName: widget.session.teamName ?? ''),
        _HoursSummary(
          copy: _copy,
          workedMinutes: worked,
          regularMinutes: regular,
          overtimeMinutes: pastEnd,
        ),
        const Spacer(),
        _EndActions(
          copy: _copy,
          submitting: _submitting,
          onEnd: _endShift,
          onNotYet: widget.onNotYet,
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.copy});
  final _ShiftCopy copy;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('b01-topbar'),
    height: DriverB01DefMetrics.topBarHeight,
    padding: const EdgeInsets.symmetric(
      horizontal: DriverB01DefMetrics.topBarPaddingHorizontal,
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
                fontSize: DriverB01DefMetrics.brandSize,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: DriverB01DefMetrics.brandTracking,
              ),
            ),
            Container(
              width: DriverB01DefMetrics.brandDotSize,
              height: DriverB01DefMetrics.brandDotSize,
              margin: const EdgeInsets.only(left: 3, bottom: 2),
              decoration: const BoxDecoration(
                color: RoundsColors.orange,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        SizedBox(
          width: DriverB01DefMetrics.notificationSize,
          height: DriverB01DefMetrics.notificationSize,
          child: IconButton(
            tooltip: copy.notifications,
            onPressed: null,
            icon: const Icon(Icons.notifications_none),
            iconSize: DriverB01DefMetrics.notificationIconSize,
          ),
        ),
      ],
    ),
  );
}

class _EndingHero extends StatelessWidget {
  const _EndingHero({
    required this.copy,
    required this.overtime,
    required this.minutes,
    required this.endLocal,
    required this.teamName,
  });
  final _ShiftCopy copy;
  final bool overtime;
  final int minutes;
  final String endLocal;
  final String teamName;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('b01-ending-hero'),
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(
      DriverB01DefMetrics.endingPaddingHorizontal,
      copy.thai
          ? DriverB01DefMetrics.thaiEndingPaddingTop
          : DriverB01DefMetrics.englishEndingPaddingTop,
      DriverB01DefMetrics.endingPaddingHorizontal,
      copy.thai
          ? DriverB01DefMetrics.thaiEndingPaddingBottom
          : DriverB01DefMetrics.englishEndingPaddingBottom,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: DriverB01DefMetrics.endingStateDotSize,
              height: DriverB01DefMetrics.endingStateDotSize,
              decoration: BoxDecoration(
                color: _amber,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _amberSoft,
                    spreadRadius: DriverB01DefMetrics.endingStateHalo,
                  ),
                ],
              ),
            ),
            const SizedBox(width: DriverB01DefMetrics.endingStateGap),
            Text(
              overtime ? copy.overtime : copy.endingSoon,
              style: TextStyle(
                color: _amber,
                fontSize: copy.thai
                    ? DriverB01DefMetrics.thaiEndingStateSize
                    : DriverB01DefMetrics.englishEndingStateSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: DriverB01DefMetrics.endingTitleTop),
        Text(
          overtime ? copy.overtimeTitle(minutes) : copy.endingTitle(minutes),
          style: TextStyle(
            color: RoundsColors.ink,
            fontSize: copy.thai
                ? DriverB01DefMetrics.thaiEndingTitleSize
                : DriverB01DefMetrics.englishEndingTitleSize,
            height: copy.thai
                ? DriverB01DefMetrics.thaiEndingTitleHeight
                : DriverB01DefMetrics.englishEndingTitleHeight,
            fontWeight: copy.thai ? FontWeight.w800 : FontWeight.w900,
            letterSpacing: copy.thai
                ? 0
                : DriverB01DefMetrics.englishEndingTitleTracking,
          ),
        ),
        const SizedBox(height: DriverB01DefMetrics.endingSublineTop),
        Text(
          overtime
              ? copy.shiftEnded(endLocal, teamName)
              : copy.endsAt(endLocal, teamName),
          style: TextStyle(
            color: RoundsColors.inkSecondary,
            fontSize: copy.thai
                ? DriverB01DefMetrics.thaiEndingSublineSize
                : DriverB01DefMetrics.englishEndingSublineSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _ActiveDelivery extends StatelessWidget {
  const _ActiveDelivery({
    required this.copy,
    required this.overtime,
    required this.stop,
    required this.totalStops,
    required this.area,
    required this.eta,
    required this.etaDeltaMinutes,
  });
  final _ShiftCopy copy;
  final bool overtime;
  final DriverRoundStopModel stop;
  final int totalStops;
  final String area;
  final DateTime? eta;
  final int? etaDeltaMinutes;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('b01-current-delivery'),
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(
      DriverB01DefMetrics.deliveryPaddingHorizontal,
      copy.thai
          ? DriverB01DefMetrics.thaiDeliveryPaddingTop
          : DriverB01DefMetrics.englishDeliveryPaddingTop,
      DriverB01DefMetrics.deliveryPaddingHorizontal,
      copy.thai
          ? DriverB01DefMetrics.thaiDeliveryPaddingBottom
          : DriverB01DefMetrics.englishDeliveryPaddingBottom,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          copy.currentDelivery,
          style: TextStyle(
            color: RoundsColors.orange,
            fontSize: copy.thai
                ? DriverB01DefMetrics.thaiDeliveryLabelSize
                : DriverB01DefMetrics.englishDeliveryLabelSize,
            fontWeight: FontWeight.w800,
            letterSpacing: copy.thai ? 0 : 1,
          ),
        ),
        const SizedBox(height: DriverB01DefMetrics.deliveryLabelBottom),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.recipientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: RoundsColors.ink,
                      fontSize: copy.thai
                          ? DriverB01DefMetrics.thaiDestinationSize
                          : DriverB01DefMetrics.englishDestinationSize,
                      height: 1.04,
                      fontWeight: FontWeight.w800,
                      letterSpacing: copy.thai ? 0 : -1.1,
                    ),
                  ),
                  const SizedBox(height: DriverB01DefMetrics.deliverySubrowTop),
                  Text(
                    area,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RoundsColors.muted,
                      fontSize: DriverB01DefMetrics.deliveryAreaSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  eta == null ? '—' : _clockTime(eta!),
                  style: TextStyle(
                    color: RoundsColors.ink,
                    fontSize: copy.thai
                        ? DriverB01DefMetrics.thaiEtaSize
                        : DriverB01DefMetrics.englishEtaSize,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  copy.eta,
                  style: const TextStyle(
                    color: RoundsColors.muted,
                    fontSize: DriverB01DefMetrics.etaLabelSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: DriverB01DefMetrics.deliveryMetaTop),
        Container(
          padding: const EdgeInsets.only(
            top: DriverB01DefMetrics.deliveryMetaPaddingTop,
          ),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: RoundsColors.line)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                copy.lastDelivery(stop.sequence, totalStops),
                style: const TextStyle(
                  color: RoundsColors.inkSecondary,
                  fontSize: DriverB01DefMetrics.deliveryMetaSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                copy.routeTiming(overtime, etaDeltaMinutes),
                style: const TextStyle(
                  color: _amber,
                  fontSize: DriverB01DefMetrics.deliveryMetaSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TaskFooter extends StatelessWidget {
  const _TaskFooter({
    required this.copy,
    required this.teamName,
    required this.onMessage,
    required this.onCall,
    required this.onReturn,
  });
  final _ShiftCopy copy;
  final String teamName;
  final VoidCallback onMessage;
  final VoidCallback onCall;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(
      DriverB01DefMetrics.footerPaddingHorizontal,
      DriverB01DefMetrics.footerPaddingTop,
      DriverB01DefMetrics.footerPaddingHorizontal,
      DriverB01DefMetrics.footerPaddingBottom,
    ),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: RoundsColors.line)),
    ),
    child: Column(
      children: [
        SizedBox(
          height: DriverB01DefMetrics.footerUtilityHeight,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      copy.dispatch,
                      style: const TextStyle(
                        color: RoundsColors.muted,
                        fontSize: DriverB01DefMetrics.dispatchLabelSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      teamName,
                      style: const TextStyle(
                        color: RoundsColors.ink,
                        fontSize: DriverB01DefMetrics.dispatchNameSize,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _UtilityButton(
                tooltip: copy.messageDispatch,
                icon: Icons.chat_bubble_outline,
                onPressed: onMessage,
              ),
              const SizedBox(width: DriverB01DefMetrics.footerActionGap),
              _UtilityButton(
                tooltip: copy.callDispatch,
                icon: Icons.phone_outlined,
                onPressed: onCall,
              ),
            ],
          ),
        ),
        const SizedBox(height: DriverB01DefMetrics.footerUtilityBottom),
        SizedBox(
          key: const Key('b01-return-to-delivery'),
          width: double.infinity,
          height: DriverB01DefMetrics.footerPrimaryHeight,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: RoundsColors.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  DriverB01DefMetrics.footerPrimaryRadius,
                ),
              ),
            ),
            onPressed: onReturn,
            icon: const Icon(Icons.near_me_outlined, size: 20),
            label: Text(
              copy.returnToDelivery,
              style: TextStyle(
                fontSize: copy.thai
                    ? DriverB01DefMetrics.thaiFooterPrimarySize
                    : DriverB01DefMetrics.englishFooterPrimarySize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _UtilityButton extends StatelessWidget {
  const _UtilityButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: DriverB01DefMetrics.footerActionSize,
    height: DriverB01DefMetrics.footerActionSize,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        side: const BorderSide(color: RoundsColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      onPressed: onPressed,
      child: Tooltip(
        message: tooltip,
        child: Icon(
          icon,
          size: DriverB01DefMetrics.footerActionIconSize,
          color: RoundsColors.inkSecondary,
        ),
      ),
    ),
  );
}

class _ConfirmHero extends StatelessWidget {
  const _ConfirmHero({required this.copy, required this.teamName});
  final _ShiftCopy copy;
  final String teamName;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('b01-confirm-hero'),
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(
      DriverB01DefMetrics.confirmPaddingHorizontal,
      copy.thai
          ? DriverB01DefMetrics.thaiConfirmPaddingTop
          : DriverB01DefMetrics.englishConfirmPaddingTop,
      DriverB01DefMetrics.confirmPaddingHorizontal,
      copy.thai
          ? DriverB01DefMetrics.thaiConfirmPaddingBottom
          : DriverB01DefMetrics.englishConfirmPaddingBottom,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: DriverB01DefMetrics.confirmStateMarkSize,
              height: DriverB01DefMetrics.confirmStateMarkSize,
              decoration: const BoxDecoration(
                color: Color(0xFFEDF8F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: DriverB01DefMetrics.confirmStateIconSize,
                color: RoundsColors.green,
              ),
            ),
            const SizedBox(width: DriverB01DefMetrics.confirmStateGap),
            Text(
              copy.lastDeliveryComplete,
              style: TextStyle(
                color: RoundsColors.green,
                fontSize: copy.thai
                    ? DriverB01DefMetrics.thaiConfirmStateSize
                    : DriverB01DefMetrics.englishConfirmStateSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: DriverB01DefMetrics.confirmTitleTop),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: copy.thai ? 353 : 330),
          child: Text(
            copy.readyToEnd,
            maxLines: copy.thai ? 1 : 2,
            style: TextStyle(
              color: RoundsColors.ink,
              fontSize: copy.thai
                  ? DriverB01DefMetrics.thaiConfirmTitleSize
                  : DriverB01DefMetrics.englishConfirmTitleSize,
              height: copy.thai
                  ? DriverB01DefMetrics.thaiConfirmTitleHeight
                  : DriverB01DefMetrics.englishConfirmTitleHeight,
              fontWeight: copy.thai ? FontWeight.w800 : FontWeight.w900,
              letterSpacing: copy.thai
                  ? 0
                  : DriverB01DefMetrics.englishConfirmTitleTracking,
            ),
          ),
        ),
        const SizedBox(height: DriverB01DefMetrics.confirmShiftTop),
        Text(
          teamName,
          style: TextStyle(
            color: RoundsColors.inkSecondary,
            fontSize: copy.thai
                ? DriverB01DefMetrics.thaiConfirmShiftSize
                : DriverB01DefMetrics.englishConfirmShiftSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _HoursSummary extends StatelessWidget {
  const _HoursSummary({
    required this.copy,
    required this.workedMinutes,
    required this.regularMinutes,
    required this.overtimeMinutes,
  });
  final _ShiftCopy copy;
  final int workedMinutes;
  final int regularMinutes;
  final int overtimeMinutes;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('b01-hours'),
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(
      DriverB01DefMetrics.hoursPaddingHorizontal,
      copy.thai
          ? DriverB01DefMetrics.thaiHoursPaddingTop
          : DriverB01DefMetrics.hoursPaddingTop,
      DriverB01DefMetrics.hoursPaddingHorizontal,
      copy.thai
          ? DriverB01DefMetrics.thaiHoursPaddingBottom
          : DriverB01DefMetrics.hoursPaddingBottom,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          copy.today,
          style: const TextStyle(
            color: RoundsColors.muted,
            fontSize: DriverB01DefMetrics.hoursLabelSize,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: DriverB01DefMetrics.hoursLabelBottom),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              copy.duration(workedMinutes),
              style: TextStyle(
                color: RoundsColors.ink,
                fontSize: copy.thai
                    ? DriverB01DefMetrics.thaiHoursTotalSize
                    : DriverB01DefMetrics.englishHoursTotalSize,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: copy.thai ? 0 : -2.2,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                copy.onTheClock,
                style: const TextStyle(
                  color: RoundsColors.muted,
                  fontSize: DriverB01DefMetrics.hoursCaptionSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: DriverB01DefMetrics.breakdownTop),
        Container(
          padding: const EdgeInsets.only(
            top: DriverB01DefMetrics.breakdownPaddingTop,
          ),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: RoundsColors.line)),
          ),
          child: Column(
            children: [
              _HourRow(
                label: copy.regular,
                value: copy.duration(regularMinutes),
              ),
              const SizedBox(height: DriverB01DefMetrics.breakdownGap),
              _HourRow(
                label: copy.overtimeLabel,
                value: copy.shortDuration(overtimeMinutes),
                overtime: true,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HourRow extends StatelessWidget {
  const _HourRow({
    required this.label,
    required this.value,
    this.overtime = false,
  });
  final String label;
  final String value;
  final bool overtime;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          color: overtime ? _amber : RoundsColors.inkSecondary,
          fontSize: DriverB01DefMetrics.hoursRowSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          color: overtime ? _amber : RoundsColors.ink,
          fontSize: DriverB01DefMetrics.hoursValueSize,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _EndActions extends StatelessWidget {
  const _EndActions({
    required this.copy,
    required this.submitting,
    required this.onEnd,
    required this.onNotYet,
  });
  final _ShiftCopy copy;
  final bool submitting;
  final VoidCallback onEnd;
  final VoidCallback? onNotYet;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(
      DriverB01DefMetrics.actionsPaddingHorizontal,
      DriverB01DefMetrics.actionsPaddingTop,
      DriverB01DefMetrics.actionsPaddingHorizontal,
      DriverB01DefMetrics.actionsPaddingBottom,
    ),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: RoundsColors.line)),
    ),
    child: Column(
      children: [
        SizedBox(
          key: const Key('b01-end-shift'),
          width: double.infinity,
          height: DriverB01DefMetrics.actionsPrimaryHeight,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: RoundsColors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  DriverB01DefMetrics.actionsPrimaryRadius,
                ),
              ),
            ),
            onPressed: submitting ? null : onEnd,
            icon: submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, size: 20),
            label: Text(
              copy.endShift,
              style: TextStyle(
                fontSize: copy.thai
                    ? DriverB01DefMetrics.thaiActionsPrimarySize
                    : DriverB01DefMetrics.englishActionsPrimarySize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: DriverB01DefMetrics.actionsSecondaryTop),
        SizedBox(
          width: double.infinity,
          height: DriverB01DefMetrics.actionsSecondaryHeight,
          child: TextButton(
            onPressed: onNotYet,
            child: Text(
              copy.notYet,
              style: const TextStyle(
                color: RoundsColors.inkSecondary,
                fontSize: DriverB01DefMetrics.actionsSecondarySize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.copy});
  final _ShiftCopy copy;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('b01-bottom-nav'),
    height: DriverB01DefMetrics.bottomNavHeight,
    padding: const EdgeInsets.fromLTRB(4, 7, 4, 9),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      children: [
        _NavItem(icon: Icons.home_outlined, label: copy.home, active: true),
        _NavItem(icon: Icons.location_on_outlined, label: copy.jobs),
        _NavItem(icon: Icons.schedule, label: copy.hours),
        _NavItem(icon: Icons.person_outline, label: copy.profile),
      ],
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: DriverB01DefMetrics.bottomNavIconSize,
          color: active ? RoundsColors.orange : RoundsColors.muted,
        ),
        const SizedBox(height: DriverB01DefMetrics.bottomNavGap),
        Text(
          label,
          style: TextStyle(
            color: active ? RoundsColors.orange : RoundsColors.muted,
            fontSize: Localizations.localeOf(context).languageCode == 'th'
                ? DriverB01DefMetrics.thaiBottomNavLabelSize
                : DriverB01DefMetrics.englishBottomNavLabelSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ShiftCopy {
  const _ShiftCopy(this.thai);
  final bool thai;

  String get notifications => thai ? 'การแจ้งเตือน' : 'Notifications';
  String get endingSoon => thai ? 'กะใกล้จบ' : 'Shift ending soon';
  String get overtime => thai ? 'เกินเวลากะ' : 'Shift overtime';
  String endingTitle(int minutes) =>
      thai ? 'เหลือ $minutes นาที' : '$minutes min left';
  String overtimeTitle(int minutes) =>
      thai ? '+$minutes นาที' : '+$minutes min';
  String endsAt(String time, String team) =>
      thai ? 'กะสิ้นสุด $time · $team' : 'Ends at $time · $team';
  String shiftEnded(String time, String team) =>
      thai ? 'กะสิ้นสุด $time · $team' : 'Shift ended $time · $team';
  String get currentDelivery => thai ? 'งานปัจจุบัน' : 'CURRENT DELIVERY';
  String get eta => thai ? 'ถึงประมาณ' : 'ETA';
  String lastDelivery(int sequence, int total) => thai
      ? 'งานสุดท้าย · $sequence/$total'
      : 'Last delivery · $sequence of $total';
  String routeTiming(bool overtime, int? minutes) {
    if (minutes == null) return thai ? 'ไม่มี ETA' : 'ETA unavailable';
    final safe = minutes.clamp(0, 999);
    if (overtime) return thai ? 'เหลือ $safe นาที' : '$safe min remaining';
    return thai ? 'เกินกะ $safe นาที' : '$safe min past shift';
  }

  String get dispatch => thai ? 'ฝ่ายจัดงาน' : 'Dispatch';
  String get messageDispatch =>
      thai ? 'ส่งข้อความถึงฝ่ายจัดงาน' : 'Message dispatch';
  String get callDispatch => thai ? 'โทรหาฝ่ายจัดงาน' : 'Call dispatch';
  String get returnToDelivery => thai ? 'กลับไปส่งงาน' : 'Return to delivery';
  String get lastDeliveryComplete =>
      thai ? 'ส่งงานสุดท้ายแล้ว' : 'Last delivery complete';
  String get readyToEnd => thai ? 'พร้อมจบกะไหม?' : 'Ready to end shift?';
  String get today => thai ? 'วันนี้' : 'TODAY';
  String get onTheClock => thai ? 'เวลาทำงานทั้งหมด' : 'On the clock';
  String get regular => thai ? 'เวลาปกติ' : 'Regular';
  String get overtimeLabel => thai ? 'ล่วงเวลา' : 'Overtime';
  String duration(int minutes) {
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return thai
        ? '$hours ชม. ${remainder.toString().padLeft(2, '0')} นาที'
        : '${hours}h ${remainder.toString().padLeft(2, '0')}m';
  }

  String shortDuration(int minutes) => thai ? '$minutes นาที' : '${minutes}m';
  String get endShift => thai ? 'จบกะ' : 'End shift';
  String get notYet => thai ? 'ยังไม่จบกะ' : 'Not yet';
  String get endFailed =>
      thai ? 'ไม่สามารถจบกะได้' : 'Shift could not be ended';
  String get home => thai ? 'หน้าแรก' : 'Home';
  String get jobs => thai ? 'งาน' : 'Jobs';
  String get hours => thai ? 'ชั่วโมง' : 'Hours';
  String get profile => thai ? 'โปรไฟล์' : 'Profile';
}

String _clockTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

const _amber = Color(0xFFB87916);
const _amberSoft = Color(0xFFFFF8E8);
