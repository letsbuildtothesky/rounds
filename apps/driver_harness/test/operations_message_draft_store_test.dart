import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/driver/driver_operations_thread.dart';
import 'package:rounds_driver_harness/src/storage/operations_message_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'message draft survives store recreation and stays scoped to a stop',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = OperationsMessageDraftStore(preferences: preferences);

      await store.save('stop-1', ' Security is checking my ID. ');

      final restored = OperationsMessageDraftStore(preferences: preferences);
      expect(restored.restore('stop-1'), ' Security is checking my ID. ');
      expect(restored.restore('stop-2'), isNull);
    },
  );

  test('blank draft clears the stored message', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = OperationsMessageDraftStore(preferences: preferences);

    await store.save('stop-1', 'Waiting at reception.');
    await store.save('stop-1', '   ');

    expect(store.restore('stop-1'), isNull);
  });

  test('staged rich media survives store recreation', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = OperationsMessageDraftStore(preferences: preferences);
    final attachment = DriverMessageAttachmentModel.media(
      kind: 'image',
      fileName: 'camera-1.jpg',
      contentType: 'image/jpeg',
      byteSize: 12345,
      localPath: '/private/camera-1.jpg',
      sha256: List.filled(64, 'a').join(),
    );

    await store.saveMedia('stop-1', [attachment]);

    final restored = OperationsMessageDraftStore(
      preferences: preferences,
    ).restoreMedia('stop-1');
    expect(restored, hasLength(1));
    expect(restored.single.kind, 'image');
    expect(restored.single.localPath, '/private/camera-1.jpg');
    expect(restored.single.sha256, List.filled(64, 'a').join());
  });
}
