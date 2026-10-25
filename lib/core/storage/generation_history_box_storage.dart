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

  LazyBox<dynamic> get _box => Hive.lazyBox<dynamic>(StorageKeys.historyBox);

  bool get isOpen => Hive.isBoxOpen(StorageKeys.historyBox);

  Future<Object?> read(String key) => _box.get(key);

  List<String> keysWithPrefix(String prefix) {
    if (!isOpen) return const [];
    return _box.keys
        .whereType<String>()
        .where((key) => key.startsWith(prefix))
        .toList();
  }

  Future<void> put(String key, Object? value) async {
    if (!isOpen) return;
    await _box.put(key, value);
  }

  Future<void> putAll(Map<String, Object?> entries) async {
    if (!isOpen || entries.isEmpty) return;
    await _box.putAll(entries);
  }

  Future<void> deleteAll(Iterable<String> keys) async {
    if (!isOpen) return;
    await _box.deleteAll(keys);
  }
}
