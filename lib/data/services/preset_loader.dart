import 'dart:convert';
import 'dart:io';

import '../../core/utils/app_logger.dart';
import '../models/prompt/algorithm_config.dart';
import '../models/prompt/random_category.dart';
import '../models/prompt/random_preset.dart';
import '../models/prompt/random_tag_group.dart';
import '../models/prompt/tag_scope.dart';
import '../models/prompt/weighted_tag.dart';

/// 预设加载器
///
/// 从 JSON/CSV 文件加载官方预设数据
class PresetLoader {
  static const String defaultPresetFile = 'assets/data/nai_official_tags.json';

  /// 加载官方预设
  ///
  /// 解析 NAI 官方标签 JSON 文件并生成 RandomPreset
  Future<RandomPreset> loadOfficialPreset() async {
    AppLogger.i('Loading official preset from $defaultPresetFile', 'PresetLoader');

    try {
      final file = File(defaultPresetFile);
      if (!file.existsSync()) {
        AppLogger.w('Official preset file not found: $defaultPresetFile', 'PresetLoader');
        return _createDefaultPreset();
      }

      final jsonStr = await file.readAsString();
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      final categories = json['categories'] as Map<String, dynamic>;
      final preset = _buildPresetFromJson(json, categories);

      AppLogger.i('Official preset loaded: ${preset.categories.length} categories', 'PresetLoader');
      return preset;
    } catch (e, stack) {
      AppLogger.e('Failed to load official preset: $e', e, stack, 'PresetLoader');
      return _createDefaultPreset();
    }
  }

  /// 从 JSON 构建预设
  RandomPreset _buildPresetFromJson(
    Map<String, dynamic> json,
    Map<String, dynamic> categories,
  ) {
    final presetCategories = <RandomCategory>[];

    // 定义类别映射：JSON key -> (显示名称, 图标, 概率)
    final categoryConfig = {
      'expression': ('表情', '😊', 0.6),
      'pose': ('姿势', '🧘', 0.5),
      'scene': ('场景', '🏞️', 0.9),
      'background': ('背景', '🎨', 0.9),
      'style': ('风格', '✨', 0.3),
      'hairColor': ('发色', '💇', 0.8),
      'hairLength': ('发型长度', '💇‍♀️', 0.5),
      'hairStyle': ('发型', '💇‍♂️', 0.5),
      'hairUpdo': ('发饰', '👑', 0.3),
      'eyeColor': ('瞳色', '👁️', 0.8),
      'clothing': ('服装', '👗', 0.7),
      'accessory': ('配饰', '💎', 0.4),
      'items': ('物品', '🎁', 0.3),
      'effect': ('效果', '🌈', 0.2),
      'bodyFeature': ('体征', '💪', 0.3),
      'speciesFeature': ('种族特征', '🧚', 0.2),
      'camera': ('镜头', '📷', 0.4),
    };

    for (final entry in categoryConfig.entries) {
      final jsonKey = entry.key;
      if (!categories.containsKey(jsonKey)) continue;

      final config = entry.value;
      final tags = (categories[jsonKey] as List).cast<String>();

      if (tags.isEmpty) continue;

      // 创建词组
      final group = RandomTagGroup.custom(
        name: config.$1,
        emoji: config.$2,
        tags: _createWeightedTags(tags),
        selectionMode: SelectionMode.single,
        probability: 1.0,
      );

      // 创建类别
      final category = RandomCategory.create(
        name: config.$1,
        key: jsonKey,
        emoji: config.$2,
        isBuiltin: true,
      ).copyWith(
        enabled: true,
        probability: config.$3,
        groupSelectionMode: SelectionMode.single,
        groupSelectCount: 1,
        shuffle: true,
        scope: TagScope.all,
      );

      final categoryWithGroup = category.addGroup(group);
      presetCategories.add(categoryWithGroup);
    }

    return RandomPreset(
      id: 'official_preset',
      name: 'NAI 官方预设',
      description: '基于 NovelAI 官方标签库的随机生成配置',
      algorithmConfig: const AlgorithmConfig(),
      categories: presetCategories,
    );
  }

  /// 创建带权重的标签列表
  List<WeightedTag> _createWeightedTags(List<String> tags) {
    return tags.map((tag) {
      return WeightedTag.simple(tag.replaceAll('_', ' '), 1);
    }).toList();
  }

  /// 创建默认预设（当 JSON 加载失败时）
  RandomPreset _createDefaultPreset() {
    AppLogger.w('Using default preset', 'PresetLoader');

    final categories = <RandomCategory>[];

    // 基础类别
    final baseCategories = [
      ('发色', 'hairColor', '💇', 0.8),
      ('瞳色', 'eyeColor', '👁️', 0.8),
      ('表情', 'expression', '😊', 0.6),
      ('姿势', 'pose', '🧘', 0.5),
      ('场景', 'scene', '🏞️', 0.9),
      ('背景', 'background', '🎨', 0.9),
      ('风格', 'style', '✨', 0.3),
    ];

    for (final config in baseCategories) {
      final group = RandomTagGroup.custom(
        name: config.$1,
        emoji: config.$3,
        selectionMode: SelectionMode.single,
      );

      final category = RandomCategory.create(
        name: config.$1,
        key: config.$2,
        emoji: config.$3,
        isBuiltin: true,
      ).copyWith(
        enabled: true,
        probability: config.$4,
        groupSelectionMode: SelectionMode.single,
      );

      categories.add(category.addGroup(group));
    }

    return RandomPreset(
      id: 'default_preset',
      name: '默认预设',
      description: '基础随机配置',
      algorithmConfig: const AlgorithmConfig(),
      categories: categories,
    );
  }

  /// 加载多个预设
  Future<List<RandomPreset>> loadAllPresets() async {
    final presets = <RandomPreset>[];

    // 加载官方预设
    final official = await loadOfficialPreset();
    presets.add(official);

    return presets;
  }

  /// 从 CSV 加载词库（备用方案）
  Future<RandomPreset> loadFromCsv(String csvPath) async {
    AppLogger.i('Loading preset from CSV: $csvPath', 'PresetLoader');

    try {
      final file = File(csvPath);
      if (!file.existsSync()) {
        AppLogger.w('CSV file not found: $csvPath', 'PresetLoader');
        return _createDefaultPreset();
      }

      final lines = await file.readAsLines();
      if (lines.isEmpty) {
        return _createDefaultPreset();
      }

      // 跳过表头
      final dataLines = lines.skip(1).where((line) => line.trim().isNotEmpty);
      final categories = <String, List<String>>{};

      for (final line in dataLines) {
        final parts = line.split(',');
        if (parts.length >= 2) {
          final category = parts[0].trim();
          final tag = parts[1].trim();

          categories.putIfAbsent(category, () => []).add(tag);
        }
      }

      // 构建预设
      final presetCategories = <RandomCategory>[];

      for (final entry in categories.entries) {
        final group = RandomTagGroup.custom(
          name: entry.key,
          tags: _createWeightedTags(entry.value),
        );

        final category = RandomCategory.create(
          name: entry.key,
          key: entry.key.toLowerCase().replaceAll(' ', '_'),
        ).addGroup(group);

        presetCategories.add(category);
      }

      return RandomPreset(
        id: 'csv_imported_preset',
        name: 'CSV 导入预设',
        description: '从 CSV 文件导入的预设',
        algorithmConfig: const AlgorithmConfig(),
        categories: presetCategories,
      );
    } catch (e, stack) {
      AppLogger.e('Failed to load CSV preset: $e', e, stack, 'PresetLoader');
      return _createDefaultPreset();
    }
  }
}
