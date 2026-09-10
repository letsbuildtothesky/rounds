import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rounds_driver_harness/src/driver/driver_api.dart';
import 'package:rounds_driver_harness/src/driver/driver_auth_boundary.dart';
import 'package:rounds_driver_harness/src/v23/driver_storage_auth.dart';
import 'package:rounds_driver_harness/src/v23/driver_storage_lifecycle.dart';

import 'v23_device_registration_test.dart' as fixture;
import 'v23_encrypted_work_store_test.dart' as evidence;

const session = {
  'user': {'id': 'verified-user', 'displayName': 'Synthetic Driver'},
  'driver': {'id': 'old-driver-id', 'version': 1, 'preferredLocale': 'en'},
};
String bearer(DateTime expiry) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'exp': expiry.millisecondsSinceEpoch ~/ 1000}))).replaceAll('=', '')}.signature';

class Boundary implements DriverAuthBoundary {
  int locks = 0;
  final tokens = <String>[];
  Future<void> Function(String)? onAuthenticate;
  @override
  void lock() {
    locks++;
  }

  @override
  Future<void> authenticate(String token) async {
    tokens.add(token);
    await onAuthenticate?.call(token);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  const storage = FlutterSecureStorage();
  DriverApi api(
    Boundary boundary,
    Future<http.Response> Function(http.Request) handler, {
    FlutterSecureStorage? tokenStore,
    Future<Never> Function()? outbox,
  }) => DriverApi(
    supabaseUrl: 'https://auth.example.test',
    publishableKey: 'fixture-public',
    roundsApiUrl: 'https://api.example.test',
    client: MockClient(handler),
    storage: tokenStore,
    authBoundary: boundary,
    exceptionOutboxFactory: outbox,
  );

  test(
    'real OTP flow authenticates new storage only with its returned bearer',
    () async {
      final boundary = Boundary();
      final driver = api(
        boundary,
        (r) async => r.url.path == '/auth/v1/verify'
            ? fixture.jsonResponse({
                'access_token': 'A',
                'refresh_token': 'refresh-A',
              })
            : fixture.jsonResponse(session),
      );
      final result = await driver.verifyPhoneOtp('+66812345678', '123456');
      expect(result.session!.driverId, 'old-driver-id');
      expect(boundary.tokens, ['A']);
      final before = boundary.locks;
      final signedOut = driver.signOut();
      expect(boundary.locks, before + 1); // Before asynchronous token deletion.
      await signedOut;
      expect(await storage.read(key: 'rounds_driver_access_token'), isNull);
    },
  );

  test(
    'delayed OTP response after sign-out cannot restore tokens or storage',
    () async {
      final boundary = Boundary();
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final driver = api(boundary, (_) {
        started.complete();
        return response.future;
      });
      final login = driver.verifyPhoneOtp('+66812345678', '123456');
      final rejected = expectLater(login, throwsA(isA<DriverApiException>()));
      await started.future;
      await driver.signOut();
      response.complete(
        fixture.jsonResponse({
          'access_token': 'A',
          'refresh_token': 'refresh-A',
        }),
      );
      await rejected;
      expect(boundary.tokens, isEmpty);
      expect(await storage.read(key: 'rounds_driver_access_token'), isNull);
    },
  );

  test(
    'a native token write already in progress is followed by sign-out deletion',
    () async {
      final tokens = PausedTokenStore();
      final boundary = Boundary();
      final driver = api(
        boundary,
        (_) async => fixture.jsonResponse({
          'access_token': 'A',
          'refresh_token': 'refresh-A',
        }),
        tokenStore: tokens,
      );
      final login = driver.verifyPhoneOtp('+66812345678', '123456');
      final rejected = expectLater(login, throwsA(isA<DriverApiException>()));
      await tokens.started.future;
      final signedOut = driver.signOut();
      tokens.release.complete();
      await rejected;
      await signedOut;
      expect(tokens.values, isEmpty);
      expect(boundary.tokens, isEmpty);
    },
  );

  test('newer sign-in wins over a late older verification response', () async {
    final boundary = Boundary();
    final first = Completer<http.Response>();
    final started = Completer<void>();
    var requests = 0;
    final driver = api(boundary, (r) async {
      if (r.url.path == '/auth/v1/verify') {
        if (++requests == 1) {
          started.complete();
          return first.future;
        }
        return fixture.jsonResponse({
          'access_token': 'B',
          'refresh_token': 'refresh-B',
        });
      }
      return fixture.jsonResponse(session);
    });
    final a = driver.verifyPhoneOtp('+66812345678', '123456');
    final rejected = expectLater(a, throwsA(isA<DriverApiException>()));
    await started.future;
    await driver.verifyPhoneOtp('+66812345679', '654321');
    first.complete(
      fixture.jsonResponse({'access_token': 'A', 'refresh_token': 'refresh-A'}),
    );
    await rejected;
    expect(boundary.tokens, ['B']);
    expect(await storage.read(key: 'rounds_driver_access_token'), 'B');
  });

  test(
    'storage authentication failure stops restore before any queue opens',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'rounds_driver_access_token': 'A',
      });
      final boundary = Boundary()
        ..onAuthenticate = (_) async =>
            throw const StorageLifecycleException('SESSION_LOCKED');
      var opened = false;
      final driver = api(
        boundary,
        (_) async => fixture.jsonResponse(session),
        outbox: () async {
          opened = true;
          throw StateError('queue reached');
        },
      );
      await expectLater(
        driver.restore(),
        throwsA(isA<StorageLifecycleException>()),
      );
      expect(opened, isFalse);
    },
  );

  test(
    'expired restore locks on 401 before refresh and failed refresh stays locked',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'rounds_driver_access_token': 'A',
        'rounds_driver_refresh_token': 'refresh-A',
      });
      final boundary = Boundary();
      final driver = api(boundary, (r) async {
        if (r.url.path == '/auth/v1/token') {
          expect(boundary.locks, greaterThan(0));
        }
        return fixture.jsonResponse({}, 401);
      });
      expect(await driver.restore(), isNull);
      expect(boundary.tokens, isEmpty);
      expect(await storage.read(key: 'rounds_driver_access_token'), isNull);
    },
  );

  test('non-session forbidden response also locks storage', () async {
    FlutterSecureStorage.setMockInitialValues({
      'rounds_driver_access_token': 'A',
    });
    final boundary = Boundary();
    final driver = api(boundary, (_) async => fixture.jsonResponse({}, 403));
    await expectLater(
      driver.resolveTeamInvite('123456'),
      throwsA(isA<DriverApiException>()),
    );
    expect(boundary.locks, 1);
  });

  test(
    'controller sign-out lock blocks a timer restore before token deletion',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'rounds_driver_access_token': 'A',
      });
      final boundary = Boundary();
      var sent = false;
      final driver = api(boundary, (_) async {
        sent = true;
        return fixture.jsonResponse(session);
      });
      driver.lockAuthentication();
      await expectLater(driver.restore(), throwsA(isA<DriverApiException>()));
      expect(sent, isFalse);
      expect(boundary.tokens, isEmpty);
      // Controller has not removed tokens yet; that cannot unlock this session.
      expect(await storage.read(key: 'rounds_driver_access_token'), 'A');
      await driver.signOut();
    },
  );

  test(
    'late refresh after sign-out cannot write or reopen an expired session',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'rounds_driver_access_token': 'A',
        'rounds_driver_refresh_token': 'refresh-A',
      });
      final boundary = Boundary();
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final driver = api(boundary, (r) async {
        if (r.url.path == '/auth/v1/token') {
          started.complete();
          return response.future;
        }
        return fixture.jsonResponse({}, 401);
      });
      final restore = driver.restore();
      final rejected = expectLater(restore, throwsA(isA<DriverApiException>()));
      await started.future;
      await driver.signOut();
      response.complete(
        fixture.jsonResponse({
          'access_token': 'renewed-A',
          'refresh_token': 'renewed-refresh',
        }),
      );
      await rejected;
      expect(boundary.tokens, isEmpty);
      expect(await storage.read(key: 'rounds_driver_access_token'), isNull);
    },
  );

  test(
    'successful refresh verifies renewed bearer before queue access',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'rounds_driver_access_token': 'A',
        'rounds_driver_refresh_token': 'refresh-A',
      });
      final boundary = Boundary();
      var inspected = false;
      final driver = api(
        boundary,
        (r) async {
          if (r.url.path == '/auth/v1/token') {
            return fixture.jsonResponse({'access_token': 'renewed-A'});
          }
          return r.headers['authorization'] == 'Bearer A'
              ? fixture.jsonResponse({}, 401)
              : fixture.jsonResponse(session);
        },
        outbox: () async {
          inspected = true;
          expect(boundary.tokens, ['renewed-A']);
          throw StateError('fixture stops at legacy queue boundary');
        },
      );
      await expectLater(driver.restore(), throwsStateError);
      expect(inspected, isTrue);
      expect(
        await storage.read(key: 'rounds_driver_access_token'),
        'renewed-A',
      );
    },
  );

  test(
    'failed new-account OTP cannot revive the previous account by polling',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'rounds_driver_access_token': 'A',
      });
      final boundary = Boundary();
      var requests = 0;
      final driver = api(boundary, (_) async {
        requests++;
        return fixture.jsonResponse({}, 400);
      });
      await expectLater(
        driver.verifyPhoneOtp('+66812345679', '654321'),
        throwsA(isA<DriverApiException>()),
      );
      await expectLater(driver.restore(), throwsA(isA<DriverApiException>()));
      expect(requests, 1);
      expect(boundary.tokens, isEmpty);
      expect(await storage.read(key: 'rounds_driver_access_token'), 'A');
    },
  );

  group('actual registration + SQLCipher Auth adapter', () {
    late Directory temp;
    late fixture.Fixture f;
    late DriverStorageLifecycle lifecycle;
    late DriverStorageAuth binding;
    late DateTime now;
    setUp(() async {
      temp = Directory(
        Directory.systemTemp
            .createTempSync('rounds-auth-binding-')
            .resolveSymbolicLinksSync(),
      );
      f = fixture.Fixture();
      now = fixture.instant;
      lifecycle = DriverStorageLifecycle(
        registration: f.make(),
        secrets: f.secrets,
        resolveRoot: () async => temp,
        prepareLegacy: (_) async {},
      );
      await lifecycle.start();
      binding = DriverStorageAuth(lifecycle, now: () => now);
    });
    tearDown(() async {
      await binding.dispose();
      temp.deleteSync(recursive: true);
    });

    test(
      'ten-second session refreshes reuse one unlocked same-token enrollment',
      () async {
        final token = bearer(now.add(const Duration(minutes: 30)));
        final a = binding.authenticate(token);
        final b = binding.authenticate(token);
        expect(identical(a, b), isTrue);
        await a;
        await binding.authenticate(token);
        expect(f.posts.length, 1);
      },
    );

    test(
      'expiry/malformed bearer can only deny; never supplies principal authority',
      () async {
        for (final token in [
          'opaque',
          bearer(now),
          'a.!!!!.b',
          bearer(now.subtract(const Duration(seconds: 1))),
        ]) {
          await expectLater(
            binding.authenticate(token),
            throwsA(isA<StorageLifecycleException>()),
          );
        }
        expect(f.requests, isEmpty);
        final token = bearer(now.add(const Duration(minutes: 30)));
        f.override = (_) async => fixture.jsonResponse({}, 401);
        await expectLater(
          binding.authenticate(token),
          fixture.failure('UNAUTHENTICATED'),
        );
        expect(f.posts, isEmpty); // A plausible exp is never authentication.
      },
    );

    test(
      'clock expiry defeats cached access without waiting for a timer callback',
      () async {
        final token = bearer(now.add(const Duration(minutes: 30)));
        await binding.authenticate(token);
        now = now.add(const Duration(minutes: 31));
        await expectLater(
          binding.authenticate(token),
          throwsA(isA<StorageLifecycleException>()),
        );
        expect(f.posts.length, 1);
      },
    );

    test(
      'background blocks cached lease and resume needs a fresh verified unlock',
      () async {
        final token = bearer(now.add(const Duration(minutes: 30)));
        await binding.authenticate(token);
        lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
        await expectLater(
          binding.authenticate(token),
          throwsA(isA<StorageLifecycleException>()),
        );
        expect(f.posts.length, 1);
        lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(f.posts.length, 1);
        await binding.authenticate(token);
        expect(f.posts.length, 2);
      },
    );

    test(
      'actual DriverApi sign-out invalidates real encrypted evidence handle',
      () async {
        final token = bearer(now.add(const Duration(minutes: 30)));
        final driver = DriverApi(
          supabaseUrl: 'https://auth.example.test',
          publishableKey: 'fixture-public',
          roundsApiUrl: 'https://api.example.test',
          authBoundary: binding,
          client: MockClient(
            (r) async => r.url.path == '/auth/v1/verify'
                ? fixture.jsonResponse({
                    'access_token': token,
                    'refresh_token': 'refresh',
                  })
                : fixture.jsonResponse(session),
          ),
        );
        await driver.verifyPhoneOtp('+66812345678', '123456');
        final original = await lifecycle.authenticate(token);
        await original.saveEvidence(
          assetId: evidence.asset,
          purposeKind: 'proof',
          purposeEntityId: evidence.entity,
          mimeType: 'image/jpeg',
          capturedAt: evidence.captured,
          bytes: evidence.photo,
        );
        final keys = Map.of(f.secrets.values);
        final signedOut = driver.signOut();
        await expectLater(
          original.readEvidence(evidence.asset),
          throwsA(isA<StorageLifecycleException>()),
        );
        await signedOut;
        expect(f.secrets.values, keys);
        final recovered = await lifecycle.authenticate(token);
        expect(await recovered.readEvidence(evidence.asset), evidence.photo);
      },
    );

    test(
      'scheduled Auth expiry locks real storage without a network request',
      () async {
        now = DateTime.now().toUtc();
        final token = bearer(now.add(const Duration(seconds: 2)));
        await binding.authenticate(token);
        final lease = await lifecycle.authenticate(token);
        lease.requireCurrent();
        final requests = f.requests.length;
        await Future<void>.delayed(const Duration(milliseconds: 2100));
        expect(lease.requireCurrent, throwsA(isA<StorageLifecycleException>()));
        expect(f.requests.length, requests);
      },
    );
  });
}

class PausedTokenStore extends FlutterSecureStorage {
  final values = <String, String>{};
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    if (value != null) values[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}
