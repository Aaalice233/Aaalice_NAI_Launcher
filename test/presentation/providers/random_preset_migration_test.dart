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
    'migration replaces the legacy default and preserves custom presets',
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
        algorithmConfig: AlgorithmConfig(globalEmphasisProbability: 0.23),
        categories: [
          RandomCategory(
            id: 'custom-category',
            name: '用户类别',
            key: 'user-category',
            groups: [
              RandomTagGroup(
                id: 'custom-group',
                name: '用户词组',
                tags: [WeightedTag(tag: 'custom survives', weight: 11)],
              ),
            ],
          ),
        ],
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
      final preservedCustom = state.presets.firstWhere(
        (preset) => preset.id == selected.id,
      );

      expect(state.selectedPresetId, selected.id);
      expect(migrated.version, 4);
      expect(migrated.name, 'NovelAI 官网预设');
      expect(migrated.description, contains('NovelAI 官网词库'));
      expect(
        migrated.categories.expand((category) => category.groups),
        isNot(
          contains(
            predicate<RandomTagGroup>((group) => group.id == 'stable-group'),
          ),
        ),
      );
      expect(preservedCustom.algorithmConfig.globalEmphasisProbability, 0.23);
      expect(
        preservedCustom.categories.single.groups.single.tags.single.tag,
        'custom survives',
      );
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
