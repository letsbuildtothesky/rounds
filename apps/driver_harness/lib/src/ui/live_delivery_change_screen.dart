import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../driver/driver_api.dart';
import '../driver/driver_session.dart';

class LiveDeliveryChangeScreen extends StatefulWidget {
  const LiveDeliveryChangeScreen({
    required this.round,
    required this.stop,
    required this.change,
    required this.enableNativeMap,
    required this.onAcknowledge,
    required this.contactScreenBuilder,
    super.key,
  });

  final DriverRoundModel round;
  final DriverRoundStopModel stop;
  final DriverLiveDeliveryChangeModel change;
  final bool enableNativeMap;
  final Future<DriverCommandOutcome?> Function() onAcknowledge;
  final WidgetBuilder contactScreenBuilder;

  @override
  State<LiveDeliveryChangeScreen> createState() =>
      _LiveDeliveryChangeScreenState();
}

class _LiveDeliveryChangeScreenState extends State<LiveDeliveryChangeScreen> {
  bool _acknowledging = false;
  String? _error;

  Future<void> _acknowledge() async {
    if (_acknowledging) return;
    setState(() {
      _acknowledging = true;
      _error = null;
    });
    final outcome = await widget.onAcknowledge();
    if (!mounted) return;
    setState(() => _acknowledging = false);
    if (outcome == null) {
      setState(
        () => _error = 'The update could not be acknowledged. Try again.',
      );
      return;
    }
    if (outcome.pendingSync) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Acknowledgement saved on this phone. It will send when connected.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width <= 350;
    final short = size.height <= DriverE04E06Metrics.shortBreakpointHeight;
    final mapHeight = short
        ? DriverE04E06Metrics.shortMapHeight
        : compact
        ? DriverE04E06Metrics.compactMapHeight
        : DriverE04E06Metrics.mapHeight;
    final presentation = _ChangePresentation.from(
      widget.change,
      widget.stop,
      widget.round,
    );
    return Scaffold(
      backgroundColor: RoundsColors.surface,
      body: SafeArea(
        child: MediaQuery.withNoTextScaling(
          child: Column(
            children: [
              _TopBar(presentation: presentation),
              SizedBox(
                key: const Key('e04-map'),
                height: mapHeight,
                width: double.infinity,
                child: _LiveChangeMap(
                  change: widget.change,
                  enabled: widget.enableNativeMap,
                ),
              ),
              Expanded(
                child: _UpdatePanel(
                  presentation: presentation,
                  impact: widget.change.impact,
                  compact: compact,
                  short: short,
                  acknowledging: _acknowledging,
                  error: _error,
                  onAcknowledge: _acknowledge,
                  onContact: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: widget.contactScreenBuilder,
                    ),
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.presentation});

  final _ChangePresentation presentation;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('e04-topbar'),
    height: DriverE04E06Metrics.topBarHeight,
    padding: const EdgeInsets.symmetric(
      horizontal: DriverE04E06Metrics.topBarPaddingHorizontal,
    ),
    decoration: const BoxDecoration(
      color: RoundsColors.surface,
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    alignment: Alignment.centerLeft,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: RoundsColors.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              presentation.state,
              style: const TextStyle(
                color: RoundsColors.orange,
                fontSize: DriverE04E06Metrics.stateSize,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: .83,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          presentation.topTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: RoundsColors.ink,
            fontSize: DriverE04E06Metrics.topTitleSize,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -.38,
          ),
        ),
      ],
    ),
  );
}

class _UpdatePanel extends StatelessWidget {
  const _UpdatePanel({
    required this.presentation,
    required this.impact,
    required this.compact,
    required this.short,
    required this.acknowledging,
    required this.error,
    required this.onAcknowledge,
    required this.onContact,
  });

  final _ChangePresentation presentation;
  final DriverLiveDeliveryImpactModel impact;
  final bool compact;
  final bool short;
  final bool acknowledging;
  final String? error;
  final VoidCallback onAcknowledge;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final horizontal = compact
        ? DriverE04E06Metrics.compactPanelPaddingHorizontal
        : DriverE04E06Metrics.panelPaddingHorizontal;
    final top = short
        ? DriverE04E06Metrics.shortPanelPaddingTop
        : compact
        ? DriverE04E06Metrics.compactPanelPaddingTop
        : DriverE04E06Metrics.panelPaddingTop;
    final titleSize = short
        ? DriverE04E06Metrics.shortTitleSize
        : compact
        ? DriverE04E06Metrics.compactTitleSize
        : DriverE04E06Metrics.titleSize;
    final diffTop = short
        ? DriverE04E06Metrics.shortDiffTop
        : DriverE04E06Metrics.diffTop;
    final impactTop = short
        ? DriverE04E06Metrics.shortImpactTop
        : DriverE04E06Metrics.impactTop;
    final actionsTop = short
        ? DriverE04E06Metrics.shortActionsTop
        : DriverE04E06Metrics.actionsTop;
    final primaryHeight = short
        ? DriverE04E06Metrics.shortPrimaryHeight
        : compact
        ? DriverE04E06Metrics.compactPrimaryHeight
        : DriverE04E06Metrics.primaryHeight;
    final secondaryHeight = short
        ? DriverE04E06Metrics.shortSecondaryHeight
        : DriverE04E06Metrics.secondaryHeight;
    return ColoredBox(
      key: const Key('e04-update-panel'),
      color: RoundsColors.surface,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          horizontal,
          top,
          horizontal,
          DriverE04E06Metrics.panelPaddingBottom,
        ),
        children: [
          const Text(
            'WHAT CHANGED',
            style: TextStyle(
              color: RoundsColors.orange,
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: .83,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            presentation.headline,
            key: const Key('e04-headline'),
            style: TextStyle(
              color: RoundsColors.ink,
              fontSize: titleSize,
              height: 1.02,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.25,
            ),
          ),
          SizedBox(height: short ? 5 : 7),
          Text(
            presentation.subline,
            style: const TextStyle(
              color: RoundsColors.muted,
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: diffTop),
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: RoundsColors.line)),
            ),
            child: Column(
              children: [
                for (final item in presentation.items)
                  _DiffRow(item: item, short: short),
              ],
            ),
          ),
          SizedBox(height: impactTop),
          _ImpactRow(impact: impact, short: short),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              key: const Key('e04-error'),
              style: const TextStyle(
                color: RoundsColors.red,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          SizedBox(height: actionsTop),
          SizedBox(
            height: primaryHeight,
            child: FilledButton(
              key: const Key('e04-acknowledge'),
              onPressed: acknowledging ? null : onAcknowledge,
              style: FilledButton.styleFrom(
                backgroundColor: RoundsColors.ink,
                disabledBackgroundColor: RoundsColors.lineStrong,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    DriverE04E06Metrics.actionRadius,
                  ),
                ),
              ),
              child: acknowledging
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Acknowledge update',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: secondaryHeight,
            child: OutlinedButton(
              key: const Key('e04-contact-operations'),
              onPressed: onContact,
              style: OutlinedButton.styleFrom(
                foregroundColor: RoundsColors.inkSecondary,
                side: const BorderSide(color: RoundsColors.lineStrong),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    DriverE04E06Metrics.actionRadius,
                  ),
                ),
              ),
              child: const Text(
                'Contact Operations',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  const _DiffRow({required this.item, required this.short});

  final _DiffItem item;
  final bool short;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(
      minHeight: short
          ? DriverE04E06Metrics.shortDiffRowHeight
          : DriverE04E06Metrics.diffRowHeight,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: RoundsColors.line)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            item.label,
            style: const TextStyle(
              color: RoundsColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.before,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8A95A2),
                    fontSize: 13,
                    height: 1.35,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
              const SizedBox(
                width: 32,
                child: Text(
                  '→',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9AA5B0), fontSize: 16),
                ),
              ),
              Expanded(
                child: Text(
                  item.after,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RoundsColors.ink,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({required this.impact, required this.short});

  final DriverLiveDeliveryImpactModel impact;
  final bool short;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border.symmetric(
        horizontal: BorderSide(color: RoundsColors.line),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: short ? 9 : 12),
            child: _ImpactValue(
              label: 'ETA',
              value: _etaLabel(impact.etaAfter),
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: EdgeInsets.fromLTRB(14, short ? 9 : 12, 0, short ? 9 : 12),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: RoundsColors.line)),
            ),
            child: _ImpactValue(
              label: 'Change',
              value: _deltaLabel(impact.durationDeltaSeconds),
              warning: impact.durationDeltaSeconds > 0,
            ),
          ),
        ),
      ],
    ),
  );

  static String _etaLabel(String? value) {
    if (value == null) return 'Recalculated';
    final eta = DateTime.tryParse(value)?.toLocal();
    if (eta == null) return 'Recalculated';
    final minutes = eta.difference(DateTime.now()).inMinutes;
    if (minutes > 0 && minutes < 24 * 60) return '$minutes min';
    final hour = eta.hour.toString().padLeft(2, '0');
    final minute = eta.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _deltaLabel(int seconds) {
    if (seconds.abs() < 30) return 'No route change';
    final minutes = (seconds.abs() / 60).ceil();
    return seconds > 0 ? '+$minutes min' : '−$minutes min';
  }
}

class _ImpactValue extends StatelessWidget {
  const _ImpactValue({
    required this.label,
    required this.value,
    this.warning = false,
  });

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: RoundsColors.muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: warning ? RoundsColors.warning : RoundsColors.ink,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: -.28,
        ),
      ),
    ],
  );
}

class _LiveChangeMap extends StatelessWidget {
  const _LiveChangeMap({required this.change, required this.enabled});

  final DriverLiveDeliveryChangeModel change;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Updated delivery map showing the old and new delivery points',
    child: enabled
        ? GoogleMapsMapView(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                latitude: change.after.latitude,
                longitude: change.after.longitude,
              ),
              zoom: 15,
            ),
            initialCompassEnabled: false,
            initialMapToolbarEnabled: false,
            initialZoomControlsEnabled: false,
            onViewCreated: (controller) => unawaited(_configure(controller)),
          )
        : CustomPaint(
            key: const Key('e04-map-preview'),
            painter: const _ChangeMapPreviewPainter(),
            child: const SizedBox.expand(),
          ),
  );

  Future<void> _configure(GoogleMapViewController controller) async {
    final oldPoint = LatLng(
      latitude: change.before.latitude,
      longitude: change.before.longitude,
    );
    final newPoint = LatLng(
      latitude: change.after.latitude,
      longitude: change.after.longitude,
    );
    try {
      await controller.setMyLocationEnabled(true);
      await controller.addMarkers([
        MarkerOptions(
          position: oldPoint,
          infoWindow: const InfoWindow(title: 'Previous delivery point'),
          alpha: .58,
          zIndex: 1,
        ),
        MarkerOptions(
          position: newPoint,
          infoWindow: const InfoWindow(title: 'Updated delivery point'),
          zIndex: 2,
        ),
      ]);
      if (oldPoint.latitude == newPoint.latitude &&
          oldPoint.longitude == newPoint.longitude) {
        await controller.moveCamera(CameraUpdate.newLatLngZoom(newPoint, 15));
      } else {
        await controller.moveCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds.createBoundsFromPoints([oldPoint, newPoint]),
            padding: 54,
          ),
        );
      }
    } catch (_) {
      // The native map can be disposed while configuration is in flight.
    }
  }
}

class _ChangeMapPreviewPainter extends CustomPainter {
  const _ChangeMapPreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF1F4F5),
    );
    final block = Paint()..color = const Color(0xFFE3E8EB);
    for (final rect in <Rect>[
      Rect.fromLTWH(size.width * .05, 28, size.width * .25, 74),
      Rect.fromLTWH(size.width * .65, 38, size.width * .28, 62),
      Rect.fromLTWH(size.width * .37, size.height * .45, size.width * .22, 67),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        block,
      );
    }
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-20, size.height * .65),
      Offset(size.width + 20, size.height * .52),
      road,
    );
    canvas.drawLine(
      Offset(size.width * .47, -20),
      Offset(size.width * .72, size.height + 20),
      road,
    );
    canvas.drawCircle(
      Offset(size.width * .70, size.height * .28),
      15,
      Paint()..color = const Color(0xFFAAB4BE),
    );
    canvas.drawCircle(
      Offset(size.width * .80, size.height * .38),
      20,
      Paint()..color = RoundsColors.orange,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChangePresentation {
  const _ChangePresentation({
    required this.state,
    required this.topTitle,
    required this.headline,
    required this.subline,
    required this.items,
  });

  final String state;
  final String topTitle;
  final String headline;
  final String subline;
  final List<_DiffItem> items;

  factory _ChangePresentation.from(
    DriverLiveDeliveryChangeModel change,
    DriverRoundStopModel stop,
    DriverRoundModel round,
  ) {
    final before = change.before;
    final after = change.after;
    final items = <_DiffItem>[];
    if (before.sequence != after.sequence) {
      items.add(
        _DiffItem(
          label: 'Next stop',
          before: 'Stop ${before.sequence}',
          after: 'Stop ${after.sequence}',
        ),
      );
    }
    if (before.rawAddress != after.rawAddress ||
        before.latitude != after.latitude ||
        before.longitude != after.longitude) {
      items.add(
        _DiffItem(
          label: 'Address',
          before: before.rawAddress,
          after: after.rawAddress,
        ),
      );
    }
    if ((before.accessNote ?? '') != (after.accessNote ?? '')) {
      items.add(
        _DiffItem(
          label: 'Entrance',
          before: _instruction(before.accessNote),
          after: _instruction(after.accessNote),
        ),
      );
    }
    if (before.windowStart != after.windowStart ||
        before.windowEnd != after.windowEnd) {
      items.add(
        _DiffItem(
          label: 'Window',
          before: _window(before.windowStart, before.windowEnd),
          after: _window(after.windowStart, after.windowEnd),
        ),
      );
    }
    final single = items.length == 1 ? items.single.label : null;
    return _ChangePresentation(
      state: single == 'Next stop' ? 'ROUND UPDATED' : 'DELIVERY UPDATED',
      topTitle: single == 'Next stop'
          ? '${round.tenantName} · ${round.stops.length} stops'
          : 'Stop ${after.sequence} · ${stop.recipientName}',
      headline: switch (single) {
        'Next stop' => 'Stop order changed',
        'Address' => 'Destination changed',
        'Entrance' => 'Entrance changed',
        'Window' => 'Delivery window changed',
        _ => 'Delivery updated',
      },
      subline: switch (single) {
        'Next stop' => '${stop.recipientName} is now Stop ${after.sequence}.',
        'Address' => 'Navigate to the new delivery point.',
        'Entrance' =>
          after.accessNote?.trim().isNotEmpty == true
              ? after.accessNote!.trim()
              : 'The delivery entrance instruction was removed.',
        'Window' => 'The promised delivery window has changed.',
        _ => 'Review every change before continuing.',
      },
      items: items,
    );
  }

  static String _instruction(String? value) {
    final result = value?.trim() ?? '';
    return result.isEmpty ? 'No instruction' : result;
  }

  static String _window(String startValue, String endValue) {
    String part(String value) {
      final date = DateTime.tryParse(value)?.toLocal();
      if (date == null) return value;
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    return '${part(startValue)}–${part(endValue)}';
  }
}

class _DiffItem {
  const _DiffItem({
    required this.label,
    required this.before,
    required this.after,
  });

  final String label;
  final String before;
  final String after;
}
