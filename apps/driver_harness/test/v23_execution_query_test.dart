import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/v23/driver_storage_lifecycle.dart';
import 'package:rounds_driver_harness/src/v23/encrypted_work_store.dart';
import 'package:rounds_driver_harness/src/v23/execution_query.dart';

import 'v23_device_registration_test.dart' as f;
import 'v23_encrypted_work_store_test.dart' as e;
import 'v23_offline_observation_test.dart' as o;

const drop = '77777777-7777-4777-8777-777777777777';
const manifest = '88888888-8888-4888-8888-888888888888';
const policy = '99999999-9999-4999-8999-999999999999';
Map<String, dynamic> projection({int version = 1}) => {
  'as_of': f.instant.toIso8601String(),
  'next_cursor': null,
  'data': {
    'view': 'execution',
    'pickup_stop_id': o.stop,
    'orders': [
      {
        'delivery_id': e.entity,
        'fulfillment_unit_id': e.entity,
        'manifest_id': manifest,
        'dropoff_stop_id': drop,
        'quantities': [
          {'line_id': manifest, 'quantity': 5},
        ],
        'preparation_state': 'ready',
      },
    ],
    'context': {
      ...o.contextJson(version: version),
      'fetched_at': f.instant.toIso8601String(),
      'stop_units': [
        {
          'stop_id': o.stop,
          'fulfillment_unit_ids': [e.entity],
        },
        {
          'stop_id': drop,
          'fulfillment_unit_ids': [e.entity],
        },
      ],
      'proof_policies': [
        {
          'fulfillment_unit_id': e.entity,
          'policy_version_id': policy,
          'policy': {
            'kind': 'proof',
            'recipient_required': ['photo'],
            'alternate_required': ['photo', 'receiver'],
            'unattended_required': ['photo', 'note'],
            'unattended_allowed': false,
            'gps_override_allowed': false,
          },
        },
      ],
      'expected_versions': [
        {
          'aggregate_type': 'assignments',
          'id': o.assignment,
          'version': version,
        },
        {'aggregate_type': 'rounds', 'id': e.entity, 'version': 1},
        {'aggregate_type': 'stops', 'id': o.stop, 'version': 1},
        {'aggregate_type': 'stops', 'id': drop, 'version': 1},
        {'aggregate_type': 'manifests', 'id': manifest, 'version': 1},
        {'aggregate_type': 'fulfillment_units', 'id': e.entity, 'version': 1},
      ],
    }..remove('proof_policy'),
  },
};
Matcher storeError(String code) =>
    throwsA(isA<EncryptedStoreException>().having((e) => e.code, 'code', code));

void main() {
  late Directory dir;
  late f.Fixture auth;
  late DriverStorageLifecycle life;
  late Map<String, dynamic> current;
  setUp(() async {
    dir = Directory.systemTemp.createTempSync('rounds-execution-query-');
    auth = f.Fixture();
    current = projection();
    auth.override = (r) async {
      if (r.url.path == '/auth/v1/user') {
        return f.jsonResponse({'id': f.subjectA});
      }
      if (r.url.path == '/v1/queries/DriverRound') {
        return f.jsonResponse(current);
      }
      return f.jsonResponse(f.wire());
    };
    life = DriverStorageLifecycle(
      registration: auth.make(),
      secrets: auth.secrets,
      resolveRoot: () async => dir,
      prepareLegacy: (_) async {},
    );
    await life.start();
  });
  tearDown(() async {
    await life.dispose();
    dir.deleteSync(recursive: true);
  });
  Future<ExecutionCaptureContext> fetch(DriverStorageLease lease) =>
      lease.fetchExecutionContext(
        bearer: 'A',
        tenantId: e.entity,
        cityId: e.entity,
        roundId: e.entity,
      );
  Future<StoredObservation> capture(
    DriverStorageLease lease, {
    int version = 1,
    String id = o.obs,
  }) async {
    final photo = o.photo();
    try {
      return await lease.recordObservation(
        o.draft(version: version, id: id),
        photo: photo,
      );
    } finally {
      photo.dispose();
    }
  }

  test(
    'registered transport -> parsed projection -> durable original context and photo',
    () async {
      var lease = await life.authenticate('A');
      final original = await fetch(lease);
      final request = auth.requests.last;
      expect(request.url.origin, 'https://api.example.test');
      expect(request.url.path, '/v1/queries/DriverRound');
      expect(request.url.queryParameters, {
        'entity_id': e.entity,
        'tenant_id': e.entity,
        'city_id': e.entity,
        'view': 'execution',
      });
      expect(request.headers['x-rounds-device-session'], f.capability);
      expect(request.followRedirects, isFalse);
      final saved = await capture(lease);
      expect(saved.state, 'local_recorded');
      expect(saved.toJson()['execution_context'], original.toJson());
      life.lock();
      lease = await life.authenticate('A');
      expect((await lease.readObservation(o.obs)).toJson(), saved.toJson());
      expect(jsonEncode(saved.toJson()), isNot(contains(f.capability)));
    },
  );
  test(
    're-fetch never rebases first context timestamp or unrelated expected versions',
    () async {
      final lease = await life.authenticate('A'), first = await fetch(lease);
      current['as_of'] = f.instant
          .add(const Duration(minutes: 1))
          .toIso8601String();
      current['data']['context']['fetched_at'] = current['as_of'];
      current['data']['context']['expected_versions'][1]['version'] = 2;
      expect((await fetch(lease)).toJson(), first.toJson());
      expect(
        (await capture(lease)).toJson()['execution_context'],
        first.toJson(),
      );
    },
  );
  test(
    'new assignment revision invalidates old capture authority without changing existing photo',
    () async {
      final lease = await life.authenticate('A');
      await fetch(lease);
      final saved = await capture(lease);
      current = projection(version: 2);
      await fetch(lease);
      await expectLater(
        lease.recordObservation(o.draft(id: o.next)),
        storeError('EXECUTION_CONTEXT_INVALIDATED'),
      );
      expect((await lease.readObservation(o.obs)).toJson(), saved.toJson());
      current = projection();
      await expectLater(
        fetch(lease),
        storeError('EXECUTION_CONTEXT_INVALIDATED'),
      );
    },
  );
  test(
    'same revision scope change fails and cannot silently revive original context',
    () async {
      final lease = await life.authenticate('A');
      await fetch(lease);
      await capture(lease);
      current['data']['context']['accepted_scope_hash'] = 'b' * 64;
      await expectLater(fetch(lease), storeError('CONTEXT_ID_CONFLICT'));
      current = projection();
      await expectLater(
        fetch(lease),
        storeError('EXECUTION_CONTEXT_INVALIDATED'),
      );
      expect((await lease.readObservation(o.obs)).state, 'local_recorded');
    },
  );
  for (final field in ['principal_id', 'tenant_id', 'city_id', 'round_id']) {
    test('wrong $field response cannot enter the cache', () async {
      final lease = await life.authenticate('A');
      current['data']['context'][field] = f.principalB;
      await expectLater(fetch(lease), f.failure('INVALID_RESPONSE'));
      await expectLater(
        lease.recordObservation(o.draft()),
        storeError('EXECUTION_CONTEXT_MISSING'),
      );
    });
  }
  test('delayed query cannot unlock or cache after sign-out', () async {
    final lease = await life.authenticate('A'),
        entered = Completer<void>(),
        release = Completer<void>();
    auth.override = (r) async {
      entered.complete();
      await release.future;
      return f.jsonResponse(current);
    };
    final pending = fetch(lease);
    final denied = expectLater(pending, throwsA(anything));
    await entered.future;
    life.lock();
    release.complete();
    await denied;
    auth.override = null;
    final again = await life.authenticate('A');
    await expectLater(
      again.recordObservation(o.draft()),
      storeError('EXECUTION_CONTEXT_MISSING'),
    );
  });
  test('newer query wins; late older query cannot replace it', () async {
    final lease = await life.authenticate('A'),
        entered = Completer<void>(),
        release = Completer<void>();
    var calls = 0;
    auth.override = (r) async {
      if (calls++ == 0) {
        entered.complete();
        await release.future;
        return f.jsonResponse(projection());
      }
      return f.jsonResponse(projection(version: 2));
    };
    final pending = fetch(lease);
    final denied = expectLater(
      pending,
      throwsA(isA<StorageLifecycleException>()),
    );
    await entered.future;
    expect((await fetch(lease)).toJson()['assignment_version'], 2);
    release.complete();
    await denied;
    await expectLater(
      lease.recordObservation(o.draft()),
      storeError('EXECUTION_CONTEXT_MISSING'),
    );
  });
  test('authorization denial locks lease and retains saved evidence', () async {
    final lease = await life.authenticate('A');
    await fetch(lease);
    await capture(lease);
    auth.override = (r) async =>
        f.jsonResponse({'code': 'NOT_AUTHORIZED'}, 403);
    await expectLater(fetch(lease), f.failure('NOT_AUTHORIZED'));
    expect(lease.requireCurrent, throwsA(isA<StorageLifecycleException>()));
    auth.override = null;
    final again = await life.authenticate('A');
    expect((await again.readObservation(o.obs)).state, 'local_recorded');
  });
  test(
    'exact generated shape and identity closure reject malformed responses',
    () {
      final changes = <void Function(Map<String, dynamic>)>[
        (v) => v['unknown'] = true,
        (v) => v['next_cursor'] = 'cursor',
        (v) => v['data']['context']['assignment_version'] = 1.5,
        (v) => v['data']['context']['expected_versions'].removeLast(),
        (v) => v['data']['context']['proof_policies'] = [],
        (v) =>
            v['data']['context']['proof_policies'][0]['policy']['unattended_allowed'] =
                'yes',
        (v) => v['data']['context']['stop_units'][1]['fulfillment_unit_ids'] = [
          f.principalB,
        ],
        (v) => v['data']['orders'][0]['quantities'][0]['quantity'] = 0.00001,
        (v) => v['data']['orders'].add(v['data']['orders'][0]),
        (v) => v['data']['context']['fetched_at'] = '2026-02-30T00:00:00Z',
      ];
      for (final change in changes) {
        final value = projection();
        change(value);
        expect(() => DriverExecutionSnapshot.parse(value), throwsA(anything));
      }
      final value = projection(),
          snapshot = DriverExecutionSnapshot.parse(value);
      value['data']['orders'].clear();
      expect(snapshot.toJson()['data']['orders'], hasLength(1));
    },
  );
}
