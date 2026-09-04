import 'package:flutter_test/flutter_test.dart';
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
}
