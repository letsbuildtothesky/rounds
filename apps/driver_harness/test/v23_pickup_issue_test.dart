import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rounds_driver_harness/src/v23/device_registration_client.dart';
import 'package:rounds_driver_harness/src/v23/encrypted_work_store.dart';
import 'package:rounds_driver_harness/src/v23/execution_query.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'v23_device_registration_test.dart' as f;
import 'v23_encrypted_work_store_test.dart' as e;
import 'v23_execution_query_test.dart' as q;
import 'v23_offline_command_test.dart' as queue;
import 'v23_offline_observation_test.dart' as o;
import 'v23_pickup_query_test.dart' as p;

// Real encrypted bytes/queue/transport. Auth, vault and upstream HTTP are
// labelled doubles; the separate PostGIS test executes query -> ReportIssue.
Map<String, dynamic> issueProjection() {
  final projection =
      jsonDecode(jsonEncode(p.pickupProjection())) as Map<String, dynamic>;
  (projection['data']['execution']['context']['expected_versions'] as List).add(
    queue.root('deliveries', e.entity, 7),
  );
  return projection;
}

Map<String, dynamic> issueReceipt(
  Map<String, dynamic> wire, {
  bool held = false,
}) {
  final issue = queue.root('issues', queue.id(800), 1);
  return {
    'command_id': wire['command_id'],
    'command_type': 'ReportIssue',
    'state': 'committed',
    'resources': [issue],
    'current_versions': wire['payload']['issue_type'] == 'pickup_wait' || held
        ? []
        : [
            for (final v in wire['expected_versions'] as List)
              {...v as Map, 'version': v['version'] + 1},
          ],
    'data': {'resource': issue, 'state': 'open'},
  };
}

void main() {
  late Directory dir;
  late f.Fixture auth;
  late DriverDeviceRegistrationClient transport;
  late RegisteredDriverDevice device;
  late EncryptedDriverStore store;
  late AuthorizedPickup pickup;
  late DateTime now;
  late Future<http.Response> Function(http.Request) handler;
  final receipts = <String, Map<String, dynamic>>{};
  final obs = queue.id(701);
  String? interruptAt;
  setUp(() async {
    dir = Directory.systemTemp.createTempSync('rounds-pickup-issue-');
    auth = f.Fixture();
    transport = auth.make();
    device = await transport.ensureSession('A');
    now = o.when.add(const Duration(minutes: 1));
    interruptAt = null;
    receipts.clear();
    final snapshot = DriverPickupSnapshot.parse(issueProjection());
    pickup = (snapshot: snapshot, originalContext: snapshot.execution.context);
    store = await EncryptedDriverStore.open(
      device: device,
      privateParent: dir,
      secrets: auth.secrets,
      commandClock: () => now,
      checkpoint: (n) async {
        if (n == interruptAt) {
          interruptAt = null;
          throw StateError('injected interruption');
        }
      },
    );
    await store.cacheExecutionContext(pickup.originalContext);
    handler = (r) async {
      if (r.method == 'GET') {
        final receipt = receipts[r.url.queryParameters['entity_id']];
        return receipt == null
            ? f.jsonResponse(queue.error('NOT_FOUND'), 404)
            : f.jsonResponse({
                'as_of': f.instant.toIso8601String(),
                'next_cursor': null,
                'data': {'result': receipt},
              });
      }
      final wire = jsonDecode(r.body) as Map<String, dynamic>;
      final receipt = receipts.putIfAbsent(
        wire['command_id'] as String,
        () => r.url.path.endsWith('ReportIssue')
            ? issueReceipt(wire)
            : queue.receipt(wire, 'ConfirmArrival'),
      );
      return f.jsonResponse(receipt);
    };
    auth.override = (r) => handler(r);
  });
  tearDown(() {
    store.close();
    transport.dispose();
    dir.deleteSync(recursive: true);
  });

  LocalPickupIssueDraft draft({
    String? id,
    String reason = 'missing',
    String? delivery = e.entity,
    String? detail,
    List<Map<String, Object?>> lines = const [],
    String? parent,
  }) => LocalPickupIssueDraft(
    pickup: pickup,
    observationId: id ?? obs,
    observedAt: now,
    reason: reason,
    deliveryId: delivery,
    detail: detail,
    affectedLines: lines,
    predecessorObservationId: parent,
  );
  Future<void> reopen() async {
    store.close();
    store = await EncryptedDriverStore.open(
      device: device,
      privateParent: dir,
      secrets: auth.secrets,
      commandClock: () => now,
    );
  }

  Future<StoredExecutionCommand> send([String? id]) => store
      .synchronizeObservation(id ?? obs, transport: transport, bearer: 'A');
  List<http.Request> posts() => auth.requests
      .where((r) => r.url.path == '/v1/commands/ReportIssue')
      .toList();
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
    'actual saved report -> frozen POST/receipt with original roots; TypeScript validates Dart bytes/hash',
    () async {
      final detail = '  One package missing\nKeep this exact.  ';
      final lines = <Map<String, Object?>>[
        {'line_id': q.manifest, 'quantity': 2},
      ];
      final input = draft(detail: detail, lines: lines);
      lines[0]['quantity'] = 99;
      await store.recordPickupIssue(input);
      final command = await store.materializeObservation(obs);
      expect(command.commandType, 'ReportIssue');
      expect((await send()).state, 'committed');
      final wire = jsonDecode(posts().single.body) as Map;
      expect(wire['occurred_at'], now.toIso8601String());
      expect(wire['payload'], {
        'round_id': e.entity,
        'delivery_id': e.entity,
        'issue_type': 'package',
        'reason_code': 'missing',
        'detail': detail,
        'affected_lines': [
          {'line_id': q.manifest, 'quantity': 2},
        ],
        'asset_ids': [],
      });
      expect(wire['expected_versions'], [
        queue.root('deliveries', e.entity, 7),
        queue.root('rounds', e.entity, 1),
      ]);
      expect(wire['execution_fence'], {
        'assignment_id': o.assignment,
        'assignment_version': 1,
        'observation_id': obs,
      });
      expect(posts().single.followRedirects, false);
      expect(input.toString(), 'LocalPickupIssueDraft(redacted)');
      await reopen();
      expect(
        (await store.materializeObservation(obs)).commandId,
        command.commandId,
      );
      expect((await send()).state, 'committed');
      expect(posts(), hasLength(1));
      store.close();
      final db = raw();
      final rows = db
          .select(
            'SELECT command_type,payload_json,request_hash,server_receipt_json FROM pending_commands',
          )
          .map((r) => Map.from(r))
          .toList();
      expect(db.select('SELECT * FROM local_assets'), isEmpty);
      final probe = Process.runSync('node', [
        '--import',
        'tsx',
        'services/api/test/v23/native-command-contract-probe.ts',
        base64Encode(utf8.encode(jsonEncode(rows))),
      ], workingDirectory: '../..');
      db.close();
      expect(probe.exitCode, 0, reason: '${probe.stdout}\n${probe.stderr}');
      expect(
        File('${store.directory}/work.db').readAsStringSync,
        throwsA(anything),
      );
    },
  );

  for (final selected in [true, false]) {
    test(
      'pickup waiting selected=$selected records no invented quantity or version change',
      () async {
        await store.recordPickupIssue(
          draft(reason: 'awaiting_goods', delivery: selected ? e.entity : null),
        );
        await store.materializeObservation(obs);
        expect((await send()).state, 'committed');
        final w = jsonDecode(posts().single.body) as Map;
        expect(w['payload']['affected_lines'], isEmpty);
        expect((w['expected_versions'] as List).length, selected ? 2 : 1);
        expect(w['payload'].containsKey('delivery_id'), selected);
      },
    );
  }
  test(
    'already held report accepts zero changed roots, not synthetic increments',
    () async {
      handler = (r) async => f.jsonResponse(
        issueReceipt(jsonDecode(r.body) as Map<String, dynamic>, held: true),
      );
      await store.recordPickupIssue(draft());
      await store.materializeObservation(obs);
      expect((await send()).state, 'committed');
    },
  );
  test('concurrent observation/materialization/send reuse exact IDs', () async {
    final input = draft();
    await Future.wait([
      store.recordPickupIssue(input),
      store.recordPickupIssue(input),
    ]);
    final commands = await Future.wait([
      store.materializeObservation(obs),
      store.materializeObservation(obs),
    ]);
    expect(commands[0].commandId, commands[1].commandId);
    await Future.wait([send(), send()]);
    expect(posts(), hasLength(1));
    await expectLater(
      store.recordPickupIssue(draft(detail: 'changed')),
      e.fails('OBSERVATION_ID_CONFLICT'),
    );
  });
  for (final boundary in [
    'observation_committed',
    'command_before_commit',
    'command_queued',
    'command_before_http',
    'command_before_receipt',
    'command_receipt_committed',
  ]) {
    test(
      '$boundary interruption preserves report and command identity',
      () async {
        final input = draft();
        interruptAt = boundary;
        if (boundary == 'observation_committed') {
          await expectLater(
            store.recordPickupIssue(input),
            e.fails('STORAGE_IO_FAILED'),
          );
        } else {
          await store.recordPickupIssue(input);
          if (boundary.startsWith('command_before_commit') ||
              boundary == 'command_queued') {
            await expectLater(
              store.materializeObservation(obs),
              e.fails('STORAGE_IO_FAILED'),
            );
          } else {
            await store.materializeObservation(obs);
            await expectLater(send(), e.fails('STORAGE_IO_FAILED'));
          }
        }
        await reopen();
        await store.recordPickupIssue(input);
        final c = await store.materializeObservation(obs);
        var result = await send();
        if (result.state == 'queued') {
          now = now.add(const Duration(seconds: 31));
          result = await send();
        }
        expect(result.state, 'committed');
        expect(result.commandId, c.commandId);
        expect(posts(), hasLength(1));
      },
    );
  }
  test(
    'response loss queries original status after restart without second POST',
    () async {
      final original = handler;
      handler = (r) async {
        final reply = await original(r);
        if (r.method == 'POST') throw const SocketException('lost');
        return reply;
      };
      await store.recordPickupIssue(draft());
      final c = await store.materializeObservation(obs);
      expect((await send()).state, 'unknown');
      await reopen();
      now = now.add(const Duration(seconds: 31));
      expect((await send()).commandId, c.commandId);
      expect((await send()).state, 'committed');
      expect(posts(), hasLength(1));
    },
  );
  test(
    'missing status retries exact frozen bytes only after retry delay',
    () async {
      final original = handler;
      var fail = true;
      handler = (r) async {
        if (r.method == 'POST' && fail) {
          fail = false;
          throw const SocketException('not received');
        }
        return original(r);
      };
      await store.recordPickupIssue(draft());
      await store.materializeObservation(obs);
      await send();
      await reopen();
      now = now.add(const Duration(seconds: 31));
      expect((await send()).state, 'queued');
      expect(posts(), hasLength(1));
      now = now.add(const Duration(seconds: 31));
      expect((await send()).state, 'committed');
      expect(posts()[0].body, posts()[1].body);
    },
  );
  test(
    'new query version never rebases an original issue or cached context',
    () async {
      final refreshed = issueProjection();
      for (final root
          in refreshed['data']['execution']['context']['expected_versions']
              as List) {
        if (root['aggregate_type'] == 'deliveries') root['version'] = 99;
      }
      final snapshot = DriverPickupSnapshot.parse(refreshed);
      final original = await store.acceptOnlineExecutionContext(
        snapshot.execution.context,
      );
      pickup = (snapshot: snapshot, originalContext: original);
      await store.recordPickupIssue(draft());
      await store.materializeObservation(obs);
      await send();
      expect(
        jsonDecode(posts().single.body)['expected_versions'][0]['version'],
        7,
      );
    },
  );
  test(
    'old stored snapshot remains readable and never backfills delivery authority',
    () async {
      final old = DriverPickupSnapshot.parse(p.pickupProjection());
      store.close();
      // Isolated second empty store models a pre-change installation; no row rewrite.
      final oldDir = Directory('${dir.path}/old')..createSync();
      store = await EncryptedDriverStore.open(
        device: device,
        privateParent: oldDir,
        secrets: auth.secrets,
        commandClock: () => now,
      );
      await store.cacheExecutionContext(old.execution.context);
      final original = await store.acceptOnlineExecutionContext(
        pickup.snapshot.execution.context,
      );
      pickup = (snapshot: pickup.snapshot, originalContext: original);
      expect(() => draft(), e.fails('PICKUP_ISSUE_CONTEXT_UNAVAILABLE'));
      expect(original.toJson(), old.execution.context.toJson());
      await store.recordPickupIssue(
        draft(reason: 'awaiting_goods', delivery: null),
      );
      await store.materializeObservation(obs);
      expect((await send()).state, 'committed');
    },
  );
  test(
    'invalidated unsent report is retained locally without a POST',
    () async {
      await store.recordPickupIssue(draft());
      await store.materializeObservation(obs);
      await store.invalidateExecutionContext(o.assignment, 1);
      expect((await send()).state, 'needs_review');
      expect(posts(), isEmpty);
    },
  );
  test(
    'invalidated uncertain report may probe, never requeue after missing status',
    () async {
      final original = handler;
      handler = (r) async {
        if (r.method == 'POST') throw const SocketException('lost');
        return original(r);
      };
      await store.recordPickupIssue(draft());
      await store.materializeObservation(obs);
      await send();
      await store.invalidateExecutionContext(o.assignment, 1);
      now = now.add(const Duration(seconds: 31));
      expect((await send()).state, 'unknown');
      expect(posts(), hasLength(1));
    },
  );
  test(
    'optional real arrival predecessor must commit; report does not fabricate arrival',
    () async {
      await store.recordObservation(
        o.draft(
          id: o.obs,
          kind: 'arrival',
          payload: {
            'command_payload': {
              'point': {'latitude': 13.7, 'longitude': 100.5},
              'accuracy_m': 5,
            },
          },
        ),
      );
      await store.recordPickupIssue(draft(parent: o.obs));
      await expectLater(
        store.materializeObservation(obs),
        e.fails('DEPENDENCY_UNRESOLVED'),
      );
      await store.materializeObservation(o.obs);
      await send(o.obs);
      await store.materializeObservation(obs);
      expect((await send()).state, 'committed');
    },
  );
  test(
    'committed issue predecessor supplies only its own changed roots',
    () async {
      await store.recordPickupIssue(draft());
      await store.materializeObservation(obs);
      await send();
      now = now.add(const Duration(seconds: 1));
      final second = queue.id(702);
      await store.recordPickupIssue(
        draft(id: second, reason: 'awaiting_goods', parent: obs),
      );
      await store.materializeObservation(second);
      expect((await send(second)).state, 'committed');
      final roots = jsonDecode(posts().last.body)['expected_versions'];
      expect(roots, [
        queue.root('deliveries', e.entity, 8),
        queue.root('rounds', e.entity, 2),
      ]);
    },
  );

  test(
    'two-order snapshots accept all delivery roots or legacy none, not partial/foreign/duplicate',
    () {
      final json =
          jsonDecode(jsonEncode(q.projection())) as Map<String, dynamic>;
      final data = json['data'] as Map, context = data['context'] as Map;
      final second = queue.id(900),
          manifest = queue.id(901),
          drop = queue.id(902);
      (data['orders'] as List).add(<String, dynamic>{
        ...data['orders'][0] as Map,
        'delivery_id': second,
        'fulfillment_unit_id': second,
        'manifest_id': manifest,
        'dropoff_stop_id': drop,
        'quantities': [
          {'line_id': manifest, 'quantity': 3},
        ],
      });
      (context['stop_units'][0]['fulfillment_unit_ids'] as List).add(second);
      (context['stop_units'] as List).add({
        'stop_id': drop,
        'fulfillment_unit_ids': [second],
      });
      (context['proof_policies'] as List).add(<String, dynamic>{
        ...context['proof_policies'][0] as Map,
        'fulfillment_unit_id': second,
      });
      final roots = context['expected_versions'] as List;
      roots.addAll([
        queue.root('stops', drop, 1),
        queue.root('manifests', manifest, 1),
        queue.root('fulfillment_units', second, 1),
      ]);
      DriverExecutionSnapshot.parse(json);
      roots.add(queue.root('deliveries', e.entity, 7));
      expect(() => DriverExecutionSnapshot.parse(json), throwsA(anything));
      roots.add(queue.root('deliveries', second, 3));
      DriverExecutionSnapshot.parse(json);
      roots.last['id'] = queue.id(903);
      expect(() => DriverExecutionSnapshot.parse(json), throwsA(anything));
      roots.last['id'] = e.entity;
      expect(() => DriverExecutionSnapshot.parse(json), throwsA(anything));
    },
  );

  test(
    'captured scope cannot be substituted or decorated with command authority',
    () async {
      final input = draft();
      final record = await store.recordPickupIssue(input);
      final action =
          record.toJson()['observed_payload'] as Map<String, dynamic>;
      action['command_payload']['asset_ids'] = [queue.id(999)];
      await store.recordObservation(
        LocalObservationDraft(
          observationId: queue.id(703),
          assignmentId: o.assignment,
          assignmentVersion: 1,
          kind: 'issue',
          stopId: o.stop,
          fulfillmentUnitId: e.entity,
          observedAt: now,
          observedPayload: action,
        ),
      );
      await expectLater(
        store.materializeObservation(queue.id(703)),
        e.fails('OBSERVATION_AUTHORITY_OVERRIDE'),
      );
      final other = pickup.originalContext.toJson()
        ..['accepted_scope_hash'] = 'b' * 64;
      pickup = (
        snapshot: pickup.snapshot,
        originalContext: ExecutionCaptureContext.fromJson(other),
      );
      expect(() => draft(), e.fails('PICKUP_SCOPE_MISMATCH'));
    },
  );

  for (final reason in ['damaged', 'wrong', 'recipient_unavailable']) {
    test('$reason cannot skip required media or use pickup semantics', () {
      expect(
        () => draft(reason: reason),
        e.fails(
          reason == 'recipient_unavailable'
              ? 'INVALID_OBSERVED_ACTION'
              : 'PICKUP_ISSUE_PHOTO_REQUIRED',
        ),
      );
    });
  }
  for (final lines in <List<Map<String, Object?>>>[
    [
      {'line_id': q.manifest, 'quantity': 6},
    ],
    [
      {'line_id': q.manifest, 'quantity': 0},
    ],
    [
      {'line_id': q.manifest, 'quantity': -1},
    ],
    [
      {'line_id': q.manifest, 'quantity': 0.00001},
    ],
    [
      {'line_id': queue.id(999), 'quantity': 1},
    ],
    [
      {'line_id': q.manifest, 'quantity': 1},
      {'line_id': q.manifest, 'quantity': 1},
    ],
  ]) {
    test('invalid or unowned measured quantities are refused: $lines', () {
      expect(() => draft(lines: lines), throwsA(anything));
    });
  }
  test(
    'no selected order means no measured quantity; unknown order refused',
    () {
      expect(
        () => draft(
          reason: 'awaiting_goods',
          delivery: null,
          lines: [
            {'line_id': q.manifest, 'quantity': 1},
          ],
        ),
        e.fails('INVALID_OBSERVED_QUANTITY'),
      );
      expect(
        () => draft(delivery: queue.id(999)),
        e.fails('OBSERVATION_OUTSIDE_CONTEXT'),
      );
      expect(
        () => draft(detail: 'a' * 241),
        e.fails('INVALID_OBSERVED_ACTION'),
      );
    },
  );
  for (final mutation in [
    'foreignRoot',
    'regression',
    'resourceMismatch',
    'wrongType',
    'waitingMutation',
  ]) {
    test('invalid receipt $mutation cannot become committed', () async {
      handler = (r) async {
        final result = issueReceipt(jsonDecode(r.body) as Map<String, dynamic>);
        switch (mutation) {
          case 'foreignRoot':
            result['current_versions'][0]['id'] = queue.id(999);
          case 'regression':
            result['current_versions'][0]['version'] = 7;
          case 'resourceMismatch':
            result['data']['resource'] = queue.root('issues', queue.id(999), 1);
          case 'wrongType':
            result['command_type'] = 'ConfirmPickup';
          case 'waitingMutation':
            result['current_versions'] = [queue.root('rounds', e.entity, 2)];
        }
        return f.jsonResponse(result);
      };
      await store.recordPickupIssue(
        draft(
          reason: mutation == 'waitingMutation' ? 'awaiting_goods' : 'missing',
        ),
      );
      await store.materializeObservation(obs);
      try {
        expect((await send()).state, 'unknown');
      } on EncryptedStoreException catch (error) {
        expect(error.code, 'INVALID_RECEIPT_BINDING');
      }
      expect((await store.observationCommand(obs))!.state, isNot('committed'));
    });
  }
  test(
    'session revocation while response is pending cannot acknowledge into a locked store',
    () async {
      final started = Completer<void>(), release = Completer<http.Response>();
      handler = (r) {
        started.complete();
        return release.future;
      };
      await store.recordPickupIssue(draft());
      await store.materializeObservation(obs);
      final sending = send();
      final check = expectLater(sending, throwsA(anything));
      await started.future;
      transport.lock();
      release.complete(
        f.jsonResponse(
          issueReceipt(jsonDecode(posts().single.body) as Map<String, dynamic>),
        ),
      );
      await check;
    },
  );
}
