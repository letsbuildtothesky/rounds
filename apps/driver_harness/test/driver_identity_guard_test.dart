import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rounds_driver_harness/src/driver/driver_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'restore rejects a different Driver before any queued work flushes',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'rounds_driver_access_token': 'different-driver-token',
        'rounds_driver_refresh_token': 'different-driver-refresh',
      });
      var sessionReads = 0;
      final api = DriverApi(
        supabaseUrl: 'https://example.supabase.co',
        publishableKey: 'public-key',
        roundsApiUrl: 'https://api.example.test',
        client: MockClient((request) async {
          sessionReads += 1;
          expect(request.method, 'GET');
          expect(request.url.path, '/v1/driver/session');
          return http.Response(
            jsonEncode({
              'user': {'id': 'user-b', 'displayName': 'Driver B'},
              'driver': {
                'id': 'driver-b',
                'version': 1,
                'preferredLocale': 'en',
              },
            }),
            200,
          );
        }),
      );

      await expectLater(
        api.restore(expectedDriverId: 'driver-a'),
        throwsA(
          isA<DriverIdentityMismatchException>().having(
            (error) => error.message,
            'message',
            contains('saved work for another Driver'),
          ),
        ),
      );

      expect(sessionReads, 1);
      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'rounds_driver_access_token'), isNull);
      expect(await storage.read(key: 'rounds_driver_refresh_token'), isNull);
    },
  );
}
