import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

/// Hive storage adapter for random prompt presets.
class RandomPresetStorage {
  static const String boxName = 'random_presets';
  static const String selectedIdKey = 'selected_preset_id';

  Box<String>? _box;

  Box<String> get _requireBox {
    final box = _box;
    if (box == null) {
      throw StateError('RandomPresetStorage has not been opened');
    }
    return box;
  }

  Future<void> open() async {
    _box = await Hive.openBox<String>(boxName);
  }

  Iterable<String> readPresetJsonValues() sync* {
    final box = _requireBox;
    for (final key in box.keys) {
      if (key == selectedIdKey) continue;
      final json = box.get(key);
      if (json != null) {
        yield json;
      }
    }
  }

  String? getSelectedPresetId() => _requireBox.get(selectedIdKey);

  Future<void> setSelectedPresetId(String id) =>
      _requireBox.put(selectedIdKey, id);

  Future<void> savePresetJson(String id, String json) =>
      _requireBox.put(id, json);

  Future<void> deletePreset(String id) => _requireBox.delete(id);
}

final randomPresetStorageProvider = Provider<RandomPresetStorage>(
  (ref) => RandomPresetStorage(),
);
