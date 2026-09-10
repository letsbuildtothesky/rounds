import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/v23/device_registration_client.dart';
import 'package:rounds_driver_harness/src/v23/driver_storage_lifecycle.dart';
import 'package:rounds_driver_harness/src/v23/encrypted_work_store.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'v23_device_registration_test.dart' as fixture;
import 'v23_encrypted_work_store_test.dart' as evidence;

const assignment = '11111111-1111-4111-8111-111111111110';
const stop = '22222222-2222-4222-8222-222222222220';
const obs = '33333333-3333-4333-8333-333333333330';
const predecessor = '44444444-4444-4444-8444-444444444440';
const next = '55555555-5555-4555-8555-555555555550';
final when = DateTime.utc(2026, 9, 9, 12);
Map<String, Object?> contextJson({
  int version = 1,
  String principal = fixture.principalA,
}) => {
  'principal_id': principal,
  'tenant_id': evidence.entity,
  'city_id': evidence.entity,
  'round_id': evidence.entity,
  'assignment_id': assignment,
  'assignment_version': version,
  'accepted_scope_hash': 'a' * 64,
  'stop_units': {
    stop: [evidence.entity],
  },
  'expected_versions': [
    {'aggregate_type': 'assignments', 'id': assignment, 'version': version},
    {'aggregate_type': 'stops', 'id': stop, 'version': 3},
  ],
  'proof_policy': {'photo_required': true, 'version': 1},
  'fetched_at': when.subtract(const Duration(minutes: 1)).toIso8601String(),
};
ExecutionCaptureContext context({
  int version = 1,
  String principal = fixture.principalA,
}) => ExecutionCaptureContext.fromJson(
  contextJson(version: version, principal: principal),
);
LocalObservationDraft draft({
  String id = obs,
  int version = 1,
  String stopId = stop,
  String unitId = evidence.entity,
  String kind = 'proof',
  DateTime? at,
  List<String> parents = const [],
  Map<String, Object?>? payload,
}) => LocalObservationDraft(
  observationId: id,
  assignmentId: assignment,
  assignmentVersion: version,
  kind: kind,
  stopId: stopId,
  fulfillmentUnitId: unitId,
  observedAt: at ?? when,
  observedPayload: payload ?? {'note': 'fresh capture'},
  predecessorObservationIds: parents,
);
ObservationPhoto photo({String assetId = evidence.asset}) => ObservationPhoto(
  assetId: assetId,
  mimeType: 'image/jpeg',
  bytes: evidence.photo,
);

void main() {
  late Directory temp;
  late fixture.Fixture auth;
  late DriverDeviceRegistrationClient registration;
  late RegisteredDriverDevice device;
  final stores = <EncryptedDriverStore>[];
  final photos = <ObservationPhoto>[];
  setUp(() async {
    temp = Directory.systemTemp.createTempSync('rounds-observations-');
    auth = fixture.Fixture();
    registration = auth.make();
    device = await registration.ensureSession('A');
  });
  tearDown(() {
    for (final value in stores) {
      value.close();
    }
    for (final value in photos) {
      value.dispose();
    }
    stores.clear();
    photos.clear();
    registration.dispose();
    temp.deleteSync(recursive: true); // Only this test-created fixture.
  });
  Future<EncryptedDriverStore> open({
    Future<void> Function(String)? checkpoint,
  }) async {
    final store = await EncryptedDriverStore.open(
      device: device,
      privateParent: temp,
      secrets: auth.secrets,
      checkpoint: checkpoint,
    );
    stores.add(store);
    return store;
  }

  ObservationPhoto capture({String assetId = evidence.asset}) {
    final value = photo(assetId: assetId);
    photos.add(value);
    return value;
  }

  sql.Database raw(EncryptedDriverStore store) {
    final key =
        jsonDecode(
              auth.secrets.values.entries
                  .singleWhere((e) => e.key.startsWith('working-store.'))
                  .value,
            )
            as Map;
    final hex = base64Decode(
      key['database'] as String,
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final db = sql.sqlite3.open('${store.directory}/work.db');
    db.execute('PRAGMA cipher_log_level = NONE');
    db.execute('PRAGMA key = "x\'$hex\'"');
    return db;
  }

  test(
    'photo + immutable observation survive reopen with original context and no command',
    () async {
      final store = await open();
      await store.cacheExecutionContext(context());
      final result = await store.recordObservation(draft(), photo: capture());
      expect(result.state, 'local_recorded');
      final json = result.toJson();
      expect(json['device_id'], fixture.deviceA);
      expect(json['session_epoch'], 1);
      expect(json['execution_context'], context().toJson());
      store.close();
      final db = raw(store);
      expect(db.select('SELECT * FROM pending_commands'), isEmpty);
      expect(db.select('SELECT * FROM observation_bindings'), isEmpty);
      expect(
        db
            .select('SELECT command_id FROM local_observations')
            .single['command_id'],
        isNull,
      );
      db.close();
      final reopened = await open();
      expect((await reopened.readObservation(obs)).toJson(), json);
      expect(await reopened.readEvidence(evidence.asset), evidence.photo);
      expect(
        latin1
            .decode(File('${store.directory}/work.db').readAsBytesSync())
            .contains('fresh capture'),
        isFalse,
      );
    },
  );

  test(
    'unknown context, foreign stop or observation predating cache writes nothing',
    () async {
      final store = await open();
      await expectLater(
        store.recordObservation(draft(), photo: capture()),
        evidence.fails('EXECUTION_CONTEXT_MISSING'),
      );
      await store.cacheExecutionContext(context());
      await expectLater(
        store.recordObservation(draft(stopId: evidence.asset)),
        evidence.fails('OBSERVATION_OUTSIDE_CONTEXT'),
      );
      await expectLater(
        store.recordObservation(
          draft(at: when.subtract(const Duration(hours: 1))),
        ),
        evidence.fails('OBSERVATION_OUTSIDE_CONTEXT'),
      );
      expect(await store.observations(), isEmpty);
      expect(Directory('${store.directory}/media').listSync(), isEmpty);
    },
  );

  test('cache is immutable and mismatched principal is rejected', () async {
    final store = await open();
    await expectLater(
      store.invalidateExecutionContext(assignment, 1),
      evidence.fails('EXECUTION_CONTEXT_MISSING'),
    );
    await store.cacheExecutionContext(context());
    await store.cacheExecutionContext(context());
    await expectLater(
      store.cacheExecutionContext(
        ExecutionCaptureContext.fromJson({
          ...contextJson(),
          'accepted_scope_hash': 'b' * 64,
        }),
      ),
      evidence.fails('CONTEXT_ID_CONFLICT'),
    );
    await expectLater(
      store.cacheExecutionContext(context(principal: fixture.principalB)),
      evidence.fails('CONTEXT_OWNER_MISMATCH'),
    );
  });

  test(
    'a pickup stop may reference several independent whole-order units',
    () async {
      final store = await open();
      await store.cacheExecutionContext(
        ExecutionCaptureContext.fromJson({
          ...contextJson(),
          'stop_units': {
            stop: [evidence.entity, evidence.asset2],
          },
        }),
      );
      await store.recordObservation(draft(kind: 'pickup'));
      await store.recordObservation(
        draft(id: next, unitId: evidence.asset2, kind: 'pickup'),
      );
      expect(await store.observations(), hasLength(2));
      await expectLater(
        store.recordObservation(draft(id: predecessor, unitId: evidence.asset)),
        evidence.fails('OBSERVATION_OUTSIDE_CONTEXT'),
      );
    },
  );

  test(
    'refresh cannot rebase original observation; invalidation cannot reactivate it',
    () async {
      final store = await open();
      await store.cacheExecutionContext(context());
      await store.recordObservation(draft(), photo: capture());
      final original = (await store.readObservation(obs)).toJson();
      await store.invalidateExecutionContext(assignment, 1);
      await store.cacheExecutionContext(context());
      await store.cacheExecutionContext(context(version: 2));
      await expectLater(
        store.recordObservation(draft(id: next)),
        evidence.fails('EXECUTION_CONTEXT_INVALIDATED'),
      );
      await expectLater(
        store.recordObservation(draft(version: 2), photo: capture()),
        evidence.fails('OBSERVATION_ID_CONFLICT'),
      );
      // Exact preservation retry remains allowed, but there is still no sender.
      await store.recordObservation(draft(), photo: capture());
      await store.recordObservation(draft(id: next, version: 2));
      expect((await store.readObservation(obs)).toJson(), original);
    },
  );

  test(
    'duplicate requests serialize and changed capture/action cannot overwrite',
    () async {
      final store = await open();
      await store.cacheExecutionContext(context());
      await Future.wait([
        store.recordObservation(draft(), photo: capture()),
        store.recordObservation(draft(), photo: capture()),
      ]);
      expect(await store.observations(), hasLength(1));
      await expectLater(
        store.recordObservation(
          draft(payload: {'note': 'changed'}),
          photo: capture(),
        ),
        evidence.fails('OBSERVATION_ID_CONFLICT'),
      );
      await expectLater(
        store.recordObservation(
          draft(),
          photo: capture(assetId: evidence.asset2),
        ),
        evidence.fails('OBSERVATION_ID_CONFLICT'),
      );
      final changed = ObservationPhoto(
        assetId: evidence.asset,
        mimeType: 'image/jpeg',
        bytes: Uint8List.fromList([1]),
      );
      photos.add(changed);
      await expectLater(
        store.recordObservation(draft(), photo: changed),
        evidence.fails('OBSERVATION_ID_CONFLICT'),
      );
      expect(await store.readEvidence(evidence.asset), evidence.photo);
    },
  );

  test(
    'reusing a pre-existing photo or another observation photo is forbidden',
    () async {
      final store = await open();
      await store.cacheExecutionContext(context());
      await store.saveEvidence(
        assetId: evidence.asset,
        purposeKind: 'proof',
        purposeEntityId: evidence.entity,
        mimeType: 'image/jpeg',
        capturedAt: when,
        bytes: evidence.photo,
      );
      await expectLater(
        store.recordObservation(draft(), photo: capture()),
        evidence.fails('OBSERVATION_ASSET_CONFLICT'),
      );
      await store.recordObservation(
        draft(),
        photo: capture(assetId: evidence.asset2),
      );
      await expectLater(
        store.recordObservation(
          draft(id: next),
          photo: capture(assetId: evidence.asset2),
        ),
        evidence.fails('OBSERVATION_ASSET_CONFLICT'),
      );
    },
  );

  test(
    'parents must exist in original fence and not occur in the future',
    () async {
      final store = await open();
      await store.cacheExecutionContext(context());
      await expectLater(
        store.recordObservation(draft(parents: [predecessor])),
        evidence.fails('OBSERVATION_DEPENDENCY_MISSING'),
      );
      await store.recordObservation(
        draft(id: predecessor, at: when.add(const Duration(seconds: 1))),
      );
      await expectLater(
        store.recordObservation(draft(parents: [predecessor])),
        evidence.fails('OBSERVATION_DEPENDENCY_MISMATCH'),
      );
      await store.cacheExecutionContext(context(version: 2));
      await expectLater(
        store.recordObservation(
          draft(
            version: 2,
            at: when.add(const Duration(seconds: 2)),
            parents: [predecessor],
          ),
        ),
        evidence.fails('OBSERVATION_DEPENDENCY_MISMATCH'),
      );
      await store.recordObservation(
        draft(at: when.add(const Duration(seconds: 2)), parents: [predecessor]),
        photo: capture(),
      );
      expect(
        (await store.readObservation(
          obs,
        )).toJson()['predecessor_observation_ids'],
        [predecessor],
      );
    },
  );

  test('self and duplicate parents are refused before storage', () {
    expect(() => draft(parents: [obs]), evidence.fails('INVALID_OBSERVATION'));
    expect(
      () => draft(parents: [predecessor, predecessor]),
      evidence.fails('INVALID_OBSERVATION'),
    );
  });

  test(
    'caller mutation and disposal after invocation cannot alter frozen input',
    () async {
      final store = await open();
      final source = contextJson();
      final cached = ExecutionCaptureContext.fromJson(source);
      (source['proof_policy'] as Map)['version'] = 99;
      await store.cacheExecutionContext(cached);
      final payload = <String, Object?>{
        'data': <String>['original'],
      };
      final intent = draft(payload: payload);
      (payload['data'] as List).add('changed');
      final image = capture();
      final pending = store.recordObservation(intent, photo: image);
      image.dispose();
      final result = await pending;
      final view = result.toJson();
      view['observed_payload']['data'].add('external edit');
      expect(result.toJson()['observed_payload'], {
        'data': ['original'],
      });
      expect(
        result.toJson()['execution_context']['proof_policy']['version'],
        1,
      );
      expect(await store.readEvidence(evidence.asset), evidence.photo);
      await expectLater(
        store.recordObservation(draft(id: next), photo: image),
        evidence.fails('INVALID_EVIDENCE'),
      );
    },
  );

  for (final boundary in [
    'metadata_committed',
    'file_staged',
    'file_renamed',
    'saved_committed',
    'observation_committed',
  ]) {
    test(
      'interruption at $boundary preserves atomic intent and truthful recovery',
      () async {
        final store = await open(
          checkpoint: (point) async {
            if (point == boundary) throw StateError('injected interruption');
          },
        );
        await store.cacheExecutionContext(context());
        await expectLater(
          store.recordObservation(draft(), photo: capture()),
          evidence.fails('STORAGE_IO_FAILED'),
        );
        store.close();
        final db = raw(store);
        expect(db.select('SELECT * FROM local_observations'), hasLength(1));
        expect(db.select('SELECT * FROM local_assets'), hasLength(1));
        expect(db.select('SELECT * FROM pending_commands'), isEmpty);
        db.close();
        final reopened = await open();
        await reopened.recoverEvidence();
        final result = await reopened.readObservation(obs);
        if (boundary == 'metadata_committed') {
          expect(result.state, 'needs_recovery');
          await expectLater(
            reopened.recordObservation(draft(), photo: capture()),
            evidence.fails('EVIDENCE_REQUIRES_RECOVERY'),
          );
        } else {
          expect(result.state, 'local_recorded');
          await reopened.recordObservation(draft(), photo: capture());
          expect(await reopened.readEvidence(evidence.asset), evidence.photo);
        }
        expect(await reopened.observations(), hasLength(1));
      },
    );
  }

  test(
    'database failure rolls back BOTH observation and photo metadata',
    () async {
      final first = await open();
      await first.cacheExecutionContext(context());
      first.close();
      final db = raw(first);
      db.execute(
        "CREATE TRIGGER test_fail_asset BEFORE INSERT ON local_assets BEGIN SELECT RAISE(ABORT,'injected'); END",
      );
      db.close();
      final store = await open();
      await expectLater(
        store.recordObservation(draft(), photo: capture()),
        evidence.fails('STORAGE_IO_FAILED'),
      );
      expect(await store.observations(), isEmpty);
      store.close();
      final check = raw(store);
      expect(check.select('SELECT * FROM local_assets'), isEmpty);
      check.close();
      expect(Directory('${store.directory}/media').listSync(), isEmpty);
    },
  );

  test(
    'tampered or missing photo never leaves observation falsely recorded',
    () async {
      final store = await open();
      await store.cacheExecutionContext(context());
      await store.recordObservation(draft(), photo: capture());
      final file = File('${store.directory}/media/${evidence.asset}.sealed');
      final bytes = file.readAsBytesSync()..[40] ^= 1;
      file.writeAsBytesSync(bytes);
      expect((await store.readObservation(obs)).state, 'needs_recovery');
      file.renameSync('${file.path}.retained');
      expect((await store.readObservation(obs)).state, 'needs_recovery');
      expect(await store.observations(), hasLength(1));
    },
  );

  test(
    'cross-account cannot inspect evidence/context; original owner can recover intent',
    () async {
      final first = await open();
      await first.cacheExecutionContext(context());
      await first.recordObservation(draft(), photo: capture());
      device = await registration.ensureSession('B');
      final other = await open();
      expect(await other.observations(), isEmpty);
      await expectLater(
        other.readObservation(obs),
        evidence.fails('OBSERVATION_NOT_FOUND'),
      );
      await expectLater(
        other.recordObservation(draft()),
        evidence.fails('EXECUTION_CONTEXT_MISSING'),
      );
      await expectLater(
        first.readObservation(obs),
        evidence.fails('STORE_LOCKED'),
      );
      device = await registration.ensureSession('A');
      expect(
        (await (await open()).readObservation(obs)).state,
        'local_recorded',
      );
    },
  );

  test(
    'new device epoch cannot overwrite original session attribution on retry',
    () async {
      final first = await open();
      await first.cacheExecutionContext(context());
      await first.recordObservation(draft(), photo: capture());
      registration.lock();
      auth.override = (request) async => request.url.path == '/auth/v1/user'
          ? fixture.jsonResponse({'id': fixture.subjectA})
          : fixture.jsonResponse(fixture.wire(epoch: 2));
      device = await registration.ensureSession('A');
      final reopened = await open();
      expect(
        (await reopened.readObservation(obs)).toJson()['session_epoch'],
        1,
      );
      await expectLater(
        reopened.recordObservation(draft(), photo: capture()),
        evidence.fails('OBSERVATION_ID_CONFLICT'),
      );
    },
  );

  test(
    'lock during capture rejects late success; original owner recovers staged intent',
    () async {
      final reached = Completer<void>(), release = Completer<void>();
      final store = await open(
        checkpoint: (point) async {
          if (point == 'file_staged') {
            reached.complete();
            await release.future;
          }
        },
      );
      await store.cacheExecutionContext(context());
      final future = store.recordObservation(draft(), photo: capture());
      final assertion = expectLater(future, evidence.fails('STORE_LOCKED'));
      await reached.future;
      registration.lock();
      release.complete();
      await assertion;
      device = await registration.ensureSession('A');
      final reopened = await open();
      await reopened.recoverEvidence();
      expect((await reopened.readObservation(obs)).state, 'local_recorded');
    },
  );

  test(
    'generation-bound lifecycle lease exposes records without bypassing lock',
    () async {
      final lifecycle = DriverStorageLifecycle(
        registration: auth.make(),
        secrets: auth.secrets,
        resolveRoot: () async => temp,
        prepareLegacy: (_) async {},
      );
      try {
        await lifecycle.start();
        final lease = await lifecycle.authenticate('A');
        await lease.cacheExecutionContext(context());
        await lease.recordObservation(draft(), photo: capture());
        expect(await lease.observations(), hasLength(1));
        await lease.invalidateExecutionContext(assignment, 1);
        lifecycle.lock();
        await expectLater(
          lease.readObservation(obs),
          throwsA(isA<StorageLifecycleException>()),
        );
        final again = await lifecycle.authenticate('A');
        expect((await again.readObservation(obs)).state, 'local_recorded');
      } finally {
        await lifecycle.dispose();
      }
    },
  );

  test(
    'JSON, ID, nesting, size, roots and pagination guardrails fail closed',
    () async {
      for (final bad in [double.nan, double.infinity, Object()]) {
        expect(
          () => draft(payload: {'bad': bad}),
          evidence.fails('INVALID_OBSERVATION'),
        );
      }
      final cyclic = <String, Object?>{};
      cyclic['loop'] = cyclic;
      expect(
        () => draft(payload: cyclic),
        evidence.fails('INVALID_OBSERVATION'),
      );
      expect(
        () => draft(payload: {'big': 'x' * 65537}),
        evidence.fails('INVALID_OBSERVATION'),
      );
      expect(() => draft(id: '$obs\n'), evidence.fails('INVALID_OBSERVATION'));
      expect(
        () => ExecutionCaptureContext.fromJson({
          ...contextJson(),
          'assignment_version': 2,
        }),
        evidence.fails('INVALID_OBSERVATION'),
      );
      expect(
        () =>
            ExecutionCaptureContext.fromJson({...contextJson(), 'extra': true}),
        evidence.fails('INVALID_OBSERVATION'),
      );
      for (final invalid in ['2026-02-30T12:00:00Z', '2026-09-09T25:00:00Z']) {
        expect(
          () => ExecutionCaptureContext.fromJson({
            ...contextJson(),
            'fetched_at': invalid,
          }),
          evidence.fails('INVALID_OBSERVATION'),
        );
      }
      expect(
        () => ExecutionCaptureContext.fromJson({
          ...contextJson(),
          'accepted_scope_hash': '${'a' * 64}\n',
        }),
        evidence.fails('INVALID_OBSERVATION'),
      );
      expect(
        () => ObservationPhoto(
          assetId: evidence.asset,
          mimeType: 'image/jpeg',
          bytes: Uint8List(0),
        ),
        evidence.fails('INVALID_EVIDENCE'),
      );
      final store = await open();
      await store.cacheExecutionContext(context());
      await store.recordObservation(draft());
      await store.recordObservation(draft(id: next));
      expect(await store.observations(limit: 1), hasLength(1));
      expect(await store.observations(limit: 1, offset: 1), hasLength(1));
      expect(await store.observations(offset: 2), isEmpty);
      await expectLater(
        store.observations(limit: 101),
        evidence.fails('INVALID_OBSERVATION'),
      );
    },
  );
}
