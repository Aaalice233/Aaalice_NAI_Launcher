import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'prompt_config.freezed.dart';
part 'prompt_config.g.dart';

/// 选取方式
enum SelectionMode {
  /// 单个 - 随机选择
  @JsonValue('single_random')
  singleRandom,

  /// 单个 - 顺序遍历
  @JsonValue('single_sequential')
  singleSequential,

  /// 单个 - 概率出现（有X%的几率随机选一个，否则不出）
  @JsonValue('single_probability')
  singleProbability,

  /// 多个 - 指定数量
  @JsonValue('multiple_count')
  multipleCount,

  /// 多个 - 指定概率（每个选项独立按概率判断）
  @JsonValue('multiple_probability')
  multipleProbability,

  /// 全部
  @JsonValue('all')
  all,
}

/// 内容类型
enum ContentType {
  /// 字符串内容
  @JsonValue('string')
  string,

  /// 嵌套配置
  @JsonValue('nested')
  nested,
}

/// 提示词配置
@freezed
class PromptConfig with _$PromptConfig {
  const PromptConfig._();

  const factory PromptConfig({
    /// 配置ID
    required String id,

    /// 配置名称
    required String name,

    /// 选取方式
    @Default(SelectionMode.singleRandom) SelectionMode selectionMode,

    /// 是否打乱顺序 (多个-指定概率 或 全部 时有效)
    @Default(false) bool shuffle,

    /// 选中数量 (多个-指定数量 时使用)
    int? selectCount,

    /// 选中概率 (多个-指定概率 时使用，0.0-1.0)
    double? selectProbability,

    /// 最小括号数
    @Default(0) int bracketMin,

    /// 最大括号数
    @Default(0) int bracketMax,

    /// 内容类型
    @Default(ContentType.string) ContentType contentType,

    /// 字符串内容列表 (每行一个)
    @Default([]) List<String> stringContents,

    /// 嵌套配置列表
    @Default([]) List<PromptConfig> nestedConfigs,

    /// 是否启用
    @Default(true) bool enabled,

    /// 顺序索引 (用于顺序遍历模式)
    @Default(0) int sequentialIndex,
  }) = _PromptConfig;

  factory PromptConfig.fromJson(Map<String, dynamic> json) =>
      _$PromptConfigFromJson(json);

  /// 创建新配置
  factory PromptConfig.create({
    required String name,
    SelectionMode selectionMode = SelectionMode.singleRandom,
    ContentType contentType = ContentType.string,
    List<String>? stringContents,
    List<PromptConfig>? nestedConfigs,
    int? selectCount,
    double? selectProbability,
    int bracketMin = 0,
    int bracketMax = 0,
    bool shuffle = false,
  }) {
    return PromptConfig(
      id: const Uuid().v4(),
      name: name,
      selectionMode: selectionMode,
      contentType: contentType,
      stringContents: stringContents ?? [],
      nestedConfigs: nestedConfigs ?? [],
      selectCount: selectCount,
      selectProbability: selectProbability,
      bracketMin: bracketMin,
      bracketMax: bracketMax,
      shuffle: shuffle,
    );
  }

  /// 生成随机提示词
  String generate(Random random, {Map<String, int>? sequentialCounters}) {
    if (!enabled) return '';

    final List<String> selectedItems = [];

    if (contentType == ContentType.string) {
      selectedItems.addAll(_selectFromStrings(random, sequentialCounters));
    } else {
      // 嵌套配置
      for (final config in _selectFromConfigs(random, sequentialCounters)) {
        final result =
            config.generate(random, sequentialCounters: sequentialCounters);
        if (result.isNotEmpty) {
          selectedItems.add(result);
        }
      }
    }

    // 应用权重括号
    final processedItems = selectedItems.map((item) {
      if (bracketMin == 0 && bracketMax == 0) return item;
      final bracketCount =
          bracketMin + random.nextInt(bracketMax - bracketMin + 1);
      if (bracketCount == 0) return item;
      final brackets = '{' * bracketCount;
      final closeBrackets = '}' * bracketCount;
      return '$brackets$item$closeBrackets';
    }).toList();

    // 打乱顺序（如果需要）
    if (shuffle &&
        (selectionMode == SelectionMode.multipleProbability ||
            selectionMode == SelectionMode.all)) {
      processedItems.shuffle(random);
    }

    return processedItems.join(', ');
  }

  /// 从字符串内容中选取
  List<String> _selectFromStrings(Random random, Map<String, int>? counters) {
    if (stringContents.isEmpty) return [];

    switch (selectionMode) {
      case SelectionMode.singleRandom:
        return [stringContents[random.nextInt(stringContents.length)]];

      case SelectionMode.singleSequential:
        final counter = counters ?? {};
        final index = counter[id] ?? 0;
        counter[id] = (index + 1) % stringContents.length;
        return [stringContents[index % stringContents.length]];

      case SelectionMode.singleProbability:
        // 先判断是否出词，出词则随机选一个
        final prob = (selectProbability ?? 0.5).clamp(0.0, 1.0);
        if (random.nextDouble() < prob) {
          return [stringContents[random.nextInt(stringContents.length)]];
        }
        return [];

      case SelectionMode.multipleCount:
        final count = (selectCount ?? 1).clamp(0, stringContents.length);
        final shuffled = List<String>.from(stringContents)..shuffle(random);
        return shuffled.take(count).toList();

      case SelectionMode.multipleProbability:
        final prob = (selectProbability ?? 0.5).clamp(0.0, 1.0);
        return stringContents.where((_) => random.nextDouble() < prob).toList();

      case SelectionMode.all:
        return List<String>.from(stringContents);
    }
  }

  /// 从嵌套配置中选取
  List<PromptConfig> _selectFromConfigs(
    Random random,
    Map<String, int>? counters,
  ) {
    if (nestedConfigs.isEmpty) return [];

    switch (selectionMode) {
      case SelectionMode.singleRandom:
        return [nestedConfigs[random.nextInt(nestedConfigs.length)]];

      case SelectionMode.singleSequential:
        final counter = counters ?? {};
        final index = counter[id] ?? 0;
        counter[id] = (index + 1) % nestedConfigs.length;
        return [nestedConfigs[index % nestedConfigs.length]];

      case SelectionMode.singleProbability:
        // 先判断是否出词，出词则随机选一个
        final prob = (selectProbability ?? 0.5).clamp(0.0, 1.0);
        if (random.nextDouble() < prob) {
          return [nestedConfigs[random.nextInt(nestedConfigs.length)]];
        }
        return [];

      case SelectionMode.multipleCount:
        final count = (selectCount ?? 1).clamp(0, nestedConfigs.length);
        final shuffled = List<PromptConfig>.from(nestedConfigs)
          ..shuffle(random);
        return shuffled.take(count).toList();

      case SelectionMode.multipleProbability:
        final prob = (selectProbability ?? 0.5).clamp(0.0, 1.0);
        return nestedConfigs.where((_) => random.nextDouble() < prob).toList();

      case SelectionMode.all:
        return List<PromptConfig>.from(nestedConfigs);
    }
  }
}

/// 完整的随机提示词配置（包含多个分组）
@freezed
class RandomPromptPreset with _$RandomPromptPreset {
  const RandomPromptPreset._();

  const factory RandomPromptPreset({
    /// 预设ID
    required String id,

    /// 预设名称
    required String name,

    /// 配置列表（按顺序生成并拼接）
    @Default([]) List<PromptConfig> configs,

    /// 是否为默认预设
    @Default(false) bool isDefault,

    /// 创建时间
    required DateTime createdAt,

    /// 更新时间
    DateTime? updatedAt,
  }) = _RandomPromptPreset;

  factory RandomPromptPreset.fromJson(Map<String, dynamic> json) =>
      _$RandomPromptPresetFromJson(json);

  /// 创建新预设
  factory RandomPromptPreset.create({
    required String name,
    List<PromptConfig>? configs,
    bool isDefault = false,
  }) {
    return RandomPromptPreset(
      id: const Uuid().v4(),
      name: name,
      configs: configs ?? [],
      isDefault: isDefault,
      createdAt: DateTime.now(),
    );
  }

  /// 生成随机提示词
  String generate({int? seed}) {
    final random = seed != null ? Random(seed) : Random();
    final counters = <String, int>{};

    final parts = <String>[];
    for (final config in configs) {
      final result = config.generate(random, sequentialCounters: counters);
      if (result.isNotEmpty) {
        parts.add(result);
      }
    }

    return parts.join(', ');
  }
}
