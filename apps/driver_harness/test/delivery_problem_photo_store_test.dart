import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/storage/delivery_problem_photo_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('damage photo and note survive restart and clear together', () async {
    SharedPreferences.setMockInitialValues({});
    final directory = await Directory.systemTemp.createTemp(
      'rounds-delivery-problem-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final captured = File('${directory.path}/captured.jpg');
    await captured.writeAsBytes([1, 2, 3, 4]);
    final preferences = await SharedPreferences.getInstance();
    final store = DeliveryProblemPhotoStore(
      preferences: preferences,
      supportDirectory: directory,
    );

    await store.retain('stop-1', captured.path);
    await store.saveNote('stop-1', 'Broken glass');

    final restored = DeliveryProblemPhotoStore(
      preferences: preferences,
      supportDirectory: directory,
    );
    expect(await restored.restore('stop-1'), isNotNull);
    expect(restored.restoreNote('stop-1'), 'Broken glass');

    await restored.clear('stop-1');
    expect(await restored.restore('stop-1'), isNull);
    expect(restored.restoreNote('stop-1'), isEmpty);
  });
}
