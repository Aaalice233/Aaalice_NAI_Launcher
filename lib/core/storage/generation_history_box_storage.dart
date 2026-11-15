import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import '../constants/storage_keys.dart';

final generationHistoryBoxStorageProvider =
    Provider<GenerationHistoryBoxStorage>(
      (ref) => const GenerationHistoryBoxStorage(),
    );

/// Hive box access adapter for [StorageKeys.historyBox] used by generation
/// session history persistence.
class GenerationHistoryBoxStorage {
  const GenerationHistoryBoxStorage();

  Box<dynamic>? get _box {
    if (!Hive.isBoxOpen(StorageKeys.historyBox)) {
      return null;
    }
    return Hive.box<dynamic>(StorageKeys.historyBox);
  }

  bool get isOpen => Hive.isBoxOpen(StorageKeys.historyBox);

  Object? read(String key) => _box?.get(key);

  List<String> keysWithPrefix(String prefix) {
    final box = _box;
    if (box == null) return const [];
    return box.keys
        .whereType<String>()
        .where((key) => key.startsWith(prefix))
        .toList();
  }

  Future<void> put(String key, Object? value) async {
    final box = _box;
    if (box == null) return;
    await box.put(key, value);
  }

  Future<void> putAll(Map<String, Object?> entries) async {
    final box = _box;
    if (box == null || entries.isEmpty) return;
    await box.putAll(entries);
  }

  Future<void> delete(String key) async {
    final box = _box;
    if (box == null) return;
    await box.delete(key);
  }

  Future<void> deleteAll(Iterable<String> keys) async {
    final box = _box;
    if (box == null) return;
    await box.deleteAll(keys);
  }
}
