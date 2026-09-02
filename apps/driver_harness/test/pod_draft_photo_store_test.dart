import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/storage/pod_draft_photo_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('retains and restores one delivery photo per Stop', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final temporary = await Directory.systemTemp.createTemp(
      'rounds-pod-draft-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final source = File('${temporary.path}/camera.jpg');
    await source.writeAsBytes([8, 6, 7, 5, 3, 0, 9]);
    final store = PodDraftPhotoStore(
      preferences: preferences,
      supportDirectory: temporary,
    );

    final retained = await store.retain('stop-1', source.path);
    expect(retained.path, isNot(source.path));
    expect(await File(retained.path).readAsBytes(), [8, 6, 7, 5, 3, 0, 9]);
    expect((await store.restore('stop-1'))?.path, retained.path);
    expect(await store.restore('stop-2'), isNull);

    await store.clear('stop-1');
    expect(await File(retained.path).exists(), isFalse);
    expect(await store.restore('stop-1'), isNull);
  });

  test('drops stale Stop metadata when its retained file is missing', () async {
    SharedPreferences.setMockInitialValues({
      'pod_draft_photo_path_stop-1': '/missing/photo.jpg',
      'pod_draft_photo_captured_at_stop-1': '2026-09-02T00:00:00.000Z',
    });
    final preferences = await SharedPreferences.getInstance();
    final temporary = await Directory.systemTemp.createTemp(
      'rounds-pod-draft-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final store = PodDraftPhotoStore(
      preferences: preferences,
      supportDirectory: temporary,
    );

    expect(await store.restore('stop-1'), isNull);
    expect(preferences.getString('pod_draft_photo_path_stop-1'), isNull);
  });
}
