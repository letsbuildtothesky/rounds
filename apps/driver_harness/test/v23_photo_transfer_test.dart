import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rounds_driver_harness/src/v23/command_wire.dart';
import 'package:rounds_driver_harness/src/v23/device_registration_client.dart';
import 'package:rounds_driver_harness/src/v23/encrypted_work_store.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'v23_device_registration_test.dart' as f;
import 'v23_encrypted_work_store_test.dart' as e;
import 'v23_offline_observation_test.dart' as o;
import 'v23_offline_command_test.dart' as q;

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jO1sAAAAASUVORK5CYII=',
);
final photoId = q.id(90), serverAsset = q.id(91), proofId = q.id(92);

class PhotoFixture {
  final temp = Directory.systemTemp.createTempSync('rounds-photo-transfer-');
  final auth = f.Fixture();
  late DriverDeviceRegistrationClient transport;
  late RegisteredDriverDevice device;
  late EncryptedDriverStore store;
  DateTime now = o.when;
  final receipts = <String, Map<String, dynamic>>{};
  final puts = <http.Request>[];
  Future<http.Response?> Function(http.Request)? intercept;
  bool uploaded = false;
  int signatures = 0;
  String uploadUrl =
      'https://upload.example.test/private-stage?signature=ephemeral-secret';
  String uploadMethod = 'PUT';
  String? uploadToken;
  Future<void> open({ExecutionCaptureContext? context}) async {
    transport = DriverDeviceRegistrationClient(
      authOrigin: Uri.parse('https://auth.example.test'),
      apiOrigin: Uri.parse('https://api.example.test'),
      publishableKey: 'test-key',
      store: DeviceInstallationStore(
        backend: auth.secrets,
        platform: 'android',
      ),
      client: auth.client,
      uploadOrigins: {Uri.parse('https://upload.example.test/')},
      now: () => f.instant,
      timeout: const Duration(seconds: 2),
    );
    device = await transport.ensureSession('A');
    auth.override = handle;
    store = await EncryptedDriverStore.open(
      device: device,
      privateParent: temp,
      secrets: auth.secrets,
      commandClock: () => now,
    );
    await store.cacheExecutionContext(
      context ?? ExecutionCaptureContext.fromJson(q.context()),
    );
  }

  Future<void> reopen({Future<void> Function(String)? checkpoint}) async {
    store.close();
    store = await EncryptedDriverStore.open(
      device: device,
      privateParent: temp,
      secrets: auth.secrets,
      commandClock: () => now,
      checkpoint: checkpoint,
    );
  }

  void close() {
    store.close();
    transport.dispose();
    temp.deleteSync(recursive: true);
  }

  void tick() {
    now = now.add(const Duration(seconds: 61));
  }

  Future<http.Response> handle(http.Request request) async {
    final overridden = await intercept?.call(request);
    if (overridden != null) return overridden;
    if (request.url.path == '/auth/v1/user') {
      return f.jsonResponse({'id': f.subjectA});
    }
    if (request.url.path.startsWith('/v1/auth/')) {
      return f.jsonResponse(f.wire());
    }
    if (request.method == 'PUT') {
      puts.add(request);
      uploaded = true;
      return http.Response('', 201);
    }
    if (request.method == 'GET') {
      final result = receipts[request.url.queryParameters['entity_id']];
      return result == null
          ? f.jsonResponse(q.error('NOT_FOUND'), 404)
          : f.jsonResponse({
              'as_of': f.instant.toIso8601String(),
              'data': {'result': outward(result)},
              'next_cursor': null,
            });
    }
    final w = jsonDecode(request.body) as Map<String, dynamic>,
        type = request.url.path.split('/').last;
    validateCommandWire('${type}Request', w);
    if (type == 'VerifyAsset' && !uploaded) {
      return f.jsonResponse(q.error('NOT_FOUND'), 404);
    }
    final result = receipts.putIfAbsent(
      w['command_id'] as String,
      () => resultFor(w, type),
    );
    return f.jsonResponse(outward(result));
  }

  Map<String, dynamic> outward(Map<String, dynamic> r) {
    if (r['command_type'] != 'ReserveAsset' || r['state'] != 'committed') {
      return r;
    }
    signatures++;
    return {
      ...r,
      'data': {
        'asset_id': serverAsset,
        'upload_url': '$uploadUrl&renewal=$signatures',
        'upload_token': uploadToken,
        'upload_method': uploadMethod,
        'expires_at': f.instant
            .add(const Duration(minutes: 4))
            .toIso8601String(),
      },
    };
  }

  Map<String, dynamic> resultFor(Map<String, dynamic> w, String type) {
    if (!{
      'ReserveAsset',
      'VerifyAsset',
      'SubmitProof',
      'CompleteDelivery',
    }.contains(type)) {
      return q.receipt(w, type);
    }
    final changed = (w['expected_versions'] as List)
        .map(
          (v) => q.root(
            v['aggregate_type'] as String,
            v['id'] as String,
            v['version'] + 1 as int,
          ),
        )
        .toList();
    var resources = <Map<String, dynamic>>[];
    late Map<String, dynamic> data;
    if (type == 'ReserveAsset') {
      resources = [q.root('assets', serverAsset, 1)];
      data = {'asset_id': serverAsset};
    } else if (type == 'VerifyAsset') {
      data = {'resource': changed.single, 'state': 'verified'};
    } else if (type == 'SubmitProof') {
      resources = [q.root('proof_submissions', proofId, 1)];
      changed.add(q.root('deliveries', q.id(41), 2));
      data = {'resource': resources.single, 'state': 'pending'};
    } else {
      changed.add(q.root('proof_submissions', proofId, 2));
      data = {'resource': changed.first, 'state': 'completed'};
    }
    return {
      'command_id': w['command_id'],
      'command_type': type,
      'state': 'committed',
      'current_versions': changed,
      'resources': resources,
      'data': data,
    };
  }

  Future<void> observation(
    int n,
    String kind,
    Map<String, dynamic> payload, {
    bool photo = false,
  }) async {
    final image = photo
        ? ObservationPhoto(assetId: photoId, mimeType: 'image/png', bytes: png)
        : null;
    try {
      await store.recordObservation(
        LocalObservationDraft(
          observationId: q.id(100 + n),
          assignmentId: o.assignment,
          assignmentVersion: 1,
          kind: kind,
          stopId: n < 3 ? o.stop : q.drop1,
          fulfillmentUnitId: q.unit1,
          observedAt: o.when.add(Duration(seconds: n)),
          observedPayload: {'command_payload': payload},
          predecessorObservationIds: n == 1 ? [] : [q.id(99 + n)],
        ),
        photo: image,
      );
    } finally {
      image?.dispose();
    }
  }

  Future<void> chain() async {
    for (var n = 1; n <= 4; n++) {
      await observation(
        n,
        n == 2
            ? 'pickup'
            : n == 4
            ? 'handoff'
            : 'arrival',
        n == 2
            ? {
                'manifest_ids': [q.manifest1, q.manifest2],
                'fulfillment_unit_ids': [q.unit1, q.unit2],
                'quantities': [
                  {'line_id': q.manifest1, 'quantity': 1},
                  {'line_id': q.manifest2, 'quantity': 2},
                ],
              }
            : n == 4
            ? {
                'receiver_kind': 'recipient',
                'receiver_contact_id': q.id(65),
                'quantities': [
                  {'line_id': q.manifest1, 'quantity': 1},
                ],
              }
            : {
                'point': {'latitude': 13.7, 'longitude': 100.5},
                'accuracy_m': 5,
              },
      );
      await store.materializeObservation(q.id(100 + n));
      expect(
        (await store.synchronizeObservation(
          q.id(100 + n),
          transport: transport,
          bearer: 'A',
        )).state,
        'committed',
      );
    }
    await observation(5, 'proof', {
      'evidence': [
        {'kind': 'photo', 'local_asset_id': photoId},
        {'kind': 'note', 'note': 'Doorstep — exact note ✓'},
        {'kind': 'location'},
        {'kind': 'manifest', 'line_id': q.manifest1, 'quantity': 1},
        {'kind': 'receiver', 'receiver_contact_id': q.id(65)},
      ],
    }, photo: true);
  }

  Future<StoredPhotoTransfer> advance() =>
      store.advancePhotoTransfer(q.id(105), transport: transport, bearer: 'A');
  Future<void> verify() async {
    await store.preparePhotoTransfer(q.id(105));
    expect((await advance()).state, 'upload');
    expect((await advance()).state, 'verify');
    expect((await advance()).state, 'verified');
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
}

void main() {
  late PhotoFixture fxt;
  setUp(() async {
    fxt = PhotoFixture();
    await fxt.open();
    await fxt.chain();
  });
  tearDown(() => fxt.close());
  test(
    'saved encrypted photo reaches verification, proof and completion with actual frozen bindings',
    () async {
      await expectLater(
        fxt.store.materializeObservation(q.id(105)),
        e.fails('ASSET_NOT_VERIFIED'),
      );
      await fxt.verify();
      await fxt.reopen();
      expect(fxt.puts.single.bodyBytes, png);
      expect(
        fxt.puts.single.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(
        fxt.puts.single.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('x-rounds-device-session')),
      );
      expect(await fxt.store.readEvidence(photoId), png);
      final proof = await fxt.store.materializeObservation(q.id(105));
      expect(
        (await fxt.store.synchronizeObservation(
          q.id(105),
          transport: fxt.transport,
          bearer: 'A',
        )).state,
        'committed',
      );
      await fxt.observation(6, 'completion', {});
      await fxt.store.materializeObservation(q.id(106));
      expect(
        (await fxt.store.synchronizeObservation(
          q.id(106),
          transport: fxt.transport,
          bearer: 'A',
        )).state,
        'committed',
      );
      final db = fxt.raw();
      try {
        final rows = db
            .select(
              'SELECT command_type,payload_json,request_hash,server_receipt_json FROM pending_commands',
            )
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
        final json = jsonEncode(rows);
        expect(json, isNot(contains('ephemeral-secret')));
        expect(json, isNot(contains('upload_url')));
        expect(
          db.select('SELECT COUNT(*) n FROM pending_commands').single['n'],
          8,
        );
        expect(
          db.select(
            'SELECT COUNT(*) n FROM command_dependencies WHERE command_id=?',
            [proof.commandId],
          ).single['n'],
          5,
        );
        final proofWire = jsonDecode(
          rows.singleWhere(
                (r) => r['command_type'] == 'SubmitProof',
              )['payload_json']
              as String,
        );
        expect(proofWire['payload']['handoff_id'], q.id(62));
        expect(proofWire['payload']['evidence'][0]['asset_id'], serverAsset);
        expect(
          proofWire['payload']['evidence'][2]['location_observation_id'],
          q.id(30),
        );
        final probe = await Process.run('node', [
          '--import',
          'tsx',
          'services/api/test/v23/native-command-contract-probe.ts',
          base64Encode(utf8.encode(json)),
        ], workingDirectory: '../..');
        expect(probe.exitCode, 0, reason: '${probe.stdout}\n${probe.stderr}');
      } finally {
        db.close();
      }
      expect(
        (await fxt.store.observations()).every(
          (o) => o.state == 'local_recorded',
        ),
        isTrue,
      );
    },
  );
  test(
    'lost PUT acknowledgement verifies existing bytes before any second upload',
    () async {
      await fxt.store.preparePhotoTransfer(q.id(105));
      await fxt.advance();
      fxt.intercept = (r) async {
        if (r.method == 'PUT') {
          fxt.uploaded = true;
          throw const SocketException('lost');
        }
        return null;
      };
      expect((await fxt.advance()).state, 'verify');
      await fxt.reopen();
      fxt.tick();
      fxt.intercept = null;
      expect((await fxt.advance()).state, 'verified');
      expect(fxt.puts, isEmpty);
    },
  );
  test(
    'missing uploaded bytes require missing verification status before retry with same IDs',
    () async {
      await fxt.store.preparePhotoTransfer(q.id(105));
      await fxt.advance();
      fxt.intercept = (r) async {
        if (r.method == 'PUT') throw const SocketException('offline');
        return null;
      };
      await fxt.advance();
      fxt.tick();
      fxt.intercept = null;
      expect((await fxt.advance()).state, 'verify');
      fxt.tick();
      expect((await fxt.advance()).state, 'upload');
      fxt.tick();
      expect((await fxt.advance()).state, 'verify');
      expect((await fxt.advance()).state, 'verified');
      expect(fxt.signatures, greaterThan(2));
      final db = fxt.raw();
      try {
        expect(
          db
              .select(
                "SELECT COUNT(*) n FROM pending_commands WHERE command_type='VerifyAsset'",
              )
              .single['n'],
          1,
        );
      } finally {
        db.close();
      }
    },
  );
  test(
    'capabilities cannot send photos to an unconfigured origin or carry a separate token',
    () async {
      fxt.uploadUrl = 'https://other.example.test/collect';
      await fxt.store.preparePhotoTransfer(q.id(105));
      await fxt.advance();
      expect(
        (await fxt.advance()).errorCode,
        'UPLOAD_NOT_CONFIGURED_OR_INVALID',
      );
      expect(fxt.puts, isEmpty);
      expect(fxt.uploaded, isFalse);
    },
  );
  test(
    'assignment change blocks new upload without changing local evidence',
    () async {
      await fxt.store.preparePhotoTransfer(q.id(105));
      await fxt.advance();
      await fxt.store.invalidateExecutionContext(o.assignment, 1);
      expect((await fxt.advance()).state, 'needs_review');
      expect(fxt.puts, isEmpty);
      expect(await fxt.store.readEvidence(photoId), png);
    },
  );
  test('verification rejection blocks proof and keeps photo', () async {
    await fxt.store.preparePhotoTransfer(q.id(105));
    await fxt.advance();
    await fxt.advance();
    fxt.intercept = (r) async {
      if (r.url.path.endsWith('/VerifyAsset')) {
        final w = jsonDecode(r.body);
        return f.jsonResponse({
          'command_id': w['command_id'],
          'command_type': 'VerifyAsset',
          'state': 'rejected',
          'error': q.error('VALIDATION_FAILED'),
        });
      }
      return null;
    };
    expect((await fxt.advance()).state, 'rejected');
    await expectLater(
      fxt.store.materializeObservation(q.id(105)),
      e.fails('ASSET_NOT_VERIFIED'),
    );
    expect(await fxt.store.readEvidence(photoId), png);
  });
  for (final variant in [
    'token',
    'post',
    'http',
    'userinfo',
    'fragment',
    'redirect',
  ]) {
    test(
      'signed PUT rejects unsupported $variant without credential/photo disclosure',
      () async {
        if (variant == 'token') fxt.uploadToken = 'not-a-header-contract';
        if (variant == 'post') fxt.uploadMethod = 'POST';
        if (variant == 'http') {
          fxt.uploadUrl = 'http://upload.example.test/object';
        }
        if (variant == 'userinfo') {
          fxt.uploadUrl = 'https://secret@upload.example.test/object';
        }
        if (variant == 'fragment') {
          fxt.uploadUrl = 'https://upload.example.test/object#fragment';
        }
        if (variant == 'redirect') {
          fxt.intercept = (r) async => r.method == 'PUT'
              ? http.Response(
                  '',
                  302,
                  headers: {'location': 'https://other.example.test/steal'},
                )
              : null;
        }
        await fxt.store.preparePhotoTransfer(q.id(105));
        await fxt.advance();
        final result = await fxt.advance();
        expect(
          result.errorCode,
          variant == 'redirect'
              ? 'UPLOAD_RESULT_UNKNOWN'
              : 'UPLOAD_NOT_CONFIGURED_OR_INVALID',
        );
        expect(fxt.puts, isEmpty);
        expect(
          fxt.auth.requests.any((r) => r.url.host == 'other.example.test'),
          isFalse,
        );
      },
    );
  }
  test(
    'reservation transaction failure rolls back its command, binding and transfer together',
    () async {
      final db = fxt.raw();
      db.execute(
        "CREATE TRIGGER reject_photo_binding BEFORE INSERT ON observation_bindings WHEN NEW.payload_pointer='/media/reserve/payload/purpose_entity_id' BEGIN SELECT RAISE(ABORT,'fixture failure'); END",
      );
      db.close();
      await expectLater(
        fxt.store.preparePhotoTransfer(q.id(105)),
        e.fails('STORAGE_IO_FAILED'),
      );
      await fxt.reopen();
      final check = fxt.raw();
      try {
        expect(
          check
              .select(
                "SELECT COUNT(*) n FROM pending_commands WHERE command_type='ReserveAsset'",
              )
              .single['n'],
          0,
        );
        expect(
          check
              .select(
                "SELECT COUNT(*) n FROM work_cache WHERE entity_type='pod_transfer_v1'",
              )
              .single['n'],
          0,
        );
        check.execute('DROP TRIGGER reject_photo_binding');
      } finally {
        check.close();
      }
      await fxt.verify();
    },
  );
  test(
    'sign-out during upload cannot return success or bind a late verification',
    () async {
      await fxt.store.preparePhotoTransfer(q.id(105));
      await fxt.advance();
      final started = Completer<void>(), reply = Completer<http.Response>();
      fxt.intercept = (r) async {
        if (r.method == 'PUT') {
          started.complete();
          return reply.future;
        }
        return null;
      };
      final pending = fxt.advance();
      final denied = expectLater(pending, e.fails('STORE_LOCKED'));
      await started.future;
      fxt.transport.lock();
      reply.complete(http.Response('', 201));
      await denied;
      expect(
        fxt.receipts.values.where((r) => r['command_type'] == 'VerifyAsset'),
        isEmpty,
      );
    },
  );
  test(
    'lost verification receipt and duplicate prepare keep one reservation and verification',
    () async {
      await Future.wait([
        fxt.store.preparePhotoTransfer(q.id(105)),
        fxt.store.preparePhotoTransfer(q.id(105)),
      ]);
      await fxt.advance();
      await fxt.advance();
      var lost = false;
      fxt.intercept = (r) async {
        if (r.url.path.endsWith('/VerifyAsset') && !lost) {
          lost = true;
          final w = jsonDecode(r.body) as Map<String, dynamic>;
          fxt.receipts[w['command_id'] as String] = fxt.resultFor(
            w,
            'VerifyAsset',
          );
          throw const SocketException('ack lost');
        }
        return null;
      };
      expect((await fxt.advance()).state, 'verify');
      await fxt.reopen();
      fxt.tick();
      expect((await fxt.advance()).state, 'verified');
      expect(fxt.puts.length, 1);
    },
  );
  test('proof rejects caller-supplied remote asset authority', () async {
    await fxt.verify();
    // A distinct immutable submission cannot smuggle a remote asset identifier.
    await fxt.store.recordObservation(
      LocalObservationDraft(
        observationId: q.id(150),
        assignmentId: o.assignment,
        assignmentVersion: 1,
        kind: 'proof',
        stopId: q.drop1,
        fulfillmentUnitId: q.unit1,
        observedAt: o.when.add(const Duration(seconds: 8)),
        observedPayload: {
          'command_payload': {
            'evidence': [
              {'kind': 'photo', 'asset_id': serverAsset},
            ],
          },
        },
        predecessorObservationIds: [q.id(104)],
      ),
    );
    await expectLater(
      fxt.store.materializeObservation(q.id(150)),
      e.fails('OBSERVATION_AUTHORITY_OVERRIDE'),
    );
  });
  test(
    'nullable proof scalar schemas reject invalid nonnull types and lengths',
    () async {
      expect(
        () => validateCommandWire('proof_ref', {
          'kind': 'manifest',
          'quantity': '1',
        }),
        f.failure('INVALID_COMMAND_WIRE'),
      );
      expect(
        () => validateCommandWire('proof_ref', {
          'kind': 'note',
          'note': 'x' * 2001,
        }),
        f.failure('INVALID_COMMAND_WIRE'),
      );
      validateCommandWire('proof_ref', {
        'kind': 'note',
        'note': null,
        'quantity': null,
      });
    },
  );
  for (final variant in ['old-format', 'unselected', 'signature']) {
    test(
      'a $variant capture cannot silently become an uploaded delivery photo',
      () async {
        final capture = ObservationPhoto(
          assetId: e.asset2,
          mimeType: 'image/png',
          bytes: png,
        );
        try {
          await fxt.store.recordObservation(
            LocalObservationDraft(
              observationId: q.id(160),
              assignmentId: o.assignment,
              assignmentVersion: 1,
              kind: 'proof',
              stopId: q.drop1,
              fulfillmentUnitId: q.unit1,
              observedAt: o.when.add(const Duration(seconds: 8)),
              predecessorObservationIds: [q.id(104)],
              observedPayload: variant == 'old-format'
                  ? {'note': 'old camera test'}
                  : {
                      'command_payload': {
                        'evidence': [
                          variant == 'signature'
                              ? {
                                  'kind': 'signature',
                                  'local_asset_id': e.asset2,
                                }
                              : {'kind': 'note', 'note': 'No selected photo'},
                        ],
                      },
                    },
            ),
            photo: capture,
          );
        } finally {
          capture.dispose();
        }
        await expectLater(
          fxt.store.preparePhotoTransfer(q.id(160)),
          e.fails('PHOTO_TRANSFER_NOT_READY'),
        );
        expect(await fxt.store.readEvidence(e.asset2), png);
        expect(fxt.puts, isEmpty);
      },
    );
  }
  for (final point in [
    'photo_before_prepare',
    'photo_prepared',
    'photo_before_upload',
    'photo_upload_returned',
    'photo_before_verified',
    'photo_verified',
  ]) {
    test(
      'restart at $point keeps photo and original command identities',
      () async {
        var crashed = false;
        await fxt.reopen(
          checkpoint: (name) async {
            if (name == point && !crashed) {
              crashed = true;
              throw StateError('injected interruption');
            }
          },
        );
        try {
          await fxt.store.preparePhotoTransfer(q.id(105));
          await fxt.advance();
          await fxt.advance();
          await fxt.advance();
        } on EncryptedStoreException catch (error) {
          expect(error.code, 'STORAGE_IO_FAILED');
        }
        expect(crashed, isTrue);
        await fxt.reopen();
        await fxt.store.preparePhotoTransfer(q.id(105));
        for (
          var i = 0;
          i < 8 &&
              (await fxt.store.photoTransfer(q.id(105)))!.state != 'verified';
          i++
        ) {
          fxt.tick();
          await fxt.advance();
        }
        expect((await fxt.store.photoTransfer(q.id(105)))!.state, 'verified');
        expect(await fxt.store.readEvidence(photoId), png);
        final db = fxt.raw();
        try {
          expect(
            db
                .select(
                  "SELECT COUNT(*) n FROM pending_commands WHERE command_type='ReserveAsset'",
                )
                .single['n'],
            1,
          );
        } finally {
          db.close();
        }
      },
    );
  }
}
