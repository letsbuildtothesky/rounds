import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../../app/driver_design_system.dart';
import '../../app/generated/driver_ui_metrics.g.dart';
import '../../navigation/google_navigation_surface.dart';

class NavigationInstructionCard extends StatelessWidget {
  const NavigationInstructionCard({required this.instruction, super.key});

  final NavigationRoadInstruction? instruction;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width <
        DriverReferenceViewport.compactBreakpoint;
    final height = compact
        ? DriverD01Metrics.compactInstructionHeight
        : DriverD01Metrics.instructionHeight;
    final iconSize = compact
        ? DriverD01Metrics.compactInstructionIconSize
        : DriverD01Metrics.instructionIconSize;
    final distance = _formattedDistance(instruction?.distanceMeters);

    return MediaQuery.withNoTextScaling(
      child: Container(
        key: const Key('pickup-navigation-instruction'),
        constraints: BoxConstraints(minHeight: height),
        padding: EdgeInsets.only(
          left: compact
              ? DriverD01Metrics.compactInstructionPaddingLeft
              : DriverD01Metrics.instructionPaddingLeft,
          right: compact
              ? DriverD01Metrics.compactInstructionPaddingRight
              : DriverD01Metrics.instructionPaddingRight,
        ),
        decoration: BoxDecoration(
          color: RoundsColors.ink,
          borderRadius: BorderRadius.circular(
            DriverD01Metrics.instructionRadius,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E172238),
              blurRadius: 26,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              key: const Key('pickup-navigation-maneuver'),
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: RoundsColors.orange,
                borderRadius: BorderRadius.circular(
                  DriverD01Metrics.instructionIconRadius,
                ),
              ),
              child: Icon(
                _maneuverIcon(instruction?.maneuver),
                color: Colors.white,
                size: compact ? 25 : 27,
              ),
            ),
            SizedBox(
              width: compact
                  ? DriverD01Metrics.compactInstructionColumnGap
                  : DriverD01Metrics.instructionColumnGap,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    key: const Key('pickup-navigation-turn-distance'),
                    TextSpan(
                      children: [
                        TextSpan(text: distance.value),
                        if (distance.unit.isNotEmpty)
                          TextSpan(
                            text: ' ${distance.unit}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .65),
                              fontSize: DriverD01Metrics.instructionUnitSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _style(
                      color: Colors.white,
                      size: compact
                          ? DriverD01Metrics.compactInstructionDistanceSize
                          : DriverD01Metrics.instructionDistanceSize,
                      height: .95,
                      weight: DriverD01Metrics.instructionDistanceWeight,
                      tracking: DriverD01Metrics.instructionDistanceTracking,
                    ),
                  ),
                  const SizedBox(height: DriverD01Metrics.instructionTextGap),
                  Text(
                    instruction?.text ?? 'Starting guided route…',
                    key: const Key('pickup-navigation-turn-text'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _style(
                      color: Colors.white.withValues(alpha: .86),
                      size: compact
                          ? DriverD01Metrics.compactInstructionTextSize
                          : DriverD01Metrics.instructionTextSize,
                      height: DriverD01Metrics.instructionTextHeight,
                      weight: DriverD01Metrics.instructionTextWeight,
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
}

({String value, String unit}) _formattedDistance(int? meters) {
  if (meters == null) return (value: '—', unit: '');
  if (meters < 1000) return (value: '$meters', unit: 'm');
  final kilometers = meters / 1000;
  return (
    value: kilometers.toStringAsFixed(kilometers >= 10 ? 0 : 1),
    unit: 'km',
  );
}

IconData _maneuverIcon(Maneuver? maneuver) {
  final name = maneuver?.name ?? '';
  if (name.contains('UTurn')) return Icons.u_turn_left_rounded;
  if (name.contains('roundabout')) return Icons.roundabout_left_rounded;
  if (name.contains('forkLeft') ||
      name.contains('mergeLeft') ||
      name.contains('KeepLeft')) {
    return Icons.fork_left_rounded;
  }
  if (name.contains('forkRight') ||
      name.contains('mergeRight') ||
      name.contains('KeepRight')) {
    return Icons.fork_right_rounded;
  }
  if (name.contains('Left')) return Icons.turn_left_rounded;
  if (name.contains('Right')) return Icons.turn_right_rounded;
  if (name.startsWith('destination')) return Icons.home_outlined;
  return Icons.straight_rounded;
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
