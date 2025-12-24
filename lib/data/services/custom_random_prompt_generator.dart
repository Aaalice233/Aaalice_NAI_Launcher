import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/character/character_prompt.dart';
import '../models/prompt/algorithm_config.dart';
import '../models/prompt/random_category.dart';
import '../models/prompt/random_preset.dart';
import '../models/prompt/random_prompt_result.dart';
import '../models/prompt/random_tag_group.dart';
import '../models/prompt/weighted_tag.dart';

part 'custom_random_prompt_generator.g.dart';

/// 自定义随机提示词生成器
///
/// 基于 RandomCategory/RandomTagGroup 和 AlgorithmConfig 生成随机提示词
/// 支持多种选择模式和权重随机偏移
class CustomRandomPromptGenerator {
  final Random _random;

  /// 顺序轮替状态存储
  /// key: groupId, value: 当前索引
  final Map<String, int> _sequentialState = {};

  CustomRandomPromptGenerator({int? seed})
      : _random = seed != null ? Random(seed) : Random();

  /// 使用预设生成随机提示词
  RandomPromptResult generate(RandomPreset preset) {
    final config = preset.algorithmConfig;
    return _generateFromCategories(preset.categories, config);
  }

  /// 使用 categories 格式生成随机提示词
  RandomPromptResult _generateFromCategories(
    List<RandomCategory> categories,
    AlgorithmConfig config,
  ) {
    // 决定角色数量
    final characterCount = _getWeightedChoiceInt(config.characterCountWeights);

    if (characterCount == 0) {
      // 无人物场景
      return _generateNoHumanPrompt(categories, config);
    }

    if (!config.isV4Model) {
      // 传统单提示词模式
      return _generateLegacyPrompt(categories, config, characterCount);
    }

    // V4+ 多角色模式
    return _generateMultiCharacterPrompt(categories, config, characterCount);
  }

  /// 生成无人物场景提示词
  RandomPromptResult _generateNoHumanPrompt(
    List<RandomCategory> categories,
    AlgorithmConfig config,
  ) {
    final tags = <String>['no humans'];

    // 遍历所有类别和分组生成标签
    for (final category in categories) {
      if (!category.enabled) continue;
      final generatedTags = _generateFromCategory(category, config);
      tags.addAll(generatedTags);
    }

    return RandomPromptResult(
      mainPrompt: tags.join(', '),
      noHumans: true,
      mode: RandomGenerationMode.custom,
    );
  }

  /// 生成传统单提示词
  RandomPromptResult _generateLegacyPrompt(
    List<RandomCategory> categories,
    AlgorithmConfig config,
    int characterCount,
  ) {
    final tags = <String>[];

    // 添加人数标签
    tags.add(_getCountTag(characterCount));

    // 遍历所有类别和分组生成标签
    for (final category in categories) {
      if (!category.enabled) continue;
      final generatedTags = _generateFromCategory(category, config);
      tags.addAll(generatedTags);
    }

    return RandomPromptResult(
      mainPrompt: tags.join(', '),
      mode: RandomGenerationMode.custom,
    );
  }

  /// 生成多角色提示词
  RandomPromptResult _generateMultiCharacterPrompt(
    List<RandomCategory> categories,
    AlgorithmConfig config,
    int characterCount,
  ) {
    final characters = <GeneratedCharacter>[];
    final genders = <CharacterGender>[];

    // 分离背景类别和角色类别
    final backgroundCategories = categories.where(
      (c) => c.enabled && c.key.toLowerCase() == 'background',
    ).toList();
    final characterCategories = categories.where(
      (c) => c.enabled && c.key.toLowerCase() != 'background',
    ).toList();

    for (var i = 0; i < characterCount; i++) {
      // 决定性别 - 使用配置的权重分布
      final gender = _getWeightedGender(config.furryGenderWeights);
      genders.add(gender);

      // 生成角色特征（排除背景类别）
      final charTags = <String>[];
      for (final category in characterCategories) {
        charTags.addAll(_generateFromCategory(category, config));
      }

      final genderTag = gender == CharacterGender.female ? '1girl' : '1boy';

      characters.add(
        GeneratedCharacter(
          prompt: [genderTag, ...charTags].join(', '),
          gender: gender,
        ),
      );
    }

    // 生成主提示词
    final mainTags = <String>[_getCountTagForCharacters(genders)];

    // 添加背景标签
    for (final cat in backgroundCategories) {
      mainTags.addAll(_generateFromCategory(cat, config));
    }

    return RandomPromptResult(
      mainPrompt: mainTags.join(', '),
      characters: characters,
      mode: RandomGenerationMode.custom,
    );
  }

  /// 从单个类别生成标签
  List<String> _generateFromCategory(
    RandomCategory category,
    AlgorithmConfig config,
  ) {
    final result = <String>[];

    for (final group in category.groups) {
      if (!group.enabled) continue;

      // 检查概率
      if (_random.nextDouble() > group.probability) {
        continue;
      }

      final tags = _selectTagsFromGroup(group, config);
      result.addAll(tags);
    }

    return result;
  }

  /// 根据选择模式从分组选取标签
  List<String> _selectTagsFromGroup(
    RandomTagGroup group,
    AlgorithmConfig config,
  ) {
    if (group.tags.isEmpty) return [];

    final selected = <String>[];

    switch (group.selectionMode) {
      case SelectionMode.single:
        // 加权随机选择一个
        final tag = _getWeightedChoice(group.tags);
        if (tag != null) {
          selected.add(_applyBracketRandomization(tag, config));
        }
        break;

      case SelectionMode.all:
        // 全选
        for (final tag in group.tags) {
          selected.add(_applyBracketRandomization(tag.tag, config));
        }
        break;

      case SelectionMode.multipleNum:
        // 随机选择 N 个
        final shuffled = List<WeightedTag>.from(group.tags)..shuffle(_random);
        final count = min(group.multipleNum, shuffled.length);
        for (var i = 0; i < count; i++) {
          selected.add(_applyBracketRandomization(shuffled[i].tag, config));
        }
        break;

      case SelectionMode.multipleProb:
        // 每个标签独立概率判断
        final totalWeight = group.tags.fold<int>(0, (sum, t) => sum + t.weight);
        for (final tag in group.tags) {
          final tagProbability = totalWeight > 0 ? tag.weight / totalWeight : 0.5;
          if (_random.nextDouble() < tagProbability) {
            selected.add(_applyBracketRandomization(tag.tag, config));
          }
        }
        break;

      case SelectionMode.sequential:
        // 顺序轮替
        if (group.tags.isNotEmpty) {
          final index = _sequentialState[group.id] ?? 0;
          final tag = group.tags[index % group.tags.length];
          selected.add(_applyBracketRandomization(tag.tag, config));
          _sequentialState[group.id] = (index + 1) % group.tags.length;
        }
        break;
    }

    return selected;
  }

  /// 加权随机选择
  String? _getWeightedChoice(List<WeightedTag> tags) {
    if (tags.isEmpty) return null;

    final totalWeight = tags.fold<int>(0, (sum, t) => sum + t.weight);
    if (totalWeight == 0) return tags.first.tag;

    final target = _random.nextInt(totalWeight) + 1;
    var cumulative = 0;

    for (final tag in tags) {
      cumulative += tag.weight;
      if (target <= cumulative) {
        return tag.tag;
      }
    }

    return tags.last.tag;
  }

  /// 从整数权重列表中选择
  int _getWeightedChoiceInt(List<List<int>> weights) {
    final totalWeight = weights.fold<int>(0, (sum, w) => sum + w[1]);
    if (totalWeight == 0) return weights.first[0];

    final target = _random.nextInt(totalWeight) + 1;
    var cumulative = 0;

    for (final w in weights) {
      cumulative += w[1];
      if (target <= cumulative) {
        return w[0];
      }
    }

    return weights.last[0];
  }

  /// 根据性别权重配置随机选择性别
  CharacterGender _getWeightedGender(Map<String, int> weights) {
    final totalWeight = weights.values.fold<int>(0, (sum, w) => sum + w);
    if (totalWeight == 0) return CharacterGender.female;

    final target = _random.nextInt(totalWeight) + 1;
    var cumulative = 0;

    for (final entry in weights.entries) {
      cumulative += entry.value;
      if (target <= cumulative) {
        return switch (entry.key) {
          'm' => CharacterGender.male,
          'f' => CharacterGender.female,
          _ => CharacterGender.female, // 'o' 和其他情况默认女性
        };
      }
    }

    return CharacterGender.female;
  }

  /// 应用权重随机偏移（随机添加括号）
  String _applyBracketRandomization(String tag, AlgorithmConfig config) {
    if (!config.bracketRandomizationEnabled) return tag;

    final range = config.bracketRandomizationMax - config.bracketRandomizationMin;
    if (range <= 0) return tag;

    final count = _random.nextInt(range + 1) + config.bracketRandomizationMin;
    if (count == 0) return tag;

    final bracket = config.bracketEnhance ? '{' : '[';
    final closeBracket = config.bracketEnhance ? '}' : ']';

    return bracket * count + tag + closeBracket * count;
  }

  /// 获取人数标签
  String _getCountTag(int count) {
    return switch (count) {
      1 => 'solo',
      2 => '2girls',
      3 => 'multiple girls',
      _ => 'group',
    };
  }

  /// 根据角色性别组合获取人数标签
  String _getCountTagForCharacters(List<CharacterGender> genders) {
    if (genders.isEmpty) return 'no humans';
    if (genders.length == 1) return 'solo';

    final femaleCount = genders.where((g) => g == CharacterGender.female).length;
    final maleCount = genders.where((g) => g == CharacterGender.male).length;

    if (genders.length == 2) {
      if (femaleCount == 2) return '2girls';
      if (maleCount == 2) return '2boys';
      if (femaleCount == 1 && maleCount == 1) return '1girl, 1boy';
    }

    if (genders.length == 3) {
      if (femaleCount == 3) return '3girls';
      if (maleCount == 3) return '3boys';
      if (femaleCount == 2 && maleCount == 1) return '2girls, 1boy';
      if (femaleCount == 1 && maleCount == 2) return '1girl, 2boys';
    }

    if (femaleCount > 0 && maleCount == 0) return 'multiple girls';
    if (maleCount > 0 && femaleCount == 0) return 'multiple boys';
    return 'group';
  }

  /// 获取顺序轮替状态（用于持久化）
  Map<String, int> get sequentialState => Map.from(_sequentialState);

  /// 恢复顺序轮替状态
  void restoreSequentialState(Map<String, int> state) {
    _sequentialState
      ..clear()
      ..addAll(state);
  }
}

/// Provider
@Riverpod(keepAlive: true)
CustomRandomPromptGenerator customRandomPromptGenerator(Ref ref) {
  return CustomRandomPromptGenerator();
}
