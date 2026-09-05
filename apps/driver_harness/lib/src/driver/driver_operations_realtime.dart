import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:realtime_client/realtime_client.dart';

const driverCommunicationsEvent = 'communications.changed';

String driverCommunicationsTopic(String driverId) => 'driver:$driverId';

String driverRealtimeEndpoint(String supabaseUrl) {
  final uri = Uri.parse(supabaseUrl);
  final scheme = switch (uri.scheme) {
    'https' => 'wss',
    'http' => 'ws',
    _ => uri.scheme,
  };
  return uri.replace(scheme: scheme, path: '/realtime/v1').toString();
}

bool isDriverCommunicationsHint(Map<String, dynamic> message, String driverId) {
  if (message['event'] != driverCommunicationsEvent) return false;
  final payload = message['payload'];
  if (payload is! Map) return false;

  return payload['schemaVersion'] == 1 &&
      payload['event'] == driverCommunicationsEvent &&
      payload['driverId'] == driverId &&
      payload['aggregateType'] == 'operations_thread' &&
      payload['aggregateId'] is String &&
      payload['aggregateVersion'] is num &&
      payload['occurredAt'] is String;
}

class DriverOperationsRealtime {
  DriverOperationsRealtime({
    required this.supabaseUrl,
    required this.publishableKey,
    required this.accessTokenProvider,
  });

  final String supabaseUrl;
  final String publishableKey;
  final Future<String?> Function() accessTokenProvider;

  RealtimeClient? _client;
  RealtimeChannel? _channel;
  int _generation = 0;

  bool get isConfigured => supabaseUrl.isNotEmpty && publishableKey.isNotEmpty;

  Future<void> start({
    required String driverId,
    required void Function() onChanged,
  }) async {
    final generation = ++_generation;
    if (kDebugMode) debugPrint('[Rounds realtime] driver channel: starting');
    await _closeCurrent();
    if (!isConfigured || driverId.isEmpty || generation != _generation) {
      if (kDebugMode) {
        debugPrint('[Rounds realtime] driver channel: not configured');
      }
      return;
    }

    final accessToken = await accessTokenProvider();
    if (accessToken == null ||
        accessToken.isEmpty ||
        generation != _generation) {
      if (kDebugMode) {
        debugPrint('[Rounds realtime] driver channel: no active session');
      }
      return;
    }

    final client = RealtimeClient(
      driverRealtimeEndpoint(supabaseUrl),
      headers: {'apikey': publishableKey},
      params: {'apikey': publishableKey},
      disconnectOnEmptyChannelsAfter: Duration.zero,
    );
    if (kDebugMode) {
      client.onOpen(
        () => debugPrint('[Rounds realtime] driver socket: connected'),
      );
      client.onClose(
        (_) => debugPrint('[Rounds realtime] driver socket: closed'),
      );
      client.onError(
        (error) => debugPrint(
          '[Rounds realtime] driver socket error (${error.runtimeType})',
        ),
      );
    }
    await client.setAuth(accessToken);
    if (generation != _generation) {
      await client.disconnect();
      return;
    }

    final channel = client
        .channel(
          driverCommunicationsTopic(driverId),
          const RealtimeChannelConfig(private: true),
        )
        .onBroadcast(
          event: driverCommunicationsEvent,
          callback: (message) {
            final accepted = isDriverCommunicationsHint(message, driverId);
            if (kDebugMode) {
              debugPrint(
                '[Rounds realtime] driver event: ${accepted ? 'accepted' : 'rejected'}',
              );
            }
            if (accepted) onChanged();
          },
        );
    _client = client;
    _channel = channel;
    if (kDebugMode) debugPrint('[Rounds realtime] driver channel: subscribing');
    channel.subscribe((status, error) {
      if (!kDebugMode || generation != _generation) return;
      final detail = error == null ? '' : ' (${error.runtimeType})';
      debugPrint('[Rounds realtime] driver channel: $status$detail');
    });
  }

  Future<void> refreshAuth() async {
    final client = _client;
    if (client == null) return;
    final accessToken = await accessTokenProvider();
    if (accessToken != null && accessToken.isNotEmpty) {
      await client.setAuth(accessToken);
    }
  }

  Future<void> close() async {
    _generation += 1;
    await _closeCurrent();
  }

  Future<void> _closeCurrent() async {
    final channel = _channel;
    final client = _client;
    _channel = null;
    _client = null;
    if (channel != null) {
      try {
        await channel.unsubscribe();
      } catch (_) {
        // Closing a degraded connection is best-effort.
      }
    }
    if (client != null) {
      try {
        await client.disconnect();
      } catch (_) {
        // The API fallback remains authoritative if the socket is already gone.
      }
    }
  }
}
