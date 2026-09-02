import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart';

import '../../app/driver_design_system.dart';
import '../../driver/driver_session.dart';

class RoundOverviewMap extends StatelessWidget {
  const RoundOverviewMap({
    required this.round,
    required this.enableNativeMap,
    this.currentStopSequence = 1,
    this.completedStopSequences = const <int>{},
    this.semanticsLabel = 'Active Round route map',
    super.key,
  });

  final DriverRoundModel round;
  final bool enableNativeMap;
  final int currentStopSequence;
  final Set<int> completedStopSequences;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel,
    child: enableNativeMap
        ? _NativeRoundMap(
            round: round,
            currentStopSequence: currentStopSequence,
          )
        : _RoundMapPreview(
            stopCount: round.stops.length,
            currentStopSequence: currentStopSequence,
            completedStopSequences: completedStopSequences,
          ),
  );
}

class _NativeRoundMap extends StatelessWidget {
  const _NativeRoundMap({
    required this.round,
    required this.currentStopSequence,
  });

  final DriverRoundModel round;
  final int currentStopSequence;

  @override
  Widget build(BuildContext context) {
    final first = round.stops.first;
    return GoogleMapsMapView(
      initialCameraPosition: CameraPosition(
        target: LatLng(latitude: first.latitude, longitude: first.longitude),
        zoom: 13.5,
      ),
      initialCompassEnabled: false,
      initialMapToolbarEnabled: false,
      initialZoomControlsEnabled: false,
      onViewCreated: (controller) => unawaited(_configure(controller)),
    );
  }

  Future<void> _configure(GoogleMapViewController controller) async {
    final points = round.stops
        .map(
          (stop) => LatLng(latitude: stop.latitude, longitude: stop.longitude),
        )
        .toList(growable: false);
    try {
      await controller.setMyLocationEnabled(true);
      await controller.addMarkers([
        for (final stop in round.stops)
          MarkerOptions(
            position: LatLng(
              latitude: stop.latitude,
              longitude: stop.longitude,
            ),
            infoWindow: InfoWindow(
              title: '${stop.sequence}. ${stop.recipientName}',
              snippet: stop.rawAddress,
            ),
            zIndex: stop.sequence == currentStopSequence ? 2 : 1,
          ),
      ]);
      if (points.length > 1) {
        await controller.addPolylines([
          PolylineOptions(
            points: points,
            strokeColor: Colors.white,
            strokeWidth: 10,
            zIndex: 1,
          ),
          PolylineOptions(
            points: points,
            strokeColor: RoundsColors.ink,
            strokeWidth: 5.5,
            zIndex: 2,
          ),
        ]);
        await controller.moveCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds.createBoundsFromPoints(points),
            padding: 54,
          ),
        );
      } else {
        await controller.moveCamera(
          CameraUpdate.newLatLngZoom(points.first, 14),
        );
      }
    } catch (_) {
      // The view can be disposed while asynchronous native setup completes.
    }
  }
}

class _RoundMapPreview extends StatelessWidget {
  const _RoundMapPreview({
    required this.stopCount,
    required this.currentStopSequence,
    required this.completedStopSequences,
  });

  final int stopCount;
  final int currentStopSequence;
  final Set<int> completedStopSequences;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const Key('e01-map-preview'),
    painter: _RoundMapPainter(
      stopCount: stopCount,
      currentStopSequence: currentStopSequence,
      completedStopSequences: completedStopSequences,
    ),
    child: const SizedBox.expand(),
  );
}

class _RoundMapPainter extends CustomPainter {
  const _RoundMapPainter({
    required this.stopCount,
    required this.currentStopSequence,
    required this.completedStopSequences,
  });

  final int stopCount;
  final int currentStopSequence;
  final Set<int> completedStopSequences;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF1F4F5),
    );
    final block = Paint()..color = const Color(0xFFE3E8EB);
    final park = Paint()..color = const Color(0xFFE2EEE5);
    for (final rect in [
      Rect.fromLTWH(size.width * .04, size.height * .10, size.width * .21, 58),
      Rect.fromLTWH(size.width * .33, size.height * .11, size.width * .20, 54),
      Rect.fromLTWH(size.width * .10, size.height * .72, size.width * .20, 58),
      Rect.fromLTWH(size.width * .47, size.height * .68, size.width * .22, 64),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        block,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .75,
          size.height * .10,
          size.width * .21,
          66,
        ),
        const Radius.circular(4),
      ),
      park,
    );

    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(-30, size.height * .44),
      Offset(size.width + 30, size.height * .53),
      road,
    );
    canvas.drawLine(
      Offset(size.width * .38, -20),
      Offset(size.width * .43, size.height + 20),
      road,
    );
    canvas.drawLine(
      Offset(18, size.height * .27),
      Offset(size.width - 12, size.height * .23),
      road..strokeWidth = 7,
    );

    final route = Path()
      ..moveTo(size.width * .15, size.height * .78)
      ..cubicTo(
        size.width * .23,
        size.height * .64,
        size.width * .30,
        size.height * .57,
        size.width * .40,
        size.height * .46,
      )
      ..cubicTo(
        size.width * .54,
        size.height * .34,
        size.width * .62,
        size.height * .20,
        size.width * .74,
        size.height * .31,
      );
    canvas.drawPath(
      route,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = RoundsColors.ink
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    final count = stopCount.clamp(1, 4);
    const markerOffsets = [
      Offset(.40, .46),
      Offset(.60, .27),
      Offset(.73, .42),
      Offset(.86, .68),
    ];
    for (var index = 0; index < count; index++) {
      final sequence = index + 1;
      final completed = completedStopSequences.contains(sequence);
      final current = sequence == currentStopSequence;
      final center = Offset(
        size.width * markerOffsets[index].dx,
        size.height * markerOffsets[index].dy,
      );
      canvas.drawCircle(
        center,
        current ? 17 : 14.5,
        Paint()
          ..color = completed
              ? RoundsColors.green
              : current
              ? RoundsColors.orange
              : Colors.white,
      );
      canvas.drawCircle(
        center,
        current ? 17 : 14.5,
        Paint()
          ..color = completed || current ? Colors.white : RoundsColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      if (completed) {
        final check = Path()
          ..moveTo(center.dx - 6, center.dy)
          ..lineTo(center.dx - 1.5, center.dy + 4)
          ..lineTo(center.dx + 6.5, center.dy - 5);
        canvas.drawPath(
          check,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke,
        );
        continue;
      }
      final label = TextPainter(
        text: TextSpan(
          text: '$sequence',
          style: TextStyle(
            color: current ? Colors.white : RoundsColors.ink,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, center - Offset(label.width / 2, label.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RoundMapPainter oldDelegate) =>
      oldDelegate.stopCount != stopCount ||
      oldDelegate.currentStopSequence != currentStopSequence ||
      oldDelegate.completedStopSequences != completedStopSequences;
}
