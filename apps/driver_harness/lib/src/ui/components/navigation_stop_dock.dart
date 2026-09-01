import 'package:flutter/material.dart';

import '../../app/driver_design_system.dart';
import '../../app/generated/driver_ui_metrics.g.dart';

class NavigationStopDock extends StatelessWidget {
  const NavigationStopDock({
    required this.sequence,
    required this.stopCount,
    required this.recipientName,
    required this.address,
    required this.etaLabel,
    required this.distanceLabel,
    required this.showArrivalAction,
    required this.arrivalLabel,
    required this.onArrival,
    this.pendingSyncLabel,
    this.pendingSyncDetail,
    super.key,
  });

  final int sequence;
  final int stopCount;
  final String recipientName;
  final String address;
  final String etaLabel;
  final String distanceLabel;
  final bool showArrivalAction;
  final String arrivalLabel;
  final VoidCallback? onArrival;
  final String? pendingSyncLabel;
  final String? pendingSyncDetail;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width <
        DriverReferenceViewport.compactBreakpoint;
    final rowHeight = compact
        ? DriverE02Metrics.compactDockRowHeight
        : DriverE02Metrics.dockRowHeight;
    final horizontalPadding = compact
        ? DriverE02Metrics.compactDockPadding
        : DriverE02Metrics.dockPaddingHorizontal;
    final verticalPadding = compact
        ? DriverE02Metrics.compactDockPadding
        : DriverE02Metrics.dockPaddingVertical;
    final titleSize = compact
        ? DriverE02Metrics.compactTitleSize
        : DriverE02Metrics.titleSize;
    final etaSize = compact
        ? DriverE02Metrics.compactEtaSize
        : DriverE02Metrics.etaSize;

    return MediaQuery.withNoTextScaling(
      child: Material(
        key: const Key('navigation-stop-dock'),
        elevation: 12,
        color: RoundsColors.surface.withValues(alpha: .985),
        shadowColor: const Color(0x3D172238),
        shape: RoundedRectangleBorder(
          side: const BorderSide(
            color: RoundsColors.lineStrong,
            width: DriverE02Metrics.dockBorderWidth,
          ),
          borderRadius: BorderRadius.circular(DriverE02Metrics.dockRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              key: const Key('navigation-stop-row'),
              height: rowHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STOP $sequence OF $stopCount',
                            key: const Key('navigation-stop-kicker'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _style(
                              color: RoundsColors.orange,
                              size: DriverE02Metrics.kickerSize,
                              height: DriverE02Metrics.kickerHeight,
                              weight: DriverE02Metrics.kickerWeight,
                              tracking: DriverE02Metrics.kickerTracking,
                            ),
                          ),
                          const SizedBox(height: DriverE02Metrics.dockTextGap),
                          Text(
                            recipientName,
                            key: const Key('navigation-stop-title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _style(
                              color: RoundsColors.ink,
                              size: titleSize,
                              height: DriverE02Metrics.titleHeight,
                              weight: DriverE02Metrics.titleWeight,
                              tracking: DriverE02Metrics.titleTracking,
                            ),
                          ),
                          const SizedBox(height: DriverE02Metrics.dockTextGap),
                          Text(
                            address,
                            key: const Key('navigation-stop-place'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _style(
                              color: RoundsColors.muted,
                              size: DriverE02Metrics.placeSize,
                              height: DriverE02Metrics.placeHeight,
                              weight: DriverE02Metrics.placeWeight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: DriverE02Metrics.dockColumnGap),
                    Semantics(
                      label: '$etaLabel, $distanceLabel remaining',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            etaLabel,
                            key: const Key('navigation-stop-eta'),
                            style: _style(
                              color: RoundsColors.ink,
                              size: etaSize,
                              height: DriverE02Metrics.etaHeight,
                              weight: DriverE02Metrics.etaWeight,
                              tracking: DriverE02Metrics.etaTracking,
                            ),
                          ),
                          const SizedBox(height: DriverE02Metrics.dockTextGap),
                          Text(
                            distanceLabel,
                            key: const Key('navigation-stop-distance'),
                            style: _style(
                              color: RoundsColors.muted,
                              size: DriverE02Metrics.distanceSize,
                              height: DriverE02Metrics.distanceHeight,
                              weight: DriverE02Metrics.distanceWeight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showArrivalAction)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DriverE02Metrics.arrivalMarginHorizontal,
                  0,
                  DriverE02Metrics.arrivalMarginHorizontal,
                  DriverE02Metrics.arrivalMarginBottom,
                ),
                child: SizedBox(
                  height: DriverE02Metrics.arrivalHeight,
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('arrival-action'),
                    onPressed: onArrival,
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      backgroundColor: RoundsColors.green,
                      disabledBackgroundColor: const Color(0xFFD9DFE5),
                      minimumSize: const Size.fromHeight(
                        DriverE02Metrics.arrivalHeight,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          DriverE02Metrics.dockRadius - 1,
                        ),
                      ),
                    ),
                    child: Text(
                      arrivalLabel,
                      style: _style(
                        color: Colors.white,
                        size: DriverE02Metrics.arrivalSize,
                        height: 1,
                        weight: DriverE02Metrics.arrivalWeight,
                      ),
                    ),
                  ),
                ),
              ),
            if (pendingSyncLabel != null)
              SizedBox(
                height: DriverE02Metrics.pendingStatusHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DriverE02Metrics.dockColumnGap,
                    0,
                    DriverE02Metrics.dockColumnGap,
                    DriverE02Metrics.arrivalMarginBottom,
                  ),
                  child: Semantics(
                    label: pendingSyncDetail == null
                        ? pendingSyncLabel
                        : '$pendingSyncLabel. $pendingSyncDetail',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          color: RoundsColors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: DriverE02Metrics.dockTextGap),
                        Expanded(
                          child: Text(
                            pendingSyncLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: RoundsColors.warning,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

TextStyle _style({
  required Color color,
  required double size,
  required double height,
  required double weight,
  double tracking = 0,
}) => TextStyle(
  color: color,
  fontSize: size,
  height: height,
  fontWeight: _nearestFlutterWeight(weight),
  fontVariations: [FontVariation('wght', weight)],
  letterSpacing: tracking,
);

FontWeight _nearestFlutterWeight(double weight) {
  final index = (weight / 100).round().clamp(1, 9);
  return FontWeight.values[index - 1];
}
