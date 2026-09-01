import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'driver_session.dart';

class DriverApiException implements Exception {
  const DriverApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DriverApi {
  DriverApi({
    required this.supabaseUrl,
    required this.publishableKey,
    required this.roundsApiUrl,
    FlutterSecureStorage? storage,
    http.Client? client,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _client = client ?? http.Client();

  static const _accessTokenKey = 'rounds_driver_access_token';
  static const _refreshTokenKey = 'rounds_driver_refresh_token';

  final String supabaseUrl;
  final String publishableKey;
  final String roundsApiUrl;
  final FlutterSecureStorage _storage;
  final http.Client _client;

  bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      publishableKey.isNotEmpty &&
      roundsApiUrl.isNotEmpty;

  Future<DriverSessionModel?> restore() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    if (accessToken == null) return null;
    try {
      return await _driverSession(accessToken);
    } on _Unauthorized {
      final refreshed = await _refresh();
      if (refreshed == null) {
        await signOut();
        return null;
      }
      return _driverSession(refreshed);
    }
  }

  Future<DriverSessionModel> signIn(String email, String password) async {
    final response = await _client.post(
      Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password'),
      headers: {'apikey': publishableKey, 'content-type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );
    if (response.statusCode != 200) {
      throw DriverApiException(_message(response, 'Sign in failed'));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = body['access_token'] as String;
    final refreshToken = body['refresh_token'] as String;
    await _writeTokens(accessToken, refreshToken);
    try {
      return await _driverSession(accessToken);
    } catch (_) {
      await signOut();
      rethrow;
    }
  }

  Future<void> signOut() => Future.wait([
    _storage.delete(key: _accessTokenKey),
    _storage.delete(key: _refreshTokenKey),
  ]);

  Future<DriverSessionModel> _driverSession(String accessToken) async {
    final response = await _client.get(
      Uri.parse('$roundsApiUrl/v1/driver/session'),
      headers: {
        'authorization': 'Bearer $accessToken',
        'x-trace-id': DateTime.now().microsecondsSinceEpoch.toString(),
      },
    );
    if (response.statusCode == 401) throw const _Unauthorized();
    if (response.statusCode != 200) {
      throw DriverApiException(
        _message(response, 'Assigned work could not be loaded'),
      );
    }
    return DriverSessionModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String?> _refresh() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null) return null;
    final response = await _client.post(
      Uri.parse('$supabaseUrl/auth/v1/token?grant_type=refresh_token'),
      headers: {'apikey': publishableKey, 'content-type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = body['access_token'] as String;
    await _writeTokens(
      accessToken,
      body['refresh_token'] as String? ?? refreshToken,
    );
    return accessToken;
  }

  Future<void> _writeTokens(String accessToken, String refreshToken) =>
      Future.wait([
        _storage.write(key: _accessTokenKey, value: accessToken),
        _storage.write(key: _refreshTokenKey, value: refreshToken),
      ]);

  String _message(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final nested = body['error'];
      if (nested is Map<String, dynamic> && nested['message'] is String) {
        return nested['message'] as String;
      }
      if (body['msg'] is String) return body['msg'] as String;
      if (body['error_description'] is String) {
        return body['error_description'] as String;
      }
    } catch (_) {}
    return fallback;
  }
}

class _Unauthorized implements Exception {
  const _Unauthorized();
}
