import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import 'location_access.dart';

class DriverPermissionsScreen extends StatefulWidget {
  const DriverPermissionsScreen({
    this.gateway = const GeolocatorLocationAccessGateway(),
    super.key,
  });

  final DriverLocationAccessGateway gateway;

  @override
  State<DriverPermissionsScreen> createState() =>
      _DriverPermissionsScreenState();
}

class _DriverPermissionsScreenState extends State<DriverPermissionsScreen>
    with WidgetsBindingObserver {
  DriverLocationAccessSnapshot? _snapshot;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final snapshot = await widget.gateway.inspect();
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
  }

  Future<void> _primary() async {
    final snapshot = _snapshot;
    if (_busy || snapshot == null) return;
    if (snapshot.ready) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _busy = true);
    try {
      switch (snapshot.state) {
        case DriverLocationAccessState.serviceDisabled:
          await widget.gateway.openLocationSettings();
        case DriverLocationAccessState.deniedForever:
          await widget.gateway.openAppSettings();
        case DriverLocationAccessState.denied:
          _snapshot = await widget.gateway.request();
        case DriverLocationAccessState.whileInUse:
        case DriverLocationAccessState.always:
          break;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: RoundsColors.surface,
    body: SafeArea(
      child: MediaQuery.withNoTextScaling(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth <=
                DriverReferenceViewport.compactBreakpoint;
            final shortViewport =
                constraints.maxHeight <= DriverN01Metrics.shortBreakpointHeight;
            return Column(
              children: [
                const _PermissionsTopBar(),
                Expanded(
                  child: Padding(
                    key: const Key('n01-main'),
                    padding: EdgeInsets.fromLTRB(
                      compact
                          ? DriverN01Metrics.compactMainPaddingHorizontal
                          : DriverN01Metrics.mainPaddingHorizontal,
                      shortViewport
                          ? DriverN01Metrics.shortMainPaddingTop
                          : compact
                          ? DriverN01Metrics.compactMainPaddingTop
                          : DriverN01Metrics.mainPaddingTop,
                      compact
                          ? DriverN01Metrics.compactMainPaddingHorizontal
                          : DriverN01Metrics.mainPaddingHorizontal,
                      shortViewport
                          ? DriverN01Metrics.shortMainPaddingBottom
                          : compact
                          ? DriverN01Metrics.compactMainPaddingBottom
                          : DriverN01Metrics.mainPaddingBottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PERMISSIONS',
                          style: TextStyle(
                            color: RoundsColors.orange,
                            fontSize: DriverN01Metrics.kickerSize,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.14,
                          ),
                        ),
                        const SizedBox(height: DriverN01Metrics.kickerBottom),
                        _PermissionIcon(
                          compact: compact,
                          shortViewport: shortViewport,
                        ),
                        SizedBox(
                          height: shortViewport
                              ? DriverN01Metrics.shortIconBottom
                              : compact
                              ? DriverN01Metrics.compactIconBottom
                              : DriverN01Metrics.iconBottom,
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 330),
                          child: Text(
                            'Location while using Rounds',
                            style: TextStyle(
                              color: RoundsColors.ink,
                              fontSize: shortViewport
                                  ? DriverN01Metrics.shortTitleSize
                                  : compact
                                  ? DriverN01Metrics.compactTitleSize
                                  : DriverN01Metrics.titleSize,
                              height: DriverN01Metrics.titleHeight,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2.15,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: shortViewport
                              ? DriverN01Metrics.shortLeadTop
                              : compact
                              ? DriverN01Metrics.compactLeadTop
                              : DriverN01Metrics.leadTop,
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 335),
                          child: Text(
                            _lead(_snapshot),
                            style: TextStyle(
                              color: RoundsColors.inkSecondary,
                              fontSize: shortViewport
                                  ? DriverN01Metrics.shortLeadSize
                                  : compact
                                  ? DriverN01Metrics.compactLeadSize
                                  : DriverN01Metrics.leadSize,
                              height: compact
                                  ? DriverN01Metrics.compactLeadHeight
                                  : DriverN01Metrics.leadHeight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: shortViewport
                              ? DriverN01Metrics.shortTruthTop
                              : compact
                              ? DriverN01Metrics.compactTruthTop
                              : DriverN01Metrics.truthTop,
                        ),
                        _PermissionTruth(
                          snapshot: _snapshot,
                          compact: compact,
                          shortViewport: shortViewport,
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          height: shortViewport
                              ? DriverN01Metrics.shortPrimaryHeight
                              : compact
                              ? DriverN01Metrics.compactPrimaryHeight
                              : DriverN01Metrics.primaryHeight,
                          child: FilledButton(
                            key: const Key('n01-primary'),
                            onPressed: _snapshot == null || _busy
                                ? null
                                : _primary,
                            style: FilledButton.styleFrom(
                              backgroundColor: RoundsColors.ink,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: RoundsColors.lineStrong,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  DriverN01Metrics.primaryRadius,
                                ),
                              ),
                            ),
                            child: _busy
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _primaryLabel(_snapshot),
                                    style: const TextStyle(
                                      fontSize: DriverN01Metrics.primarySize,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -.34,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(height: DriverN01Metrics.secondaryTop),
                        SizedBox(
                          width: double.infinity,
                          height: shortViewport
                              ? DriverN01Metrics.shortSecondaryHeight
                              : compact
                              ? DriverN01Metrics.compactSecondaryHeight
                              : DriverN01Metrics.secondaryHeight,
                          child: TextButton(
                            key: const Key('n01-back'),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Back to profile',
                              style: TextStyle(
                                color: RoundsColors.muted,
                                fontSize: DriverN01Metrics.secondarySize,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _PermissionsTopBar extends StatelessWidget {
  const _PermissionsTopBar();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('n01-topbar'),
    height: DriverN01Metrics.topBarHeight,
    padding: const EdgeInsets.symmetric(
      horizontal: DriverN01Metrics.topBarPaddingHorizontal,
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
                fontSize: DriverN01Metrics.brandSize,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(left: 3, bottom: 2),
              decoration: const BoxDecoration(
                color: RoundsColors.orange,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const Text(
          'TEAM PILOT',
          style: TextStyle(
            color: RoundsColors.muted,
            fontSize: DriverN01Metrics.stepSize,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: .9,
          ),
        ),
      ],
    ),
  );
}

class _PermissionIcon extends StatelessWidget {
  const _PermissionIcon({required this.compact, required this.shortViewport});

  final bool compact;
  final bool shortViewport;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('n01-icon'),
    width: shortViewport
        ? DriverN01Metrics.shortIconSize
        : compact
        ? DriverN01Metrics.compactIconSize
        : DriverN01Metrics.iconSize,
    height: shortViewport
        ? DriverN01Metrics.shortIconSize
        : compact
        ? DriverN01Metrics.compactIconSize
        : DriverN01Metrics.iconSize,
    decoration: BoxDecoration(
      border: Border.all(color: RoundsColors.line),
      borderRadius: BorderRadius.circular(DriverN01Metrics.iconRadius),
    ),
    child: Icon(
      Icons.location_on_outlined,
      color: RoundsColors.orange,
      size: shortViewport
          ? DriverN01Metrics.shortIconGlyphSize
          : compact
          ? DriverN01Metrics.compactIconGlyphSize
          : DriverN01Metrics.iconGlyphSize,
    ),
  );
}

class _PermissionTruth extends StatelessWidget {
  const _PermissionTruth({
    required this.snapshot,
    required this.compact,
    required this.shortViewport,
  });

  final DriverLocationAccessSnapshot? snapshot;
  final bool compact;
  final bool shortViewport;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('n01-truth'),
    decoration: const BoxDecoration(
      border: Border.symmetric(
        horizontal: BorderSide(color: RoundsColors.line),
      ),
    ),
    child: Column(
      children: [
        _TruthRow(
          icon: snapshot?.ready ?? false
              ? Icons.check
              : Icons.location_searching,
          text: _truthLabel(snapshot),
          compact: compact,
          shortViewport: shortViewport,
        ),
        const Divider(height: 1, color: RoundsColors.line),
        _TruthRow(
          icon: Icons.camera_alt_outlined,
          text: 'Camera is requested only when evidence is required',
          compact: compact,
          shortViewport: shortViewport,
        ),
      ],
    ),
  );
}

class _TruthRow extends StatelessWidget {
  const _TruthRow({
    required this.icon,
    required this.text,
    required this.compact,
    required this.shortViewport,
  });

  final IconData icon;
  final String text;
  final bool compact;
  final bool shortViewport;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      minHeight: shortViewport
          ? DriverN01Metrics.shortTruthRowMinHeight
          : compact
          ? DriverN01Metrics.compactTruthRowMinHeight
          : DriverN01Metrics.truthRowMinHeight,
    ),
    child: Row(
      children: [
        SizedBox(
          width: DriverN01Metrics.truthIconSize,
          height: DriverN01Metrics.truthIconSize,
          child: Icon(
            icon,
            size: DriverN01Metrics.truthGlyphSize,
            color: const Color(0xFF168B50),
          ),
        ),
        const SizedBox(width: DriverN01Metrics.truthGap),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: RoundsColors.inkSecondary,
              fontSize: compact
                  ? DriverN01Metrics.compactTruthCopySize
                  : DriverN01Metrics.truthCopySize,
              height: DriverN01Metrics.truthCopyHeight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

String _lead(DriverLocationAccessSnapshot? snapshot) {
  if (snapshot == null) return 'Checking this phone’s current location access.';
  return switch (snapshot.state) {
    DriverLocationAccessState.serviceDisabled =>
      'Turn on device location before starting navigation.',
    DriverLocationAccessState.denied =>
      'Needed for navigation, arrival and accurate delivery ETAs.',
    DriverLocationAccessState.deniedForever =>
      'Location is blocked. Open device settings to restore it.',
    DriverLocationAccessState.whileInUse =>
      'Rounds can use location while the app is open for active Team work.',
    DriverLocationAccessState.always =>
      'Location is ready for active Team work and background navigation.',
  };
}

String _truthLabel(DriverLocationAccessSnapshot? snapshot) {
  if (snapshot == null) return 'Checking route and arrival access';
  return switch (snapshot.state) {
    DriverLocationAccessState.serviceDisabled =>
      'Device location services are off',
    DriverLocationAccessState.denied => 'Location has not been allowed',
    DriverLocationAccessState.deniedForever =>
      'Location is blocked in app settings',
    DriverLocationAccessState.whileInUse =>
      'Route and arrival access is ready while using Rounds',
    DriverLocationAccessState.always =>
      'Route and background navigation access is ready',
  };
}

String _primaryLabel(DriverLocationAccessSnapshot? snapshot) {
  if (snapshot == null) return 'Checking access';
  return switch (snapshot.state) {
    DriverLocationAccessState.serviceDisabled => 'Open location settings',
    DriverLocationAccessState.denied => 'Allow location',
    DriverLocationAccessState.deniedForever => 'Open app settings',
    DriverLocationAccessState.whileInUse ||
    DriverLocationAccessState.always => 'Done',
  };
}

bool isCameraPermissionError(Object error) =>
    error is PlatformException && error.code == 'camera_access_denied';

Future<void> showLocationPermissionRecovery(
  BuildContext context,
  DriverLocationAccessException failure, {
  DriverLocationAccessGateway gateway = const GeolocatorLocationAccessGateway(),
}) async {
  final recover = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: RoundsColors.ink.withValues(alpha: .38),
    builder: (_) => _LocationPermissionSheet(failure: failure),
  );
  if (recover != true || !context.mounted) return;
  switch (failure.state) {
    case DriverLocationAccessState.serviceDisabled:
      await gateway.openLocationSettings();
    case DriverLocationAccessState.deniedForever:
      await gateway.openAppSettings();
    case DriverLocationAccessState.denied:
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => DriverPermissionsScreen(gateway: gateway),
        ),
      );
    case DriverLocationAccessState.whileInUse:
    case DriverLocationAccessState.always:
      break;
  }
}

Future<void> showCameraPermissionRecovery(BuildContext context) async {
  final openSettings = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: RoundsColors.ink.withValues(alpha: .38),
    builder: (_) => const _CameraPermissionSheet(),
  );
  if (openSettings == true) await Geolocator.openAppSettings();
}

class _CameraPermissionSheet extends StatelessWidget {
  const _CameraPermissionSheet();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('n01-camera-sheet'),
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: RoundsColors.lineStrong,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const Text(
          'CAMERA PERMISSION',
          style: TextStyle(
            color: RoundsColors.orange,
            fontSize: 11.5,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Camera access needed',
          style: TextStyle(
            color: RoundsColors.ink,
            fontSize: 28,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Rounds asks for the camera only when proof or problem evidence is required. No photo or delivery completion is fabricated.',
          style: TextStyle(
            color: RoundsColors.muted,
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 56,
          child: FilledButton(
            key: const Key('n01-camera-settings'),
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: RoundsColors.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            child: const Text(
              'Open app settings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Not now',
              style: TextStyle(
                color: RoundsColors.muted,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _LocationPermissionSheet extends StatelessWidget {
  const _LocationPermissionSheet({required this.failure});

  final DriverLocationAccessException failure;

  @override
  Widget build(BuildContext context) {
    final settings = failure.state != DriverLocationAccessState.denied;
    return Container(
      key: const Key('n01-location-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: RoundsColors.lineStrong,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const Text(
            'LOCATION PERMISSION',
            style: TextStyle(
              color: RoundsColors.orange,
              fontSize: 11.5,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            failure.state == DriverLocationAccessState.serviceDisabled
                ? 'Turn location on'
                : 'Location access needed',
            style: const TextStyle(
              color: RoundsColors.ink,
              fontSize: 28,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            failure.toString(),
            style: const TextStyle(
              color: RoundsColors.muted,
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 56,
            child: FilledButton(
              key: const Key('n01-location-recover'),
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: RoundsColors.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: Text(
                settings ? 'Open settings' : 'Review location access',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Not now',
                style: TextStyle(
                  color: RoundsColors.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
