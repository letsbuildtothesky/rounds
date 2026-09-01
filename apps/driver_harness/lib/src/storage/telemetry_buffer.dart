import 'package:sqflite/sqflite.dart';

import '../telemetry/position_sample.dart';
import 'harness_database.dart';

class TelemetryBuffer {
  const TelemetryBuffer(this.database);

  final HarnessDatabase database;

  Future<void> append(PositionSample sample) => database.database.insert(
    'position_samples',
    sample.toDatabase(),
    conflictAlgorithm: ConflictAlgorithm.ignore,
  );

  Future<List<Map<String, Object?>>> pending({int limit = 200}) =>
      database.database.query(
        'position_samples',
        where: 'upload_state = ?',
        whereArgs: ['pending'],
        orderBy: 'sequence asc',
        limit: limit,
      );

  Future<void> acknowledgeThrough(int watermark) => database.database.update(
    'position_samples',
    {'upload_state': 'uploaded'},
    where: 'sequence <= ?',
    whereArgs: [watermark],
  );
}
