import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rounds_driver_harness/src/v23/command_wire.dart';
import 'package:rounds_driver_harness/src/v23/device_registration_client.dart';
import 'package:rounds_driver_harness/src/v23/driver_storage_lifecycle.dart';
import 'package:rounds_driver_harness/src/v23/encrypted_work_store.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'v23_device_registration_test.dart' as f;
import 'v23_encrypted_work_store_test.dart' as e;
import 'v23_offline_observation_test.dart' as o;

String id(int n) => '12345678-1234-4234-8234-${n.toString().padLeft(12, '0')}';
final unit1 = id(1),
    unit2 = id(2),
    manifest1 = id(3),
    manifest2 = id(4),
    drop1 = id(5),
    drop2 = id(6),
    attempt1 = id(7),
    attempt2 = id(8);
Map<String, dynamic> root(String type, String id, int version) => {
  'aggregate_type': type,
  'id': id,
  'version': version,
};
Map<String, dynamic> context() => {
  ...o.contextJson(),
  'stop_units': {
    o.stop: [unit1, unit2],
    drop1: [unit1],
    drop2: [unit2],
  },
  'expected_versions': [
    root('assignments', o.assignment, 1),
    root('rounds', e.entity, 3),
    root('stops', o.stop, 10),
    root('stops', drop1, 7),
    root('stops', drop2, 8),
    root('manifests', manifest1, 4),
    root('manifests', manifest2, 5),
    root('fulfillment_units', unit1, 1),
    root('fulfillment_units', unit2, 1),
  ],
};
Map<String, dynamic> error(String code) => {
  'code': code,
  'message_key': 'errors.test',
  'retryable': false,
  'trace_id': 'test',
};
Map<String, dynamic> receipt(Map<String, dynamic> wire, String type) {
  final p = wire['payload'] as Map;
  final roots = (wire['expected_versions'] as List)
      .map(
        (v) => <String, dynamic>{
          ...v as Map<String, dynamic>,
          'version': v['version'] + 1,
        },
      )
      .toList();
  final resources = <Map<String, dynamic>>[];
  Map<String, dynamic> data;
  if (type == 'ConfirmArrival') {
    data = {'resource': roots.single};
    resources.add(root('location_observations', id(30), 1));
    if (p['stop_id'] == drop1) {
      roots.add(root('delivery_attempts', attempt1, 2));
    }
  } else if (type == 'ConfirmPickup') {
    Map<String, dynamic> unit(String uid, String mid, int n) => {
      'id': uid,
      'version': 2,
      'delivery_id': id(40 + n),
      'manifest_id': mid,
      'parent_unit_id': null,
      'remaining_obligation_id': null,
      'state': 'collected',
      'allocated_quantities': [
        {'line_id': mid, 'quantity': n},
      ],
      'delivered_quantities': [],
      'return_quantities': [],
      'cancelled_quantities': [],
    };
    Map<String, dynamic> attempt(String aid, String uid, String stop, int n) =>
        {
          'id': aid,
          'version': 1,
          'delivery_id': id(40 + n),
          'stop_id': stop,
          'driver_id': id(60),
          'state': 'pending',
          'attempt_number': 1,
          'arrived_at': null,
          'handoff_at': null,
          'closed_at': null,
          'handoff_id': null,
          'fulfillment_unit_id': uid,
        };
    resources.addAll([
      root('delivery_attempts', attempt1, 1),
      root('delivery_attempts', attempt2, 1),
      root('custody_events', id(61), 1),
    ]);
    // Intentionally reverse server result order: binding MUST select unit1.
    data = {
      'custody_event_id': id(61),
      'collected_units': [unit(unit2, manifest2, 2), unit(unit1, manifest1, 1)],
      'attempts': [
        attempt(attempt2, unit2, drop2, 2),
        attempt(attempt1, unit1, drop1, 1),
      ],
      'remaining_units': [],
      'obligation_ids': [],
    };
  } else {
    resources.addAll([
      root('handoffs', id(62), 1),
      root('custody_events', id(63), 1),
    ]);
    data = {
      'handoff_id': id(62),
      'attempt_id': p['attempt_id'],
      'custody_event_id': id(63),
      'quantities': p['quantities'],
      'proof_policy_version_id': id(64),
    };
  }
  return {
    'command_id': wire['command_id'],
    'command_type': type,
    'state': 'committed',
    'current_versions': roots,
    'resources': resources,
    'data': data,
  };
}

void main() {
  late Directory temp;
  late f.Fixture auth;
  late DriverDeviceRegistrationClient transport;
  late RegisteredDriverDevice device;
  late EncryptedDriverStore store;
  late DateTime now;
  final stores = <EncryptedDriverStore>[];
  final received = <String, Map<String, dynamic>>{};
  late Future<http.Response> Function(http.Request) handler;
  setUp(() async {
    temp = Directory.systemTemp.createTempSync('rounds-command-queue-');
    auth = f.Fixture();
    now = o.when;
    transport = auth.make();
    device = await transport.ensureSession('A');
    handler = (request) async {
      if (request.url.path == '/auth/v1/user') {
        return f.jsonResponse({'id': f.subjectA});
      }
      if (request.url.path.startsWith('/v1/auth/')) {
        return f.jsonResponse(f.wire());
      }
      if (request.method == 'GET') {
        final result = received[request.url.queryParameters['entity_id']];
        return result == null
            ? f.jsonResponse(error('NOT_FOUND'), 404)
            : f.jsonResponse({
                'as_of': f.instant.toIso8601String(),
                'data': {'result': result},
                'next_cursor': null,
              });
      }
      final wire = jsonDecode(request.body) as Map<String, dynamic>,
          type = request.url.path.split('/').last;
      final result = received.putIfAbsent(
        wire['command_id'] as String,
        () => receipt(wire, type),
      );
      return f.jsonResponse(result);
    };
    auth.override = (request) => handler(request);
    store = await EncryptedDriverStore.open(
      device: device,
      privateParent: temp,
      secrets: auth.secrets,
      commandClock: () => now,
    );
    stores.add(store);
    await store.cacheExecutionContext(
      ExecutionCaptureContext.fromJson(context()),
    );
  });
  tearDown(() {
    for (final s in stores) {
      s.close();
    }
    stores.clear();
    received.clear();
    transport.dispose();
    temp.deleteSync(recursive: true); // Only the exact test-created fixture.
  });
  Future<void> reopen({Future<void> Function(String)? checkpoint}) async {
    store.close();
    store = await EncryptedDriverStore.open(
      device: device,
      privateParent: temp,
      secrets: auth.secrets,
      commandClock: () => now,
      checkpoint: checkpoint,
    );
    stores.add(store);
  }

  Future<void> observe(
    int n, {
    String kind = 'arrival',
    String? stop,
    List<String>? parents,
    Map<String, dynamic>? payload,
  }) async {
    await store.recordObservation(
      LocalObservationDraft(
        observationId: id(100 + n),
        assignmentId: o.assignment,
        assignmentVersion: 1,
        kind: kind,
        stopId: stop ?? o.stop,
        fulfillmentUnitId: unit1,
        observedAt: o.when.add(Duration(seconds: n)),
        observedPayload: {
          'command_payload':
              payload ??
              {
                'point': {'latitude': 13.7, 'longitude': 100.5},
                'accuracy_m': 5.0,
              },
        },
        predecessorObservationIds: parents ?? [],
      ),
    );
  }

  Future<StoredExecutionCommand> send(int n) => store.synchronizeObservation(
    id(100 + n),
    transport: transport,
    bearer: 'A',
  );
  List<http.Request> business() => auth.requests
      .where(
        (r) =>
            r.url.path.startsWith('/v1/commands/') ||
            r.url.path == '/v1/queries/CommandStatus',
      )
      .toList();
  void tick() => now = now.add(const Duration(seconds: 31));
  Future<void> pickup() async {
    await observe(1);
    await store.materializeObservation(id(101));
    await send(1);
    await observe(
      2,
      kind: 'pickup',
      parents: [id(101)],
      payload: {
        'manifest_ids': [manifest1, manifest2],
        'fulfillment_unit_ids': [unit1, unit2],
        'quantities': [
          {'line_id': manifest1, 'quantity': 1},
          {'line_id': manifest2, 'quantity': 2},
        ],
      },
    );
    await store.materializeObservation(id(102));
    await send(2);
  }

  sql.Database raw() {
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
    db.execute('PRAGMA cipher_log_level=NONE');
    db.execute('PRAGMA key="x\'$hex\'"');
    return db;
  }

  test(
    'arrival -> complete-order pickup -> own arrival -> handoff uses shuffled unit receipt and exact version pointers',
    () async {
      await pickup();
      await observe(3, stop: drop1, parents: [id(102)]);
      await store.materializeObservation(id(103));
      await send(3);
      await observe(
        4,
        kind: 'handoff',
        stop: drop1,
        parents: [id(103)],
        payload: {
          'receiver_kind': 'recipient',
          'quantities': [
            {'line_id': manifest1, 'quantity': 1},
          ],
        },
      );
      final frozen = await store.materializeObservation(id(104));
      expect((await send(4)).state, 'committed');
      expect((await send(4)).commandId, frozen.commandId);
      final post = business().last, wire = jsonDecode(post.body) as Map;
      expect(wire['payload']['attempt_id'], attempt1);
      expect(wire['expected_versions'], [
        root('delivery_attempts', attempt1, 2),
      ]);
      expect(wire['execution_fence'], {
        'assignment_id': o.assignment,
        'assignment_version': 1,
        'observation_id': id(104),
      });
      expect(post.headers['x-rounds-device-session'], f.capability);
      expect(post.headers['authorization'], 'Bearer A');
      expect(post.followRedirects, false);
      store.close();
      final db = raw();
      final probe = Process.runSync('node', [
        '--import',
        'tsx',
        'services/api/test/v23/native-command-contract-probe.ts',
        base64Encode(
          utf8.encode(
            jsonEncode(
              db
                  .select(
                    'SELECT command_type,payload_json,request_hash,server_receipt_json FROM pending_commands ORDER BY occurred_at',
                  )
                  .map((r) => Map.from(r))
                  .toList(),
            ),
          ),
        ),
      ], workingDirectory: '../..');
      expect(probe.exitCode, 0, reason: '${probe.stdout}\n${probe.stderr}');
      final binding = db.select(
        'SELECT * FROM observation_bindings WHERE observation_id=? AND payload_pointer=\'/payload/attempt_id\'',
        [id(104)],
      ).single;
      expect(binding['dependency_observation_id'], id(102));
      expect(binding['result_pointer'], '/data/attempts/1/id');
      expect(jsonDecode(binding['resolved_value_json'] as String), attempt1);
      expect(
        db.select('SELECT * FROM command_dependencies WHERE command_id=?', [
          frozen.commandId,
        ]).length,
        3,
      );
      expect(
        db.select('SELECT * FROM command_roots WHERE command_id=?', [
          frozen.commandId,
        ]).single['expected_version'],
        2,
      );
      final before = db
          .select(
            'SELECT payload_json FROM local_observations ORDER BY observation_id',
          )
          .map((r) => r['payload_json'])
          .toList();
      expect(
        jsonEncode(
          db
              .select('SELECT * FROM pending_commands')
              .map((r) => Map.from(r))
              .toList(),
        ),
        isNot(contains(f.capability)),
      );
      db.close();
      await reopen();
      expect(
        (await store.materializeObservation(id(104))).commandId,
        frozen.commandId,
      );
      expect(
        (await store.observations())
            .map((v) => canonicalNativeCommand(v.toJson()))
            .toList(),
        before
            .map((v) => canonicalNativeCommand(jsonDecode(v as String)))
            .toList(),
      );
    },
  );

  test(
    'unconfirmed predecessor blocks materialization without allocating another command',
    () async {
      await observe(1);
      await store.materializeObservation(id(101));
      await observe(2, kind: 'pickup', parents: [id(101)], payload: {});
      await expectLater(
        store.materializeObservation(id(102)),
        e.fails('DEPENDENCY_UNRESOLVED'),
      );
      expect(await store.observationCommand(id(102)), null);
      expect(business(), isEmpty);
    },
  );

  test(
    'lost POST acknowledgment reconciles same identity by GET only after retry due time',
    () async {
      await observe(1);
      final queued = await store.materializeObservation(id(101));
      final original = handler;
      handler = (r) async {
        final result = await original(r);
        if (r.method == 'POST') throw Exception('lost response');
        return result;
      };
      expect((await send(1)).state, 'unknown');
      expect((await send(1)).attempts, 1);
      await reopen();
      tick();
      expect((await send(1)).state, 'committed');
      expect(business().map((r) => r.method), ['POST', 'GET']);
      expect(
        business().last.url.queryParameters['entity_id'],
        queued.commandId,
      );
    },
  );

  test(
    'interruption before HTTP probes status then retries original bytes, never a new ID',
    () async {
      await observe(1);
      final queued = await store.materializeObservation(id(101));
      await reopen(
        checkpoint: (name) async {
          if (name == 'command_before_http') throw StateError('kill point');
        },
      );
      await expectLater(send(1), e.fails('STORAGE_IO_FAILED'));
      expect(business(), isEmpty);
      await reopen();
      expect((await send(1)).state, 'queued');
      expect(business().single.method, 'GET');
      expect((await send(1)).state, 'queued');
      expect(business().length, 1);
      tick();
      expect((await send(1)).state, 'committed');
      expect(jsonDecode(business().last.body)['command_id'], queued.commandId);
    },
  );

  for (final boundary in ['command_before_commit', 'command_queued']) {
    test(
      '$boundary interruption keeps atomic command/observation linkage',
      () async {
        await observe(1);
        await reopen(
          checkpoint: (n) async {
            if (n == boundary) throw StateError('kill point');
          },
        );
        await expectLater(
          store.materializeObservation(id(101)),
          e.fails('STORAGE_IO_FAILED'),
        );
        final prior = await store.observationCommand(id(101));
        expect(prior == null, boundary == 'command_before_commit');
        await reopen();
        final next = await store.materializeObservation(id(101));
        if (prior != null) expect(next.commandId, prior.commandId);
        expect((await send(1)).state, 'committed');
      },
    );
  }
  for (final boundary in [
    'command_before_receipt',
    'command_receipt_committed',
  ]) {
    test(
      '$boundary interruption recovers committed response without duplicate POST',
      () async {
        await observe(1);
        await store.materializeObservation(id(101));
        await reopen(
          checkpoint: (n) async {
            if (n == boundary) throw StateError('kill point');
          },
        );
        await expectLater(send(1), e.fails('STORAGE_IO_FAILED'));
        await reopen();
        expect((await send(1)).state, 'committed');
        expect(business().where((r) => r.method == 'POST').length, 1);
      },
    );
  }

  test(
    'concurrent materialization and send serialize to one ID and one POST',
    () async {
      await observe(1);
      final commands = await Future.wait([
        store.materializeObservation(id(101)),
        store.materializeObservation(id(101)),
      ]);
      expect(commands[0].commandId, commands[1].commandId);
      await Future.wait([send(1), send(1)]);
      expect(business().length, 1);
    },
  );
  test(
    'wrong response identity cannot authorize successor; original request remains frozen',
    () async {
      await observe(1);
      final queued = await store.materializeObservation(id(101));
      final original = handler;
      handler = (r) async {
        final response = await original(r);
        final value = jsonDecode(response.body) as Map;
        value['command_id'] = id(999);
        return f.jsonResponse(value);
      };
      expect((await send(1)).state, 'unknown');
      expect(
        (await store.observationCommand(id(101)))!.requestHash,
        queued.requestHash,
      );
    },
  );
  test(
    'mismatched stop in structurally valid receipt is not committed',
    () async {
      await observe(1);
      await store.materializeObservation(id(101));
      final original = handler;
      handler = (r) async {
        final response = await original(r);
        final value = jsonDecode(response.body) as Map;
        value['data']['resource']['id'] = drop2;
        return f.jsonResponse(value);
      };
      await expectLater(send(1), e.fails('INVALID_RECEIPT_BINDING'));
      expect((await store.observationCommand(id(101)))!.state, 'sending');
    },
  );
  test(
    'error response is not a rejection receipt; rejected status blocks successors',
    () async {
      await observe(1);
      final q = await store.materializeObservation(id(101));
      handler = (r) async => r.method == 'POST'
          ? f.jsonResponse(error('PICKUP_NOT_READY'), 422)
          : f.jsonResponse({
              'as_of': f.instant.toIso8601String(),
              'data': {
                'result': {
                  'command_id': q.commandId,
                  'command_type': 'ConfirmArrival',
                  'state': 'rejected',
                  'error': error('PICKUP_NOT_READY'),
                },
              },
              'next_cursor': null,
            });
      expect((await send(1)).state, 'unknown');
      tick();
      expect((await send(1)).state, 'rejected');
      await observe(2, kind: 'pickup', parents: [id(101)], payload: {});
      await expectLater(
        store.materializeObservation(id(102)),
        e.fails('DEPENDENCY_UNRESOLVED'),
      );
    },
  );
  test(
    'changed assignment never rebases unsent command or refreshes it into authority',
    () async {
      await observe(1);
      final q = await store.materializeObservation(id(101));
      await store.invalidateExecutionContext(o.assignment, 1);
      expect((await send(1)).state, 'needs_review');
      expect(business(), isEmpty);
      expect(
        (await store.materializeObservation(id(101))).requestHash,
        q.requestHash,
      );
    },
  );
  test(
    'changed assignment still reconciles an already uncertain original result',
    () async {
      await observe(1);
      await store.materializeObservation(id(101));
      final original = handler;
      handler = (r) async {
        final result = await original(r);
        if (r.method == 'POST') throw StateError('lost');
        return result;
      };
      await send(1);
      await store.invalidateExecutionContext(o.assignment, 1);
      tick();
      expect((await send(1)).state, 'committed');
      expect(business().map((r) => r.method), ['POST', 'GET']);
    },
  );
  test(
    'authorization denial locks storage and retains uncertain bytes',
    () async {
      await observe(1);
      await store.materializeObservation(id(101));
      handler = (r) async => f.jsonResponse(error('NOT_AUTHORIZED'), 403);
      await expectLater(send(1), throwsA(isA<Object>()));
      await expectLater(
        store.observationCommand(id(101)),
        e.fails('STORE_LOCKED'),
      );
    },
  );
  test(
    'late successful response after sign-out does not write a receipt',
    () async {
      await observe(1);
      await store.materializeObservation(id(101));
      final gate = Completer<http.Response>();
      final started = Completer<void>();
      handler = (_) {
        started.complete();
        return gate.future;
      };
      final pending = send(1);
      await started.future;
      final request = business().single;
      transport.lock();
      gate.complete(
        f.jsonResponse(
          receipt(
            jsonDecode(request.body) as Map<String, dynamic>,
            'ConfirmArrival',
          ),
        ),
      );
      await expectLater(pending, throwsA(isA<Object>()));
      final db = raw();
      expect(
        db
            .select('SELECT state,server_receipt_json FROM pending_commands')
            .single['state'],
        'sending',
      );
      expect(
        db
            .select('SELECT server_receipt_json FROM pending_commands')
            .single['server_receipt_json'],
        null,
      );
      db.close();
    },
  );
  test(
    'foreign transport cannot use the current registered device capability',
    () async {
      await observe(1);
      await store.materializeObservation(id(101));
      final other = auth.make(origin: 'https://other.example.test');
      expect(
        (await store.synchronizeObservation(
          id(101),
          transport: other,
          bearer: 'A',
        )).state,
        'unknown',
      );
      expect(business(), isEmpty);
      other.dispose();
    },
  );
  test(
    'generic old observations and proof/photo actions are retained, not guessed into commands',
    () async {
      await store.recordObservation(
        LocalObservationDraft(
          observationId: id(101),
          assignmentId: o.assignment,
          assignmentVersion: 1,
          kind: 'arrival',
          stopId: o.stop,
          fulfillmentUnitId: unit1,
          observedAt: o.when,
          observedPayload: {'note': 'old local data'},
        ),
      );
      await expectLater(
        store.materializeObservation(id(101)),
        e.fails('OBSERVATION_FORMAT_UNSUPPORTED'),
      );
      await observe(2, kind: 'proof', payload: {});
      await expectLater(
        store.materializeObservation(id(102)),
        e.fails('DEPENDENCY_SEQUENCE_INVALID'),
      );
      expect((await store.observations()).length, 2);
      expect(business(), isEmpty);
    },
  );
  test('caller cannot inject bound attempt/stop authority', () async {
    await observe(1, payload: {'stop_id': drop2});
    await expectLater(
      store.materializeObservation(id(101)),
      e.fails('OBSERVATION_AUTHORITY_OVERRIDE'),
    );
  });
  test(
    'transport denial invalidates the cached lease and allows explicit same-account recovery',
    () async {
      await observe(1);
      await store.materializeObservation(id(101));
      store.close();
      final life = DriverStorageLifecycle(
        registration: transport,
        secrets: auth.secrets,
        resolveRoot: () async => temp,
        prepareLegacy: (_) async {},
      );
      await life.start();
      final lease = await life.authenticate('A');
      final original = handler;
      handler = (r) async => r.url.path.startsWith('/v1/commands/')
          ? f.jsonResponse(error('NOT_AUTHORIZED'), 403)
          : original(r);
      await expectLater(
        lease.synchronizeObservation(id(101), bearer: 'A'),
        e.fails('STORE_LOCKED'),
      );
      expect(lease.requireCurrent, throwsA(isA<StorageLifecycleException>()));
      handler = original;
      final renewed = await life.authenticate('A');
      renewed.requireCurrent();
      expect((await renewed.observationCommand(id(101)))!.state, 'sending');
      expect(
        (await renewed.synchronizeObservation(id(101), bearer: 'A')).state,
        'queued',
      );
      await life.dispose();
    },
  );
  test(
    'expired transport capability locks instead of trapping retries in cached authentication',
    () async {
      await observe(1);
      await store.materializeObservation(id(101));
      transport.dispose();
      var networkNow = f.instant;
      transport = DriverDeviceRegistrationClient(
        authOrigin: Uri.parse('https://auth.example.test'),
        apiOrigin: Uri.parse('https://api.example.test'),
        publishableKey: 'test-key',
        store: DeviceInstallationStore(
          backend: auth.secrets,
          platform: 'android',
        ),
        client: auth.client,
        now: () => networkNow,
      );
      device = await transport.ensureSession('A');
      await reopen();
      networkNow = networkNow.add(const Duration(minutes: 16));
      await expectLater(send(1), e.fails('STORE_LOCKED'));
      expect(business(), isEmpty);
      expect(device.requireCurrentSession, f.failure('SESSION_CHANGED'));
    },
  );
  test(
    'SQLite constraint failure rolls back command, roots and observation link together',
    () async {
      await observe(1);
      store.close();
      final db = raw();
      db.execute(
        "CREATE TRIGGER fail_command_roots BEFORE INSERT ON command_roots BEGIN SELECT RAISE(ABORT,'test interruption'); END",
      );
      db.close();
      await reopen();
      await expectLater(
        store.materializeObservation(id(101)),
        e.fails('STORAGE_IO_FAILED'),
      );
      expect(await store.observationCommand(id(101)), null);
      store.close();
      final check = raw();
      expect(check.select('SELECT * FROM pending_commands'), isEmpty);
      expect(check.select('SELECT * FROM observation_bindings'), isEmpty);
      check.close();
    },
  );
  test(
    'rate limiting observes server Retry-After before asking for status',
    () async {
      await observe(1);
      await store.materializeObservation(id(101));
      handler = (_) async => http.Response(
        jsonEncode(error('RATE_LIMITED')),
        429,
        headers: {'content-type': 'application/json', 'retry-after': '60'},
      );
      expect((await send(1)).state, 'unknown');
      tick();
      await send(1);
      expect(business().length, 1);
      tick();
      await send(1);
      expect(business().last.method, 'GET');
    },
  );
  test(
    'redirect and malformed success never become receipt authority',
    () async {
      await observe(1);
      await store.materializeObservation(id(101));
      handler = (_) async => http.Response(
        '',
        302,
        headers: {'location': 'https://another.example.test'},
      );
      expect((await send(1)).state, 'unknown');
      expect(business().length, 1);
      tick();
      handler = (_) async => http.Response(
        '<html>sign in</html>',
        200,
        headers: {'content-type': 'text/html'},
      );
      expect((await send(1)).state, 'unknown');
      expect(business().last.url.origin, 'https://api.example.test');
    },
  );
  test(
    'missing receipt retries byte-identically only after status and backoff',
    () async {
      await observe(1);
      await store.materializeObservation(id(101));
      final original = handler;
      var failed = false;
      handler = (r) async {
        if (r.method == 'POST' && !failed) {
          failed = true;
          throw StateError('before delivery');
        }
        return original(r);
      };
      expect((await send(1)).state, 'unknown');
      tick();
      expect((await send(1)).state, 'queued');
      tick();
      expect((await send(1)).state, 'committed');
      expect(business().map((r) => r.method), ['POST', 'GET', 'POST']);
      expect(business().first.bodyBytes, business().last.bodyBytes);
    },
  );
  test(
    'assignment changes while status is absent never triggers a replacement POST',
    () async {
      await observe(1);
      await store.materializeObservation(id(101));
      handler = (r) async {
        if (r.method == 'POST') throw StateError('lost');
        return f.jsonResponse(error('NOT_FOUND'), 404);
      };
      await send(1);
      await store.invalidateExecutionContext(o.assignment, 1);
      tick();
      expect((await send(1)).state, 'unknown');
      tick();
      await send(1);
      expect(business().map((r) => r.method), ['POST', 'GET', 'GET']);
    },
  );
  test('another account cannot inspect or send original commands', () async {
    await observe(1);
    await store.materializeObservation(id(101));
    auth.override = (r) async => r.url.path == '/auth/v1/user'
        ? f.jsonResponse({'id': f.subjectB})
        : f.jsonResponse(f.wire(principal: f.principalB));
    final other = await transport.ensureSession('B');
    final b = await EncryptedDriverStore.open(
      device: other,
      privateParent: temp,
      secrets: auth.secrets,
    );
    stores.add(b);
    expect(await b.observationCommand(id(101)), null);
    await expectLater(
      b.synchronizeObservation(id(101), transport: transport, bearer: 'B'),
      e.fails('COMMAND_NOT_MATERIALIZED'),
    );
    await expectLater(
      store.observationCommand(id(101)),
      e.fails('STORE_LOCKED'),
    );
    expect(business(), isEmpty);
  });
  test(
    'unsupported dependency branching retains records without a partial command',
    () async {
      await observe(1);
      await store.materializeObservation(id(101));
      await send(1);
      await observe(2);
      await observe(
        3,
        kind: 'pickup',
        parents: [id(101), id(102)],
        payload: {},
      );
      await expectLater(
        store.materializeObservation(id(103)),
        e.fails('DEPENDENCY_CHAIN_UNSUPPORTED'),
      );
      expect(await store.observationCommand(id(103)), null);
      expect((await store.observations()).length, 3);
    },
  );
  test(
    'copied photo remains saved locally after an execution command, never verified',
    () async {
      final photo = o.photo();
      try {
        await store.recordObservation(
          LocalObservationDraft(
            observationId: id(101),
            assignmentId: o.assignment,
            assignmentVersion: 1,
            kind: 'arrival',
            stopId: o.stop,
            fulfillmentUnitId: unit1,
            observedAt: o.when,
            observedPayload: {
              'command_payload': {
                'point': {'latitude': 13.7, 'longitude': 100.5},
                'accuracy_m': 1,
              },
            },
          ),
          photo: photo,
        );
      } finally {
        photo.dispose();
      }
      await store.materializeObservation(id(101));
      await send(1);
      await reopen();
      expect(await store.readEvidence(e.asset), e.photo);
      store.close();
      final db = raw();
      expect(
        db
            .select('SELECT state,server_asset_id FROM local_assets')
            .single['state'],
        'saved',
      );
      expect(
        db
            .select('SELECT server_asset_id FROM local_assets')
            .single['server_asset_id'],
        null,
      );
      db.close();
    },
  );
  test(
    'corrupt frozen bytes fail closed instead of regenerating another command',
    () async {
      await observe(1);
      await store.materializeObservation(id(101));
      store.close();
      final db = raw();
      db.execute('UPDATE pending_commands SET request_hash=\'corrupt\'');
      db.close();
      await reopen();
      await expectLater(send(1), e.fails('COMMAND_REQUIRES_RECOVERY'));
      expect(business(), isEmpty);
    },
  );
  test(
    'lease forwards materialize/send but never grants access after lock',
    () async {
      store.close();
      final life = DriverStorageLifecycle(
        registration: transport,
        secrets: auth.secrets,
        resolveRoot: () async => temp,
        prepareLegacy: (_) async {},
      );
      await life.start();
      final lease = await life.authenticate('A');
      await lease.recordObservation(
        LocalObservationDraft(
          observationId: id(101),
          assignmentId: o.assignment,
          assignmentVersion: 1,
          kind: 'arrival',
          stopId: o.stop,
          fulfillmentUnitId: unit1,
          observedAt: o.when,
          observedPayload: {
            'command_payload': {
              'point': {'latitude': 13.7, 'longitude': 100.5},
              'accuracy_m': 1,
            },
          },
        ),
      );
      await lease.materializeObservation(id(101));
      expect(
        (await lease.synchronizeObservation(id(101), bearer: 'A')).state,
        'committed',
      );
      life.lock();
      await expectLater(
        lease.observationCommand(id(101)),
        throwsA(isA<StorageLifecycleException>()),
      );
      await life.dispose();
    },
  );
  test(
    'canonical bytes preserve Unicode/array order and normalize ECMAScript numeric thresholds',
    () {
      expect(
        canonicalNativeCommand({
          'z': -0.0,
          'a': [1.0, 0.000001, 0.0000001, 13.7, 'ไทย/🍀'],
        }),
        '{'
        '"a":[1,0.000001,1e-7,13.7,"ไทย/🍀"],"z":0}',
      );
      expect(
        () => canonicalNativeCommand({'x': double.nan}),
        f.failure('INVALID_COMMAND_WIRE'),
      );
      expect(
        () => canonicalNativeCommand({'x': '\ud800'}),
        f.failure('INVALID_COMMAND_WIRE'),
      );
    },
  );
}
