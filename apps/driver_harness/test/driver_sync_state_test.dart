import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/connectivity/driver_sync_state.dart';
import 'package:rounds_driver_harness/src/storage/harness_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'queue inspector reports real durable work by user-visible type',
    () async {
      final database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await HarnessDatabase.createCommandOutboxSchema(db);
            await HarnessDatabase.createPodEvidenceSchema(db);
            await HarnessDatabase.createDeliveryExceptionEvidenceSchema(db);
            await HarnessDatabase.createMessageMediaOutboxSchema(db);
            await db.execute('''
            create table position_samples (
              sequence integer primary key,
              captured_at text not null,
              latitude real not null,
              longitude real not null,
              accuracy_meters real not null,
              source text not null,
              heading_degrees real,
              speed_meters_per_second real,
              upload_state text not null
            )
          ''');
          },
        ),
      );
      addTearDown(database.close);

      final now = DateTime.utc(2026, 9, 3).toIso8601String();
      Future<void> command(String id, String type, String status) =>
          database.insert('driver_command_outbox', {
            'id': id,
            'command_type': type,
            'aggregate_id': 'stop-1',
            'expected_version': 1,
            'idempotency_key': id,
            'endpoint': '/test',
            'payload_json': '{}',
            'dependency_ids_json': '[]',
            'created_at': now,
            'occurred_from_device_at': now,
            'status': status,
          });
      await command('message', 'thread.send_message', 'pending');
      await command('status', 'stop.confirm_arrival', 'sending');
      await command('done', 'round.confirm_pickup', 'committed');
      await database.insert('position_samples', {
        'sequence': 1,
        'captured_at': now,
        'latitude': 13.7,
        'longitude': 100.5,
        'accuracy_meters': 4.0,
        'source': 'gps',
        'upload_state': 'pending',
      });
      await database.insert('message_media_outbox', {
        'id': 'rich-message',
        'round_id': 'round-1',
        'stop_id': 'stop-1',
        'body': 'See attachment',
        'attachments_json': '[]',
        'idempotency_key': 'rich-message',
        'status': 'uploading',
        'created_at': now,
        'updated_at': now,
      });

      final snapshot =
          await SqliteDriverQueueInspector(
            databaseFactory: () async => database,
          ).inspect(
            phase: DriverConnectionPhase.offline,
            assignedRoundAvailable: true,
            currentRouteAvailable: true,
            lastSyncedAt: DateTime.utc(2026, 9, 3, 8),
          );

      expect(snapshot.pendingMessageCount, 2);
      expect(snapshot.pendingStatusCount, 1);
      expect(snapshot.pendingTelemetryCount, 1);
      expect(snapshot.pendingProofCount, 0);
      expect(snapshot.totalPending, 4);
      expect(snapshot.assignedRoundAvailable, isTrue);
      expect(snapshot.currentRouteAvailable, isTrue);
    },
  );
}
