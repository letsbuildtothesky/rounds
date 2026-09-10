import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rounds_driver_harness/src/v23/driver_storage_lifecycle.dart';
import 'package:rounds_driver_harness/src/v23/encrypted_work_store.dart';
import 'package:rounds_driver_harness/src/v23/execution_query.dart';

import 'v23_device_registration_test.dart' as f;
import 'v23_encrypted_work_store_test.dart' as e;
import 'v23_offline_observation_test.dart' as o;
import 'v23_offline_command_test.dart' as q;
import 'v23_pickup_issue_test.dart' as issue;

final obs = q.id(701);
Map<String, dynamic> projection() => {
  'as_of': f.instant.toIso8601String(),
  'next_cursor': null,
  'data': {
    'view': 'pickup_issue',
    'principal_id': f.principalA,
    'tenant_id': e.entity,
    'city_id': e.entity,
    'round_id': e.entity,
    'assignment_id': o.assignment,
    'assignment_version': 1,
    'observation_id': obs,
    'issue_id': q.id(800),
    'issue_version': 1,
    'state': 'open',
    'departure_gate': 'blocked',
    'orders': [
      {
        'delivery_id': e.entity,
        'readiness': 'held',
        'preparation_state': 'ready',
        'outcome': 'open',
      },
    ],
    'decisions': [],
  },
};

void main() {
  late Directory dir;
  late f.Fixture fixture;
  late DriverStorageLifecycle life;
  late DriverStorageLease lease;
  late Map<String, dynamic> current;
  Future<http.Response>? delayed;
  bool failTransport = false;
  Completer<void>? started;
  late AuthorizedPickup pickup;
  setUp(() async {
    dir = Directory.systemTemp.createTempSync('rounds-issue-reader-');
    fixture = f.Fixture();
    current = projection();
    delayed = null;
    failTransport = false;
    started = null;
    fixture.override = (r) async {
      if (r.url.path == '/auth/v1/user') {
        return f.jsonResponse({
          'id': r.headers['authorization'] == 'Bearer B'
              ? f.subjectB
              : f.subjectA,
        });
      }
      if (r.url.path == '/v1/queries/DriverRound') {
        if (failTransport) throw TimeoutException('fixture timeout');
        if (started != null && !started!.isCompleted) started!.complete();
        return delayed ?? f.jsonResponse(current);
      }
      if (r.url.path.endsWith('/ReportIssue')) {
        return f.jsonResponse(
          issue.issueReceipt(jsonDecode(r.body) as Map<String, dynamic>),
        );
      }
      return f.jsonResponse(
        f.wire(
          principal: r.headers['authorization'] == 'Bearer B'
              ? f.principalB
              : f.principalA,
        ),
      );
    };
    life = DriverStorageLifecycle(
      registration: fixture.make(),
      secrets: fixture.secrets,
      resolveRoot: () async => dir,
      prepareLegacy: (_) async {},
      commandClock: () => o.when.add(const Duration(minutes: 1)),
    );
    await life.start();
    lease = await life.authenticate('A');
    final snapshot = DriverPickupSnapshot.parse(issue.issueProjection());
    pickup = (snapshot: snapshot, originalContext: snapshot.execution.context);
    await lease.cacheExecutionContext(pickup.originalContext);
  });
  tearDown(() async {
    await life.dispose();
    dir.deleteSync(recursive: true);
  });
  Future<void> report({bool send = true}) async {
    await lease.recordPickupIssue(
      LocalPickupIssueDraft(
        pickup: pickup,
        observationId: obs,
        observedAt: o.when,
        reason: 'missing',
        deliveryId: e.entity,
      ),
    );
    await lease.materializeObservation(obs);
    if (send) {
      expect(
        (await lease.synchronizeObservation(obs, bearer: 'A')).state,
        'committed',
      );
    }
  }

  Future<DriverPickupIssueSnapshot> fetch() =>
      lease.fetchPickupIssue(bearer: 'A', observationId: obs);
  int getCount() => fixture.requests
      .where((r) => r.url.path == '/v1/queries/DriverRound')
      .length;

  test(
    'committed original receipt -> exact authenticated GET; query never rewrites evidence/queue/fence',
    () async {
      await report();
      final before = (await lease.readObservation(obs)).toJson(),
          command = await lease.observationCommand(obs);
      final result = await fetch(), request = fixture.requests.last;
      expect(result.toJson(), current);
      expect(result.toString(), 'DriverPickupIssueSnapshot(redacted)');
      expect(request.method, 'GET');
      expect(request.url.origin, 'https://api.example.test');
      expect(request.followRedirects, false);
      expect(request.url.queryParameters, {
        'entity_id': e.entity,
        'tenant_id': e.entity,
        'city_id': e.entity,
        'view': 'pickup_issue',
        'issue_id': q.id(800),
      });
      expect(request.headers['x-rounds-device-session'], f.capability);
      expect((await lease.readObservation(obs)).toJson(), before);
      expect(
        (await lease.observationCommand(obs))!.requestHash,
        command!.requestHash,
      );
      life.lock();
      lease = await life.authenticate('A');
      expect((await fetch()).toJson(), current);
      expect((await lease.readObservation(obs)).toJson(), before);
    },
  );
  test(
    'unsubmitted and queued observations cannot fetch invented issue IDs',
    () async {
      await expectLater(fetch(), e.fails('ISSUE_NOT_REPORTED'));
      await report(send: false);
      await expectLater(fetch(), e.fails('ISSUE_NOT_REPORTED'));
      expect(getCount(), 0);
    },
  );
  test(
    'actual decision is informational, exact text retained while order remains held',
    () async {
      await report();
      current['data']['state'] = 'decided';
      current['data']['issue_version'] = 2;
      current['data']['decisions'] = [
        {
          'id': q.id(801),
          'decided_at': f.instant.toIso8601String(),
          'action': 'wait',
          'instructions': '  Wait at pickup.\nOperations is checking.  ',
        },
      ];
      final d = (await fetch()).toJson()['data'];
      expect(
        d['decisions'][0]['instructions'],
        '  Wait at pickup.\nOperations is checking.  ',
      );
      expect(d['orders'][0]['readiness'], 'held');
      expect(d['departure_gate'], 'blocked');
    },
  );
  for (final key in [
    'principal_id',
    'tenant_id',
    'city_id',
    'round_id',
    'assignment_id',
    'observation_id',
    'issue_id',
  ]) {
    test('rejects response with different original $key', () async {
      await report();
      current['data'][key] = q.id(999);
      await expectLater(fetch(), f.failure('INVALID_RESPONSE'));
    });
  }
  test(
    'rejects changed assignment version or selected delivery, without refreshing originals',
    () async {
      await report();
      current['data']['assignment_version'] = 2;
      await expectLater(fetch(), f.failure('INVALID_RESPONSE'));
      current = projection();
      current['data']['orders'][0]['delivery_id'] = q.id(999);
      await expectLater(fetch(), f.failure('INVALID_RESPONSE'));
    },
  );
  test('out-of-order response cannot replace a newer refresh', () async {
    await report();
    started = Completer<void>();
    final hold = Completer<http.Response>();
    delayed = hold.future;
    final old = fetch();
    final assertion = expectLater(
      old,
      throwsA(
        isA<StorageLifecycleException>().having(
          (e) => e.code,
          'code',
          'QUERY_SUPERSEDED',
        ),
      ),
    );
    await started!.future;
    delayed = null;
    expect((await fetch()).toJson(), current);
    hold.complete(f.jsonResponse(current));
    await assertion;
  });
  test('account lock during request discards late status', () async {
    await report();
    started = Completer<void>();
    final hold = Completer<http.Response>();
    delayed = hold.future;
    final pending = fetch();
    final assertion = expectLater(pending, throwsA(anything));
    await started!.future;
    life.lock();
    hold.complete(f.jsonResponse(current));
    await assertion;
  });
  test(
    'late denial from old account does not lock newly authenticated account',
    () async {
      await report();
      started = Completer<void>();
      final hold = Completer<http.Response>();
      delayed = hold.future;
      final pending = fetch();
      final assertion = expectLater(pending, throwsA(anything));
      await started!.future;
      life.lock();
      final next = await life.authenticate('B');
      hold.complete(f.jsonResponse(q.error('NOT_AUTHORIZED'), 403));
      await assertion;
      expect(next.principalId, f.principalB);
      expect(next.requireCurrent, returnsNormally);
    },
  );
  test(
    'unknown HTTP outcome is not an empty decision; no mutation or report retry',
    () async {
      await report();
      failTransport = true;
      await expectLater(fetch(), throwsA(anything));
      expect((await lease.observationCommand(obs))!.state, 'committed');
      expect(
        fixture.requests
            .where((r) => r.url.path.endsWith('/ReportIssue'))
            .length,
        1,
      );
    },
  );
  test(
    'current authority denial locks lease without deleting committed report',
    () async {
      await report();
      delayed = Future.value(f.jsonResponse(q.error('NOT_AUTHORIZED'), 403));
      await expectLater(fetch(), throwsA(anything));
      expect(lease.requireCurrent, throwsA(anything));
      delayed = null;
      lease = await life.authenticate('A');
      expect((await lease.observationCommand(obs))!.state, 'committed');
    },
  );
  test(
    'exact parser rejects invented actions, inconsistent states, unknown fields and oversized instructions',
    () {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (v) {
          v['data']['state'] = 'decided';
        },
        (v) {
          v['data']['can_continue'] = true;
        },
        (v) {
          v['data']['issue_version'] = 9007199254740992;
        },
        (v) {
          v['data']['decisions'] = [
            {
              'id': q.id(801),
              'decided_at': f.instant.toIso8601String(),
              'action': 'partial_pickup',
              'instructions': 'Take some.',
            },
          ];
        },
        (v) {
          v['data']['state'] = 'decided';
          v['data']['decisions'] = [
            {
              'id': q.id(801),
              'decided_at': f.instant.toIso8601String(),
              'action': 'wait',
              'instructions': 'x' * 4001,
            },
          ];
        },
      ]) {
        final v = projection();
        mutate(v);
        expect(
          () => DriverPickupIssueSnapshot.parse(v),
          f.failure('INVALID_RESPONSE'),
        );
      }
    },
  );
}
