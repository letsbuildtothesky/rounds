import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/storage/driver_command_outbox.dart';
import 'package:rounds_driver_harness/src/storage/harness_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('pending command survives database close and reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'rounds-outbox-test-',
    );
    final databasePath = '${directory.path}/outbox.db';
    try {
      var database = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (database, _) =>
              HarnessDatabase.createCommandOutboxSchema(database),
        ),
      );
      var outbox = DriverCommandOutbox(database);
      await outbox.enqueue(
        commandType: 'stop.confirm_arrival',
        aggregateId: 'stop-1',
        expectedVersion: 4,
        idempotencyKey: 'arrival:stop-1:v4',
        endpoint: '/v1/driver/stops/stop-1/arrival',
        payload: const {},
      );
      await database.close();

      database = await databaseFactoryFfi.openDatabase(databasePath);
      outbox = DriverCommandOutbox(database);
      final restored = await outbox.readyToSend();
      expect(restored, hasLength(1));
      expect(restored.single.commandType, 'stop.confirm_arrival');
      expect(restored.single.expectedVersion, 4);
      await database.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('duplicate enqueue reuses one stable idempotency record', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) =>
            HarnessDatabase.createCommandOutboxSchema(database),
      ),
    );
    final outbox = DriverCommandOutbox(database);
    final first = await outbox.enqueue(
      commandType: 'stop.report_pickup_problem',
      aggregateId: 'stop-1',
      expectedVersion: 2,
      idempotencyKey: 'problem:stop-1:v2:missing',
      endpoint: '/v1/driver/stops/stop-1/pickup-problem',
      payload: const {'category': 'missing_item'},
    );
    final duplicate = await outbox.enqueue(
      commandType: 'stop.report_pickup_problem',
      aggregateId: 'stop-1',
      expectedVersion: 2,
      idempotencyKey: 'problem:stop-1:v2:missing',
      endpoint: '/v1/driver/stops/stop-1/pickup-problem',
      payload: const {'category': 'missing_item'},
    );
    expect(duplicate.id, first.id);
    expect(await outbox.readyToSend(), hasLength(1));

    await outbox.markCommitted(first.id);
    expect(await outbox.readyToSend(), isEmpty);
    await database.close();
  });

  test('offline Operations message remains queryable after restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'rounds-message-outbox-test-',
    );
    final databasePath = '${directory.path}/outbox.db';
    try {
      var database = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (database, _) =>
              HarnessDatabase.createCommandOutboxSchema(database),
        ),
      );
      var outbox = DriverCommandOutbox(database);
      await outbox.enqueue(
        commandType: 'thread.send_message',
        aggregateId: 'stop-1',
        expectedVersion: 1,
        idempotencyKey: 'message:stop-1:one',
        endpoint: '/v1/driver/rounds/round-1/stops/stop-1/messages',
        payload: const {'body': 'Please call me'},
      );
      await database.close();

      database = await databaseFactoryFfi.openDatabase(databasePath);
      outbox = DriverCommandOutbox(database);
      final restored = await outbox.pendingByType('thread.send_message');
      expect(restored, hasLength(1));
      expect(restored.single.payloadJson, contains('Please call me'));
      await database.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
