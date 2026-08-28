import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/content_selection.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/cloud_sync/cloud_sync_content_selection_store.dart';

void main() {
  test('content selection defaults keep prompt on and Skills off', () {
    const selection = CloudSyncContentSelection();

    expect(selection.includeAgentSystemPrompt, isTrue);
    expect(selection.includeSkills, isFalse);
    expect(selection.selectedSkillIds, isEmpty);
  });

  test('content selection persists exact source-qualified Skill ids', () async {
    final storage = _MemoryStorage();
    final store = CloudSyncContentSelectionStore(storage);
    const selection = CloudSyncContentSelection(
      includeAgentSystemPrompt: false,
      includeSkills: true,
      selectedSkillIds: {'workspace:shared-skill', 'piUser:shared-skill'},
    );

    await store.save(selection);
    final restored = store.load();

    expect(restored.includeAgentSystemPrompt, isFalse);
    expect(restored.includeSkills, isTrue);
    expect(restored.selectedSkillIds, selection.selectedSkillIds);
    expect(
      storage.values[StorageKeys.cloudSyncContentSelection],
      isNot(contains('password')),
    );
  });

  test('selection rejects unknown schema fields and unsafe identities', () {
    expect(
      () => CloudSyncContentSelection.decode(
        '{"version":1,"includeAgentSystemPrompt":true,'
        '"includeSkills":true,"selectedSkillIds":["workspace:../bad"]}',
      ),
      throwsFormatException,
    );
    expect(
      () => const CloudSyncContentSelection(
        includeSkills: true,
        selectedSkillIds: {'workspace:bad--name'},
      ).encode(),
      throwsFormatException,
    );
    expect(
      () => CloudSyncContentSelection.decode(
        '{"version":1,"includeAgentSystemPrompt":true,'
        '"includeSkills":false,"selectedSkillIds":[],"extra":true}',
      ),
      throwsFormatException,
    );
  });
}

class _MemoryStorage extends LocalStorageService {
  final values = <String, Object?>{};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (values[key] as T?) ?? defaultValue;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}
