import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../permissions/location_access.dart';
import '../storage/harness_database.dart';
import '../storage/telemetry_buffer.dart';
import 'operational_location_settings.dart';
import 'position_sample.dart';

class OperationalLocationRecorder {
  OperationalLocationRecorder({
    this.onPositionReceived,
    this.onSample,
    this.onPersistenceError,
    this.onLocationStreamError,
  });

  final void Function(DateTime capturedAt)? onPositionReceived;
  final void Function(DateTime capturedAt)? onSample;
  final void Function(Object error)? onPersistenceError;
  final void Function(Object error)? onLocationStreamError;

  HarnessDatabase? _database;
  StreamSubscription<Position>? _subscription;
  Future<void> _writeTail = Future<void>.value();
  int _nextSequence = 1;

  Future<void> start() async {
    await requireOperationalLocationAccess();

    final database = await HarnessDatabase.open();
    _database = database;
    final rows = await database.database.rawQuery(
      'select max(sequence) as highest_sequence from position_samples',
    );
    final highest = rows.single['highest_sequence'] as int?;
    _nextSequence = (highest ?? 0) + 1;

    _subscribeToPositionStream();
  }

  Future<void> restartLocationStream() async {
    await requireOperationalLocationAccess();
    await _subscription?.cancel();
    _subscribeToPositionStream();
  }

  void _subscribeToPositionStream() {
    _subscription = Geolocator.getPositionStream(
      locationSettings: operationalLocationSettings(defaultTargetPlatform),
    ).listen(_queue, onError: onLocationStreamError);
  }

  void _queue(Position position) {
    final sequence = _nextSequence++;
    final capturedAt = position.timestamp.toUtc();
    onPositionReceived?.call(capturedAt);
    _writeTail = _writeTail
        .then((_) async {
          final database = _database;
          if (database == null) return;
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
          onPersistenceError?.call(error);
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
