import 'dart:math';

import '../../models/character/character_prompt.dart';
import '../../models/prompt/character_count_config.dart';
import '../../models/prompt/random_category.dart';
import '../../models/prompt/random_preset.dart';
import '../../models/prompt/random_prompt_result.dart';
import '../../models/prompt/random_tag_group.dart';
import '../../models/prompt/tag_scope.dart';
import '../../models/prompt/weighted_tag.dart';
import '../bracket_formatter.dart';
import '../weighted_selector.dart';

/// 预设生成策略
///
/// 负责从 RandomPreset 配置生成标签列表和多角色提示词。
/// 支持按作用域（global/character）和性别过滤类别。
/// 从 RandomPromptGenerator.generateFromPreset 提取。
///
/// ## 主要功能
///
/// - 解析 RandomPreset 配置结构
/// - 按作用域过滤类别（global/character/all）
/// - 按性别过滤类别（male/female/general）
/// - 支持多种词组选择模式（单选/多选/全部）
/// - 支持多种标签选择模式（单选/多选/全部/随机）
/// - 应用权重括号到生成的标签
/// - 生成多角色提示词（V4+ 模型）
///
/// ## 生成流程
///
/// 1. 遍历预设中的所有类别
/// 2. 过滤禁用的类别和不符合作用域/性别的类别
/// 3. 检查类别概率，决定是否生成
/// 4. 根据 groupSelectionMode 选择词组
/// 5. 在每个词组中根据 selectionMode 选择标签
/// 6. 应用括号权重
///
/// ## 多角色生成
///
/// 使用 [generateMultiCharacter] 方法生成 V4+ 模型的多角色提示词：
/// - 生成全局标签（背景、场景等）
/// - 为每个角色槽位生成独立的角色提示词
/// - 自动根据性别过滤标签
///
/// ## 选择模式
///
/// **词组选择** (groupSelectionMode):
/// - `single`: 随机选择一个词组
/// - `multiple`: 随机选择多个词组（groupSelectCount）
/// - `all`: 使用所有词组
///
/// **标签选择** (selectionMode):
/// - `single`: 随机选择一个标签
/// - `multiple`: 随机选择多个标签（multipleNum）
/// - `all`: 使用所有标签
/// - `random`: 每个标签独立随机决定
///
/// ## 性能特性
///
/// - 时间复杂度: O(n * m)，n 为类别数，m 为平均标签数
/// - 异步设计，支持大规模词库
/// - 使用加权随机算法，符合 NAI 官网行为
class PresetGeneratorStrategy {
  /// 加权选择器
  final WeightedSelector _weightedSelector;

  /// 括号格式化器
  final BracketFormatter _bracketFormatter;

  /// 创建预设生成策略
  ///
  /// [weightedSelector] 加权选择器（可选，默认创建新实例）
  /// [bracketFormatter] 括号格式化器（可选，默认创建新实例）
  PresetGeneratorStrategy({
    WeightedSelector? weightedSelector,
    BracketFormatter? bracketFormatter,
  })  : _weightedSelector = weightedSelector ?? WeightedSelector(),
        _bracketFormatter = bracketFormatter ?? BracketFormatter();

  /// 选择人数类别和标签选项
  ///
  /// [config] 人数类别配置
  /// [random] 随机数生成器
  ///
  /// 返回选中的类别和标签选项（标签选项可能为 null）
  ///
  /// 示例：
  /// ```dart
  /// final strategy = PresetGeneratorStrategy();
  /// final config = CharacterCountConfig.naiDefault;
  /// final (category, tagOption) = strategy.selectCharacterCountAndOption(
  ///   config: config,
  ///   random: Random(42),
  /// );
  /// ```
  (CharacterCountCategory, CharacterTagOption?) selectCharacterCountAndOption({
    required CharacterCountConfig config,
    required Random random,
  }) {
    // 获取启用的类别
    final enabledCategories = config.enabledCategories;
    if (enabledCategories.isEmpty) {
      // 无启用类别，返回默认单人
      return (CharacterCountConfig.naiDefault.categories.first, null);
    }

    // 按权重选择类别
    final category = _selectWeightedCategory(enabledCategories, random);

    // 获取启用的标签选项
    final enabledOptions = category.enabledTagOptions;
    if (enabledOptions.isEmpty) {
      return (category, null);
    }

    // 按权重选择标签选项
    final tagOption = _selectWeightedTagOption(enabledOptions, random);

    return (category, tagOption);
  }

  /// 按权重选择人数类别
  ///
  /// [categories] 类别列表
  /// [random] 随机数生成器
  CharacterCountCategory _selectWeightedCategory(
    List<CharacterCountCategory> categories,
    Random random,
  ) {
    if (categories.length == 1) return categories.first;

    final totalWeight = categories.fold<int>(0, (sum, c) => sum + c.weight);
    if (totalWeight <= 0) return categories[random.nextInt(categories.length)];

    final target = random.nextInt(totalWeight) + 1;
    var cumulative = 0;

    for (final category in categories) {
      cumulative += category.weight;
      if (target <= cumulative) {
        return category;
      }
    }

    return categories.last;
  }

  /// 按权重选择标签选项
  ///
  /// [options] 标签选项列表
  /// [random] 随机数生成器
  CharacterTagOption _selectWeightedTagOption(
    List<CharacterTagOption> options,
    Random random,
  ) {
    if (options.length == 1) return options.first;

    final totalWeight = options.fold<int>(0, (sum, o) => sum + o.weight);
    if (totalWeight <= 0) return options[random.nextInt(options.length)];

    final target = random.nextInt(totalWeight) + 1;
    var cumulative = 0;

    for (final option in options) {
      cumulative += option.weight;
      if (target <= cumulative) {
        return option;
      }
    }

    return options.last;
  }

  /// 从预设生成标签
  ///
  /// [preset] 预设配置
  /// [random] 随机数生成器
  /// [targetScope] 目标作用域（用于过滤类别，默认 all）
  /// [characterGender] 角色性别（用于过滤性别限定类别，默认 null）
  ///
  /// 返回生成的标签列表
  ///
  /// 示例：
  /// ```dart
  /// final strategy = PresetGeneratorStrategy();
  /// final preset = RandomPreset.create(name: 'My Preset');
  /// final tags = await strategy.generate(
  ///   preset: preset,
  ///   random: Random(42),
  /// );
  /// ```
  Future<List<String>> generate({
    required RandomPreset preset,
    required Random random,
    TagScope targetScope = TagScope.all,
    String? characterGender,
  }) async {
    final results = <String>[];

    for (final category in preset.categories) {
      // 跳过禁用的类别
      if (!category.enabled) continue;

      // 作用域过滤
      if (!category.isApplicableToScope(targetScope)) continue;

      // 性别过滤（仅在指定性别时应用）
      if (characterGender != null &&
          !category.isApplicableToGender(characterGender)) continue;

      // 类别概率检查
      if (random.nextDouble() > category.probability) continue;

      // 生成类别内的标签
      final categoryTags = await _generateFromCategory(
        category,
        random,
        targetScope: targetScope,
        characterGender: characterGender,
      );
      results.addAll(categoryTags);
    }

    return results;
  }

  /// 从单个类别生成标签
  ///
  /// [category] 类别配置
  /// [random] 随机数生成器
  /// [targetScope] 目标作用域
  /// [characterGender] 角色性别
  Future<List<String>> _generateFromCategory(
    RandomCategory category,
    Random random, {
    TagScope targetScope = TagScope.all,
    String? characterGender,
  }) async {
    // 过滤启用且符合条件的词组
    final enabledGroups = category.groups.where((g) {
      if (!g.enabled) return false;
      if (!g.isApplicableToScope(targetScope)) return false;
      if (characterGender != null && !g.isApplicableToGender(characterGender)) {
        return false;
      }
      return true;
    }).toList();

    if (enabledGroups.isEmpty) return [];

    // 根据 groupSelectionMode 选择词组
    final selectedGroups = _selectGroups(
      enabledGroups,
      category.groupSelectionMode,
      category.groupSelectCount,
      random,
    );

    final results = <String>[];
    for (final group in selectedGroups) {
      // 词组概率检查
      if (random.nextDouble() > group.probability) continue;

      // 从词组生成标签
      final tags = await _generateFromGroup(
        group,
        category,
        random,
      );
      results.addAll(tags);
    }

    // 类别级打乱
    if (category.shuffle) {
      results.shuffle(random);
    }

    return results;
  }

  /// 从单个词组生成标签
  ///
  /// [group] 词组配置
  /// [category] 所属类别
  /// [random] 随机数生成器
  Future<List<String>> _generateFromGroup(
    RandomTagGroup group,
    RandomCategory category,
    Random random,
  ) async {
    // 简化实现：仅支持直接标签类型
    // 暂不支持嵌套配置（nodeType == TagGroupNodeType.config）
    // 暂不支持 Pool 类型（sourceType == TagGroupSourceType.pool）
    if (group.tags.isEmpty) return [];

    // 根据 selectionMode 选择标签
    final selectedTags = _selectTags(
      group.tags,
      group.selectionMode,
      group.multipleNum,
      random,
    );

    // 应用括号
    final bracketMin = category.useUnifiedBracket
        ? category.unifiedBracketMin
        : group.bracketMin;
    final bracketMax = category.useUnifiedBracket
        ? category.unifiedBracketMax
        : group.bracketMax;

    return selectedTags.map((tag) {
      if (bracketMin > 0 || bracketMax > 0) {
        return _bracketFormatter.applyBrackets(
          tag,
          bracketMin,
          bracketMax,
          random: random,
        );
      }
      return tag;
    }).toList();
  }

  /// 选择词组
  ///
  /// [groups] 词组列表
  /// [mode] 选择模式
  /// [count] 选择数量
  /// [random] 随机数生成器
  List<RandomTagGroup> _selectGroups(
    List<RandomTagGroup> groups,
    SelectionMode mode,
    int count,
    Random random,
  ) {
    if (groups.isEmpty) return [];

    switch (mode) {
      case SelectionMode.single:
        // 单选模式：随机选择一个
        return [groups[random.nextInt(groups.length)]];

      case SelectionMode.multipleNum:
        // 多选模式：选择指定数量（不超过列表长度）
        final actualCount = count.clamp(1, groups.length);
        final shuffled = List<RandomTagGroup>.from(groups)..shuffle(random);
        return shuffled.take(actualCount).toList();

      case SelectionMode.multipleProb:
      case SelectionMode.sequential:
      case SelectionMode.all:
        // 全选模式：返回所有
        return groups;
    }
  }

  /// 选择标签
  ///
  /// [tags] 标签列表
  /// [mode] 选择模式
  /// [count] 选择数量
  /// [random] 随机数生成器
  List<String> _selectTags(
    List<WeightedTag> tags,
    SelectionMode mode,
    int count,
    Random random,
  ) {
    if (tags.isEmpty) return [];

    switch (mode) {
      case SelectionMode.single:
        // 单选模式：加权随机选择一个
        final tag = _weightedSelector.select(tags, random: random);
        return [tag];

      case SelectionMode.multipleNum:
        // 多选模式：加权随机选择指定数量（不重复）
        final actualCount = count.clamp(1, tags.length);
        final selected = <String>[];
        final remaining = List<WeightedTag>.from(tags);

        for (int i = 0; i < actualCount && remaining.isNotEmpty; i++) {
          final tag = _weightedSelector.select(remaining, random: random);
          selected.add(tag);
          // 移除已选标签（避免重复）
          remaining.removeWhere((t) {
            final tagText = _bracketFormatter.removeBrackets(t.toString());
            final selectedText = _bracketFormatter.removeBrackets(tag);
            return tagText == selectedText;
          });
        }
        return selected;

      case SelectionMode.multipleProb:
      case SelectionMode.sequential:
      case SelectionMode.all:
        // 全选模式：返回所有标签文本
        return tags.map((t) => _weightedSelector.select([t], random: random)).toList();
    }
  }

  /// 生成多角色结果（V4+ 模型）
  ///
  /// [preset] 预设配置
  /// [random] 随机数生成器
  /// [tagOption] 角色标签选项（包含人数标签和槽位配置）
  ///
  /// 返回多角色生成结果，包含主提示词和角色提示词列表
  ///
  /// 生成流程：
  /// 1. 添加人数标签到主提示词（如 "solo", "2girls"）
  /// 2. 生成全局标签（scope: global 或 all）
  /// 3. 为每个角色槽位生成角色提示词（scope: character，按性别过滤）
  ///
  /// 示例：
  /// ```dart
  /// final strategy = PresetGeneratorStrategy();
  /// final preset = RandomPreset.create(name: 'My Preset');
  /// final tagOption = CharacterTagOption(
  ///   label: '2 Girls',
  ///   mainPromptTags: '2girls',
  ///   slotTags: [CharacterSlotTag(characterTag: 'girl'), CharacterSlotTag(characterTag: 'girl')],
  /// );
  /// final result = await strategy.generateMultiCharacter(
  ///   preset: preset,
  ///   random: Random(42),
  ///   tagOption: tagOption,
  /// );
  /// ```
  Future<RandomPromptResult> generateMultiCharacter({
    required RandomPreset preset,
    required Random random,
    CharacterTagOption? tagOption,
  }) async {
    final mainTags = <String>[];
    final characters = <GeneratedCharacter>[];

    // 1. 添加人数标签到主提示词（如 "solo", "2girls"）
    if (tagOption != null && tagOption.mainPromptTags.isNotEmpty) {
      mainTags.add(tagOption.mainPromptTags);
    }

    // 2. 生成全局标签（scope: global 或 all）
    final globalTags = await generate(
      preset: preset,
      random: random,
      targetScope: TagScope.global,
    );
    mainTags.addAll(globalTags);

    // 3. 为每个角色槽位生成角色提示词
    if (tagOption != null && tagOption.slotTags.isNotEmpty) {
      for (final slotTag in tagOption.slotTags) {
        final charTags = <String>[];

        // 确定性别标签（如 "1girl" 或 "1boy"）
        final genderTag = _getGenderTag(slotTag.characterTag);
        charTags.add(genderTag);

        // 生成角色特征标签（scope: character，按性别过滤）
        final characterFeatures = await generate(
          preset: preset,
          random: random,
          targetScope: TagScope.character,
          characterGender: slotTag.characterTag,
        );
        charTags.addAll(characterFeatures);

        // 确定角色性别枚举
        final gender = slotTag.characterTag.contains('girl')
            ? CharacterGender.female
            : slotTag.characterTag.contains('boy')
                ? CharacterGender.male
                : CharacterGender.other;

        characters.add(
          GeneratedCharacter(
            prompt: charTags.join(', '),
            gender: gender,
          ),
        );
      }
    } else {
      // 无槽位配置时，生成单角色（兼容旧配置）
      final charTags = await generate(
        preset: preset,
        random: random,
        targetScope: TagScope.character,
      );
      if (charTags.isNotEmpty) {
        characters.add(
          GeneratedCharacter(
            prompt: charTags.join(', '),
            gender: CharacterGender.female,
          ),
        );
      }
    }

    return RandomPromptResult.multiCharacter(
      mainPrompt: mainTags.join(', '),
      characters: characters,
      seed: random is Random ? random.hashCode : null,
    );
  }

  /// 根据槽位标签获取性别标签
  ///
  /// 例如: "girl" -> "1girl", "boy" -> "1boy"
  ///
  /// 如果标签已包含数字前缀（如 "2girls"），则直接返回原标签。
  String _getGenderTag(String slotTag) {
    // 如果已经包含数字前缀，直接返回
    if (RegExp(r'^\d').hasMatch(slotTag)) {
      return slotTag;
    }
    // 添加 "1" 前缀
    return '1$slotTag';
  }
}
