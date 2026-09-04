import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rounds_driver_harness/src/driver/driver_api.dart';
import 'package:rounds_driver_harness/src/driver/driver_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'local locale wins after one stale cross-device profile conflict',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'rounds_driver_access_token': 'access-token',
      });
      final submittedVersions = <int>[];
      var sessionReadCount = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/v1/driver/preferences/locale') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          submittedVersions.add(body['expectedVersion'] as int);
          expect(body['preferredLocale'], 'th-TH');
          expect(request.headers['idempotency-key'], contains('th-TH'));
          return submittedVersions.length == 1
              ? http.Response(
                  jsonEncode({
                    'status': 'rejected',
                    'error': {'code': 'STALE_VERSION', 'message': 'refresh'},
                  }),
                  409,
                )
              : http.Response(jsonEncode({'status': 'committed'}), 201);
        }
        if (request.method == 'GET' &&
            request.url.path == '/v1/driver/session') {
          sessionReadCount += 1;
          return http.Response(
            jsonEncode(
              _sessionJson(
                version: sessionReadCount == 1 ? 8 : 9,
                locale: sessionReadCount == 1 ? 'en' : 'th-TH',
              ),
            ),
            200,
          );
        }
        fail('Unexpected request ${request.method} ${request.url}');
      });
      final api = DriverApi(
        supabaseUrl: 'https://example.supabase.co',
        publishableKey: 'public-key',
        roundsApiUrl: 'https://api.example.test',
        client: client,
      );

      final synced = await api.syncPreferredLocale(
        session: DriverSessionModel.fromJson(
          _sessionJson(version: 7, locale: 'en'),
        ),
        preferredLocale: 'th-TH',
      );

      expect(submittedVersions, [7, 8]);
      expect(synced?.version, 9);
      expect(synced?.preferredLocale, 'th-TH');
    },
  );

  test('offline locale sync returns without blocking local work', () async {
    FlutterSecureStorage.setMockInitialValues({
      'rounds_driver_access_token': 'access-token',
    });
    final api = DriverApi(
      supabaseUrl: 'https://example.supabase.co',
      publishableKey: 'public-key',
      roundsApiUrl: 'https://api.example.test',
      client: MockClient((_) => throw const SocketException('offline')),
    );

    final synced = await api.syncPreferredLocale(
      session: DriverSessionModel.fromJson(
        _sessionJson(version: 7, locale: 'en'),
      ),
      preferredLocale: 'th-TH',
    );

    expect(synced, isNull);
  });
}

Map<String, Object?> _sessionJson({
  required int version,
  required String locale,
}) => {
  'user': {'id': 'auth-user', 'displayName': 'Johannes'},
  'driver': {
    'id': '97000000-0000-4000-8000-000000000002',
    'version': version,
    'preferredLocale': locale,
  },
  'team': {
    'tenantId': '97000000-0000-4000-8000-000000000001',
    'displayName': 'UrbanFlowers',
    'status': 'active',
  },
};
