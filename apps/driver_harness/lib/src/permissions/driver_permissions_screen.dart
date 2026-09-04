import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../app/app_strings.dart';
import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import 'location_access.dart';

class DriverPermissionsScreen extends StatefulWidget {
  const DriverPermissionsScreen({
    this.gateway = const GeolocatorLocationAccessGateway(),
    this.locale = HarnessLocale.english,
    super.key,
  });

  final DriverLocationAccessGateway gateway;
  final HarnessLocale locale;

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
  Widget build(BuildContext context) {
    final copy = _N01Copy(widget.locale);
    return Scaffold(
      backgroundColor: RoundsColors.surface,
      body: SafeArea(
        child: MediaQuery.withNoTextScaling(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth <=
                  DriverReferenceViewport.compactBreakpoint;
              final shortViewport =
                  constraints.maxHeight <=
                  DriverN01Metrics.shortBreakpointHeight;
              return Column(
                children: [
                  _PermissionsTopBar(copy: copy),
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
                          Text(
                            copy.kicker,
                            style: const TextStyle(
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
                            height: _iconBottom(
                              copy,
                              compact: compact,
                              shortViewport: shortViewport,
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 330),
                            child: Text(
                              copy.title,
                              style: TextStyle(
                                color: RoundsColors.ink,
                                fontSize: _titleSize(
                                  copy,
                                  compact: compact,
                                  shortViewport: shortViewport,
                                ),
                                height: copy.isThai
                                    ? compact
                                          ? DriverN01Metrics
                                                .compactThaiTitleHeight
                                          : DriverN01Metrics.thaiTitleHeight
                                    : DriverN01Metrics.titleHeight,
                                fontWeight: FontWeight.w900,
                                letterSpacing: copy.isThai ? 0 : -2.15,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: _leadTop(
                              copy,
                              compact: compact,
                              shortViewport: shortViewport,
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 335),
                            child: Text(
                              copy.lead(_snapshot),
                              style: TextStyle(
                                color: RoundsColors.inkSecondary,
                                fontSize: _leadSize(
                                  copy,
                                  compact: compact,
                                  shortViewport: shortViewport,
                                ),
                                height: copy.isThai
                                    ? compact
                                          ? DriverN01Metrics
                                                .compactThaiLeadHeight
                                          : DriverN01Metrics.thaiLeadHeight
                                    : compact
                                    ? DriverN01Metrics.compactLeadHeight
                                    : DriverN01Metrics.leadHeight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: _truthTop(
                              copy,
                              compact: compact,
                              shortViewport: shortViewport,
                            ),
                          ),
                          _PermissionTruth(
                            snapshot: _snapshot,
                            copy: copy,
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
                                disabledBackgroundColor:
                                    RoundsColors.lineStrong,
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
                                      copy.primaryLabel(_snapshot),
                                      style: TextStyle(
                                        fontSize: compact && copy.isThai
                                            ? DriverN01Metrics
                                                  .compactThaiPrimarySize
                                            : DriverN01Metrics.primarySize,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -.34,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(
                            height: copy.isThai
                                ? DriverN01Metrics.thaiSecondaryTop
                                : DriverN01Metrics.secondaryTop,
                          ),
                          SizedBox(
                            width: double.infinity,
                            height: shortViewport
                                ? copy.isThai
                                      ? DriverN01Metrics
                                            .shortThaiSecondaryHeight
                                      : DriverN01Metrics.shortSecondaryHeight
                                : compact
                                ? copy.isThai
                                      ? DriverN01Metrics
                                            .compactThaiSecondaryHeight
                                      : DriverN01Metrics.compactSecondaryHeight
                                : copy.isThai
                                ? DriverN01Metrics.thaiSecondaryHeight
                                : DriverN01Metrics.secondaryHeight,
                            child: TextButton(
                              key: const Key('n01-back'),
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                copy.notNow,
                                style: const TextStyle(
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
}

class _PermissionsTopBar extends StatelessWidget {
  const _PermissionsTopBar({required this.copy});

  final _N01Copy copy;

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
        Text(
          copy.step,
          style: TextStyle(
            color: RoundsColors.muted,
            fontSize: copy.isThai
                ? DriverN01Metrics.thaiStepSize
                : DriverN01Metrics.stepSize,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: copy.isThai ? 0 : .9,
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
    required this.copy,
    required this.compact,
    required this.shortViewport,
  });

  final DriverLocationAccessSnapshot? snapshot;
  final _N01Copy copy;
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
          text: copy.truthLabel(snapshot),
          compact: compact,
          shortViewport: shortViewport,
          thai: copy.isThai,
        ),
        const Divider(height: 1, color: RoundsColors.line),
        _TruthRow(
          icon: Icons.arrow_forward,
          text: copy.workUseTruth,
          compact: compact,
          shortViewport: shortViewport,
          thai: copy.isThai,
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
    this.thai = false,
  });

  final IconData icon;
  final String text;
  final bool compact;
  final bool shortViewport;
  final bool thai;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      minHeight: shortViewport
          ? DriverN01Metrics.shortTruthRowMinHeight
          : compact
          ? thai
                ? DriverN01Metrics.compactThaiTruthRowMinHeight
                : DriverN01Metrics.compactTruthRowMinHeight
          : thai
          ? DriverN01Metrics.thaiTruthRowMinHeight
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
                  ? thai
                        ? DriverN01Metrics.compactThaiTruthCopySize
                        : DriverN01Metrics.compactTruthCopySize
                  : thai
                  ? DriverN01Metrics.thaiTruthCopySize
                  : DriverN01Metrics.truthCopySize,
              height: thai
                  ? DriverN01Metrics.thaiTruthCopyHeight
                  : DriverN01Metrics.truthCopyHeight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

double _iconBottom(
  _N01Copy copy, {
  required bool compact,
  required bool shortViewport,
}) {
  if (shortViewport) {
    return copy.isThai
        ? DriverN01Metrics.shortThaiIconBottom
        : DriverN01Metrics.shortIconBottom;
  }
  if (compact) {
    return copy.isThai
        ? DriverN01Metrics.compactThaiIconBottom
        : DriverN01Metrics.compactIconBottom;
  }
  return copy.isThai
      ? DriverN01Metrics.thaiIconBottom
      : DriverN01Metrics.iconBottom;
}

double _titleSize(
  _N01Copy copy, {
  required bool compact,
  required bool shortViewport,
}) {
  if (shortViewport) {
    return copy.isThai
        ? DriverN01Metrics.shortThaiTitleSize
        : DriverN01Metrics.shortTitleSize;
  }
  if (compact) {
    return copy.isThai
        ? DriverN01Metrics.compactThaiTitleSize
        : DriverN01Metrics.compactTitleSize;
  }
  return copy.isThai
      ? DriverN01Metrics.thaiTitleSize
      : DriverN01Metrics.titleSize;
}

double _leadTop(
  _N01Copy copy, {
  required bool compact,
  required bool shortViewport,
}) {
  if (shortViewport) {
    return copy.isThai
        ? DriverN01Metrics.shortThaiLeadTop
        : DriverN01Metrics.shortLeadTop;
  }
  if (compact) {
    return copy.isThai
        ? DriverN01Metrics.compactThaiLeadTop
        : DriverN01Metrics.compactLeadTop;
  }
  return copy.isThai ? DriverN01Metrics.thaiLeadTop : DriverN01Metrics.leadTop;
}

double _leadSize(
  _N01Copy copy, {
  required bool compact,
  required bool shortViewport,
}) {
  if (shortViewport) {
    return copy.isThai
        ? DriverN01Metrics.shortThaiLeadSize
        : DriverN01Metrics.shortLeadSize;
  }
  if (compact) {
    return copy.isThai
        ? DriverN01Metrics.compactThaiLeadSize
        : DriverN01Metrics.compactLeadSize;
  }
  return copy.isThai
      ? DriverN01Metrics.thaiLeadSize
      : DriverN01Metrics.leadSize;
}

double _truthTop(
  _N01Copy copy, {
  required bool compact,
  required bool shortViewport,
}) {
  if (shortViewport) {
    return copy.isThai
        ? DriverN01Metrics.shortThaiTruthTop
        : DriverN01Metrics.shortTruthTop;
  }
  if (compact) {
    return copy.isThai
        ? DriverN01Metrics.compactThaiTruthTop
        : DriverN01Metrics.compactTruthTop;
  }
  return copy.isThai
      ? DriverN01Metrics.thaiTruthTop
      : DriverN01Metrics.truthTop;
}

class _N01Copy {
  const _N01Copy(this.locale);

  final HarnessLocale locale;

  bool get isThai => locale == HarnessLocale.thai;
  String get kicker => isThai ? 'สิทธิ์การใช้งาน' : 'PERMISSIONS';
  String get step => isThai ? '1 จาก 1' : '1 OF 1';
  String get title =>
      isThai ? 'ใช้ตำแหน่งกับ Rounds' : 'Location while using Rounds';
  String get notNow => isThai ? 'ไว้ทีหลัง' : 'Not now';
  String get workUseTruth => isThai
      ? 'ใช้เฉพาะตอนทำงานหรือเปิดรับงาน'
      : 'Used only while working or open for jobs';

  String lead(DriverLocationAccessSnapshot? snapshot) {
    if (snapshot == null) {
      return isThai
          ? 'กำลังตรวจสอบสิทธิ์ตำแหน่งของโทรศัพท์เครื่องนี้'
          : 'Checking this phone’s current location access.';
    }
    return switch (snapshot.state) {
      DriverLocationAccessState.serviceDisabled =>
        isThai
            ? 'เปิดตำแหน่งของอุปกรณ์ก่อนเริ่มนำทาง'
            : 'Turn on device location before starting navigation.',
      DriverLocationAccessState.denied =>
        isThai
            ? 'เพื่อการนำทาง การยืนยันว่าถึงจุด และเวลาถึงที่แม่นยำ'
            : 'Needed for navigation, arrival and accurate delivery ETAs.',
      DriverLocationAccessState.deniedForever =>
        isThai
            ? 'สิทธิ์ตำแหน่งถูกบล็อก เปิดการตั้งค่าเพื่ออนุญาตอีกครั้ง'
            : 'Location is blocked. Open device settings to restore it.',
      DriverLocationAccessState.whileInUse =>
        isThai
            ? 'Rounds ใช้ตำแหน่งขณะเปิดแอปเพื่อทำงาน Team'
            : 'Rounds can use location while the app is open for active Team work.',
      DriverLocationAccessState.always =>
        isThai
            ? 'ตำแหน่งพร้อมสำหรับงาน Team และการนำทางเบื้องหลัง'
            : 'Location is ready for active Team work and background navigation.',
    };
  }

  String truthLabel(DriverLocationAccessSnapshot? snapshot) {
    if (snapshot == null) {
      return isThai
          ? 'กำลังตรวจสอบเส้นทางและสถานะเมื่อถึงจุด'
          : 'Checking route and arrival access';
    }
    return switch (snapshot.state) {
      DriverLocationAccessState.serviceDisabled =>
        isThai
            ? 'บริการตำแหน่งของอุปกรณ์ปิดอยู่'
            : 'Device location services are off',
      DriverLocationAccessState.denied =>
        isThai
            ? 'เส้นทางและสถานะเมื่อถึงจุดแม่นยำ'
            : 'Accurate route and arrival state',
      DriverLocationAccessState.deniedForever =>
        isThai
            ? 'สิทธิ์ตำแหน่งถูกบล็อกในการตั้งค่าแอป'
            : 'Location is blocked in app settings',
      DriverLocationAccessState.whileInUse =>
        isThai
            ? 'เส้นทางและสถานะเมื่อถึงจุดพร้อมขณะใช้ Rounds'
            : 'Route and arrival access is ready while using Rounds',
      DriverLocationAccessState.always =>
        isThai
            ? 'เส้นทางและการนำทางเบื้องหลังพร้อมใช้งาน'
            : 'Route and background navigation access is ready',
    };
  }

  String primaryLabel(DriverLocationAccessSnapshot? snapshot) {
    if (snapshot == null) return isThai ? 'กำลังตรวจสอบ' : 'Checking access';
    return switch (snapshot.state) {
      DriverLocationAccessState.serviceDisabled =>
        isThai ? 'เปิดการตั้งค่าตำแหน่ง' : 'Open location settings',
      DriverLocationAccessState.denied =>
        isThai ? 'อนุญาตตำแหน่ง' : 'Allow location',
      DriverLocationAccessState.deniedForever =>
        isThai ? 'เปิดการตั้งค่าแอป' : 'Open app settings',
      DriverLocationAccessState.whileInUse ||
      DriverLocationAccessState.always => isThai ? 'เสร็จ' : 'Done',
    };
  }

  String get cameraKicker => isThai ? 'สิทธิ์การใช้กล้อง' : 'CAMERA PERMISSION';
  String get cameraTitle =>
      isThai ? 'ต้องอนุญาตให้ใช้กล้อง' : 'Camera access needed';
  String get cameraLead => isThai
      ? 'Rounds ขอใช้กล้องเฉพาะเมื่อต้องถ่ายหลักฐานหรือแจ้งปัญหา ไม่มีการสร้างรูปหรือยืนยันการส่งปลอม'
      : 'Rounds asks for the camera only when proof or problem evidence is required. No photo or delivery completion is fabricated.';
  String get openAppSettings =>
      isThai ? 'เปิดการตั้งค่าแอป' : 'Open app settings';
  String get notNowSheet => isThai ? 'ไว้ทีหลัง' : 'Not now';
  String get locationKicker => isThai ? 'สิทธิ์ตำแหน่ง' : 'LOCATION PERMISSION';
  String locationTitle(DriverLocationAccessState state) =>
      state == DriverLocationAccessState.serviceDisabled
      ? (isThai ? 'เปิดตำแหน่ง' : 'Turn location on')
      : (isThai ? 'ต้องอนุญาตตำแหน่ง' : 'Location access needed');
  String locationRecoveryLead(
    DriverLocationAccessState state,
  ) => switch (state) {
    DriverLocationAccessState.serviceDisabled =>
      isThai
          ? 'เปิดบริการตำแหน่งของอุปกรณ์ แล้วกลับมาลองอีกครั้ง'
          : 'Turn on device location services, then return and try again.',
    DriverLocationAccessState.deniedForever =>
      isThai
          ? 'สิทธิ์ตำแหน่งถูกบล็อก เปิดการตั้งค่าแอปเพื่ออนุญาตอีกครั้ง'
          : 'Location is blocked. Open app settings to restore access.',
    DriverLocationAccessState.denied =>
      isThai
          ? 'ตรวจสอบและอนุญาตตำแหน่งเพื่อใช้การนำทางและยืนยันว่าถึงจุด'
          : 'Review and allow location for navigation and arrival confirmation.',
    DriverLocationAccessState.whileInUse || DriverLocationAccessState.always =>
      isThai ? 'ตำแหน่งพร้อมใช้งาน' : 'Location access is ready.',
  };
  String get openSettings => isThai ? 'เปิดการตั้งค่า' : 'Open settings';
  String get reviewLocation =>
      isThai ? 'ตรวจสอบสิทธิ์ตำแหน่ง' : 'Review location access';
}

bool isCameraPermissionError(Object error) =>
    error is PlatformException && error.code == 'camera_access_denied';

Future<void> showLocationPermissionRecovery(
  BuildContext context,
  DriverLocationAccessException failure, {
  DriverLocationAccessGateway gateway = const GeolocatorLocationAccessGateway(),
  HarnessLocale locale = HarnessLocale.english,
}) async {
  final recover = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: RoundsColors.ink.withValues(alpha: .38),
    builder: (_) => _LocationPermissionSheet(failure: failure, locale: locale),
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
          builder: (_) =>
              DriverPermissionsScreen(gateway: gateway, locale: locale),
        ),
      );
    case DriverLocationAccessState.whileInUse:
    case DriverLocationAccessState.always:
      break;
  }
}

Future<void> showCameraPermissionRecovery(
  BuildContext context, {
  HarnessLocale locale = HarnessLocale.english,
}) async {
  final openSettings = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: RoundsColors.ink.withValues(alpha: .38),
    builder: (_) => _CameraPermissionSheet(locale: locale),
  );
  if (openSettings == true) await Geolocator.openAppSettings();
}

class _CameraPermissionSheet extends StatelessWidget {
  const _CameraPermissionSheet({required this.locale});

  final HarnessLocale locale;

  @override
  Widget build(BuildContext context) {
    final copy = _N01Copy(locale);
    return Container(
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
          Text(
            copy.cameraKicker,
            style: const TextStyle(
              color: RoundsColors.orange,
              fontSize: 11.5,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            copy.cameraTitle,
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
            copy.cameraLead,
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
              key: const Key('n01-camera-settings'),
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: RoundsColors.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: Text(
                copy.openAppSettings,
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
              child: Text(
                copy.notNowSheet,
                style: const TextStyle(
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

class _LocationPermissionSheet extends StatelessWidget {
  const _LocationPermissionSheet({required this.failure, required this.locale});

  final DriverLocationAccessException failure;
  final HarnessLocale locale;

  @override
  Widget build(BuildContext context) {
    final settings = failure.state != DriverLocationAccessState.denied;
    final copy = _N01Copy(locale);
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
          Text(
            copy.locationKicker,
            style: const TextStyle(
              color: RoundsColors.orange,
              fontSize: 11.5,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            copy.locationTitle(failure.state),
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
            copy.locationRecoveryLead(failure.state),
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
                settings ? copy.openSettings : copy.reviewLocation,
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
              child: Text(
                copy.notNowSheet,
                style: const TextStyle(
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
