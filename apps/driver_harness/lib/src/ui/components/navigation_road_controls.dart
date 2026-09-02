import 'package:flutter/material.dart';

import '../../app/driver_design_system.dart';
import '../../app/generated/driver_ui_metrics.g.dart';

class NavigationRoadControlButton extends StatelessWidget {
  const NavigationRoadControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width <
        DriverReferenceViewport.compactBreakpoint;
    final size = compact
        ? DriverE02Metrics.compactRoadControlSize
        : DriverE02Metrics.roadControlSize;
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: RoundsColors.surface.withValues(alpha: .97),
        elevation: 6,
        shadowColor: const Color(0x24172238),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: RoundsColors.lineStrong),
          borderRadius: BorderRadius.circular(
            DriverE02Metrics.roadControlRadius,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Icon(
            icon,
            size: DriverE02Metrics.roadControlIconSize,
            color: RoundsColors.ink,
            semanticLabel: tooltip,
          ),
        ),
      ),
    );
  }
}

class NavigationRoadMenuButton extends StatelessWidget {
  const NavigationRoadMenuButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width <
        DriverReferenceViewport.compactBreakpoint;
    final size = compact
        ? DriverE02Metrics.compactRoadControlSize
        : DriverE02Metrics.roadControlSize;
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: RoundsColors.surface.withValues(alpha: .97),
        elevation: 6,
        shadowColor: const Color(0x24172238),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: RoundsColors.lineStrong),
          borderRadius: BorderRadius.circular(
            DriverE02Metrics.roadControlRadius,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('navigation-more'),
          onTap: onPressed,
          child: const Icon(
            Icons.more_horiz,
            color: RoundsColors.ink,
            size: DriverE02Metrics.roadControlIconSize,
            semanticLabel: 'More actions',
          ),
        ),
      ),
    );
  }
}
