import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../storage/harness_database.dart';
import '../storage/harness_event_log.dart';
import '../storage/telemetry_buffer.dart';
import 'telemetry_batch.dart';

class TelemetryUploader {
  TelemetryUploader({
    required this.supabaseUrl,
    required this.publishableKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String supabaseUrl;
  final String publishableKey;
  final http.Client _client;

  HarnessDatabase? _database;
  Timer? _timer;
  bool _inFlight = false;

  bool get isConfigured =>
      supabaseUrl.startsWith('https://') && publishableKey.isNotEmpty;

  Future<void> start() async {
    if (!isConfigured || _database != null) return;
    _database = await HarnessDatabase.open();
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(flush()),
    );
    unawaited(flush());
  }

  Future<void> flush() async {
    final database = _database;
    if (database == null || _inFlight) return;
    _inFlight = true;
    try {
      final rows = await TelemetryBuffer(database).pending(limit: 200);
      if (rows.isEmpty) return;
      final traceId = const Uuid().v4();
      final response = await _client
          .post(
            Uri.parse('$supabaseUrl/functions/v1/location-ingest'),
            headers: {
              'apikey': publishableKey,
              'content-type': 'application/json',
            },
            body: jsonEncode(locationBatchFromRows(rows, traceId: traceId)),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('ingest HTTP ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, Object?>;
      final watermark = (body['ingestWatermark'] as num).toInt();
      await TelemetryBuffer(database).acknowledgeThrough(watermark);
      await HarnessEventLog(database).record(
        'telemetry_batch_uploaded',
        payload: {
          'trace_id': traceId,
          'first_sequence': rows.first['sequence'],
          'last_sequence': rows.last['sequence'],
          'sample_count': rows.length,
          'ingest_watermark': watermark,
          'broadcasts': body['broadcasts'],
        },
      );
    } catch (error) {
      await HarnessEventLog(
        database,
      ).record('telemetry_batch_failed', payload: {'error': error.toString()});
    } finally {
      _inFlight = false;
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await flush();
    await _database?.database.close();
    _database = null;
    _client.close();
  }
}
