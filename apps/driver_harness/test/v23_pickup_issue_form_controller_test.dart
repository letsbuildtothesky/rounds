import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:rounds_driver_harness/src/v23/driver_storage_auth.dart';
import 'package:rounds_driver_harness/src/v23/driver_storage_lifecycle.dart';
import 'package:rounds_driver_harness/src/v23/execution_query.dart';
import 'package:rounds_driver_harness/src/v23/pickup_issue_form_controller.dart';
import 'package:rounds_driver_harness/src/v23/pickup_issue_form_route.dart';
import 'package:rounds_driver_harness/src/v23/pickup_issue_recovery.dart';

import 'v23_device_registration_test.dart' as f;
import 'v23_driver_auth_test.dart' as a;
import 'v23_encrypted_work_store_test.dart' as e;
import 'v23_offline_observation_test.dart' as o;
import 'v23_photo_transfer_test.dart' as media;
import 'v23_pickup_issue_test.dart' as issue;
import 'v23_pickup_issue_query_test.dart' as reader;
import 'v23_offline_command_test.dart' as q;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late media.PhotoFixture fx;
  late DriverStorageLifecycle life;
  late DriverStorageAuth auth;
  late PickupIssueFormController controller;
  late String token;
  String? failAt;
  late Map<String, dynamic> reply;
  Future<http.Response>? replyResponse;
  Completer<void>? replyStarted;
  bool failReply = false;
  setUp(() async {
    fx = media.PhotoFixture();
    await fx.open(
      context: DriverPickupSnapshot.parse(
        issue.issueProjection(),
      ).execution.context,
    );
    fx.store.close();
    failAt = null;
    reply = reader.projection();
    replyResponse = null;
    replyStarted = null;
    failReply = false;
    fx.intercept = (r) async {
      if (r.url.path == '/v1/queries/DriverRound') {
        if (r.url.queryParameters['view'] == 'pickup_issue') {
          if (replyStarted != null && !replyStarted!.isCompleted) {
            replyStarted!.complete();
          }
          if (failReply) throw TimeoutException('fixture reply lost');
          reply['data']['observation_id'] = controller.form.observationId;
          return replyResponse ?? f.jsonResponse(reply);
        }
        return f.jsonResponse(issue.issueProjection());
      }
      if (r.method == 'POST' && r.url.path.endsWith('/ReportIssue')) {
        final w = jsonDecode(r.body) as Map<String, dynamic>;
        return f.jsonResponse(
          fx.receipts.putIfAbsent(w['command_id'], () => issue.issueReceipt(w)),
        );
      }
      return null;
    };
    life = DriverStorageLifecycle(
      registration: fx.transport,
      secrets: fx.auth.secrets,
      resolveRoot: () async => fx.temp,
      prepareLegacy: (_) async {},
      commandClock: () => fx.now,
      storageCheckpoint: (point) async {
        if (point == failAt) {
          failAt = null;
          throw StateError('fixture interrupted write');
        }
      },
    );
    await life.start();
    auth = DriverStorageAuth(life, now: () => f.instant);
    token = a.bearer(f.instant.add(const Duration(minutes: 30)));
    final pickup = await auth.fetchPickup(
      bearer: token,
      tenantId: e.entity,
      cityId: e.entity,
      roundId: e.entity,
    );
    controller = await PickupIssueFormController.open(
      auth,
      () => token,
      pickup,
      deliveryId: e.entity,
      clock: () => o.when,
    );
  });
  tearDown(() async {
    controller.dispose();
    await auth.dispose();
    fx.close();
  });
  int posts(String kind) => fx.auth.requests
      .where((r) => r.method == 'POST' && r.url.path.endsWith('/$kind'))
      .length;
  int reads() => fx.auth.requests
      .where((r) => r.url.queryParameters['view'] == 'pickup_issue')
      .length;
  Future<void> submitted() async {
    await controller.choose('missing');
    await controller.submit();
    expect(controller.committed, isTrue);
  }

  void decision(int version, String action, String instructions) {
    reply['data']['state'] = 'decided';
    reply['data']['issue_version'] = version;
    reply['data']['decisions'] = [
      {
        'id': q.id(800 + version),
        'decided_at': f.instant.toIso8601String(),
        'action': action,
        'instructions': instructions,
      },
    ];
  }

  Future<XFile?> camera() async {
    life.didChangeAppLifecycleState(AppLifecycleState.paused);
    life.didChangeAppLifecycleState(AppLifecycleState.resumed);
    return XFile.fromData(media.png, name: 'fixture.png');
  }

  test('reply refresh cannot send or invent an unreported issue', () async {
    expect(controller.recovery.phase, PickupIssueReadPhase.notRequested);
    expect(
      () => controller.refreshInstructions(),
      e.fails('ISSUE_NOT_REPORTED'),
    );
    expect(reads(), 0);
    expect(posts('ReportIssue'), 0);
  });

  test(
    'committed report reads waiting truth without altering queue or evidence',
    () async {
      await submitted();
      final before = (await auth.currentLease.readObservation(
        controller.form.observationId,
      )).toJson();
      final hash = controller.command!.requestHash;
      await controller.refreshInstructions();
      expect(controller.recovery.phase, PickupIssueReadPhase.waiting);
      expect(controller.recovery.instructions, isNull);
      expect(controller.recovery.departureGate, 'blocked');
      expect(controller.recovery.isLastKnown, isFalse);
      expect(controller.committed, isTrue);
      expect(controller.command!.requestHash, hash);
      expect(
        (await auth.currentLease.readObservation(
          controller.form.observationId,
        )).toJson(),
        before,
      );
      expect(reads(), 1);
      expect(posts('ReportIssue'), 1);
    },
  );

  test(
    'actual attributed replies retain exact text and replace superseded instructions',
    () async {
      await submitted();
      decision(2, 'wait', '  Wait at pickup.\nOperations is checking.  ');
      await controller.refreshInstructions();
      expect(controller.recovery.phase, PickupIssueReadPhase.instructions);
      expect(
        controller.recovery.instructions,
        '  Wait at pickup.\nOperations is checking.  ',
      );
      expect(controller.recovery.issueVersion, 2);
      decision(3, 'escalate', 'Contact Operations.');
      await controller.refreshInstructions();
      expect(controller.recovery.action, 'escalate');
      expect(controller.recovery.decisionId, q.id(803));
      expect(controller.recovery.instructions, 'Contact Operations.');
      expect(controller.recovery.issueState, 'decided');
      expect(controller.recovery.departureGate, 'blocked');
      expect(controller.recovery.asOf, reply['as_of']);
      expect(
        controller.recovery.toString(),
        isNot(contains('Contact Operations')),
      );
      expect(posts('ReportIssue'), 1);
      expect(posts('ConfirmPickup'), 0);
    },
  );

  test(
    'lost first reply is unavailable, not empty, not an unsent report',
    () async {
      await submitted();
      failReply = true;
      await controller.refreshInstructions();
      expect(controller.recovery.phase, PickupIssueReadPhase.failed);
      expect(controller.recovery.errorCode, isNotNull);
      expect(controller.recovery.snapshot, isNull);
      expect(controller.errorCode, isNull);
      expect(controller.committed, isTrue);
      failReply = false;
      await controller.refreshInstructions();
      expect(controller.recovery.phase, PickupIssueReadPhase.waiting);
      expect(controller.recovery.errorCode, isNull);
      expect(posts('ReportIssue'), 1);
    },
  );

  test(
    'failed refresh keeps prior reply marked last-known, successful read clears stale',
    () async {
      await submitted();
      decision(2, 'wait', 'Wait at pickup.');
      await controller.refreshInstructions();
      failReply = true;
      await controller.refreshInstructions();
      expect(controller.recovery.isLastKnown, isTrue);
      expect(controller.recovery.instructions, 'Wait at pickup.');
      expect(controller.recovery.phase, PickupIssueReadPhase.failed);
      failReply = false;
      decision(3, 'escalate', 'Call Operations.');
      await controller.refreshInstructions();
      expect(controller.recovery.isLastKnown, isFalse);
      expect(controller.recovery.instructions, 'Call Operations.');
    },
  );

  test(
    'refresh taps coalesce; loading cannot label an old reply current',
    () async {
      await submitted();
      decision(2, 'wait', 'Wait.');
      await controller.refreshInstructions();
      final gate = Completer<http.Response>();
      replyResponse = gate.future;
      replyStarted = Completer<void>();
      final first = controller.refreshInstructions();
      final second = controller.refreshInstructions();
      expect(identical(first, second), isTrue);
      await replyStarted!.future;
      expect(controller.recovery.phase, PickupIssueReadPhase.loading);
      expect(controller.recovery.isLastKnown, isTrue);
      expect(reads(), 2);
      gate.complete(f.jsonResponse(reply));
      await Future.wait([first, second]);
      expect(controller.recovery.isLastKnown, isFalse);
    },
  );

  test(
    'older issue version cannot replace an already observed instruction',
    () async {
      await submitted();
      decision(3, 'escalate', 'Latest reply');
      await controller.refreshInstructions();
      decision(2, 'wait', 'Obsolete reply');
      await controller.refreshInstructions();
      expect(controller.recovery.errorCode, 'SOURCE_STALE');
      expect(controller.recovery.isLastKnown, isTrue);
      expect(controller.recovery.instructions, 'Latest reply');
      expect(controller.recovery.issueVersion, 3);
    },
  );

  test(
    'a completed reply cannot revive as current after reauthentication',
    () async {
      await submitted();
      decision(2, 'wait', 'Old session reply');
      await controller.refreshInstructions();
      auth.lock();
      await auth.authenticate(token);
      expect(controller.recovery.phase, PickupIssueReadPhase.notRequested);
      expect(controller.recovery.snapshot, isNull);
      decision(3, 'escalate', 'Fresh session reply');
      await controller.refreshInstructions();
      expect(controller.recovery.instructions, 'Fresh session reply');
      expect(controller.recovery.isLastKnown, isFalse);
      expect(posts('ReportIssue'), 1);
    },
  );

  test(
    'same-account sign-out/sign-in discards an earlier Auth generation reply',
    () async {
      await submitted();
      final gate = Completer<http.Response>();
      replyResponse = gate.future;
      replyStarted = Completer<void>();
      final read = controller.refreshInstructions();
      final assertion = expectLater(
        read,
        throwsA(isA<StorageLifecycleException>()),
      );
      await replyStarted!.future;
      auth.lock();
      await auth.authenticate(token);
      gate.complete(f.jsonResponse(reply));
      await assertion;
      expect(controller.recovery.snapshot, isNull);
      expect(controller.recovery.phase, PickupIssueReadPhase.notRequested);
    },
  );

  test(
    'lock before scheduled read cannot query or preserve old reply state',
    () async {
      await submitted();
      decision(2, 'wait', 'Private reply');
      await controller.refreshInstructions();
      final request = controller.refreshInstructions();
      final assertion = expectLater(
        request,
        throwsA(isA<StorageLifecycleException>()),
      );
      auth.lock();
      await assertion;
      await auth.authenticate(token);
      expect(controller.recovery.snapshot, isNull);
      expect(reads(), 1);
    },
  );

  test(
    'server revocation removes readable reply state without resending',
    () async {
      await submitted();
      decision(2, 'wait', 'Private reply');
      await controller.refreshInstructions();
      replyResponse = Future.value(
        f.jsonResponse(q.error('NOT_AUTHORIZED'), 403),
      );
      await expectLater(
        controller.refreshInstructions(),
        throwsA(isA<StorageLifecycleException>()),
      );
      expect(
        () => controller.recovery,
        throwsA(isA<StorageLifecycleException>()),
      );
      expect(posts('ReportIssue'), 1);
    },
  );

  test(
    'dispose discards late reply and reopening starts with no cached authority',
    () async {
      await submitted();
      final gate = Completer<http.Response>();
      replyResponse = gate.future;
      replyStarted = Completer<void>();
      final read = controller.refreshInstructions();
      final assertion = expectLater(
        read,
        throwsA(isA<StorageLifecycleException>()),
      );
      await replyStarted!.future;
      final id = controller.form.id;
      controller.dispose();
      gate.complete(f.jsonResponse(reply));
      await assertion;
      controller = await PickupIssueFormController.resume(
        auth,
        () => token,
        id,
      );
      expect(controller.committed, isTrue);
      expect(controller.recovery.phase, PickupIssueReadPhase.notRequested);
      expect(posts('ReportIssue'), 1);
    },
  );

  test(
    'controller sends latest queued edits, one report after rapid double tap',
    () async {
      await controller.choose('missing');
      final first = controller.editDetail('early');
      final last = controller.editDetail('Latest typed text');
      await Future.wait([
        first,
        last,
        controller.submit(),
        controller.submit(),
      ]);
      expect(controller.errorCode, isNull);
      expect(controller.committed, isTrue);
      expect(posts('ReportIssue'), 1);
      final report = fx.auth.requests.singleWhere(
        (r) => r.url.path.endsWith('/ReportIssue'),
      );
      expect(jsonDecode(report.body)['payload']['detail'], 'Latest typed text');
    },
  );

  for (final unavailable in [false, true]) {
    testWidgets(
      'reopened sent report reaches host immediately; reply unavailable=$unavailable is separate',
      (tester) async {
        await tester.runAsync(submitted);
        Future<void> pumpIoUntil(bool Function() ready) async {
          for (var i = 0; i < 200; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 5)),
            );
            await tester.pump();
            if (ready()) return;
          }
          fail('The route did not finish its bounded real-I/O fixture');
        }

        final gate = Completer<http.Response>();
        replyResponse = gate.future;
        replyStarted = Completer<void>();
        var reported = 0, recovery = 0;
        PickupIssueReadPhase? navigationPhase;
        final view = MaterialApp(
          home: PickupIssueFormRoute(
            controller: controller,
            onBack: () {},
            onMore: () {},
            onReported: (c) {
              reported++;
              navigationPhase = c.recovery.phase;
            },
            onRecovery: (_) => recovery++,
          ),
        );
        await tester.pumpWidget(view);
        await pumpIoUntil(() => replyStarted!.isCompleted);
        expect(reported, 1);
        expect(navigationPhase, PickupIssueReadPhase.loading);
        expect(recovery, 0);
        expect(reads(), 1);
        await tester.pumpWidget(view);
        expect(reads(), 1);
        // Coalesces with the route's actual in-flight request.
        final pending = controller.refreshInstructions();
        if (unavailable) {
          gate.completeError(TimeoutException('fixture reply unavailable'));
        } else {
          decision(2, 'wait', 'Wait for Operations.');
          gate.complete(f.jsonResponse(reply));
        }
        await pumpIoUntil(
          () => controller.recovery.phase != PickupIssueReadPhase.loading,
        );
        await pending;
        await tester.pumpAndSettle();
        expect(
          controller.recovery.phase,
          unavailable
              ? PickupIssueReadPhase.failed
              : PickupIssueReadPhase.instructions,
        );
        expect(reported, 1);
        expect(recovery, 0);
        expect(posts('ReportIssue'), 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'host controller replacement resets local text and route selection',
    (tester) async {
      await tester.runAsync(() async {
        await controller.choose('missing');
        await controller.editDetail('Earlier form details');
      });
      Widget view() => MaterialApp(
        home: PickupIssueFormRoute(
          controller: controller,
          onBack: () {},
          onMore: () {},
          onReported: (_) {},
          onRecovery: (_) {},
        ),
      );
      await tester.pumpWidget(view());
      expect(find.text('Earlier form details'), findsOneWidget);
      final old = controller;
      await tester.runAsync(() async {
        controller = await PickupIssueFormController.resume(
          auth,
          () => token,
          old.form.id,
        );
        await controller.editDetail('Current form details');
      });
      await tester.pumpWidget(view());
      old.dispose();
      expect(find.text('Earlier form details'), findsNothing);
      expect(find.text('Current form details'), findsOneWidget);
      expect(posts('ReportIssue'), 0);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'real Auth camera return, note edit, upload verification and ReportIssue',
    () async {
      await controller.choose('damaged');
      await controller.capture(camera: camera);
      expect(controller.errorCode, isNull);
      expect(controller.preview, media.png);
      expect(posts('ReportIssue'), 0);
      expect(await auth.currentLease.observations(), isEmpty);
      await controller.editDetail('Edited after camera');
      await controller.submit();
      expect(controller.errorCode, isNull);
      expect(controller.committed, isTrue);
      expect(posts('ReserveAsset'), 1);
      expect(posts('VerifyAsset'), 1);
      expect(posts('ReportIssue'), 1);
      expect(fx.puts, hasLength(1));
    },
  );
  test(
    'uncertain report probes original status after reassignment without another POST',
    () async {
      await controller.choose('missing');
      fx.intercept = (r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/ReportIssue')) {
          final wire = jsonDecode(r.body) as Map<String, dynamic>;
          fx.receipts[wire['command_id']] = issue.issueReceipt(wire);
          throw TimeoutException('fixture lost report response');
        }
        return null;
      };
      await controller.submit();
      expect(controller.committed, isFalse);
      expect(posts('ReportIssue'), 1);
      await auth.currentLease.invalidateExecutionContext(o.assignment, 1);
      fx.intercept = null;
      fx.tick();
      await controller.submit();
      expect(controller.errorCode, isNull);
      expect(controller.committed, isTrue);
      expect(posts('ReportIssue'), 1);
      expect(
        fx.auth.requests.any(
          (r) => r.method == 'GET' && r.url.path.endsWith('/CommandStatus'),
        ),
        isTrue,
      );
    },
  );
  test(
    'failed draft write does not submit stale note, subsequent save recovers',
    () async {
      await controller.choose('missing');
      failAt = 'pickup_form_edit_committed';
      await controller.editDetail('latest text');
      await controller.submit();
      expect(controller.errorCode, isNotNull);
      expect(posts('ReportIssue'), 0);
      await controller.editDetail('latest text');
      await controller.submit();
      expect(controller.committed, isTrue);
    },
  );
  test('cancelled retake retains preview and does not submit', () async {
    await controller.choose('wrong');
    await controller.capture(camera: camera);
    final asset = controller.form.photoId;
    await controller.capture(camera: () async => null);
    expect(controller.form.photoId, asset);
    expect(controller.preview, media.png);
    expect(controller.form.frozen, isFalse);
    expect(posts('ReportIssue'), 0);
  });
  test('sign-out during camera never saves/sends under a new lease', () async {
    await controller.choose('damaged');
    await expectLater(
      controller.capture(
        camera: () async {
          auth.lock();
          return XFile.fromData(media.png, name: 'fixture.png');
        },
      ),
      throwsA(isA<StorageLifecycleException>()),
    );
    expect(controller.preview, isNull);
    expect(posts('ReportIssue'), 0);
  });
  test(
    'dispose during camera suppresses late UI result, retains same-owner photo',
    () async {
      await controller.choose('damaged');
      final gate = Completer<XFile?>();
      final result = controller.capture(camera: () => gate.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      controller.dispose();
      gate.complete(XFile.fromData(media.png, name: 'fixture.png'));
      await expectLater(result, throwsA(isA<StorageLifecycleException>()));
      expect(posts('ReportIssue'), 0);
      // Prevent the tearDown from disposing the same ChangeNotifier twice.
      controller = await PickupIssueFormController.resume(
        auth,
        () => token,
        controller.form.id,
        clock: () => o.when,
      );
      expect(controller.form.photoId, isNotNull);
    },
  );
  testWidgets(
    'G03 actual route chooses missing, saves details and reaches committed callback',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var reported = 0, recovery = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PickupIssueFormRoute(
            controller: controller,
            onBack: () {},
            onMore: () {},
            onReported: (_) => reported++,
            onRecovery: (_) => recovery++,
          ),
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Missing'));
        while (controller.busy) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.enterText(
          find.byKey(const Key('g03-details')),
          'Reported from widget',
        );
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Request instructions'));
        // Wait for actual bounded IO work, not a simulated successful timer.
        while (controller.busy) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await tester.pumpAndSettle();
      expect(reported, 1);
      expect(recovery, 0);
      expect(posts('ReportIssue'), 1);
      expect(tester.takeException(), isNull);
    },
  );
}
