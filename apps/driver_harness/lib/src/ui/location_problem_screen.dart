import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_api.dart';
import '../driver/driver_session.dart';
import '../permissions/driver_permissions_screen.dart';
import '../permissions/location_access.dart';
import 'components/rounds_action_drawer.dart';
import 'operations_chat_screen.dart';
import 'call_contact_screen.dart';

class DriverLocationEvidence {
  const DriverLocationEvidence({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
}

typedef DriverLocationProvider = Future<DriverLocationEvidence> Function();
typedef LocationProblemLauncher = Future<bool> Function(Uri uri);

enum LocationProblemContext { pickup, delivery }

class LocationProblemScreen extends StatefulWidget {
  const LocationProblemScreen({
    required this.controller,
    required this.round,
    required this.stop,
    required this.problemContext,
    this.locationProvider = _currentLocation,
    this.launcher = _launchExternal,
    super.key,
  });

  final HarnessAppController controller;
  final DriverRoundModel round;
  final DriverRoundStopModel stop;
  final LocationProblemContext problemContext;
  final DriverLocationProvider locationProvider;
  final LocationProblemLauncher launcher;

  @override
  State<LocationProblemScreen> createState() => _LocationProblemScreenState();
}

enum _LocationProblemState { problem, waiting }

class _LocationProblemScreenState extends State<LocationProblemScreen> {
  _LocationProblemState _state = _LocationProblemState.problem;
  bool _submitting = false;
  bool _savedLocally = false;
  String _oldPoint = '';
  String _newPoint = '';
  bool _usedLocation = false;

  bool get _pickup => widget.problemContext == LocationProblemContext.pickup;

  String get _contextName =>
      _pickup ? widget.round.pickup.displayName : widget.stop.recipientName;

  String get _address =>
      _pickup ? widget.round.pickup.rawAddress : widget.stop.rawAddress;

  String get _currentPoint {
    if (_pickup) return widget.round.pickup.displayName;
    final access = widget.stop.accessNote?.trim();
    return access == null || access.isEmpty
        ? 'Current destination pin'
        : access;
  }

  double get _expectedLatitude =>
      _pickup ? widget.round.pickup.latitude! : widget.stop.latitude;

  double get _expectedLongitude =>
      _pickup ? widget.round.pickup.longitude! : widget.stop.longitude;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width <
        DriverReferenceViewport.compactBreakpoint;
    return Scaffold(
      backgroundColor: RoundsColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _LocationProblemTopBar(
              sequence: widget.stop.sequence,
              stopCount: widget.round.stops.length,
              name: _contextName,
              compact: compact,
              onBack: () => Navigator.of(context).pop(),
              onMore: _openMore,
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('location-problem-content'),
                padding: EdgeInsets.fromLTRB(
                  compact
                      ? DriverG02Metrics.compactContentPaddingHorizontal
                      : DriverG02Metrics.contentPaddingHorizontal,
                  compact
                      ? DriverG02Metrics.compactContentPaddingTop
                      : DriverG02Metrics.contentPaddingTop,
                  compact
                      ? DriverG02Metrics.compactContentPaddingHorizontal
                      : DriverG02Metrics.contentPaddingHorizontal,
                  DriverG02Metrics.contentPaddingBottom,
                ),
                child: _state == _LocationProblemState.problem
                    ? _problemBody(compact)
                    : _waitingBody(compact),
              ),
            ),
            _footer(compact),
          ],
        ),
      ),
    );
  }

  Widget _problemBody(bool compact) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _StateKicker(
        key: Key('location-problem-kicker'),
        label: 'Delivery problem',
        color: RoundsColors.red,
      ),
      SizedBox(height: DriverG02Metrics.heroGap),
      Text(
        'Location problem',
        key: const Key('location-problem-title'),
        style: TextStyle(
          color: RoundsColors.ink,
          fontSize: compact
              ? DriverG02Metrics.compactHeroSize
              : DriverG02Metrics.heroSize,
          height: DriverG02Metrics.heroHeight,
          fontWeight: FontWeight.w900,
          letterSpacing: DriverG02Metrics.heroTracking,
        ),
      ),
      SizedBox(height: DriverG02Metrics.locationGap),
      Text(
        _address,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: RoundsColors.muted,
          fontSize: DriverG02Metrics.locationSize,
          height: DriverG02Metrics.locationHeight,
          fontWeight: FontWeight.w700,
        ),
      ),
      SizedBox(height: DriverG02Metrics.contextGap),
      Container(
        padding: const EdgeInsets.only(top: DriverG02Metrics.contextPaddingTop),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: RoundsColors.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SmallLabel('Current stop'),
                  const SizedBox(height: 6),
                  Text(
                    _currentPoint,
                    style: const TextStyle(
                      color: RoundsColors.ink,
                      fontSize: 20,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _pickup
                        ? 'Pickup pin supplied by Operations'
                        : 'Pin is set at the operational destination',
                    style: const TextStyle(
                      color: RoundsColors.muted,
                      fontSize: 13.5,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            _ManifestTag(stop: widget.stop),
          ],
        ),
      ),
      SizedBox(
        height: compact
            ? DriverG02Metrics.compactSectionGap
            : DriverG02Metrics.sectionGap,
      ),
      const _SmallLabel('What is wrong?'),
      const SizedBox(height: 7),
      const Divider(height: 1, color: RoundsColors.line),
      _ProblemChoice(
        label: 'Pin is wrong',
        icon: Icons.location_on_outlined,
        compact: compact,
        onTap: _openPinCorrection,
      ),
      _ProblemChoice(
        label: 'Entrance / access is wrong',
        icon: Icons.home_work_outlined,
        compact: compact,
        onTap: _openEntranceChoices,
      ),
      _ProblemChoice(
        label: 'Address is wrong',
        icon: Icons.article_outlined,
        compact: compact,
        onTap: _openAddressChoices,
      ),
      _ProblemChoice(
        label: "Can't find location",
        icon: Icons.search,
        compact: compact,
        onTap: _openFindChoices,
      ),
    ],
  );

  Widget _waitingBody(bool compact) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _StateKicker(
        key: const Key('location-problem-waiting-kicker'),
        label: _savedLocally ? 'Offline' : 'Location update',
        color: RoundsColors.orange,
      ),
      SizedBox(height: DriverG02Metrics.heroGap),
      Text(
        _savedLocally ? 'Saved locally' : 'Sent to Operations',
        key: const Key('location-problem-waiting-title'),
        style: TextStyle(
          color: RoundsColors.ink,
          fontSize: compact
              ? DriverG02Metrics.compactHeroSize
              : DriverG02Metrics.heroSize,
          height: DriverG02Metrics.heroHeight,
          fontWeight: FontWeight.w900,
          letterSpacing: DriverG02Metrics.heroTracking,
        ),
      ),
      SizedBox(height: DriverG02Metrics.locationGap),
      Text(
        _address,
        style: const TextStyle(
          color: RoundsColors.muted,
          fontSize: DriverG02Metrics.locationSize,
          height: DriverG02Metrics.locationHeight,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 28),
      Container(
        constraints: const BoxConstraints(minHeight: 70),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: RoundsColors.line),
            bottom: BorderSide(color: RoundsColors.line),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _ChangeSide(label: 'Current', value: _oldPoint),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                Icons.arrow_forward,
                color: RoundsColors.orange,
                size: 19,
              ),
            ),
            Expanded(
              child: _ChangeSide(label: 'Proposed', value: _newPoint),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      _SmallLabel(_savedLocally ? 'Offline' : 'Operations review'),
      const SizedBox(height: 7),
      Text(
        _savedLocally ? 'Waiting to sync' : 'Waiting for confirmation',
        style: const TextStyle(
          color: RoundsColors.ink,
          fontSize: 24,
          height: 1.05,
          fontWeight: FontWeight.w900,
          letterSpacing: -.84,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        _savedLocally
            ? 'The report will send when Rounds reconnects.'
            : _usedLocation
            ? 'Your current position was attached automatically.'
            : 'Operations has the structured location report.',
        style: const TextStyle(
          color: RoundsColors.muted,
          fontSize: 13.5,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _footer(bool compact) {
    final horizontal = compact
        ? DriverG02Metrics.compactFooterPaddingHorizontal
        : DriverG02Metrics.footerPaddingHorizontal;
    return Container(
      key: const Key('location-problem-footer'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        horizontal,
        DriverG02Metrics.footerPaddingTop,
        horizontal,
        DriverG02Metrics.footerPaddingBottom,
      ),
      decoration: const BoxDecoration(
        color: RoundsColors.surface,
        border: Border(top: BorderSide(color: RoundsColors.line)),
      ),
      child: _state == _LocationProblemState.problem
          ? SizedBox(
              height: compact
                  ? DriverG02Metrics.compactSecondaryHeight
                  : DriverG02Metrics.secondaryHeight,
              child: TextButton(
                key: const Key('location-problem-call'),
                onPressed: _callContact,
                child: Text(_pickup ? 'Call pickup' : 'Call recipient'),
              ),
            )
          : SizedBox(
              height: compact
                  ? DriverG02Metrics.compactPrimaryHeight
                  : DriverG02Metrics.primaryHeight,
              child: FilledButton(
                key: const Key('location-problem-waiting'),
                onPressed: null,
                style: FilledButton.styleFrom(
                  disabledBackgroundColor: const Color(0xFFE0E5E9),
                  disabledForegroundColor: const Color(0xFF8E99A7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      DriverG02Metrics.primaryRadius,
                    ),
                  ),
                ),
                child: Text(
                  _savedLocally ? 'Waiting to sync' : 'Waiting for Operations',
                ),
              ),
            ),
    );
  }

  Future<void> _openPinCorrection() async {
    final evidence = await _readLocation();
    if (evidence == null || !mounted) return;
    final send = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: RoundsColors.ink.withValues(alpha: .38),
      builder: (_) => _CorrectPinSheet(
        expectedLatitude: _expectedLatitude,
        expectedLongitude: _expectedLongitude,
        evidence: evidence,
      ),
    );
    if (send == true && mounted) {
      await _submit(
        category: 'wrong_pin',
        label: 'Pin correction',
        oldPoint: _currentPoint,
        newPoint: 'Current driver location',
        evidence: evidence,
      );
    }
  }

  Future<void> _openEntranceChoices() async {
    final choice = await _showChoiceSheet(
      title: 'Entrance / access',
      choices: const [
        _SheetChoice('Wrong entrance', Icons.home_work_outlined),
        _SheetChoice('Access closed', Icons.block_outlined),
        _SheetChoice('Better driveway', Icons.route_outlined),
        _SheetChoice('Different building', Icons.apartment_outlined),
      ],
    );
    if (choice == null || !mounted) return;
    final evidence = await _readLocation();
    if (evidence == null || !mounted) return;
    await _submit(
      category: 'wrong_entrance',
      label: choice,
      oldPoint: _currentPoint,
      newPoint: choice == 'Access closed'
          ? 'Alternative access near driver'
          : choice == 'Different building'
          ? 'Building near driver'
          : 'Current entrance',
      evidence: evidence,
    );
  }

  Future<void> _openAddressChoices() async {
    final choice = await _showChoiceSheet(
      title: 'Address problem',
      choices: const [
        _SheetChoice('Written address is wrong', Icons.article_outlined),
        _SheetChoice('Different building', Icons.apartment_outlined),
        _SheetChoice('Recipient gave new address', Icons.location_on_outlined),
      ],
    );
    if (choice == null || !mounted) return;
    final evidence = choice == 'Different building'
        ? await _readLocation()
        : null;
    if (choice == 'Different building' && evidence == null) return;
    if (!mounted) return;
    await _submit(
      category: 'wrong_address',
      label: choice,
      oldPoint: _currentPoint,
      newPoint: choice == 'Recipient gave new address'
          ? 'New recipient address'
          : choice == 'Different building'
          ? 'Building near driver'
          : 'Operations correction',
      evidence: evidence,
    );
  }

  Future<void> _openFindChoices() async {
    final choice = await _showChoiceSheet(
      title: "Can't find location",
      choices: const [
        _SheetChoice('Call recipient', Icons.call_outlined),
        _SheetChoice('Send my location', Icons.location_on_outlined),
        _SheetChoice('Contact Operations', Icons.chat_bubble_outline),
      ],
    );
    if (choice == null || !mounted) return;
    if (choice == 'Call recipient') {
      await _callContact();
      return;
    }
    if (choice == 'Contact Operations') {
      await _openChat();
      return;
    }
    final evidence = await _readLocation();
    if (evidence == null || !mounted) return;
    await _submit(
      category: 'cannot_find_location',
      label: "Can't find location",
      oldPoint: _currentPoint,
      newPoint: 'Current driver location',
      evidence: evidence,
    );
  }

  Future<String?> _showChoiceSheet({
    required String title,
    required List<_SheetChoice> choices,
  }) => showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: RoundsColors.ink.withValues(alpha: .38),
    builder: (_) => _LocationChoiceSheet(title: title, choices: choices),
  );

  Future<DriverLocationEvidence?> _readLocation() async {
    try {
      return await widget.locationProvider();
    } catch (error) {
      if (error is DriverLocationAccessException && mounted) {
        await showLocationPermissionRecovery(context, error);
        return null;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const Key('location-problem-gps-error'),
            content: Text('Current location is unavailable: $error'),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _submit({
    required String category,
    required String label,
    required String oldPoint,
    required String newPoint,
    DriverLocationEvidence? evidence,
  }) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final outcome = await widget.controller.reportLocationProblem(
      stop: widget.stop,
      stage: _pickup ? 'pickup' : 'delivery',
      category: category,
      detail: label,
      position: evidence == null
          ? null
          : {
              'latitude': evidence.latitude,
              'longitude': evidence.longitude,
              'accuracyMeters': evidence.accuracyMeters,
              'source': 'rounds_os',
            },
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (outcome == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('location-problem-send-error'),
          content: Text(
            widget.controller.driverError ?? 'Location report was not saved',
          ),
        ),
      );
      return;
    }
    setState(() {
      _state = _LocationProblemState.waiting;
      _savedLocally =
          outcome.disposition == DriverCommandDisposition.pendingSync;
      _oldPoint = oldPoint;
      _newPoint = newPoint;
      _usedLocation = evidence != null;
    });
  }

  Future<void> _openMore() async {
    final action = await showRoundsActionDrawer(
      context,
      title: 'Stop actions',
      actions: [
        RoundsDrawerAction(
          value: 'call',
          label: _pickup ? 'Call pickup' : 'Call recipient',
          icon: Icons.call_outlined,
        ),
        const RoundsDrawerAction(
          value: 'message',
          label: 'Message Operations',
          icon: Icons.chat_bubble_outline,
        ),
        const RoundsDrawerAction(
          value: 'return',
          label: 'Return to navigation',
          icon: Icons.arrow_back,
        ),
      ],
      showCancel: false,
    );
    if (!mounted || action == null) return;
    if (action == 'call') await _callContact();
    if (action == 'message') await _openChat();
    if (action == 'return' && mounted) Navigator.of(context).pop();
  }

  Future<void> _openChat() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => OperationsChatScreen(
        controller: widget.controller,
        round: widget.round,
        stop: widget.stop,
      ),
    ),
  );

  Future<void> _callContact() async {
    if (!_pickup) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => CallContactScreen(
            controller: widget.controller,
            round: widget.round,
            stop: widget.stop,
            target: CallContactTarget.recipient,
            launcher: widget.launcher,
          ),
        ),
      );
      return;
    }
    final phone = _pickup
        ? widget.round.pickup.contactPhone.trim()
        : widget.stop.recipientPhone.trim();
    final opened =
        phone.isNotEmpty &&
        await widget.launcher(Uri(scheme: 'tel', path: phone));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The phone app could not be opened.')),
      );
    }
  }
}

class _LocationProblemTopBar extends StatelessWidget {
  const _LocationProblemTopBar({
    required this.sequence,
    required this.stopCount,
    required this.name,
    required this.compact,
    required this.onBack,
    required this.onMore,
  });

  final int sequence;
  final int stopCount;
  final String name;
  final bool compact;
  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('location-problem-topbar'),
    height: DriverG02Metrics.topBarHeight,
    padding: const EdgeInsets.symmetric(
      horizontal: DriverG02Metrics.topBarPaddingHorizontal,
    ),
    decoration: const BoxDecoration(
      color: RoundsColors.surface,
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      children: [
        _TopButton(
          key: const Key('location-problem-back'),
          icon: Icons.arrow_back,
          tooltip: 'Back',
          onPressed: onBack,
        ),
        const SizedBox(width: DriverG02Metrics.topColumnGap),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STOP $sequence OF $stopCount',
                style: const TextStyle(
                  color: RoundsColors.orange,
                  fontSize: DriverG02Metrics.topKickerSize,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: DriverG02Metrics.topKickerTracking,
                ),
              ),
              const SizedBox(height: DriverG02Metrics.topTitleGap),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RoundsColors.ink,
                  fontSize: DriverG02Metrics.topTitleSize,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: DriverG02Metrics.topTitleTracking,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: DriverG02Metrics.topColumnGap),
        _TopButton(
          key: const Key('location-problem-more'),
          icon: Icons.more_horiz,
          tooltip: 'More actions',
          onPressed: onMore,
        ),
      ],
    ),
  );
}

class _TopButton extends StatelessWidget {
  const _TopButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: DriverG02Metrics.topButtonSize,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DriverG02Metrics.topButtonRadius),
        ),
      ),
      icon: Icon(icon, size: DriverG02Metrics.topIconSize),
    ),
  );
}

class _StateKicker extends StatelessWidget {
  const _StateKicker({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: DriverG02Metrics.issueDotSize,
        height: DriverG02Metrics.issueDotSize,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: DriverG02Metrics.issueSize,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: DriverG02Metrics.issueTracking,
        ),
      ),
    ],
  );
}

class _SmallLabel extends StatelessWidget {
  const _SmallLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      color: RoundsColors.muted,
      fontSize: 10.5,
      height: 1,
      fontWeight: FontWeight.w800,
      letterSpacing: .89,
    ),
  );
}

class _ManifestTag extends StatelessWidget {
  const _ManifestTag({required this.stop});
  final DriverRoundStopModel stop;

  @override
  Widget build(BuildContext context) {
    final item = stop.manifestItems.firstOrNull;
    final label = item?.handlingNote?.trim().isNotEmpty ?? false
        ? item!.handlingNote!.trim()
        : item?.description ?? 'Delivery';
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: RoundsColors.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: RoundsColors.inkSecondary,
                fontSize: 12.5,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProblemChoice extends StatelessWidget {
  const _ProblemChoice({
    required this.label,
    required this.icon,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key(
      'location-problem-${label.toLowerCase().replaceAll(RegExp(r"[^a-z]+"), "-").replaceAll(RegExp(r"-+$"), "")}',
    ),
    onTap: onTap,
    child: Container(
      constraints: BoxConstraints(
        minHeight: compact
            ? DriverG02Metrics.compactChoiceHeight
            : DriverG02Metrics.choiceHeight,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: RoundsColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: compact
                ? DriverG02Metrics.compactChoiceIconColumn
                : DriverG02Metrics.choiceIconColumn,
            child: Icon(
              icon,
              color: RoundsColors.inkSecondary,
              size: compact
                  ? DriverG02Metrics.compactChoiceIconSize
                  : DriverG02Metrics.choiceIconSize,
            ),
          ),
          SizedBox(
            width: compact
                ? DriverG02Metrics.compactChoiceColumnGap
                : DriverG02Metrics.choiceColumnGap,
          ),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: RoundsColors.ink,
                fontSize: compact
                    ? DriverG02Metrics.compactChoiceTitleSize
                    : DriverG02Metrics.choiceTitleSize,
                height: DriverG02Metrics.choiceTitleHeight,
                fontWeight: FontWeight.w800,
                letterSpacing: DriverG02Metrics.choiceTitleTracking,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: RoundsColors.muted, size: 18),
          const SizedBox(width: 4),
        ],
      ),
    ),
  );
}

class _ChangeSide extends StatelessWidget {
  const _ChangeSide({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SmallLabel(label),
      const SizedBox(height: 6),
      Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: RoundsColors.ink,
          fontSize: 14.5,
          height: 1.25,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _SheetChoice {
  const _SheetChoice(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _LocationChoiceSheet extends StatelessWidget {
  const _LocationChoiceSheet({required this.title, required this.choices});
  final String title;
  final List<_SheetChoice> choices;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width <
        DriverReferenceViewport.compactBreakpoint;
    final inset = compact
        ? DriverG02Metrics.compactSheetInset
        : DriverG02Metrics.sheetInset;
    final horizontal = compact
        ? DriverG02Metrics.compactSheetHeadPaddingHorizontal
        : DriverG02Metrics.sheetHeadPaddingHorizontal;
    return Padding(
      padding: EdgeInsets.all(inset),
      child: Material(
        key: const Key('location-problem-choice-sheet'),
        color: RoundsColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: RoundsColors.lineStrong),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(DriverG02Metrics.sheetRadiusTop),
            topRight: const Radius.circular(DriverG02Metrics.sheetRadiusTop),
            bottomLeft: const Radius.circular(
              DriverG02Metrics.sheetRadiusBottom,
            ),
            bottomRight: const Radius.circular(
              DriverG02Metrics.sheetRadiusBottom,
            ),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: DriverG02Metrics.sheetHandleHeight,
              child: Center(
                child: Container(
                  width: DriverG02Metrics.sheetHandleWidth,
                  height: DriverG02Metrics.sheetHandleThickness,
                  decoration: BoxDecoration(
                    color: RoundsColors.lineStrong,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                0,
                horizontal,
                DriverG02Metrics.sheetHeadPaddingBottom,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: TextStyle(
                    color: RoundsColors.ink,
                    fontSize: compact
                        ? DriverG02Metrics.compactSheetTitleSize
                        : DriverG02Metrics.sheetTitleSize,
                    height: 1.02,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.92,
                  ),
                ),
              ),
            ),
            for (final choice in choices)
              InkWell(
                key: Key(
                  'location-sheet-${choice.label.toLowerCase().replaceAll(RegExp(r"[^a-z]+"), "-").replaceAll(RegExp(r"-+$"), "")}',
                ),
                onTap: () => Navigator.of(context).pop(choice.label),
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: compact
                        ? DriverG02Metrics.compactSheetRowHeight
                        : DriverG02Metrics.sheetRowHeight,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact
                        ? DriverG02Metrics.compactSheetRowPaddingHorizontal
                        : DriverG02Metrics.sheetRowPaddingHorizontal,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: RoundsColors.line)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        child: Icon(
                          choice.icon,
                          size: DriverG02Metrics.sheetRowIconSize,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          choice.label,
                          style: TextStyle(
                            color: RoundsColors.ink,
                            fontSize: compact
                                ? DriverG02Metrics.compactSheetRowSize
                                : DriverG02Metrics.sheetRowSize,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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
}

class _CorrectPinSheet extends StatelessWidget {
  const _CorrectPinSheet({
    required this.expectedLatitude,
    required this.expectedLongitude,
    required this.evidence,
  });

  final double expectedLatitude;
  final double expectedLongitude;
  final DriverLocationEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width <
        DriverReferenceViewport.compactBreakpoint;
    final inset = compact
        ? DriverG02Metrics.compactSheetInset
        : DriverG02Metrics.sheetInset;
    return Padding(
      padding: EdgeInsets.all(inset),
      child: Material(
        key: const Key('location-problem-pin-sheet'),
        color: RoundsColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: RoundsColors.lineStrong),
          borderRadius: BorderRadius.circular(DriverG02Metrics.sheetRadiusTop),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: DriverG02Metrics.sheetHandleHeight,
                child: Center(
                  child: Container(
                    width: DriverG02Metrics.sheetHandleWidth,
                    height: DriverG02Metrics.sheetHandleThickness,
                    decoration: BoxDecoration(
                      color: RoundsColors.lineStrong,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 13),
                child: Text(
                  'Correct pin',
                  style: TextStyle(
                    color: RoundsColors.ink,
                    fontSize: DriverG02Metrics.sheetTitleSize,
                    height: 1.02,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.92,
                  ),
                ),
              ),
              Container(
                key: const Key('location-problem-pin-evidence'),
                height: compact
                    ? DriverG02Metrics.compactSheetMapHeight
                    : DriverG02Metrics.sheetMapHeight,
                margin: const EdgeInsets.fromLTRB(18, 0, 18, 15),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F4F5),
                  border: Border.all(color: RoundsColors.line),
                  borderRadius: BorderRadius.circular(7),
                ),
                clipBehavior: Clip.antiAlias,
                child: CustomPaint(
                  painter: _PositionEvidencePainter(
                    expectedLatitude: expectedLatitude,
                    expectedLongitude: expectedLongitude,
                    actualLatitude: evidence.latitude,
                    actualLongitude: evidence.longitude,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              Text(
                'Current location · ±${evidence.accuracyMeters.round()} m',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RoundsColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 11),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: SizedBox(
                  height: 58,
                  child: FilledButton(
                    key: const Key('location-problem-send-current'),
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: RoundsColors.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    child: const Text('Send current location'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PositionEvidencePainter extends CustomPainter {
  const _PositionEvidencePainter({
    required this.expectedLatitude,
    required this.expectedLongitude,
    required this.actualLatitude,
    required this.actualLongitude,
  });

  final double expectedLatitude;
  final double expectedLongitude;
  final double actualLatitude;
  final double actualLongitude;

  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(-20, size.height * .55),
      Offset(size.width + 20, size.height * .35),
      road,
    );
    canvas.drawLine(
      Offset(size.width * .58, -20),
      Offset(size.width * .65, size.height + 20),
      road,
    );

    final longitudeScale = math.cos(expectedLatitude * math.pi / 180);
    final dx = (actualLongitude - expectedLongitude) * longitudeScale;
    final dy = actualLatitude - expectedLatitude;
    final magnitude = math.max(math.sqrt(dx * dx + dy * dy), .000001);
    final unitX = dx / magnitude;
    final unitY = dy / magnitude;
    final expected = Offset(size.width * .64, size.height * .31);
    final actual = Offset(
      (expected.dx + unitX * size.width * .23).clamp(32, size.width - 32),
      (expected.dy - unitY * size.height * .28).clamp(32, size.height - 32),
    );
    canvas.drawCircle(expected, 16, Paint()..color = Colors.white);
    canvas.drawCircle(expected, 12, Paint()..color = const Color(0xFF98A3AF));
    canvas.drawCircle(actual, 16, Paint()..color = Colors.white);
    canvas.drawCircle(actual, 12, Paint()..color = RoundsColors.orange);
    final connector = Paint()
      ..color = RoundsColors.orange.withValues(alpha: .55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(expected, actual, connector);
  }

  @override
  bool shouldRepaint(covariant _PositionEvidencePainter oldDelegate) =>
      expectedLatitude != oldDelegate.expectedLatitude ||
      expectedLongitude != oldDelegate.expectedLongitude ||
      actualLatitude != oldDelegate.actualLatitude ||
      actualLongitude != oldDelegate.actualLongitude;
}

Future<DriverLocationEvidence> _currentLocation() async {
  await requireOperationalLocationAccess();
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 12),
    ),
  );
  return DriverLocationEvidence(
    latitude: position.latitude,
    longitude: position.longitude,
    accuracyMeters: position.accuracy,
  );
}

Future<bool> _launchExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
