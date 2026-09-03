import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';

class DriverSplashScreen extends StatefulWidget {
  const DriverSplashScreen({
    required this.onComplete,
    this.proceedAfter = const Duration(
      milliseconds: DriverA01Metrics.proceedAfterMs,
    ),
    super.key,
  });

  final VoidCallback onComplete;
  final Duration proceedAfter;

  @override
  State<DriverSplashScreen> createState() => _DriverSplashScreenState();
}

class _DriverSplashScreenState extends State<DriverSplashScreen>
    with SingleTickerProviderStateMixin {
  static const _animationDuration = Duration(
    milliseconds:
        DriverA01Metrics.pulseDelayMs + DriverA01Metrics.pulseDurationMs,
  );

  late final AnimationController _controller;
  late final Animation<double> _wordOpacity;
  late final Animation<double> _wordOffset;
  late final Animation<double> _dotOpacity;
  late final Animation<double> _dotScale;
  late final Animation<double> _dotPulse;
  Timer? _proceedTimer;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );
    _wordOpacity = _metricTween(
      begin: 0,
      end: 1,
      delayMs: DriverA01Metrics.wordDelayMs,
      durationMs: DriverA01Metrics.wordDurationMs,
      curve: Curves.easeOutCubic,
    );
    _wordOffset = _metricTween(
      begin: DriverA01Metrics.wordInitialOffsetY,
      end: 0,
      delayMs: DriverA01Metrics.wordDelayMs,
      durationMs: DriverA01Metrics.wordDurationMs,
      curve: Curves.easeOutCubic,
    );
    _dotOpacity = _metricTween(
      begin: 0,
      end: 1,
      delayMs: DriverA01Metrics.dotDelayMs,
      durationMs: DriverA01Metrics.dotDurationMs,
      curve: Curves.easeOut,
    );
    _dotScale = _metricTween(
      begin: .45,
      end: 1,
      delayMs: DriverA01Metrics.dotDelayMs,
      durationMs: DriverA01Metrics.dotDurationMs,
      curve: Curves.easeOutBack,
    );
    _dotPulse =
        TweenSequence<double>([
          TweenSequenceItem(tween: ConstantTween(1), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1, end: 1.06), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.06, end: 1), weight: 1),
        ]).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(
              DriverA01Metrics.pulseDelayMs / _animationDuration.inMilliseconds,
              1,
              curve: Curves.easeInOut,
            ),
          ),
        );
    _controller.forward();
    _proceedTimer = Timer(widget.proceedAfter, _complete);
  }

  Animation<double> _metricTween({
    required double begin,
    required double end,
    required int delayMs,
    required int durationMs,
    required Curve curve,
  }) => Tween<double>(begin: begin, end: end).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delayMs / _animationDuration.inMilliseconds,
        (delayMs + durationMs) / _animationDuration.inMilliseconds,
        curve: curve,
      ),
    ),
  );

  void _complete() {
    if (_completed) return;
    _completed = true;
    _proceedTimer?.cancel();
    widget.onComplete();
  }

  @override
  void dispose() {
    _proceedTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: const Color(0xFFF7F8FA),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Semantics(
      button: true,
      label: 'Continue',
      child: GestureDetector(
        key: const Key('a01-splash'),
        behavior: HitTestBehavior.opaque,
        onTap: _complete,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFBFBFC), Color(0xFFF7F8FA)],
            ),
          ),
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Row(
                key: const Key('a01-brand'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Opacity(
                    opacity: _wordOpacity.value,
                    child: Transform.translate(
                      offset: Offset(0, _wordOffset.value),
                      child: const Text(
                        'Rounds',
                        key: Key('a01-word'),
                        style: TextStyle(
                          color: RoundsColors.ink,
                          fontSize: DriverA01Metrics.wordSize,
                          height: DriverA01Metrics.wordHeight,
                          fontWeight: FontWeight.w900,
                          letterSpacing: DriverA01Metrics.wordTracking,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: DriverA01Metrics.dotMarginLeft,
                      bottom: DriverA01Metrics.dotMarginBottom,
                    ),
                    child: Opacity(
                      opacity: _dotOpacity.value,
                      child: Transform.scale(
                        scale: _dotScale.value * _dotPulse.value,
                        child: Container(
                          key: const Key('a01-dot'),
                          width: DriverA01Metrics.dotSize,
                          height: DriverA01Metrics.dotSize,
                          decoration: BoxDecoration(
                            color: RoundsColors.orange,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: RoundsColors.orange.withValues(
                                  alpha: .16,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
