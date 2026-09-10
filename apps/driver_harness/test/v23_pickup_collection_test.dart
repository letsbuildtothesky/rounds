import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rounds_driver_harness/src/ui/components/pickup_collection_view.dart';
import 'package:rounds_driver_harness/src/v23/driver_storage_lifecycle.dart';
import 'package:rounds_driver_harness/src/v23/encrypted_work_store.dart';
import 'package:rounds_driver_harness/src/v23/execution_query.dart';
import 'package:rounds_driver_harness/src/v23/pickup_collection_controller.dart';
import 'package:rounds_driver_harness/src/v23/pickup_collection_route.dart';

import 'v23_device_registration_test.dart' as f;
import 'v23_encrypted_work_store_test.dart' as e;
import 'v23_execution_query_test.dart' as q;
import 'v23_offline_command_test.dart' as queue;
import 'v23_offline_observation_test.dart' as o;
import 'v23_pickup_query_test.dart' as p;

// Labelled protocol double; actual SQLCipher, store, queue and route run below.
Map<String, dynamic> committed(Map<String, dynamic> wire, String type) {
  if (type == 'ConfirmArrival') return queue.receipt(wire, type);
  final result = queue.receipt(wire, type);
  final data = result['data'] as Map<String, dynamic>;
  final unit = Map<String, dynamic>.from(
    (data['collected_units'] as List).first as Map,
  );
  unit.addAll({
    'id': e.entity,
    'delivery_id': e.entity,
    'manifest_id': q.manifest,
    'allocated_quantities': [
      {'line_id': q.manifest, 'quantity': 5},
    ],
  });
  final attempt = Map<String, dynamic>.from(
    (data['attempts'] as List).first as Map,
  );
  attempt.addAll({
    'id': queue.attempt1,
    'delivery_id': e.entity,
    'stop_id': q.drop,
    'fulfillment_unit_id': e.entity,
  });
  data['collected_units'] = [unit];
  data['attempts'] = [attempt];
  (result['resources'] as List).removeWhere((r) => r['id'] == queue.attempt2);
  return result;
}

void main() {
  late Directory dir;
  late f.Fixture auth;
  late DriverStorageLifecycle life;
  late DriverStorageLease lease;
  late AuthorizedPickup pickup;
  late DateTime now;
  late Map<String, dynamic> projection;
  final receipts = <String, Map<String, dynamic>>{};
  String? failBoundary;
  Future<http.Response> Function(http.Request)? commandHandler;
  setUp(() async {
    dir = Directory.systemTemp.createTempSync('rounds-pickup-collection-');
    auth = f.Fixture();
    now = o.when.add(const Duration(minutes: 1));
    projection = p.pickupProjection();
    receipts.clear();
    failBoundary = null;
    commandHandler = null;
    auth.override = (r) async {
      if (r.url.path == '/auth/v1/user') {
        return f.jsonResponse({'id': f.subjectA});
      }
      if (r.url.path == '/v1/queries/DriverRound') {
        return f.jsonResponse(projection);
      }
      if (r.url.path == '/v1/queries/CommandStatus') {
        final receipt = receipts[r.url.queryParameters['entity_id']];
        return receipt == null
            ? f.jsonResponse(queue.error('NOT_FOUND'), 404)
            : f.jsonResponse({
                'as_of': f.instant.toIso8601String(),
                'data': {'result': receipt},
                'next_cursor': null,
              });
      }
      if (r.url.path.startsWith('/v1/commands/')) {
        if (commandHandler != null) return commandHandler!(r);
        final wire = jsonDecode(r.body) as Map<String, dynamic>;
        final result = receipts.putIfAbsent(
          wire['command_id'] as String,
          () => committed(wire, r.url.path.split('/').last),
        );
        return f.jsonResponse(result);
      }
      return f.jsonResponse(f.wire());
    };
    life = DriverStorageLifecycle(
      registration: auth.make(),
      secrets: auth.secrets,
      resolveRoot: () async => dir,
      prepareLegacy: (_) async {},
      commandClock: () => now,
      storageCheckpoint: (name) async {
        if (name == failBoundary) {
          failBoundary = null;
          throw StateError('injected interruption');
        }
      },
    );
    await life.start();
    lease = await life.authenticate('A');
    pickup = await lease.fetchPickup(
      bearer: 'A',
      tenantId: e.entity,
      cityId: e.entity,
      roundId: e.entity,
    );
  });
  tearDown(() async {
    await life.dispose();
    dir.deleteSync(recursive: true);
  });
  Future<void> arrival({
    String id = o.obs,
    String stop = o.stop,
    String kind = 'arrival',
    bool send = true,
  }) async {
    await lease.recordObservation(
      o.draft(
        id: id,
        kind: kind,
        stopId: stop,
        payload: {
          'command_payload': {
            'point': {'latitude': 13.7, 'longitude': 100.5},
            'accuracy_m': 5,
          },
        },
      ),
    );
    if (send) {
      await lease.materializeObservation(id);
      await lease.synchronizeObservation(id, bearer: 'A');
    }
  }

  Future<PickupCollectionController> open() => PickupCollectionController.open(
    lease,
    pickup,
    arrivalObservationId: o.obs,
    clock: () => now,
  );
  Future<PickupCollectionController> ready() async {
    await arrival();
    final c = await open();
    await c.setSelected(p.parcel, true);
    return c;
  }

  List<http.Request> posts() => auth.requests
      .where((r) => r.url.path == '/v1/commands/ConfirmPickup')
      .toList();
  Future<PickupCollectionController> reopen(
    PickupCollectionController c,
  ) async {
    final id = c.id;
    c.dispose();
    life.lock();
    lease = await life.authenticate('A');
    return PickupCollectionController.resume(lease, id, clock: () => now);
  }

  test(
    'requires actual recorded pickup arrival, never query-only/fake arrival',
    () async {
      await expectLater(open(), q.storeError('PICKUP_ARRIVAL_REQUIRED'));
      expect(await lease.observations(), isEmpty);
      expect(posts(), isEmpty);
    },
  );
  for (final wrong in ['stop', 'kind', 'context']) {
    test('rejects $wrong arrival without creating a collection', () async {
      if (wrong == 'context') {
        final other = pickup.originalContext.toJson()
          ..['expected_versions'][1]['version'] = 9;
        pickup = (
          snapshot: pickup.snapshot,
          originalContext: ExecutionCaptureContext.fromJson(other),
        );
      }
      await arrival(
        stop: wrong == 'stop' ? q.drop : o.stop,
        kind: wrong == 'kind' ? 'pickup' : 'arrival',
        send: false,
      );
      await expectLater(open(), q.storeError('PICKUP_ARRIVAL_SCOPE_MISMATCH'));
    });
  }
  test(
    'selection is encrypted and restored after database/controller reopen without query',
    () async {
      final c = await ready();
      final id = c.observationId,
          queryCount = auth.requests
              .where((r) => r.url.path == '/v1/queries/DriverRound')
              .length;
      final restored = await reopen(c);
      expect(restored.selected, {p.parcel});
      expect(restored.observationId, id);
      expect(restored.canConfirm, isTrue);
      expect(
        auth.requests
            .where((r) => r.url.path == '/v1/queries/DriverRound')
            .length,
        queryCount,
      );
      expect(posts(), isEmpty);
      restored.dispose();
    },
  );
  test('missing/unknown checkbox cannot record partial pickup', () async {
    await arrival();
    final c = await open();
    await c.confirm(bearer: 'A');
    expect(c.errorCode, 'PICKUP_COLLECTION_INCOMPLETE');
    expect(c.frozen, isFalse);
    await c.setSelected(o.next, true);
    expect(c.errorCode, 'PICKUP_PACKAGE_UNKNOWN');
    expect(posts(), isEmpty);
    expect((await lease.observations()).length, 1);
    c.dispose();
  });
  test(
    'one package sends exact five items with original arrival and receipt-derived stop version',
    () async {
      final c = await ready();
      await c.confirm(bearer: 'A');
      expect(c.errorCode, isNull);
      expect(c.committed, isTrue);
      final wire = jsonDecode(posts().single.body) as Map;
      expect(wire['payload']['quantities'], [
        {'line_id': q.manifest, 'quantity': 5},
      ]);
      expect(wire['payload']['manifest_ids'], [q.manifest]);
      expect(wire['payload']['fulfillment_unit_ids'], [e.entity]);
      expect(
        wire['expected_versions'].singleWhere(
          (v) => v['aggregate_type'] == 'stops',
        )['version'],
        2,
      );
      final observation = (await lease.readObservation(
        c.observationId,
      )).toJson();
      expect(observation['predecessor_observation_ids'], [o.obs]);
      expect(observation['execution_context'], pickup.originalContext.toJson());
      await c.setSelected(p.parcel, false);
      expect(c.errorCode, 'PICKUP_ALREADY_RECORDED');
      expect(c.selected, {p.parcel});
      c.dispose();
    },
  );
  test(
    'two controllers/concurrent confirms share one observation and one command',
    () async {
      final a = await ready(), b = await open();
      expect(b.selected, {p.parcel});
      await Future.wait([
        a.confirm(bearer: 'A'),
        b.confirm(bearer: 'A'),
        a.confirm(bearer: 'A'),
      ]);
      expect(a.errorCode, isNull);
      expect(b.errorCode, isNull);
      expect(a.observationId, b.observationId);
      expect(a.command?.commandId, b.command?.commandId);
      expect(posts().length, 1);
      expect(
        (await lease.observations())
            .where((o) => o.toJson()['kind'] == 'pickup')
            .length,
        1,
      );
      a.dispose();
      b.dispose();
    },
  );
  test('new arrival cannot quietly start a second collection', () async {
    final c = await ready();
    await arrival(id: o.next, send: false);
    await expectLater(
      lease.openPickupCollection(pickup, arrivalObservationId: o.next),
      q.storeError('PICKUP_COLLECTION_CHANGED'),
    );
    expect((await open()).observationId, c.observationId);
    c.dispose();
  });
  test(
    'changed package contents fail closed, refreshed names/versions do not rebase',
    () async {
      final c = await ready();
      projection['data']['merchant'] = 'Updated label';
      projection['data']['execution']['context']['expected_versions'][1]['version'] =
          10;
      final fresh = await lease.fetchPickup(
        bearer: 'A',
        tenantId: e.entity,
        cityId: e.entity,
        roundId: e.entity,
      );
      final same = await lease.openPickupCollection(
        fresh,
        arrivalObservationId: o.obs,
      );
      expect(same.observationId, c.observationId);
      expect(same.selected, {p.parcel});
      projection['data']['orders'][0]['packages'][0]['package_id'] = o.next;
      final changed = await lease.fetchPickup(
        bearer: 'A',
        tenantId: e.entity,
        cityId: e.entity,
        roundId: e.entity,
      );
      await expectLater(
        lease.openPickupCollection(changed, arrivalObservationId: o.obs),
        q.storeError('PICKUP_COLLECTION_CHANGED'),
      );
      await c.confirm(bearer: 'A');
      expect(
        jsonDecode(posts().single.body)['expected_versions'].singleWhere(
          (v) => v['aggregate_type'] == 'rounds',
        )['version'],
        1,
      );
      c.dispose();
    },
  );
  for (final boundary in [
    'pickup_confirmation_intent_committed',
    'observation_committed',
    'command_queued',
    'command_receipt_committed',
  ]) {
    test(
      'restart after $boundary preserves confirmation ID/time and one POST',
      () async {
        final c = await ready(),
            id = c.observationId,
            at = now.toIso8601String();
        failBoundary = boundary;
        await c.confirm(bearer: 'A');
        expect(c.errorCode, 'STORAGE_IO_FAILED');
        expect(c.frozen, isTrue);
        now = now.add(const Duration(minutes: 1));
        final restored = await reopen(c);
        await restored.confirm(bearer: 'A');
        expect(restored.committed, isTrue);
        expect(restored.observationId, id);
        expect((await lease.readObservation(id)).toJson()['observed_at'], at);
        expect(posts().length, 1);
        restored.dispose();
      },
    );
  }
  test(
    'pending actual arrival retains confirmation, sends only after original parent receipt',
    () async {
      await arrival(send: false);
      final c = await open();
      await c.setSelected(p.parcel, true);
      await c.confirm(bearer: 'A');
      expect(c.state, 'local_recorded');
      expect(c.errorCode, 'DEPENDENCY_UNRESOLVED');
      expect(posts(), isEmpty);
      await lease.materializeObservation(o.obs);
      await lease.synchronizeObservation(o.obs, bearer: 'A');
      await c.confirm(bearer: 'A');
      expect(c.committed, isTrue);
      expect(posts().length, 1);
      c.dispose();
    },
  );
  test(
    'lost response: respect retry time, reopen and GET original status, never new POST',
    () async {
      final c = await ready();
      commandHandler = (r) async {
        final wire = jsonDecode(r.body) as Map<String, dynamic>;
        receipts[wire['command_id'] as String] = committed(
          wire,
          'ConfirmPickup',
        );
        throw const SocketException('simulated lost response');
      };
      await c.confirm(bearer: 'A');
      expect(c.state, 'unknown');
      expect(c.committed, isFalse);
      final count = auth.requests.length;
      await c.confirm(bearer: 'A');
      expect(auth.requests.length, count);
      now = now.add(const Duration(seconds: 31));
      final restored = await reopen(c);
      await restored.confirm(bearer: 'A');
      expect(restored.committed, isTrue);
      expect(posts().length, 1);
      expect(auth.requests.last.url.path, '/v1/queries/CommandStatus');
      restored.dispose();
    },
  );
  test(
    'authoritative rejection stays rejected across retry/reopen and cannot uncheck',
    () async {
      final c = await ready();
      commandHandler = (r) async {
        final wire = jsonDecode(r.body) as Map;
        final rejection = <String, dynamic>{
          'command_id': wire['command_id'],
          'command_type': 'ConfirmPickup',
          'state': 'rejected',
          'error': queue.error('PICKUP_NOT_READY'),
        };
        receipts[wire['command_id'] as String] = rejection;
        return f.jsonResponse(queue.error('PICKUP_NOT_READY'), 422);
      };
      await c.confirm(bearer: 'A');
      expect(c.state, 'unknown');
      now = now.add(const Duration(seconds: 31));
      await c.confirm(bearer: 'A');
      expect(c.state, 'rejected');
      expect(c.committed, isFalse);
      final restored = await reopen(c);
      await restored.confirm(bearer: 'A');
      expect(restored.state, 'rejected');
      expect(posts().length, 1);
      restored.dispose();
    },
  );
  test(
    'reassignment before intent prevents send and preserves checks',
    () async {
      final c = await ready();
      await lease.invalidateExecutionContext(o.assignment, 1);
      await c.confirm(bearer: 'A');
      expect(c.errorCode, 'EXECUTION_FENCE_CHANGED');
      expect(c.frozen, isFalse);
      expect(c.selected, {p.parcel});
      expect(posts(), isEmpty);
      c.dispose();
    },
  );
  test(
    'unsent frozen command under reassignment becomes needs_review, not pickup confirmed',
    () async {
      final c = await ready();
      failBoundary = 'command_queued';
      await c.confirm(bearer: 'A');
      await lease.invalidateExecutionContext(o.assignment, 1);
      await c.confirm(bearer: 'A');
      expect(c.state, 'needs_review');
      expect(c.committed, isFalse);
      expect(posts(), isEmpty);
      c.dispose();
    },
  );
  test(
    'uncertain commit is still reconciled by original status after reassignment',
    () async {
      final c = await ready();
      commandHandler = (r) async {
        final wire = jsonDecode(r.body) as Map<String, dynamic>;
        receipts[wire['command_id'] as String] = committed(
          wire,
          'ConfirmPickup',
        );
        throw const SocketException('lost');
      };
      await c.confirm(bearer: 'A');
      await lease.invalidateExecutionContext(o.assignment, 1);
      now = now.add(const Duration(seconds: 31));
      await c.confirm(bearer: 'A');
      expect(c.committed, isTrue);
      expect(posts().length, 1);
      c.dispose();
    },
  );
  test(
    'late response after signout never notifies success in old controller',
    () async {
      final c = await ready();
      final entered = Completer<void>(), release = Completer<void>();
      commandHandler = (r) async {
        entered.complete();
        await release.future;
        return f.jsonResponse(
          committed(
            jsonDecode(r.body) as Map<String, dynamic>,
            'ConfirmPickup',
          ),
        );
      };
      var successes = 0;
      c.addListener(() {
        if (c.committed) successes++;
      });
      final attempt = c.confirm(bearer: 'A');
      await entered.future;
      life.lock();
      release.complete();
      await expectLater(attempt, throwsA(isA<StorageLifecycleException>()));
      expect(successes, 0);
      expect(c.committed, isFalse);
      c.dispose();
    },
  );
  testWidgets(
    'approved view checkbox/confirm is wired to encrypted queue and real receipt path',
    (tester) async {
      late PickupCollectionController c;
      await tester.runAsync(() async {
        await arrival();
        c = await open();
      });
      var navigated = 0, recoveries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PickupCollectionRoute(
            controller: c,
            bearer: () => 'A',
            onBack: () {},
            onProblem: () {},
            onCommitted: () {
              navigated++;
            },
            onRecovery: (_) {
              recoveries++;
            },
          ),
        ),
      );
      expect(find.byType(PickupCollectionView), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('One physical parcel'));
        await waitIdle(c);
      });
      await tester.pump();
      expect(c.selected, {p.parcel});
      await tester.runAsync(() async {
        await tester.tap(find.text('Confirm 1 package'));
        await waitIdle(c);
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      expect(c.committed, isTrue);
      expect(navigated, 1);
      expect(recoveries, 0);
      expect(posts().length, 1);
      expect(find.text('Pickup confirmed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  test(
    'all actual parcels are required; two checked parcels still send five items',
    () async {
      projection['data']['orders'][0]['packages'] = [
        {
          'package_id': p.parcel,
          'label': 'Parcel A',
          'contents': [
            {'line_id': q.manifest, 'quantity': 2},
          ],
        },
        {
          'package_id': o.next,
          'label': 'Parcel B',
          'contents': [
            {'line_id': q.manifest, 'quantity': 3},
          ],
        },
      ];
      pickup = await lease.fetchPickup(
        bearer: 'A',
        tenantId: e.entity,
        cityId: e.entity,
        roundId: e.entity,
      );
      final c = await ready();
      expect(c.canConfirm, isFalse);
      await c.confirm(bearer: 'A');
      expect(posts(), isEmpty);
      await c.setSelected(o.next, true);
      await c.confirm(bearer: 'A');
      expect(c.committed, isTrue);
      expect(jsonDecode(posts().single.body)['payload']['quantities'], [
        {'line_id': q.manifest, 'quantity': 5},
      ]);
      c.dispose();
    },
  );
  test(
    'no-package order remains an explicit UI gap, not an invented package',
    () async {
      projection['data']['orders'][0]['packages'] = [];
      pickup = await lease.fetchPickup(
        bearer: 'A',
        tenantId: e.entity,
        cityId: e.entity,
        roundId: e.entity,
      );
      await arrival();
      await expectLater(
        open(),
        q.storeError('PICKUP_PACKAGE_DISPLAY_UNAVAILABLE'),
      );
      expect(posts(), isEmpty);
    },
  );
  test('physical confirmation cannot precede its actual arrival', () async {
    final c = await ready();
    now = o.when.subtract(const Duration(seconds: 1));
    await c.confirm(bearer: 'A');
    expect(c.errorCode, 'PICKUP_OBSERVATION_TIME_INVALID');
    expect(c.frozen, isFalse);
    expect(posts(), isEmpty);
    c.dispose();
  });
  test('selection commit interruption keeps the check after reopen', () async {
    await arrival();
    final c = await open();
    failBoundary = 'pickup_selection_committed';
    await c.setSelected(p.parcel, true);
    expect(c.errorCode, 'STORAGE_IO_FAILED');
    final restored = await reopen(c);
    expect(restored.selected, {p.parcel});
    expect(restored.frozen, isFalse);
    expect(posts(), isEmpty);
    restored.dispose();
  });
  test(
    'interrupted before HTTP probes status then resends the SAME frozen ID',
    () async {
      final c = await ready();
      failBoundary = 'command_before_http';
      await c.confirm(bearer: 'A');
      final id = c.command!.commandId;
      expect(c.state, 'sending');
      expect(posts(), isEmpty);
      final restored = await reopen(c);
      await restored.confirm(bearer: 'A');
      expect(auth.requests.last.url.path, '/v1/queries/CommandStatus');
      expect(restored.state, 'queued');
      now = now.add(const Duration(seconds: 31));
      await restored.confirm(bearer: 'A');
      expect(restored.committed, isTrue);
      expect(restored.command!.commandId, id);
      expect(posts().length, 1);
      restored.dispose();
    },
  );
}

Future<void> waitIdle(PickupCollectionController c) async {
  if (!c.busy) return;
  final done = Completer<void>();
  void check() {
    if (!c.busy && !done.isCompleted) done.complete();
  }

  c.addListener(check);
  try {
    await done.future.timeout(const Duration(seconds: 10));
  } finally {
    c.removeListener(check);
  }
}
