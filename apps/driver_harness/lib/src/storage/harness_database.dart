import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class HarnessDatabase {
  HarnessDatabase._(this.database);

  final Database database;

  static Future<HarnessDatabase> open() async {
    final databaseRoot = await getDatabasesPath();
    final database = await openDatabase(
      path.join(databaseRoot, 'rounds_phase_zero.db'),
      version: 3,
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
        await createPodEvidenceSchema(database);
      },
      onUpgrade: (database, oldVersion, _) async {
        if (oldVersion < 2) await createCommandOutboxSchema(database);
        if (oldVersion < 3) await createPodEvidenceSchema(database);
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

  static Future<void> createPodEvidenceSchema(Database database) async {
    await database.execute('''
      create table pod_evidence_outbox (
        id text primary key,
        stop_id text not null,
        expected_stop_version integer not null,
        manifest_id text not null,
        manifest_version integer not null,
        confirmed_line_numbers_json text not null,
        local_path text not null,
        sha256 text not null,
        byte_size integer not null,
        content_type text not null,
        handoff_type text not null,
        receiver_name text,
        receiver_relationship text,
        left_at_location text,
        note text,
        media_asset_id text,
        storage_bucket text,
        storage_path text,
        tus_endpoint text,
        upload_signature text,
        upload_url text,
        upload_offset integer not null default 0,
        idempotency_key text not null unique,
        status text not null,
        attempts integer not null default 0,
        last_error text,
        created_at text not null,
        updated_at text not null
      )
    ''');
    await database.execute('''
      create index pod_evidence_flush_idx
      on pod_evidence_outbox (status, created_at)
    ''');
  }
}
