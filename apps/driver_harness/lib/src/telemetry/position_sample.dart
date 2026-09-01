enum TelemetrySource { googleNavigation, roundsOperatingSystem }

extension TelemetrySourceWire on TelemetrySource {
  String get wireValue => switch (this) {
    TelemetrySource.googleNavigation => 'google_nav',
    TelemetrySource.roundsOperatingSystem => 'rounds_os',
  };
}

class PositionSample {
  const PositionSample({
    required this.sequence,
    required this.capturedAt,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.source,
    this.headingDegrees,
    this.speedMetersPerSecond,
  });

  final int sequence;
  final DateTime capturedAt;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final TelemetrySource source;
  final double? headingDegrees;
  final double? speedMetersPerSecond;

  Map<String, Object?> toDatabase() => {
    'sequence': sequence,
    'captured_at': capturedAt.toUtc().toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'accuracy_meters': accuracyMeters,
    'source': source.wireValue,
    'heading_degrees': headingDegrees,
    'speed_meters_per_second': speedMetersPerSecond,
    'upload_state': 'pending',
  };

  Map<String, Object?> toWire() {
    final result = <String, Object?>{
      'sequence': sequence,
      'capturedAt': capturedAt.toUtc().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
      'source': source.wireValue,
    };
    final heading = headingDegrees;
    final speed = speedMetersPerSecond;
    if (heading != null) result['headingDegrees'] = heading;
    if (speed != null) result['speedMetersPerSecond'] = speed;
    return result;
  }
}
