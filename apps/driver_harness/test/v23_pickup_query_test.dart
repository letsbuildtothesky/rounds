import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/ui/components/pickup_collection_view.dart';
import 'package:rounds_driver_harness/src/v23/driver_storage_lifecycle.dart';
import 'package:rounds_driver_harness/src/v23/execution_query.dart';
import 'package:rounds_driver_harness/src/v23/pickup_presentation.dart';

import 'v23_device_registration_test.dart' as f;
import 'v23_encrypted_work_store_test.dart' as e;
import 'v23_execution_query_test.dart' as q;
import 'v23_offline_observation_test.dart' as o;

const parcel = '66666666-6666-4666-8666-666666666666';
Map<String, dynamic> pickupProjection({int version = 1}) => {
  'as_of': f.instant.toIso8601String(),
  'next_cursor': null,
  'data': {
    'view': 'pickup',
    'execution': q.projection(version: version)['data'],
    'merchant': 'Fixture merchant',
    'pickup_site_name': 'Fixture pickup',
    'orders': [
      {
        'delivery_id': e.entity,
        'manifest_id': q.manifest,
        'reference': 'REF-101',
        'recipient_name': 'Johannes fixture',
        'stop_sequence': 1,
        'lines': [
          {
            'line_id': q.manifest,
            'label': 'Five items',
            'quantity': 5,
            'unit': 'item',
            'handling_keys': ['Fragile'],
          },
        ],
        'packages': [
          {
            'package_id': parcel,
            'label': 'One physical parcel',
            'contents': [
              {'line_id': q.manifest, 'quantity': 5},
            ],
          },
        ],
      },
    ],
  },
};

void main() {
  late Directory dir;
  late f.Fixture auth;
  late DriverStorageLifecycle life;
  late Map<String, dynamic> current;
  setUp(() async {
    dir = Directory.systemTemp.createTempSync('rounds-pickup-query-');
    auth = f.Fixture();
    current = pickupProjection();
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
  Future<AuthorizedPickup> fetch(DriverStorageLease lease) => lease.fetchPickup(
    bearer: 'A',
    tenantId: e.entity,
    cityId: e.entity,
    roundId: e.entity,
  );

  test(
    'authenticated pickup transport and actual parcel identity, not five anonymous rows',
    () async {
      final lease = await life.authenticate('A'), result = await fetch(lease);
      final r = auth.requests.last;
      expect(r.url.origin, 'https://api.example.test');
      expect(r.url.queryParameters, {
        'entity_id': e.entity,
        'tenant_id': e.entity,
        'city_id': e.entity,
        'view': 'pickup',
      });
      expect(r.headers['x-rounds-device-session'], f.capability);
      expect(r.followRedirects, isFalse);
      final p = PickupPresentation.fromSnapshot(result.snapshot);
      expect(p.packages.length, 1);
      expect(p.packages.single.key, parcel);
      expect(p.packages.single.title, 'One physical parcel');
      expect(p.packages.single.reference, 'REF-101');
      expect(p.packages.single.recipient, 'Johannes fixture');
      expect(p.packages.single.handling, 'Fragile');
      expect(p.packages.single.keepCool, isFalse);
      expect(p.site, 'Fixture pickup');
      expect(p.stopCount, 1);
      expect(() => p.packages.clear(), throwsUnsupportedError);
      expect(result.snapshot.toString(), 'DriverPickupSnapshot(redacted)');
      result.snapshot.toJson()['data']['merchant'] = 'Mutation';
      expect(result.snapshot.toJson()['data']['merchant'], 'Fixture merchant');
      expect(
        result.originalContext.toJson(),
        result.snapshot.execution.context.toJson(),
      );
    },
  );
  test(
    'fresh recipient name never rebases original persisted versions or timestamp',
    () async {
      final lease = await life.authenticate('A'), first = await fetch(lease);
      current['data']['orders'][0]['recipient_name'] = 'Updated recipient';
      current['data']['execution']['context']['expected_versions'][1]['version'] =
          2;
      current['as_of'] = f.instant
          .add(const Duration(minutes: 1))
          .toIso8601String();
      current['data']['execution']['context']['fetched_at'] = current['as_of'];
      final second = await fetch(lease);
      expect(
        second.snapshot.toJson()['data']['orders'][0]['recipient_name'],
        'Updated recipient',
      );
      expect(
        second.snapshot.execution.context.toJson(),
        isNot(first.originalContext.toJson()),
      );
      expect(second.originalContext.toJson(), first.originalContext.toJson());
      life.lock();
      final reopened = await life.authenticate('A');
      expect(
        (await fetch(reopened)).originalContext.toJson(),
        first.originalContext.toJson(),
      );
    },
  );
  test('unpacked data is valid but cannot fabricate a parcel checklist', () {
    current['data']['orders'][0]['packages'] = [];
    final snapshot = DriverPickupSnapshot.parse(current);
    expect(
      () => PickupPresentation.fromSnapshot(snapshot),
      throwsA(
        isA<PickupPresentationException>().having(
          (e) => e.code,
          'code',
          'PICKUP_PACKAGE_DISPLAY_UNAVAILABLE',
        ),
      ),
    );
  });
  test('decimal quantities use integer quanta for package totals', () {
    final order = current['data']['orders'][0];
    current['data']['execution']['orders'][0]['quantities'][0]['quantity'] =
        0.3;
    order['lines'][0]['quantity'] = 0.3;
    order['packages'][0]['contents'][0]['quantity'] = 0.1;
    order['packages'].add({
      'package_id': q.drop,
      'label': 'Second parcel',
      'contents': [
        {'line_id': q.manifest, 'quantity': 0.2},
      ],
    });
    expect(
      PickupPresentation.fromSnapshot(
        DriverPickupSnapshot.parse(current),
      ).packages.length,
      2,
    );
  });
  test('Unicode length bound counts characters, not UTF-16 halves', () {
    current['data']['merchant'] = '🌼' * 200;
    expect(
      DriverPickupSnapshot.parse(current).toJson()['data']['merchant'],
      '🌼' * 200,
    );
    current['data']['merchant'] = '🌼' * 201;
    expect(
      () => DriverPickupSnapshot.parse(current),
      f.failure('INVALID_RESPONSE'),
    );
  });
  final mutations = <String, void Function(Map<String, dynamic>)>{
    'private unexpected field': (d) => d['contact_secret'] = 'hidden',
    'missing name': (d) => d['orders'][0].remove('recipient_name'),
    'blank name': (d) => d['orders'][0]['recipient_name'] = '  ',
    'foreign manifest': (d) => d['orders'][0]['manifest_id'] = q.drop,
    'foreign line': (d) => d['orders'][0]['lines'][0]['line_id'] = q.drop,
    'wrong line quantity': (d) => d['orders'][0]['lines'][0]['quantity'] = 4,
    'fraction beyond four decimals': (d) =>
        d['orders'][0]['lines'][0]['quantity'] = 5.00001,
    'empty contents': (d) => d['orders'][0]['packages'][0]['contents'] = [],
    'foreign contents': (d) =>
        d['orders'][0]['packages'][0]['contents'][0]['line_id'] = q.drop,
    'short contents': (d) =>
        d['orders'][0]['packages'][0]['contents'][0]['quantity'] = 4,
    'excess contents': (d) =>
        d['orders'][0]['packages'][0]['contents'][0]['quantity'] = 6,
    'duplicate parcel': (d) =>
        d['orders'][0]['packages'].add(d['orders'][0]['packages'][0]),
    'duplicate line': (d) =>
        d['orders'][0]['lines'].add(d['orders'][0]['lines'][0]),
    'duplicate delivery': (d) => d['orders'].add(d['orders'][0]),
    'invalid sequence': (d) => d['orders'][0]['stop_sequence'] = 0,
    'inconsistent timestamp': (d) =>
        d['execution']['context']['fetched_at'] = '2026-01-01T00:00:00.000Z',
  };
  for (final m in mutations.entries) {
    test('rejects ${m.key} before caching or rendering', () async {
      m.value(current['data']);
      final lease = await life.authenticate('A');
      await expectLater(fetch(lease), f.failure('INVALID_RESPONSE'));
      await expectLater(
        lease.recordObservation(o.draft()),
        q.storeError('EXECUTION_CONTEXT_MISSING'),
      );
    });
  }
  for (final field in ['principal_id', 'tenant_id', 'city_id', 'round_id']) {
    test('wrong $field cannot enter account storage', () async {
      current['data']['execution']['context'][field] = f.principalB;
      final lease = await life.authenticate('A');
      await expectLater(fetch(lease), f.failure('INVALID_RESPONSE'));
      await expectLater(
        lease.recordObservation(o.draft()),
        q.storeError('EXECUTION_CONTEXT_MISSING'),
      );
    });
  }
  test(
    'query arriving after sign-out cannot publish or cache pickup data',
    () async {
      final lease = await life.authenticate('A'),
          entered = Completer<void>(),
          release = Completer<void>();
      auth.override = (r) async {
        entered.complete();
        await release.future;
        return f.jsonResponse(current);
      };
      final pending = fetch(lease),
          denied = expectLater(pending, throwsA(anything));
      await entered.future;
      life.lock();
      release.complete();
      await denied;
      auth.override = null;
      final again = await life.authenticate('A');
      await expectLater(
        again.recordObservation(o.draft()),
        q.storeError('EXECUTION_CONTEXT_MISSING'),
      );
    },
  );
  test('execution and pickup views share supersession guard', () async {
    final lease = await life.authenticate('A'),
        entered = Completer<void>(),
        release = Completer<void>();
    auth.override = (r) async {
      if (r.url.queryParameters['view'] == 'pickup') {
        entered.complete();
        await release.future;
        return f.jsonResponse(current);
      }
      return f.jsonResponse(q.projection(version: 2));
    };
    final pending = fetch(lease),
        denied = expectLater(
          pending,
          throwsA(isA<StorageLifecycleException>()),
        );
    await entered.future;
    final newer = await lease.fetchExecutionContext(
      bearer: 'A',
      tenantId: e.entity,
      cityId: e.entity,
      roundId: e.entity,
    );
    expect(newer.toJson()['assignment_version'], 2);
    release.complete();
    await denied;
  });
  test('permission denial invalidates the lease', () async {
    final lease = await life.authenticate('A');
    await fetch(lease);
    auth.override = (r) async =>
        f.jsonResponse({'code': 'NOT_AUTHORIZED'}, 403);
    await expectLater(fetch(lease), f.failure('NOT_AUTHORIZED'));
    expect(lease.requireCurrent, throwsA(isA<StorageLifecycleException>()));
  });
  testWidgets(
    'parsed display fills the EXISTING approved view and selected state',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = PickupPresentation.fromSnapshot(
        DriverPickupSnapshot.parse(current),
      );
      final selected = <String>{};
      var confirms = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: SafeArea(
                child: PickupCollectionView(
                  merchant: p.merchant,
                  stopCount: p.stopCount,
                  packages: p.packages,
                  selected: selected,
                  onToggle: (id) => setState(() => selected.add(id)),
                  onBack: () {},
                  onProblem: () {},
                  onConfirm: selected.length == p.packages.length
                      ? () => confirms++
                      : null,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Fixture merchant'), findsOneWidget);
      expect(find.text('One physical parcel'), findsOneWidget);
      expect(find.textContaining('Johannes fixture'), findsWidgets);
      expect(find.text('0 of 1'), findsOneWidget);
      await tester.tap(find.text('One physical parcel'));
      await tester.pump();
      expect(selected, {parcel});
      expect(find.text('1 of 1'), findsOneWidget);
      await tester.tap(find.text('Confirm 1 package'));
      await tester.pump();
      expect(confirms, 1);
      expect(tester.takeException(), isNull);
      // The callback is deliberately not a server commitment assertion.
    },
  );
}
