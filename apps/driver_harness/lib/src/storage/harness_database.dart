import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class HarnessDatabase {
  HarnessDatabase._(this.database);

  final Database database;

  static Future<HarnessDatabase> open() async {
    final databaseRoot = await getDatabasesPath();
    final database = await openDatabase(
      path.join(databaseRoot, 'rounds_phase_zero.db'),
      version: 2,
      onCreate: (database, _) async {
        await database.execute('''
          create table navigation_intents (
            logical_key text primary key,
            stop_id text not null,
            destination_version integer not null,
            nav_session_id text not null,
            destination_fingerprint text not null,
            created_at text not null,
            last_attached_at text not null
          )
        ''');
        await database.execute('''
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
        await database.execute('''
          create table harness_events (
            id integer primary key autoincrement,
            event_type text not null,
            occurred_at text not null,
            trace_id text not null,
            payload_json text not null
          )
        ''');
        await createCommandOutboxSchema(database);
      },
      onUpgrade: (database, oldVersion, _) async {
        if (oldVersion < 2) await createCommandOutboxSchema(database);
      },
    );
    return HarnessDatabase._(database);
  }

  static Future<void> createCommandOutboxSchema(Database database) async {
    await database.execute('''
      create table driver_command_outbox (
        id text primary key,
        command_type text not null,
        aggregate_id text not null,
        expected_version integer not null,
        idempotency_key text not null unique,
        endpoint text not null,
        payload_json text not null,
        dependency_ids_json text not null,
        created_at text not null,
        occurred_from_device_at text not null,
        attempts integer not null default 0,
        next_retry_at text,
        status text not null,
        last_error text
      )
    ''');
    await database.execute('''
      create index driver_command_outbox_flush_idx
      on driver_command_outbox (status, created_at)
    ''');
  }
}
