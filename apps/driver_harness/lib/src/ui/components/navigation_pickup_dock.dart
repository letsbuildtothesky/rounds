import 'package:flutter/material.dart';

import '../../app/driver_design_system.dart';
import '../../app/generated/driver_ui_metrics.g.dart';

class NavigationPickupDock extends StatelessWidget {
  const NavigationPickupDock({
    required this.pickupName,
    required this.address,
    required this.etaLabel,
    required this.distanceLabel,
    required this.showArrivalAction,
    required this.onArrival,
    super.key,
  });

  final String pickupName;
  final String address;
  final String etaLabel;
  final String distanceLabel;
  final bool showArrivalAction;
  final VoidCallback onArrival;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width <
        DriverReferenceViewport.compactBreakpoint;
    final rowHeight = compact
        ? DriverD01Metrics.compactDockRowHeight
        : DriverD01Metrics.dockRowHeight;
    final padding = compact
        ? DriverD01Metrics.compactDockPadding
        : DriverD01Metrics.dockPaddingHorizontal;

    return MediaQuery.withNoTextScaling(
      child: Material(
        key: const Key('pickup-navigation-dock'),
        elevation: 12,
        color: RoundsColors.surface.withValues(alpha: .985),
        shadowColor: const Color(0x3D172238),
        shape: RoundedRectangleBorder(
          side: const BorderSide(
            color: RoundsColors.lineStrong,
            width: DriverD01Metrics.dockBorderWidth,
          ),
          borderRadius: BorderRadius.circular(DriverD01Metrics.dockRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              key: const Key('pickup-navigation-row'),
              height: rowHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: padding,
                  vertical: compact
                      ? padding
                      : DriverD01Metrics.dockPaddingVertical,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            showArrivalAction ? 'ALMOST THERE' : 'PICKUP',
                            key: const Key('pickup-navigation-kicker'),
                            maxLines: 1,
                            style: _style(
                              color: RoundsColors.orange,
                              size: DriverD01Metrics.kickerSize,
                              height: DriverD01Metrics.kickerHeight,
                              weight: DriverD01Metrics.kickerWeight,
                              tracking: DriverD01Metrics.kickerTracking,
                            ),
                          ),
                          const SizedBox(height: DriverD01Metrics.dockTextGap),
                          Text(
                            pickupName,
                            key: const Key('pickup-navigation-title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _style(
                              color: RoundsColors.ink,
                              size: compact
                                  ? DriverD01Metrics.compactTitleSize
                                  : DriverD01Metrics.titleSize,
                              height: DriverD01Metrics.titleHeight,
                              weight: DriverD01Metrics.titleWeight,
                              tracking: DriverD01Metrics.titleTracking,
                            ),
                          ),
                          const SizedBox(height: DriverD01Metrics.dockTextGap),
                          Text(
                            showArrivalAction ? 'Entrance ahead' : address,
                            key: const Key('pickup-navigation-place'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _style(
                              color: RoundsColors.muted,
                              size: DriverD01Metrics.placeSize,
                              height: DriverD01Metrics.placeHeight,
                              weight: DriverD01Metrics.placeWeight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: DriverD01Metrics.dockColumnGap),
                    Semantics(
                      label: '$etaLabel, $distanceLabel to pickup',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            etaLabel,
                            key: const Key('pickup-navigation-eta'),
                            style: _style(
                              color: RoundsColors.ink,
                              size: compact
                                  ? DriverD01Metrics.compactEtaSize
                                  : DriverD01Metrics.etaSize,
                              height: DriverD01Metrics.etaHeight,
                              weight: DriverD01Metrics.etaWeight,
                              tracking: DriverD01Metrics.etaTracking,
                            ),
                          ),
                          const SizedBox(height: DriverD01Metrics.dockTextGap),
                          Text(
                            distanceLabel,
                            key: const Key('pickup-navigation-distance'),
                            style: _style(
                              color: RoundsColors.muted,
                              size: DriverD01Metrics.distanceSize,
                              height: DriverD01Metrics.distanceHeight,
                              weight: DriverD01Metrics.distanceWeight,
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
                  DriverD01Metrics.arrivalMarginHorizontal,
                  0,
                  DriverD01Metrics.arrivalMarginHorizontal,
                  DriverD01Metrics.arrivalMarginBottom,
                ),
                child: SizedBox(
                  height: DriverD01Metrics.arrivalHeight,
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('pickup-arrival-action'),
                    onPressed: onArrival,
                    style: FilledButton.styleFrom(
                      backgroundColor: RoundsColors.green,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          DriverD01Metrics.dockRadius - 1,
                        ),
                      ),
                    ),
                    child: Text(
                      "I'm at pickup",
                      style: _style(
                        color: Colors.white,
                        size: DriverD01Metrics.arrivalSize,
                        height: 1,
                        weight: DriverD01Metrics.arrivalWeight,
                      ),
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
  fontWeight: FontWeight.values[(weight / 100).round().clamp(1, 9) - 1],
  fontVariations: [FontVariation('wght', weight)],
  letterSpacing: tracking,
);
