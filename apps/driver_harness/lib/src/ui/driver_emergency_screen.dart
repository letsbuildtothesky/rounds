import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../app/harness_app_controller.dart';
import '../driver/driver_api.dart';
import '../driver/driver_session.dart';
import '../permissions/location_access.dart';
import 'location_problem_screen.dart';

typedef DriverEmergencyLauncher = Future<bool> Function(Uri uri);

enum _EmergencyViewState { initial, safe, urgent }

class DriverEmergencyScreen extends StatefulWidget {
  const DriverEmergencyScreen({
    required this.controller,
    required this.round,
    required this.stop,
    this.locationProvider = _currentEmergencyLocation,
    this.launcher = _launchExternal,
    super.key,
  });

  final HarnessAppController controller;
  final DriverRoundModel round;
  final DriverRoundStopModel stop;
  final DriverLocationProvider locationProvider;
  final DriverEmergencyLauncher launcher;

  @override
  State<DriverEmergencyScreen> createState() => _DriverEmergencyScreenState();
}

class _DriverEmergencyScreenState extends State<DriverEmergencyScreen> {
  _EmergencyViewState _state = _EmergencyViewState.initial;
  DriverLocationEvidence? _location;
  bool _readingLocation = true;
  bool _submitting = false;
  bool _pendingSync = false;

  @override
  void initState() {
    super.initState();
    _captureLocation();
  }

  Future<void> _captureLocation() async {
    try {
      final location = await widget.locationProvider();
      if (mounted) setState(() => _location = location);
    } catch (_) {
      // Emergency reporting must never wait for location permission or GPS.
    } finally {
      if (mounted) setState(() => _readingLocation = false);
    }
  }

  Future<void> _report(String safetyStatus) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final evidence = _location;
    final outcome = await widget.controller.reportDriverEmergency(
      stop: widget.stop,
      safetyStatus: safetyStatus,
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
          key: const Key('driver-emergency-send-error'),
          content: Text(
            widget.controller.driverError ?? 'Emergency status was not saved.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _state = safetyStatus == 'urgent'
          ? _EmergencyViewState.urgent
          : _EmergencyViewState.safe;
      _pendingSync =
          outcome.disposition == DriverCommandDisposition.pendingSync;
    });
  }

  Future<void> _callOperations() async {
    final phone = widget.round.pickup.contactPhone.trim();
    final opened =
        phone.isNotEmpty &&
        await widget.launcher(Uri(scheme: 'tel', path: phone));
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The phone app could not be opened.')),
    );
  }

  Future<void> _openEmergencyAssistance() async {
    final number = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: RoundsColors.ink.withValues(alpha: .28),
      isDismissible: true,
      builder: (_) => const _EmergencyAssistanceSheet(),
    );
    if (number == null || !mounted) return;
    final opened = await widget.launcher(Uri(scheme: 'tel', path: number));
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The phone app could not be opened.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final submitted = _state != _EmergencyViewState.initial;
    return PopScope(
      canPop: submitted,
      child: Scaffold(
        backgroundColor: RoundsColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              _EmergencyTopBar(pendingSync: _pendingSync, submitted: submitted),
              Expanded(
                child: SingleChildScrollView(
                  key: const Key('driver-emergency-content'),
                  padding: const EdgeInsets.fromLTRB(
                    DriverG05Metrics.contentPaddingHorizontal,
                    DriverG05Metrics.contentPaddingTop,
                    DriverG05Metrics.contentPaddingHorizontal,
                    DriverG05Metrics.contentPaddingBottom,
                  ),
                  child: _state == _EmergencyViewState.initial
                      ? _InitialEmergencyBody(
                          readingLocation: _readingLocation,
                          hasLocation: _location != null,
                          submitting: _submitting,
                          onSafe: () => _report('safe'),
                          onUrgent: () => _report('urgent'),
                        )
                      : _ReportedEmergencyBody(
                          urgent: _state == _EmergencyViewState.urgent,
                          pendingSync: _pendingSync,
                          hasLocation: _location != null,
                        ),
                ),
              ),
              if (submitted)
                _EmergencyFooter(
                  urgent: _state == _EmergencyViewState.urgent,
                  onPrimary: _state == _EmergencyViewState.urgent
                      ? _openEmergencyAssistance
                      : _callOperations,
                  onSecondary: _state == _EmergencyViewState.urgent
                      ? _callOperations
                      : () => Navigator.of(context).pop(true),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyTopBar extends StatelessWidget {
  const _EmergencyTopBar({required this.pendingSync, required this.submitted});

  final bool pendingSync;
  final bool submitted;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('driver-emergency-topbar'),
    height: DriverG05Metrics.topBarHeight,
    padding: const EdgeInsets.symmetric(
      horizontal: DriverG05Metrics.topBarPaddingHorizontal,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    alignment: Alignment.centerLeft,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          !submitted
              ? 'EMERGENCY'
              : pendingSync
              ? 'PENDING SYNC'
              : 'EMERGENCY HOLD',
          style: const TextStyle(
            color: RoundsColors.red,
            fontSize: DriverG05Metrics.topEyebrowSize,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: DriverG05Metrics.topEyebrowTracking,
          ),
        ),
        const SizedBox(height: DriverG05Metrics.topTitleGap),
        const Text(
          'Driver emergency',
          style: TextStyle(
            color: RoundsColors.ink,
            fontSize: DriverG05Metrics.topTitleSize,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -.425,
          ),
        ),
      ],
    ),
  );
}

class _InitialEmergencyBody extends StatelessWidget {
  const _InitialEmergencyBody({
    required this.readingLocation,
    required this.hasLocation,
    required this.submitting,
    required this.onSafe,
    required this.onUrgent,
  });

  final bool readingLocation;
  final bool hasLocation;
  final bool submitting;
  final VoidCallback onSafe;
  final VoidCallback onUrgent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _EmergencyKicker(label: 'EMERGENCY', color: RoundsColors.red),
      const SizedBox(height: DriverG05Metrics.heroGap),
      const Text(
        'Are you safe?',
        style: TextStyle(
          color: RoundsColors.ink,
          fontSize: DriverG05Metrics.heroSize,
          height: DriverG05Metrics.heroHeight,
          fontWeight: FontWeight.w900,
          letterSpacing: DriverG05Metrics.heroTracking,
        ),
      ),
      const SizedBox(height: DriverG05Metrics.questionGap),
      const Text(
        'SAFETY STATUS',
        style: TextStyle(
          color: RoundsColors.muted,
          fontSize: DriverG05Metrics.questionSize,
          fontWeight: FontWeight.w900,
          letterSpacing: DriverG05Metrics.questionTracking,
        ),
      ),
      const SizedBox(height: DriverG05Metrics.choiceListGap),
      Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: RoundsColors.line)),
        ),
        child: Column(
          children: [
            _SafetyChoice(
              key: const Key('driver-emergency-safe'),
              icon: Icons.check,
              color: RoundsColors.green,
              softColor: const Color(0xFFEAF7EF),
              title: 'I’m safe',
              detail: 'I can wait safely while Rounds contacts Operations.',
              enabled: !submitting,
              onTap: onSafe,
            ),
            _SafetyChoice(
              key: const Key('driver-emergency-urgent'),
              icon: Icons.priority_high,
              color: RoundsColors.red,
              softColor: const Color(0xFFFFF0F0),
              title: 'I need urgent help',
              detail: 'Accident, injury or unsafe situation.',
              enabled: !submitting,
              onTap: onUrgent,
            ),
          ],
        ),
      ),
      _EmergencyLocationLine(
        title: readingLocation
            ? 'Checking current location'
            : hasLocation
            ? 'Current location available'
            : 'Current location unavailable',
        detail: hasLocation
            ? 'It will be attached to the emergency event'
            : 'You can report the emergency without it',
      ),
      if (submitting) ...[
        const SizedBox(height: 20),
        const Center(child: CircularProgressIndicator()),
      ],
    ],
  );
}

class _ReportedEmergencyBody extends StatelessWidget {
  const _ReportedEmergencyBody({
    required this.urgent,
    required this.pendingSync,
    required this.hasLocation,
  });

  final bool urgent;
  final bool pendingSync;
  final bool hasLocation;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _EmergencyKicker(
        label: urgent ? 'URGENT HELP' : 'SAFETY STATUS',
        color: urgent ? RoundsColors.red : RoundsColors.green,
      ),
      const SizedBox(height: DriverG05Metrics.heroGap),
      Text(
        urgent ? 'I need urgent help' : 'I’m safe',
        style: const TextStyle(
          color: RoundsColors.ink,
          fontSize: DriverG05Metrics.heroSize,
          height: DriverG05Metrics.heroHeight,
          fontWeight: FontWeight.w900,
          letterSpacing: DriverG05Metrics.heroTracking,
        ),
      ),
      const SizedBox(height: DriverG05Metrics.subGap),
      Text(
        pendingSync
            ? 'Saved on this phone. Operations has not received it yet.'
            : 'Operations has received the emergency event and the Stop is protected by an emergency hold.',
        style: const TextStyle(
          color: RoundsColors.muted,
          fontSize: DriverG05Metrics.subSize,
          height: DriverG05Metrics.subHeight,
          fontWeight: FontWeight.w700,
        ),
      ),
      _EmergencyLocationLine(
        title: hasLocation
            ? 'Current location recorded'
            : 'Location unavailable',
        detail: hasLocation
            ? pendingSync
                  ? 'Saved with the pending emergency event'
                  : 'Attached to the emergency event'
            : 'The emergency event was sent without location',
      ),
      if (!urgent) _EmergencyStateBlock(pendingSync: pendingSync),
    ],
  );
}

class _EmergencyKicker extends StatelessWidget {
  const _EmergencyKicker({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: DriverG05Metrics.kickerDotSize,
        height: DriverG05Metrics.kickerDotSize,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: DriverG05Metrics.kickerGap),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: DriverG05Metrics.kickerSize,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: DriverG05Metrics.kickerTracking,
        ),
      ),
    ],
  );
}

class _SafetyChoice extends StatelessWidget {
  const _SafetyChoice({
    required this.icon,
    required this.color,
    required this.softColor,
    required this.title,
    required this.detail,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final Color color;
  final Color softColor;
  final String title;
  final String detail;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? onTap : null,
    child: Container(
      constraints: const BoxConstraints(
        minHeight: DriverG05Metrics.choiceRowHeight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: RoundsColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: DriverG05Metrics.choiceIconColumn,
            child: Container(
              width: DriverG05Metrics.choiceIconSize,
              height: DriverG05Metrics.choiceIconSize,
              decoration: BoxDecoration(
                color: softColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: DriverG05Metrics.choiceGlyphSize,
              ),
            ),
          ),
          const SizedBox(width: DriverG05Metrics.choiceColumnGap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: RoundsColors.ink,
                    fontSize: DriverG05Metrics.choiceTitleSize,
                    height: DriverG05Metrics.choiceTitleHeight,
                    fontWeight: FontWeight.w900,
                    letterSpacing: DriverG05Metrics.choiceTitleTracking,
                  ),
                ),
                const SizedBox(height: DriverG05Metrics.choiceDetailGap),
                Text(
                  detail,
                  style: const TextStyle(
                    color: RoundsColors.muted,
                    fontSize: DriverG05Metrics.choiceDetailSize,
                    height: DriverG05Metrics.choiceDetailHeight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DriverG05Metrics.choiceArrowColumn),
          Icon(Icons.chevron_right, color: color, size: 22),
        ],
      ),
    ),
  );
}

class _EmergencyLocationLine extends StatelessWidget {
  const _EmergencyLocationLine({required this.title, required this.detail});
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: DriverG05Metrics.locationMarginTop),
    padding: const EdgeInsets.only(top: DriverG05Metrics.locationPaddingTop),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: DriverG05Metrics.locationIconSize,
          color: RoundsColors.orange,
        ),
        const SizedBox(width: DriverG05Metrics.locationColumnGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: RoundsColors.inkSecondary,
                  fontSize: DriverG05Metrics.locationTitleSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: DriverG05Metrics.locationDetailGap),
              Text(
                detail,
                style: const TextStyle(
                  color: RoundsColors.muted,
                  fontSize: DriverG05Metrics.locationDetailSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EmergencyStateBlock extends StatelessWidget {
  const _EmergencyStateBlock({required this.pendingSync});
  final bool pendingSync;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: DriverG05Metrics.stateMarginTop),
    padding: const EdgeInsets.only(top: DriverG05Metrics.statePaddingTop),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: RoundsColors.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pendingSync ? 'SYNC STATUS' : 'OPERATIONS',
          style: const TextStyle(
            color: RoundsColors.green,
            fontSize: DriverG05Metrics.stateLabelSize,
            fontWeight: FontWeight.w900,
            letterSpacing: DriverG05Metrics.stateLabelTracking,
          ),
        ),
        const SizedBox(height: DriverG05Metrics.stateTitleGap),
        Text(
          pendingSync ? 'Waiting to sync' : 'Emergency hold active',
          style: const TextStyle(
            color: RoundsColors.ink,
            fontSize: DriverG05Metrics.stateTitleSize,
            height: DriverG05Metrics.stateTitleHeight,
            fontWeight: FontWeight.w900,
            letterSpacing: DriverG05Metrics.stateTitleTracking,
          ),
        ),
        const SizedBox(height: DriverG05Metrics.stateDetailGap),
        Text(
          pendingSync
              ? 'Keep safe while Rounds retries. Operations cannot act until this event reaches the server.'
              : 'Operations can see the priority event. No reassignment or next step has been approved yet.',
          style: const TextStyle(
            color: RoundsColors.muted,
            fontSize: DriverG05Metrics.stateDetailSize,
            height: DriverG05Metrics.stateDetailHeight,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _EmergencyFooter extends StatelessWidget {
  const _EmergencyFooter({
    required this.urgent,
    required this.onPrimary,
    required this.onSecondary,
  });

  final bool urgent;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('driver-emergency-footer'),
    padding: const EdgeInsets.fromLTRB(
      DriverG05Metrics.footerPaddingHorizontal,
      DriverG05Metrics.footerPaddingTop,
      DriverG05Metrics.footerPaddingHorizontal,
      DriverG05Metrics.footerPaddingBottom,
    ),
    decoration: const BoxDecoration(
      color: RoundsColors.surface,
      border: Border(top: BorderSide(color: RoundsColors.line)),
    ),
    child: Column(
      children: [
        SizedBox(
          height: DriverG05Metrics.primaryHeight,
          width: double.infinity,
          child: FilledButton(
            key: const Key('driver-emergency-primary'),
            onPressed: onPrimary,
            style: FilledButton.styleFrom(
              backgroundColor: urgent ? RoundsColors.red : RoundsColors.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  DriverG05Metrics.primaryRadius,
                ),
              ),
            ),
            child: Text(
              urgent ? 'Emergency assistance' : 'Call Operations',
              style: const TextStyle(
                fontSize: DriverG05Metrics.primarySize,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: DriverG05Metrics.secondaryGap),
        SizedBox(
          height: DriverG05Metrics.secondaryHeight,
          width: double.infinity,
          child: TextButton(
            key: const Key('driver-emergency-secondary'),
            onPressed: onSecondary,
            child: Text(
              urgent ? 'Call Operations' : 'Return to Round',
              style: const TextStyle(
                color: RoundsColors.inkSecondary,
                fontSize: DriverG05Metrics.secondarySize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _EmergencyAssistanceSheet extends StatelessWidget {
  const _EmergencyAssistanceSheet();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(DriverG05Metrics.sheetInset),
    child: Material(
      key: const Key('emergency-assistance-sheet'),
      color: RoundsColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DriverG05Metrics.sheetRadiusTop),
          bottom: Radius.circular(DriverG05Metrics.sheetRadiusBottom),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DriverG05Metrics.sheetPaddingHorizontal,
          10,
          DriverG05Metrics.sheetPaddingHorizontal,
          DriverG05Metrics.sheetPaddingBottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: DriverG05Metrics.sheetHandleWidth,
                height: DriverG05Metrics.sheetHandleHeight,
                margin: const EdgeInsets.only(
                  bottom: DriverG05Metrics.sheetHandleBottom,
                ),
                decoration: BoxDecoration(
                  color: RoundsColors.lineStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Emergency assistance',
              style: TextStyle(
                color: RoundsColors.ink,
                fontSize: DriverG05Metrics.sheetTitleSize,
                fontWeight: FontWeight.w900,
                letterSpacing: -.77,
              ),
            ),
            const SizedBox(height: DriverG05Metrics.sheetDetailGap),
            const Text(
              'Choose the help you need. Your emergency hold stays active.',
              style: TextStyle(
                color: RoundsColors.muted,
                fontSize: DriverG05Metrics.sheetDetailSize,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 11),
            _EmergencyCallRow(
              key: const Key('emergency-medical'),
              icon: Icons.medical_services_outlined,
              title: 'Medical emergency',
              detail: 'Call emergency medical services · 1669',
              onTap: () => Navigator.of(context).pop('1669'),
            ),
            _EmergencyCallRow(
              key: const Key('emergency-police'),
              icon: Icons.warning_amber_rounded,
              title: 'Police / immediate danger',
              detail: 'Call the emergency police line · 191',
              onTap: () => Navigator.of(context).pop('191'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmergencyCallRow extends StatelessWidget {
  const _EmergencyCallRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(
        minHeight: DriverG05Metrics.sheetRowHeight,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: RoundsColors.line)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: RoundsColors.red,
            size: DriverG05Metrics.sheetRowIconSize,
          ),
          const SizedBox(width: DriverG05Metrics.sheetRowColumnGap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: DriverG05Metrics.sheetRowTitleSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: DriverG05Metrics.sheetRowDetailGap),
                Text(
                  detail,
                  style: const TextStyle(
                    color: RoundsColors.muted,
                    fontSize: DriverG05Metrics.sheetRowDetailSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<DriverLocationEvidence> _currentEmergencyLocation() async {
  await requireOperationalLocationAccess();
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 8),
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
