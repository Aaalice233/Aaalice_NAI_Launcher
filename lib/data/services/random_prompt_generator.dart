import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../datasources/local/pool_cache_service.dart';
import '../datasources/local/tag_group_cache_service.dart';
import '../models/character/character_prompt.dart';
import '../models/prompt/category_filter_config.dart';
import '../models/prompt/random_category.dart';
import '../models/prompt/random_preset.dart';
import '../models/prompt/random_prompt_result.dart';
import '../models/prompt/random_tag_group.dart';
import '../models/prompt/tag_category.dart';
import '../models/prompt/tag_group.dart';
import '../models/prompt/tag_library.dart';
import '../models/prompt/weighted_tag.dart';
import 'sequential_state_service.dart';
import 'tag_library_service.dart';

part 'random_prompt_generator.g.dart';

/// 随机提示词生成器
///
/// 复刻 NovelAI 官网的随机提示词生成算法
/// 参考: docs/NAI随机提示词功能分析.md
class RandomPromptGenerator {
  final TagLibraryService _libraryService;
  final SequentialStateService _sequentialService;
  final TagGroupCacheService _tagGroupCacheService;
  final PoolCacheService _poolCacheService;

  RandomPromptGenerator(
    this._libraryService,
    this._sequentialService,
    this._tagGroupCacheService,
    this._poolCacheService,
  );

  /// 获取过滤后的类别标签（根据分类级 Danbooru 补充配置）
  List<WeightedTag> _getFilteredCategory(
    TagLibrary library,
    TagSubCategory category,
    CategoryFilterConfig filterConfig,
  ) {
    final includeSupplement = filterConfig.isEnabled(category);
    return library.getFilteredCategory(
      category,
      includeDanbooruSupplement: includeSupplement,
    );
  }

  /// 角色数量权重分布（来自 NAI 官网）
  /// [[1,70], [2,20], [3,7], [0,5]]
  static const List<List<int>> characterCountWeights = [
    [1, 70], // 1人 70%
    [2, 20], // 2人 20%
    [3, 7], // 3人 7%
    [0, 5], // 无人 5%
  ];

  /// Furry 性别权重分布（预留，当前未使用）
  /// [["m",45], ["f",45], ["o",10]]
  // ignore: unused_field
  static const List<List<dynamic>> furryGenderWeights = [
    ['m', 45], // 男性 45%
    ['f', 45], // 女性 45%
    ['o', 10], // 其他 10%
  ];

  /// 加权随机选择算法（复刻官网 ty 函数）
  ///
  /// [tags] 标签列表
  /// [context] 当前上下文（用于条件过滤）
  /// [random] 随机数生成器
  String getWeightedChoice(
    List<WeightedTag> tags, {
    List<String>? context,
    Random? random,
  }) {
    if (tags.isEmpty) {
      throw ArgumentError('Tags list cannot be empty');
    }

    random ??= Random();

    // 1. 过滤符合条件的标签
    final filtered = tags.where((t) {
      if (t.conditions == null || t.conditions!.isEmpty) return true;
      return t.conditions!.any((c) => context?.contains(c) ?? false);
    }).toList();

    if (filtered.isEmpty) {
      // 如果没有符合条件的标签，返回第一个标签
      return tags.first.tag;
    }

    // 2. 计算总权重
    final totalWeight = filtered.fold<int>(0, (sum, t) => sum + t.weight);

    // 3. 生成 [1, totalWeight] 范围内的随机数
    final target = random.nextInt(totalWeight) + 1;

    // 4. 累加权重直到超过随机数
    var cumulative = 0;
    for (final tag in filtered) {
      cumulative += tag.weight;
      if (target <= cumulative) {
        return tag.tag;
      }
    }

    // 不应该到达这里
    return filtered.last.tag;
  }

  /// 从整数权重列表中选择（用于角色数量等）
  int getWeightedChoiceInt(List<List<int>> weights, {Random? random}) {
    random ??= Random();

    final totalWeight = weights.fold<int>(0, (sum, w) => sum + w[1]);
    final target = random.nextInt(totalWeight) + 1;

    var cumulative = 0;
    for (final w in weights) {
      cumulative += w[1];
      if (target <= cumulative) {
        return w[0];
      }
    }

    return weights.last[0];
  }

  /// 决定角色数量
  int determineCharacterCount({Random? random}) {
    return getWeightedChoiceInt(characterCountWeights, random: random);
  }

  /// 生成官网模式随机提示词
  ///
  /// [isV4Model] 是否为 V4+ 模型（支持多角色）
  /// [seed] 随机种子（可选）
  /// [categoryFilterConfig] 分类级 Danbooru 补充配置
  Future<RandomPromptResult> generateNaiStyle({
    bool isV4Model = true,
    int? seed,
    CategoryFilterConfig categoryFilterConfig = const CategoryFilterConfig(),
  }) async {
    final random = seed != null ? Random(seed) : Random();
    final library = await _libraryService.getAvailableLibrary();

    AppLogger.d(
      'Generating NAI style prompt with library: ${library.name}',
      'RandomGen',
    );

    // 决定角色数量
    final characterCount = determineCharacterCount(random: random);

    AppLogger.d('Character count: $characterCount', 'RandomGen');

    if (characterCount == 0) {
      // 无人物场景
      return _generateNoHumanPrompt(library, random, seed, categoryFilterConfig);
    }

    if (!isV4Model) {
      // 传统模式：生成合并的单提示词
      return _generateLegacyPrompt(library, random, characterCount, seed, categoryFilterConfig);
    }

    // V4+ 模式：生成主提示词 + 角色提示词
    return _generateMultiCharacterPrompt(library, random, characterCount, seed, categoryFilterConfig);
  }

  /// 生成无人物场景提示词
  RandomPromptResult _generateNoHumanPrompt(
    TagLibrary library,
    Random random,
    int? seed,
    CategoryFilterConfig filterConfig,
  ) {
    final tags = <String>['no humans'];

    // 添加场景（必选）
    final sceneTags = _getFilteredCategory(library, TagSubCategory.scene, filterConfig);
    if (sceneTags.isNotEmpty) {
      tags.add(getWeightedChoice(sceneTags, random: random));
    }

    // 添加背景（90%）
    if (random.nextDouble() < 0.9) {
      final bgTags = _getFilteredCategory(library, TagSubCategory.background, filterConfig);
      if (bgTags.isNotEmpty) {
        tags.add(getWeightedChoice(bgTags, random: random));
      }
    }

    // 添加风格（50%）
    if (random.nextDouble() < 0.5) {
      final styleTags = _getFilteredCategory(library, TagSubCategory.style, filterConfig);
      if (styleTags.isNotEmpty) {
        tags.add(getWeightedChoice(styleTags, random: random));
      }
    }

    // 额外添加1-3个场景元素（50%）
    if (random.nextDouble() < 0.5) {
      final sceneTagsExtra = _getFilteredCategory(library, TagSubCategory.scene, filterConfig);
      if (sceneTagsExtra.length > 1) {
        final count = random.nextInt(3) + 1;
        final selected = <String>{};
        for (var i = 0; i < count && selected.length < sceneTagsExtra.length; i++) {
          final tag = getWeightedChoice(sceneTagsExtra, random: random);
          if (!tags.contains(tag)) {
            selected.add(tag);
          }
        }
        tags.addAll(selected);
      }
    }

    return RandomPromptResult.noHuman(
      prompt: tags.join(', '),
      seed: seed,
    );
  }

  /// 生成传统单提示词（用于非 V4 模型）
  RandomPromptResult _generateLegacyPrompt(
    TagLibrary library,
    Random random,
    int characterCount,
    int? seed,
    CategoryFilterConfig filterConfig,
  ) {
    final tags = <String>[];

    // 添加人数标签
    tags.add(_getCountTag(characterCount));

    // 添加角色特征
    final charTags =
        _generateCharacterTags(library, random, CharacterGender.female, filterConfig);
    tags.addAll(charTags);

    // 添加背景
    if (random.nextDouble() < 0.9) {
      final bgTags = _getFilteredCategory(library, TagSubCategory.background, filterConfig);
      if (bgTags.isNotEmpty) {
        tags.add(getWeightedChoice(bgTags, random: random));
      }
    }

    // 添加场景
    if (random.nextDouble() < 0.5) {
      final sceneTags = _getFilteredCategory(library, TagSubCategory.scene, filterConfig);
      if (sceneTags.isNotEmpty) {
        tags.add(getWeightedChoice(sceneTags, random: random));
      }
    }

    return RandomPromptResult(
      mainPrompt: tags.join(', '),
      seed: seed,
    );
  }

  /// 生成多角色提示词（V4+ 模式）
  RandomPromptResult _generateMultiCharacterPrompt(
    TagLibrary library,
    Random random,
    int characterCount,
    int? seed,
    CategoryFilterConfig filterConfig,
  ) {
    // 先生成角色以确定性别组合
    final characters = <GeneratedCharacter>[];
    final genders = <CharacterGender>[];

    for (var i = 0; i < characterCount; i++) {
      // 决定性别（第一个默认女性，后续随机）
      final gender = i == 0
          ? CharacterGender.female
          : (random.nextBool() ? CharacterGender.female : CharacterGender.male);

      genders.add(gender);
      final charTags = _generateCharacterTags(library, random, gender, filterConfig);

      // 添加人物标签
      final genderTag = gender == CharacterGender.female ? '1girl' : '1boy';
      charTags.insert(0, genderTag);

      characters.add(
        GeneratedCharacter(
          prompt: charTags.join(', '),
          gender: gender,
        ),
      );
    }

    // 生成主提示词
    final mainTags = <String>[];

    // 根据角色性别组合添加精确的人数标签
    mainTags.add(_getCountTagForCharacters(genders));

    // 添加风格（30%）
    if (random.nextDouble() < 0.3) {
      final styleTags = _getFilteredCategory(library, TagSubCategory.style, filterConfig);
      if (styleTags.isNotEmpty) {
        mainTags.add(getWeightedChoice(styleTags, random: random));
      }
    }

    // 添加背景（90%）
    if (random.nextDouble() < 0.9) {
      final bgTags = _getFilteredCategory(library, TagSubCategory.background, filterConfig);
      if (bgTags.isNotEmpty) {
        final bg = getWeightedChoice(bgTags, random: random);
        mainTags.add(bg);

        // 如果是详细背景，添加额外场景元素
        if (bg.contains('detailed') || bg.contains('amazing')) {
          final sceneTags = _getFilteredCategory(library, TagSubCategory.scene, filterConfig);
          if (sceneTags.isNotEmpty) {
            final count = random.nextInt(2) + 1;
            for (var i = 0; i < count; i++) {
              mainTags.add(getWeightedChoice(sceneTags, random: random));
            }
          }
        }
      }
    }

    return RandomPromptResult.multiCharacter(
      mainPrompt: mainTags.join(', '),
      characters: characters,
      seed: seed,
    );
  }

  /// 生成单个角色的特征标签
  List<String> _generateCharacterTags(
    TagLibrary library,
    Random random,
    CharacterGender gender,
    CategoryFilterConfig filterConfig,
  ) {
    final tags = <String>[];

    // 发色（80%）
    if (random.nextDouble() < 0.8) {
      final hairColors = _getFilteredCategory(library, TagSubCategory.hairColor, filterConfig);
      if (hairColors.isNotEmpty) {
        tags.add(getWeightedChoice(hairColors, random: random));
      }
    }

    // 瞳色（80%）
    if (random.nextDouble() < 0.8) {
      final eyeColors = _getFilteredCategory(library, TagSubCategory.eyeColor, filterConfig);
      if (eyeColors.isNotEmpty) {
        tags.add(getWeightedChoice(eyeColors, random: random));
      }
    }

    // 发型（50%）
    if (random.nextDouble() < 0.5) {
      final hairStyles = _getFilteredCategory(library, TagSubCategory.hairStyle, filterConfig);
      if (hairStyles.isNotEmpty) {
        tags.add(getWeightedChoice(hairStyles, random: random));
      }
    }

    // 表情（60%）
    if (random.nextDouble() < 0.6) {
      final expressions = _getFilteredCategory(library, TagSubCategory.expression, filterConfig);
      if (expressions.isNotEmpty) {
        tags.add(getWeightedChoice(expressions, random: random));
      }
    }

    // 姿势（50%）
    if (random.nextDouble() < 0.5) {
      final poses = _getFilteredCategory(library, TagSubCategory.pose, filterConfig);
      if (poses.isNotEmpty) {
        tags.add(getWeightedChoice(poses, random: random));
      }
    }

    return tags;
  }

  /// 获取人数标签
  ///
  /// 注意: "duo" 和 "trio" 是 Danbooru 已废弃的标签，不应使用
  /// 参考: https://danbooru.donmai.us/wiki_pages/duo
  /// NAI 官网使用具体的角色组合标签如 2girls, 1girl 1boy 等
  String _getCountTag(int count) {
    return switch (count) {
      1 => 'solo',
      2 => '2girls',  // 默认使用 2girls，V4模式会根据实际性别生成
      3 => 'multiple girls',
      _ => 'group',
    };
  }

  /// 根据角色性别组合获取精确的人数标签（用于 V4 多角色模式）
  ///
  /// 返回逗号分隔的标签字符串，例如 "1girl, 1boy"
  ///
  /// 所有可能的组合：
  /// - 0人: "no humans"
  /// - 1人: "solo"
  /// - 2女: "2girls"
  /// - 2男: "2boys"
  /// - 1女1男: "1girl, 1boy"
  /// - 3女: "3girls"
  /// - 3男: "3boys"
  /// - 2女1男: "2girls, 1boy"
  /// - 1女2男: "1girl, 2boys"
  /// - 更多同性: "multiple girls" 或 "multiple boys"
  /// - 混合多人: "group"
  String _getCountTagForCharacters(List<CharacterGender> genders) {
    if (genders.isEmpty) return 'no humans';
    if (genders.length == 1) return 'solo';

    final femaleCount = genders.where((g) => g == CharacterGender.female).length;
    final maleCount = genders.where((g) => g == CharacterGender.male).length;

    // 2人组合
    if (genders.length == 2) {
      if (femaleCount == 2) return '2girls';
      if (maleCount == 2) return '2boys';
      if (femaleCount == 1 && maleCount == 1) return '1girl, 1boy';
    }

    // 3人组合
    if (genders.length == 3) {
      if (femaleCount == 3) return '3girls';
      if (maleCount == 3) return '3boys';
      if (femaleCount == 2 && maleCount == 1) return '2girls, 1boy';
      if (femaleCount == 1 && maleCount == 2) return '1girl, 2boys';
    }

    // 更多角色
    if (femaleCount > 0 && maleCount == 0) return 'multiple girls';
    if (maleCount > 0 && femaleCount == 0) return 'multiple boys';
    return 'group';
  }

  /// 使用自定义预设生成（包装现有功能）
  RandomPromptResult generateCustom(String customPrompt, {int? seed}) {
    return RandomPromptResult(
      mainPrompt: customPrompt,
      mode: RandomGenerationMode.custom,
      seed: seed,
    );
  }

  // ========== 从预设配置生成（Phase 1 新增） ==========

  /// 从预设生成提示词
  ///
  /// [preset] 随机预设配置
  /// [isV4Model] 是否为 V4+ 模型
  /// [seed] 随机种子
  Future<RandomPromptResult> generateFromPreset({
    required RandomPreset preset,
    bool isV4Model = true,
    int? seed,
  }) async {
    final random = seed != null ? Random(seed) : Random();

    AppLogger.d(
      'Generating from preset: ${preset.name} (${preset.categories.length} categories)',
      'RandomGen',
    );

    // 从预设类别生成标签
    final tags = await _generateFromPresetCategories(preset, random);

    if (tags.isEmpty) {
      // 如果没有生成任何标签，返回默认结果
      return RandomPromptResult(
        mainPrompt: '',
        mode: RandomGenerationMode.naiOfficial,
        seed: seed,
      );
    }

    return RandomPromptResult(
      mainPrompt: tags.join(', '),
      mode: RandomGenerationMode.naiOfficial,
      seed: seed,
    );
  }

  /// 从预设类别列表生成标签
  Future<List<String>> _generateFromPresetCategories(RandomPreset preset, Random random) async {
    final results = <String>[];

    for (final category in preset.categories) {
      // 跳过禁用的类别
      if (!category.enabled) continue;

      // 类别概率检查
      if (random.nextDouble() > category.probability) continue;

      // 生成类别内的标签
      final categoryTags = await _generateFromCategory(category, random);
      results.addAll(categoryTags);
    }

    // 应用变量替换
    return _applyVariableReplacement(results, preset, random);
  }

  /// 从单个类别生成标签
  Future<List<String>> _generateFromCategory(RandomCategory category, Random random) async {
    final enabledGroups = category.groups.where((g) => g.enabled).toList();
    if (enabledGroups.isEmpty) return [];

    // 根据 groupSelectionMode 选择词组
    final selectedGroups = _selectItems<RandomTagGroup>(
      enabledGroups,
      category.groupSelectionMode,
      category.groupSelectCount,
      random,
      (g) => 1.0, // 词组默认等权重选择
      sequentialKey: 'cat_${category.id}',
    );

    final results = <String>[];
    for (final group in selectedGroups) {
      // 词组概率检查
      if (random.nextDouble() > group.probability) continue;

      // 从词组生成标签
      final tags = await _generateFromGroup(group, category, random);
      results.addAll(tags);
    }

    // 类别级打乱
    if (category.shuffle) {
      results.shuffle(random);
    }

    return results;
  }

  /// 从单个词组生成标签（支持递归嵌套）
  Future<List<String>> _generateFromGroup(
    RandomTagGroup group,
    RandomCategory category,
    Random random,
  ) async {
    // 处理嵌套配置
    if (group.nodeType == TagGroupNodeType.config) {
      return _generateFromNestedGroup(group, category, random);
    }

    // Pool 类型使用专门的生成逻辑
    if (group.sourceType == TagGroupSourceType.pool) {
      return _generateFromPoolGroup(group, category, random);
    }

    // 获取标签列表：对于同步类型的组从缓存读取，否则使用内嵌标签
    final enabledTags = await _getTagsForGroup(group);
    if (enabledTags.isEmpty) return [];

    // 根据 selectionMode 选择标签
    final selectedTags = _selectItems<WeightedTag>(
      enabledTags,
      group.selectionMode,
      group.multipleNum,
      random,
      (t) => t.weight.toDouble(), // 使用标签权重
      sequentialKey: 'grp_${group.id}',
    );

    // 确定括号范围
    final bracketMin = category.useUnifiedBracket
        ? category.unifiedBracketMin
        : group.bracketMin;
    final bracketMax = category.useUnifiedBracket
        ? category.unifiedBracketMax
        : group.bracketMax;

    // 应用权重括号
    final bracketedTags = selectedTags.map((t) {
      return _applyBrackets(t.tag, bracketMin, bracketMax, random);
    }).toList();

    // 词组级打乱
    if (group.shuffle) {
      bracketedTags.shuffle(random);
    }

    return bracketedTags;
  }

  /// 从 Pool 类型词组生成标签
  ///
  /// Pool 使用按帖子随机的逻辑，与普通词组不同：
  /// 1. 根据 selectionMode 决定选择几个帖子
  /// 2. 从缓存随机获取帖子
  /// 3. 根据 poolOutputConfig 提取标签
  /// 4. 应用括号权重和打乱
  Future<List<String>> _generateFromPoolGroup(
    RandomTagGroup group,
    RandomCategory category,
    Random random,
  ) async {
    final sourceId = group.sourceId;
    if (sourceId == null || sourceId.isEmpty) {
      AppLogger.w('Pool ${group.name} has no sourceId', 'RandomGen');
      return [];
    }

    final poolId = int.tryParse(sourceId);
    if (poolId == null) {
      AppLogger.w('Invalid pool ID: $sourceId', 'RandomGen');
      return [];
    }

    // 确保 Pool 缓存已加载到内存
    final poolEntry = await _poolCacheService.getPool(poolId);
    if (poolEntry == null || poolEntry.posts.isEmpty) {
      AppLogger.w('Pool cache not found or empty for: $sourceId', 'RandomGen');
      return [];
    }

    // 根据 selectionMode 决定选择几个帖子
    final postCount = switch (group.selectionMode) {
      SelectionMode.single => 1,
      SelectionMode.all => poolEntry.posts.length,
      SelectionMode.multipleNum => group.poolPostCount,
      SelectionMode.multipleProb => 1, // Pool 不适用概率模式，默认选1个
      SelectionMode.sequential => 1, // 顺序模式也选1个
    };

    // 从缓存随机获取帖子
    final selectedPosts = _poolCacheService.getRandomPosts(poolId, postCount, random);
    if (selectedPosts.isEmpty) {
      AppLogger.w('No posts selected from pool: $sourceId', 'RandomGen');
      return [];
    }

    // 根据 poolOutputConfig 提取标签
    final outputConfig = group.poolOutputConfig;
    final allTags = <String>[];

    for (final post in selectedPosts) {
      final tags = post.getTagsForOutput(outputConfig);
      allTags.addAll(tags);
    }

    if (allTags.isEmpty) {
      AppLogger.d('No tags extracted from pool posts: $sourceId', 'RandomGen');
      return [];
    }

    // 打乱标签（如果配置要求）
    if (outputConfig.shuffleTags || group.shuffle) {
      allTags.shuffle(random);
    }

    // 确定括号范围
    final bracketMin = category.useUnifiedBracket
        ? category.unifiedBracketMin
        : group.bracketMin;
    final bracketMax = category.useUnifiedBracket
        ? category.unifiedBracketMax
        : group.bracketMax;

    // 应用权重括号并格式化标签
    return allTags.map((tag) {
      // 将下划线替换为空格
      final formattedTag = tag.replaceAll('_', ' ');
      return _applyBrackets(formattedTag, bracketMin, bracketMax, random);
    }).toList();
  }

  /// 从嵌套词组生成标签（递归）
  Future<List<String>> _generateFromNestedGroup(
    RandomTagGroup group,
    RandomCategory category,
    Random random,
  ) async {
    final enabledChildren = group.children.where((c) => c.enabled).toList();
    if (enabledChildren.isEmpty) return [];

    // 根据 selectionMode 选择子词组
    final selectedChildren = _selectItems<RandomTagGroup>(
      enabledChildren,
      group.selectionMode,
      group.multipleNum,
      random,
      (c) => 1.0, // 子词组默认等权重
      sequentialKey: 'nested_${group.id}',
    );

    final results = <String>[];
    for (final child in selectedChildren) {
      // 子词组概率检查
      if (random.nextDouble() > child.probability) continue;

      // 递归生成
      final childTags = await _generateFromGroup(child, category, random);
      results.addAll(childTags);
    }

    // 词组级打乱
    if (group.shuffle) {
      results.shuffle(random);
    }

    return results;
  }

  /// 通用选择算法
  ///
  /// 支持 5 种选择模式：
  /// - single: 加权随机选择一个
  /// - all: 选择所有
  /// - multipleNum: 选择指定数量
  /// - multipleProb: 每个独立概率判断
  /// - sequential: 顺序轮替（持久化）
  ///
  /// [sequentialKey] 用于 sequential 模式的持久化 key
  List<T> _selectItems<T>(
    List<T> items,
    SelectionMode mode,
    int count,
    Random random,
    double Function(T) weightGetter, {
    String? sequentialKey,
  }) {
    if (items.isEmpty) return [];

    return switch (mode) {
      SelectionMode.single => [_weightedSelect(items, random, weightGetter)],
      SelectionMode.all => List.from(items),
      SelectionMode.multipleNum => _selectByCount(items, count, random, weightGetter),
      SelectionMode.multipleProb => _selectByProbability(items, random, (item) {
        // 对于 RandomTagGroup 使用其 probability 属性
        if (item is RandomTagGroup) return item.probability;
        // 对于 WeightedTag 使用归一化的权重作为概率
        if (item is WeightedTag) return item.weight / 10.0;
        // 其他类型默认 50%
        return 0.5;
      }),
      SelectionMode.sequential => [_getSequentialItem(items, sequentialKey ?? 'default')],
    };
  }

  /// 加权随机选择单个项目
  T _weightedSelect<T>(
    List<T> items,
    Random random,
    double Function(T) weightGetter,
  ) {
    if (items.length == 1) return items.first;

    final totalWeight = items.fold<double>(0, (sum, t) => sum + weightGetter(t));
    if (totalWeight <= 0) return items[random.nextInt(items.length)];

    final target = random.nextDouble() * totalWeight;
    var cumulative = 0.0;

    for (final item in items) {
      cumulative += weightGetter(item);
      if (target <= cumulative) {
        return item;
      }
    }

    return items.last;
  }

  /// 按数量选择（不重复）
  List<T> _selectByCount<T>(
    List<T> items,
    int count,
    Random random,
    double Function(T) weightGetter,
  ) {
    if (count >= items.length) return List.from(items);

    final selected = <T>[];
    final remaining = List<T>.from(items);

    for (var i = 0; i < count && remaining.isNotEmpty; i++) {
      final item = _weightedSelect(remaining, random, weightGetter);
      selected.add(item);
      remaining.remove(item);
    }

    return selected;
  }

  /// 按概率独立选择（每个项目使用自己的概率）
  ///
  /// 对于 RandomTagGroup 使用其 probability 属性
  /// 对于其他类型使用默认 50% 概率
  List<T> _selectByProbability<T>(
    List<T> items,
    Random random,
    double Function(T) probabilityGetter,
  ) {
    return items.where((item) => random.nextDouble() < probabilityGetter(item)).toList();
  }

  /// 顺序轮替选择（使用持久化服务）
  T _getSequentialItem<T>(List<T> items, String key) {
    final index = _sequentialService.getNextIndexSync(key, items.length);
    return items[index];
  }

  /// 应用权重括号
  ///
  /// [bracketMin] 最小括号层数（可为负数）
  /// [bracketMax] 最大括号层数（可为负数）
  /// 正数使用 {} 增强权重
  /// 负数使用 [] 降低权重
  String _applyBrackets(String tag, int bracketMin, int bracketMax, Random random) {
    if (bracketMin == 0 && bracketMax == 0) return tag;

    // 确保 min <= max
    final min = bracketMin <= bracketMax ? bracketMin : bracketMax;
    final max = bracketMin <= bracketMax ? bracketMax : bracketMin;

    // 随机选择层数
    final n = min + random.nextInt(max - min + 1);

    if (n == 0) return tag;

    // 负数用 []（降权），正数用 {}（增强）
    if (n < 0) {
      final count = -n;
      final open = '[' * count;
      final close = ']' * count;
      return '$open$tag$close';
    } else {
      final open = '{' * n;
      final close = '}' * n;
      return '$open$tag$close';
    }
  }

  // ========== 变量替换系统（Phase 4） ==========

  /// 变量引用正则：__变量名__
  static final RegExp _variablePattern = RegExp(
    r'__([^\s_][^_]*?)__',
    unicode: true,
  );

  /// 替换变量引用
  ///
  /// 支持格式：__变量名__
  /// 会在预设的类别和词组中查找匹配项并生成内容
  Future<String> _replaceVariables(String text, RandomPreset preset, Random random) async {
    if (!text.contains('__')) return text;

    // 由于 replaceAllMapped 不支持 async，需要手动处理
    var result = text;
    final matches = _variablePattern.allMatches(text).toList();

    for (final match in matches.reversed) {
      final varName = match.group(1)!;
      String? replacement;

      // 1. 在类别中查找匹配（按名称或 key）
      for (final category in preset.categories) {
        if (category.name == varName || category.key == varName) {
          final generated = await _generateFromCategory(category, random);
          replacement = generated.join(', ');
          break;
        }

        // 2. 在词组中查找匹配
        for (final group in category.groups) {
          if (group.name == varName) {
            final generated = await _generateFromGroup(group, category, random);
            replacement = generated.join(', ');
            break;
          }
        }
        if (replacement != null) break;
      }

      // 未找到匹配，保持原样
      replacement ??= match.group(0)!;
      result = result.replaceRange(match.start, match.end, replacement);
    }

    return result;
  }

  /// 对生成结果进行变量替换
  Future<List<String>> _applyVariableReplacement(
    List<String> tags,
    RandomPreset preset,
    Random random,
  ) async {
    final results = <String>[];
    for (final tag in tags) {
      results.add(await _replaceVariables(tag, preset, random));
    }
    return results;
  }

  // ========== 从缓存获取标签（用于同步类型的组） ==========

  /// 获取词组的标签列表
  ///
  /// 对于同步类型（tagGroup）的组，从缓存读取标签
  /// 对于自定义类型的组，直接返回内嵌的标签
  /// 注意：Pool 类型由 _generateFromPoolGroup 单独处理
  Future<List<WeightedTag>> _getTagsForGroup(RandomTagGroup group) async {
    // 自定义类型：直接返回内嵌标签
    if (group.sourceType == TagGroupSourceType.custom) {
      return group.tags;
    }

    // Tag Group 类型：从缓存读取
    if (group.sourceType == TagGroupSourceType.tagGroup) {
      final sourceId = group.sourceId;
      if (sourceId == null || sourceId.isEmpty) {
        AppLogger.w(
          'Tag group ${group.name} has no sourceId',
          'RandomGen',
        );
        return group.tags; // fallback to embedded tags
      }

      final tagGroup = await _tagGroupCacheService.getTagGroup(sourceId);
      if (tagGroup == null) {
        AppLogger.w(
          'Tag group cache not found for: $sourceId',
          'RandomGen',
        );
        return group.tags; // fallback to embedded tags
      }

      // 将 TagGroupEntry 转换为 WeightedTag
      return _convertTagGroupEntriesToWeightedTags(tagGroup.tags);
    }

    // Pool 类型由 _generateFromPoolGroup 单独处理，这里不应该被调用
    // 如果被调用，返回空列表（作为安全措施）
    if (group.sourceType == TagGroupSourceType.pool) {
      AppLogger.w(
        '_getTagsForGroup called for Pool type - this should not happen',
        'RandomGen',
      );
      return [];
    }

    return group.tags;
  }

  /// 将 TagGroupEntry 列表转换为 WeightedTag 列表
  List<WeightedTag> _convertTagGroupEntriesToWeightedTags(List<TagGroupEntry> entries) {
    return entries.map((entry) {
      // 根据热度计算权重 (1-10)
      final weight = _calculateWeightFromPostCount(entry.postCount);
      return WeightedTag(
        tag: entry.name.replaceAll('_', ' '),
        weight: weight,
      );
    }).toList();
  }

  /// 根据帖子数量计算权重（1-10）
  ///
  /// 使用对数缩放，更合理地分配权重
  int _calculateWeightFromPostCount(int postCount) {
    if (postCount <= 0) return 1;
    if (postCount < 100) return 1;
    if (postCount < 1000) return 2;
    if (postCount < 5000) return 3;
    if (postCount < 10000) return 4;
    if (postCount < 50000) return 5;
    if (postCount < 100000) return 6;
    if (postCount < 500000) return 7;
    if (postCount < 1000000) return 8;
    if (postCount < 5000000) return 9;
    return 10;
  }
}

/// Provider
@Riverpod(keepAlive: true)
RandomPromptGenerator randomPromptGenerator(Ref ref) {
  final libraryService = ref.watch(tagLibraryServiceProvider);
  final sequentialService = ref.watch(sequentialStateServiceProvider);
  final tagGroupCacheService = ref.watch(tagGroupCacheServiceProvider);
  final poolCacheService = ref.watch(poolCacheServiceProvider);
  return RandomPromptGenerator(
    libraryService,
    sequentialService,
    tagGroupCacheService,
    poolCacheService,
  );
}
