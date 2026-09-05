import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rounds_driver_harness/src/driver/driver_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('phone OTP request uses the verified Supabase SMS contract', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final api = DriverApi(
      supabaseUrl: 'https://project.supabase.co',
      publishableKey: 'publishable',
      roundsApiUrl: 'https://api.rounds.test',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/auth/v1/otp');
        expect(request.headers['apikey'], 'publishable');
        expect(jsonDecode(request.body), {
          'phone': '+66812345678',
          'create_user': true,
          'channel': 'sms',
        });
        return http.Response('{}', 200);
      }),
    );

    await api.requestPhoneOtp('+66812345678');
  });

  test('new verified phone continues to a real matching Team invite', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final requests = <String>[];
    final api = DriverApi(
      supabaseUrl: 'https://project.supabase.co',
      publishableKey: 'publishable',
      roundsApiUrl: 'https://api.rounds.test',
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.url.path == '/auth/v1/verify') {
          expect(jsonDecode(request.body), {
            'phone': '+66812345678',
            'token': '123456',
            'type': 'sms',
          });
          return http.Response(
            jsonEncode({'access_token': 'access', 'refresh_token': 'refresh'}),
            200,
          );
        }
        if (request.url.path == '/v1/driver/session') {
          return http.Response(
            jsonEncode({
              'error': {'code': 'NOT_AUTHORIZED'},
            }),
            403,
          );
        }
        if (request.url.path == '/v1/driver/team-invites/pending') {
          return http.Response(jsonEncode(_inviteJson), 200);
        }
        fail('Unexpected request $request');
      }),
    );

    final verified = await api.verifyPhoneOtp('+66812345678', '123456');

    expect(verified.session, isNull);
    expect(verified.pendingInvite?.businessName, 'UrbanFlowers');
    expect(requests, [
      'POST /auth/v1/verify',
      'GET /v1/driver/session',
      'GET /v1/driver/team-invites/pending',
    ]);
    const storage = FlutterSecureStorage();
    expect(await storage.read(key: 'rounds_driver_access_token'), 'access');
  });

  test(
    'manual code resolves and accepts only through authenticated API routes',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'rounds_driver_access_token': 'access',
        'rounds_driver_refresh_token': 'refresh',
      });
      final api = DriverApi(
        supabaseUrl: 'https://project.supabase.co',
        publishableKey: 'publishable',
        roundsApiUrl: 'https://api.rounds.test',
        client: MockClient((request) async {
          if (request.url.path == '/v1/driver/team-invites/resolve') {
            expect(request.headers['authorization'], 'Bearer access');
            expect(jsonDecode(request.body), {'code': '234567'});
            return http.Response(jsonEncode(_inviteJson), 200);
          }
          if (request.url.path == '/v1/driver/team-invites/accept') {
            expect(request.headers['authorization'], 'Bearer access');
            expect(jsonDecode(request.body), {
              'inviteId': _inviteJson['id'],
              'preferredLocale': 'en',
              'code': '234567',
            });
            return http.Response(jsonEncode({'session': _sessionJson}), 201);
          }
          fail('Unexpected request $request');
        }),
      );

      final invite = await api.resolveTeamInvite('234567');
      final session = await api.acceptTeamInvite(
        invite: invite,
        preferredLocale: 'en',
        code: '234567',
      );

      expect(invite.locationLabel, 'Bangkok · Delivery team');
      expect(session.teamName, 'UrbanFlowers');
    },
  );
}

const _inviteJson = <String, Object?>{
  'id': 'a5000000-0000-4000-8000-000000000001',
  'tenantId': 'a5000000-0000-4000-8000-000000000002',
  'businessName': 'UrbanFlowers',
  'businessInitials': 'UF',
  'locationLabel': 'Bangkok · Delivery team',
  'expiresAt': '2026-09-06T00:00:00.000Z',
};

const _sessionJson = <String, Object?>{
  'user': {'id': 'auth-user', 'displayName': 'Johannes'},
  'driver': {
    'id': 'a5000000-0000-4000-8000-000000000003',
    'version': 1,
    'preferredLocale': 'en',
  },
  'team': {
    'tenantId': 'a5000000-0000-4000-8000-000000000002',
    'displayName': 'UrbanFlowers',
    'status': 'active',
  },
};
