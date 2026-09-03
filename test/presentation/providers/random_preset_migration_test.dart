import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/data/models/prompt/algorithm_config.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/weighted_tag.dart';
import 'package:nai_launcher/presentation/providers/random_preset_provider.dart';

void main() {
  late Directory hiveDirectory;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    hiveDirectory = await Directory.systemTemp.createTemp(
      'random_preset_migration_',
    );
    Hive.init(hiveDirectory.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test(
    'migration preserves selected preset ids, settings and custom tags',
    () async {
      final box = await Hive.openBox<String>('random_presets');
      const oldDefault = RandomPreset(
        id: 'default',
        name: '保留名称',
        isDefault: true,
        version: 2,
        algorithmConfig: AlgorithmConfig(
          characterCountWeights: [
            [2, 100],
          ],
          globalEmphasisProbability: 0.37,
        ),
        categories: [
          RandomCategory(
            id: 'stable-category',
            name: '自定义类别',
            key: 'custom-category',
            probability: 0.42,
            groups: [
              RandomTagGroup(
                id: 'stable-group',
                name: '自定义词组',
                tags: [WeightedTag(tag: 'keep me', weight: 17)],
              ),
            ],
          ),
        ],
      );
      const selected = RandomPreset(
        id: 'selected-custom',
        name: '当前预设',
        version: 2,
      );
      await box.put(oldDefault.id, jsonEncode(oldDefault.toJson()));
      await box.put(selected.id, jsonEncode(selected.toJson()));
      await box.put('selected_preset_id', selected.id);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(randomPresetNotifierProvider.notifier);
      await notifier.whenLoaded;
      final state = container.read(randomPresetNotifierProvider);
      final migrated = state.presets.firstWhere((preset) => preset.isDefault);

      expect(state.selectedPresetId, selected.id);
      expect(migrated.version, 4);
      expect(migrated.name, oldDefault.name);
      expect(migrated.algorithmConfig, oldDefault.algorithmConfig);
      final stableCategory = migrated.categories.firstWhere(
        (category) => category.id == 'stable-category',
      );
      expect(migrated.categories.length, greaterThan(1));
      expect(stableCategory.probability, 0.42);
      expect(stableCategory.groups.single.id, 'stable-group');
      expect(stableCategory.groups.single.tags.single.tag, 'keep me');
    },
  );

  test('invalid stored selection falls back to an existing preset', () async {
    final box = await Hive.openBox<String>('random_presets');
    await box.put('selected_preset_id', 'missing-preset');

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(randomPresetNotifierProvider.notifier);
    await notifier.whenLoaded;
    final state = container.read(randomPresetNotifierProvider);

    expect(state.selectedPresetId, isNot('missing-preset'));
    expect(
      state.presets.any((preset) => preset.id == state.selectedPresetId),
      isTrue,
    );
    expect(box.get('selected_preset_id'), state.selectedPresetId);
  });

  test('deleting selected preset persists the fallback selection', () async {
    final box = await Hive.openBox<String>('random_presets');
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(randomPresetNotifierProvider.notifier);
    await notifier.whenLoaded;

    final created = await notifier.createPreset(
      name: '待删除预设',
      copyFromCurrent: false,
    );
    expect(box.get('selected_preset_id'), created.id);

    await notifier.deletePreset(created.id);
    final state = container.read(randomPresetNotifierProvider);

    expect(state.selectedPresetId, isNot(created.id));
    expect(
      state.presets.any((preset) => preset.id == state.selectedPresetId),
      isTrue,
    );
    expect(box.get('selected_preset_id'), state.selectedPresetId);
  });
}
