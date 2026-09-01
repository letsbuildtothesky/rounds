import 'package:sqflite/sqflite.dart';

import '../navigation/navigation_intent.dart';
import 'harness_database.dart';

class SqliteNavigationIntentStore implements NavigationIntentStore {
  const SqliteNavigationIntentStore(this.database);

  final HarnessDatabase database;

  @override
  Future<NavigationIntent?> find(String stopId, int destinationVersion) async {
    final rows = await database.database.query(
      'navigation_intents',
      where: 'logical_key = ?',
      whereArgs: ['$stopId:$destinationVersion'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return NavigationIntent(
      stopId: row['stop_id']! as String,
      destinationVersion: row['destination_version']! as int,
      navSessionId: row['nav_session_id']! as String,
      destinationFingerprint: row['destination_fingerprint']! as String,
      createdAt: DateTime.parse(row['created_at']! as String),
      lastAttachedAt: DateTime.parse(row['last_attached_at']! as String),
    );
  }

  @override
  Future<void> save(NavigationIntent intent) =>
      database.database.insert('navigation_intents', {
        'logical_key': intent.logicalKey,
        'stop_id': intent.stopId,
        'destination_version': intent.destinationVersion,
        'nav_session_id': intent.navSessionId,
        'destination_fingerprint': intent.destinationFingerprint,
        'created_at': intent.createdAt.toUtc().toIso8601String(),
        'last_attached_at': intent.lastAttachedAt.toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
}
