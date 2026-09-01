import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../storage/harness_database.dart';
import '../storage/telemetry_buffer.dart';
import 'position_sample.dart';

class OperationalLocationRecorder {
  OperationalLocationRecorder({this.onSample, this.onError});

  final void Function(DateTime capturedAt)? onSample;
  final void Function(Object error)? onError;

  HarnessDatabase? _database;
  StreamSubscription<Position>? _subscription;
  Future<void> _writeTail = Future<void>.value();
  int _nextSequence = 1;

  Future<void> start() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission was not granted.');
    }

    final database = await HarnessDatabase.open();
    _database = database;
    final rows = await database.database.rawQuery(
      'select max(sequence) as highest_sequence from position_samples',
    );
    final highest = rows.single['highest_sequence'] as int?;
    _nextSequence = (highest ?? 0) + 1;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
    _subscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(_queue, onError: onError);
  }

  void _queue(Position position) {
    final sequence = _nextSequence++;
    _writeTail = _writeTail
        .then((_) async {
          final database = _database;
          if (database == null) return;
          final capturedAt = position.timestamp.toUtc();
          await TelemetryBuffer(database).append(
            PositionSample(
              sequence: sequence,
              capturedAt: capturedAt,
              latitude: position.latitude,
              longitude: position.longitude,
              accuracyMeters: position.accuracy,
              headingDegrees: position.heading >= 0 ? position.heading : null,
              speedMetersPerSecond: position.speed >= 0 ? position.speed : null,
              source: TelemetrySource.roundsOperatingSystem,
            ),
          );
          onSample?.call(capturedAt);
        })
        .catchError((Object error) {
          onError?.call(error);
        });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _writeTail;
    await _database?.database.close();
    _database = null;
  }
}
