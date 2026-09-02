import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/debug/debug_acceptance_photo_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('retains, restores, and clears a captured photo', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final temporary = await Directory.systemTemp.createTemp(
      'rounds-debug-acceptance-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final source = File('${temporary.path}/camera.jpg');
    await source.writeAsBytes([1, 2, 3, 4]);
    final store = DebugAcceptancePhotoStore(
      preferences: preferences,
      supportDirectory: temporary,
    );

    final retained = await store.retain(source.path);
    expect(retained.path, isNot(source.path));
    expect(await File(retained.path).readAsBytes(), [1, 2, 3, 4]);

    final restored = await store.restore();
    expect(restored?.path, retained.path);
    expect(restored?.capturedAt, retained.capturedAt);

    await store.clear();
    expect(await File(retained.path).exists(), isFalse);
    expect(await store.restore(), isNull);
  });

  test('drops stale metadata when its retained file is missing', () async {
    SharedPreferences.setMockInitialValues({
      'debug_acceptance_photo_path': '/missing/photo.jpg',
      'debug_acceptance_photo_captured_at': '2026-09-02T00:00:00.000Z',
    });
    final preferences = await SharedPreferences.getInstance();
    final temporary = await Directory.systemTemp.createTemp(
      'rounds-debug-acceptance-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final store = DebugAcceptancePhotoStore(
      preferences: preferences,
      supportDirectory: temporary,
    );

    expect(await store.restore(), isNull);
    expect(preferences.getString('debug_acceptance_photo_path'), isNull);
  });
}
