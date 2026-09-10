import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rounds_driver_harness/src/v23/device_registration_client.dart';
import 'package:rounds_driver_harness/src/v23/device_wire.dart';

const subjectA = '11111111-1111-4111-8111-111111111111';
const subjectB = '22222222-2222-4222-8222-222222222222';
const principalA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const principalB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const deviceA = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
final instant = DateTime.utc(2026, 9, 8, 12);
String get capability => 'test_payload.${List.filled(43, 'a').join()}';
Map<String, dynamic> wire({String principal = principalA, int epoch = 1}) => {
  'principal_id': principal,
  'device_id': deviceA,
  'session_epoch': epoch,
  'device_session': capability,
  'expires_at': instant.add(const Duration(minutes: 15)).toIso8601String(),
};
http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);
Matcher failure(String code) => throwsA(
  isA<DeviceEnrollmentException>().having((e) => e.code, 'safe code', code),
);

class MemorySecrets implements DeviceSecretBackend {
  final values = <String, String>{};
  bool failWrite = false,
      loseWrite = false,
      failRead = false,
      throwAfterWrite = false;
  int writes = 0;
  @override
  Future<String?> read(String key) async {
    if (failRead) throw Exception('native error with private details');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    if (failWrite) throw Exception('native error with secret');
    if (!loseWrite) values[key] = value;
    if (throwAfterWrite) throw Exception('ack lost after durable write');
  }
}

class Fixture {
  final secrets = MemorySecrets();
  final requests = <http.Request>[];
  Future<http.Response> Function(http.Request)? override;
  late final client = MockClient((request) async {
    requests.add(request);
    if (override != null) return override!(request);
    if (request.url.path == '/auth/v1/user') {
      return jsonResponse({
        'id': request.headers['authorization'] == 'Bearer B'
            ? subjectB
            : subjectA,
      });
    }
    if (request.url.path.endsWith('/revoke')) {
      return jsonResponse({'device_id': deviceA, 'revoked': true});
    }
    return jsonResponse(
      wire(
        principal: request.headers['authorization'] == 'Bearer B'
            ? principalB
            : principalA,
      ),
    );
  });
  DriverDeviceRegistrationClient make({
    String platform = 'android',
    Duration? timeout,
    String origin = 'https://api.example.test',
  }) => DriverDeviceRegistrationClient(
    authOrigin: Uri.parse('https://auth.example.test'),
    apiOrigin: Uri.parse(origin),
    publishableKey: 'public-test-key',
    store: DeviceInstallationStore(backend: secrets, platform: platform),
    client: client,
    now: () => instant,
    timeout: timeout ?? const Duration(seconds: 1),
  );
  List<http.Request> get posts =>
      requests.where((r) => r.method == 'POST').toList();
}

class AbortProbe extends http.BaseClient {
  bool aborted = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final pending = Completer<http.StreamedResponse>();
    expect(request, isA<http.Abortable>());
    (request as http.Abortable).abortTrigger!.then((_) {
      aborted = true;
      pending.completeError(http.RequestAbortedException(request.url));
    });
    return pending.future;
  }
}

void main() {
  test('deadline aborts an outstanding native-compatible request', () async {
    final probe = AbortProbe();
    final client = DriverDeviceRegistrationClient(
      authOrigin: Uri.parse('https://auth.example.test'),
      apiOrigin: Uri.parse('https://api.example.test'),
      publishableKey: 'public-test-key',
      store: DeviceInstallationStore(
        backend: MemorySecrets(),
        platform: 'android',
      ),
      client: probe,
      timeout: const Duration(milliseconds: 30),
    );
    await expectLater(
      client.ensureSession('A'),
      failure('PROVIDER_UNAVAILABLE'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(probe.aborted, isTrue);
  });

  test(
    'schema rejects normalized calendar overflows and UUID trailing bytes',
    () {
      for (final date in [
        '2026-02-30T12:00:00Z',
        '2026-09-08T25:00:00Z',
        '2026-09-08T12:00:00+24:00',
        '2026-09-08T12:00:00Z\n',
      ]) {
        expect(
          () => deviceWire('DriverDeviceSessionResult', {
            ...wire(),
            'expires_at': date,
          }),
          failure('INVALID_RESPONSE'),
        );
      }
      expect(
        () => deviceWire('DriverDeviceSessionResult', {
          ...wire(),
          'principal_id': '$principalA\n',
        }),
        failure('INVALID_RESPONSE'),
      );
    },
  );

  test('epoch regression blocks without replacing original identity', () async {
    final f = Fixture();
    f.override = (r) async => r.method == 'GET'
        ? jsonResponse({'id': subjectA})
        : jsonResponse(wire(epoch: 2));
    await f.make().ensureSession('A');
    f.override = null;
    await expectLater(
      f.make().ensureSession('A'),
      failure('IDENTITY_MISMATCH'),
    );
    expect(jsonDecode(f.secrets.values.values.single)['epoch'], 2);
  });

  test(
    'persist before registration; restart/refresh reuses exact secret and identity',
    () async {
      final f = Fixture();
      f.override = (request) async {
        if (request.method == 'GET') return jsonResponse({'id': subjectA});
        expect(f.secrets.values, hasLength(1));
        final saved = jsonDecode(f.secrets.values.values.single) as Map;
        expect(
          jsonDecode(request.body)['installation_secret'],
          saved['secret'],
        );
        expect(request.followRedirects, isFalse);
        return jsonResponse(wire());
      };
      final first = await f.make().ensureSession('A');
      final second = await f.make().ensureSession('A');
      expect(f.posts.map((r) => r.body).toSet(), hasLength(1));
      expect(first.deviceId, second.deviceId);
      expect(first.transportHeaders['X-Rounds-Device-Session'], capability);
      expect(f.secrets.values.values.single, isNot(contains(capability)));
      expect(f.secrets.values.values.single, isNot(contains('Bearer')));
      expect(first.toString(), isNot(contains(capability)));
    },
  );

  test('concurrent client instances serialize installation creation', () async {
    final f = Fixture();
    await Future.wait(List.generate(6, (_) => f.make().ensureSession('A')));
    expect(f.secrets.values, hasLength(1));
    expect(f.posts.map((r) => r.body).toSet(), hasLength(1));
  });

  test(
    'verified accounts and configured environments have separate stable secrets',
    () async {
      final f = Fixture();
      await f.make().ensureSession('A');
      await f.make().ensureSession('B');
      await f.make(origin: 'https://other.example.test').ensureSession('A');
      expect(f.secrets.values, hasLength(3));
      final bodies = f.posts.map((r) => jsonDecode(r.body) as Map).toList();
      expect(bodies.map((b) => b['installation_secret']).toSet(), hasLength(3));
      expect(bodies.every((b) => !b.containsKey('principal_id')), isTrue);
    },
  );

  for (final mode in ['failWrite', 'loseWrite', 'failRead']) {
    test('$mode prevents any enrollment POST; no insecure fallback', () async {
      final f = Fixture();
      f.secrets.failWrite = mode == 'failWrite';
      f.secrets.loseWrite = mode == 'loseWrite';
      f.secrets.failRead = mode == 'failRead';
      await expectLater(
        f.make().ensureSession('A'),
        failure('SECURE_STORAGE_UNAVAILABLE'),
      );
      expect(f.posts, isEmpty);
    });
  }

  test(
    'lost secure write acknowledgement recovers same persisted identity',
    () async {
      final f = Fixture();
      f.secrets.throwAfterWrite = true;
      await expectLater(
        f.make().ensureSession('A'),
        failure('SECURE_STORAGE_UNAVAILABLE'),
      );
      expect(f.posts, isEmpty);
      final original = jsonDecode(f.secrets.values.values.single)['secret'];
      f.secrets.throwAfterWrite = false;
      await f.make().ensureSession('A');
      expect(jsonDecode(f.posts.single.body)['installation_secret'], original);
    },
  );

  test('corrupt stored identity is retained, never replaced or sent', () async {
    final f = Fixture();
    await f.make().ensureSession('A');
    f.secrets.values[f.secrets.values.keys.single] =
        'broken private credential';
    final writes = f.secrets.writes;
    await expectLater(
      f.make().ensureSession('A'),
      failure('SECURE_STORAGE_CORRUPT'),
    );
    expect(f.secrets.writes, writes);
    expect(f.posts, hasLength(1));
    expect(f.secrets.values.values.single, 'broken private credential');
  });

  test(
    '401 or invalid provider identity never reads or writes local secrets',
    () async {
      final f = Fixture();
      f.secrets.failRead = true;
      f.override = (_) async =>
          jsonResponse({'code': 'bad', 'secret': 'do not echo'}, 401);
      await expectLater(
        f.make().ensureSession('not-a-jwt'),
        failure('UNAUTHENTICATED'),
      );
      f.override = (_) async => jsonResponse({'id': 'caller-chosen-name'});
      await expectLater(
        f.make().ensureSession('A'),
        failure('INVALID_RESPONSE'),
      );
      expect(f.secrets.writes, 0);
      expect(f.posts, isEmpty);
    },
  );

  test(
    'server denies device: durable block survives restart without key rotation',
    () async {
      final f = Fixture();
      await f.make().ensureSession('A');
      final original = jsonDecode(f.secrets.values.values.single)['secret'];
      f.override = (r) async => r.method == 'GET'
          ? jsonResponse({'id': subjectA})
          : jsonResponse({'code': 'NOT_AUTHORIZED'}, 403);
      await expectLater(f.make().ensureSession('A'), failure('NOT_AUTHORIZED'));
      f.override = null;
      await expectLater(
        f.make().ensureSession('A'),
        failure('DEVICE_REQUIRES_RECOVERY'),
      );
      expect(jsonDecode(f.secrets.values.values.single)['secret'], original);
      expect(f.posts, hasLength(2));
    },
  );

  test(
    'unknown registration retries exact identity; no capabilities in error text',
    () async {
      final f = Fixture();
      f.override = (r) async {
        if (r.method == 'GET') return jsonResponse({'id': subjectA});
        throw http.ClientException('transport may contain a secret', r.url);
      };
      await expectLater(f.make().ensureSession('A'), failure('UNKNOWN_RESULT'));
      f.override = null;
      await f.make().ensureSession('A');
      expect(f.posts[0].body, f.posts[1].body);
    },
  );

  test(
    'unknown revoke stays locked and explicit retry uses same secret',
    () async {
      final f = Fixture();
      await f.make().ensureSession('A');
      f.override = (r) async => r.method == 'GET'
          ? jsonResponse({'id': subjectA})
          : jsonResponse({'code': 'UNKNOWN_RESULT'}, 503);
      await expectLater(f.make().revoke('A'), failure('UNKNOWN_RESULT'));
      f.override = null;
      await expectLater(
        f.make().ensureSession('A'),
        failure('DEVICE_REQUIRES_RECOVERY'),
      );
      await f.make().revoke('A');
      expect(f.posts[1].body, f.posts[2].body);
      expect(jsonDecode(f.secrets.values.values.single)['state'], 'revoked');
      await expectLater(
        f.make().ensureSession('A'),
        failure('DEVICE_REQUIRES_RECOVERY'),
      );
    },
  );

  test('revoke missing identity never generates a new one', () async {
    final f = Fixture();
    await expectLater(f.make().revoke('A'), failure('NOT_ENROLLED'));
    expect(f.secrets.values, isEmpty);
    expect(f.posts, isEmpty);
  });

  test(
    'sign-out invalidates in-flight result and preserves installation',
    () async {
      final f = Fixture();
      final reached = Completer<void>(), resume = Completer<void>();
      f.override = (r) async {
        if (r.method == 'GET') return jsonResponse({'id': subjectA});
        reached.complete();
        await resume.future;
        return jsonResponse(wire());
      };
      final client = f.make();
      final pending = client.ensureSession('A');
      final assertion = expectLater(pending, failure('SESSION_CHANGED'));
      await reached.future;
      client.lock();
      resume.complete();
      await assertion;
      expect(f.secrets.values, hasLength(1));
      f.override = null;
      await client.ensureSession('B');
      expect(f.secrets.values, hasLength(2));
    },
  );

  test(
    'timeout has no late storage side effects and retains identity',
    () async {
      final f = Fixture();
      final resume = Completer<void>();
      f.override = (r) async {
        if (r.method == 'GET') return jsonResponse({'id': subjectA});
        await resume.future;
        return jsonResponse(wire());
      };
      await expectLater(
        f.make(timeout: const Duration(milliseconds: 30)).ensureSession('A'),
        failure('UNKNOWN_RESULT'),
      );
      final writes = f.secrets.writes;
      resume.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(f.secrets.writes, writes);
    },
  );

  test(
    'principal/device identity and epoch cannot be silently replaced',
    () async {
      final f = Fixture();
      await f.make().ensureSession('A');
      f.override = (r) async => r.method == 'GET'
          ? jsonResponse({'id': subjectA})
          : jsonResponse(wire(principal: principalB));
      await expectLater(
        f.make().ensureSession('A'),
        failure('IDENTITY_MISMATCH'),
      );
      expect(
        jsonDecode(f.secrets.values.values.single)['principal'],
        principalA,
      );
    },
  );

  test(
    'platform mismatch fails before POST and does not overwrite record',
    () async {
      final f = Fixture();
      await f.make().ensureSession('A');
      await expectLater(
        f.make(platform: 'ios').ensureSession('A'),
        failure('IDENTITY_MISMATCH'),
      );
      expect(f.posts, hasLength(1));
    },
  );

  for (final invalid in <Map<String, dynamic>>[
    {...wire(), 'extra': true},
    {...wire(), 'session_epoch': 0},
    {...wire(), 'session_epoch': 1.5},
    {...wire(), 'session_epoch': 9007199254740992},
    {...wire(), 'device_id': 'invalid'},
    {...wire(), 'device_session': '$capability\n'},
    {...wire(), 'expires_at': instant.toIso8601String()},
    {
      ...wire(),
      'expires_at': instant.add(const Duration(hours: 1)).toIso8601String(),
    },
  ]) {
    test(
      'strict generated contract/lifetime rejection ${invalid.keys.where((k) => invalid[k] != wire()[k]).join(',')}:${invalid['session_epoch']}',
      () async {
        final f = Fixture();
        f.override = (r) async => r.method == 'GET'
            ? jsonResponse({'id': subjectA})
            : jsonResponse(invalid);
        await expectLater(
          f.make().ensureSession('A'),
          failure('INVALID_RESPONSE'),
        );
        expect(jsonDecode(f.secrets.values.values.single)['principal'], isNull);
      },
    );
  }

  test(
    'oversized response and redirect are rejected without response echo',
    () async {
      final f = Fixture();
      f.override = (r) async => r.method == 'GET'
          ? jsonResponse({'id': subjectA})
          : http.Response('private${List.filled(5000, 'x').join()}', 200);
      await expectLater(
        f.make().ensureSession('A'),
        failure('INVALID_RESPONSE'),
      );
      f.override = (_) async => http.Response(
        '',
        307,
        headers: {'location': 'https://attacker.test'},
      );
      await expectLater(
        f.make().ensureSession('A'),
        failure('PROVIDER_UNAVAILABLE'),
      );
    },
  );

  test('rejects insecure or ambiguous origins and unsupported platform', () {
    final f = Fixture();
    for (final origin in [
      'http://api.example.test',
      'https://user@api.example.test',
      'https://api.example.test/path',
      'https://api.example.test?x=1',
    ]) {
      expect(() => f.make(origin: origin), failure('INVALID_CONFIGURATION'));
    }
    expect(() => f.make(platform: 'web'), failure('UNSUPPORTED_PLATFORM'));
  });
}
