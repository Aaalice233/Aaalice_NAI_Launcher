import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../datasources/local/pool_cache_service.dart';
import '../datasources/local/tag_group_cache_service.dart';
import '../models/character/character_prompt.dart';
import '../models/prompt/algorithm_config.dart';
import '../models/prompt/category_filter_config.dart';
import '../models/prompt/character_count_config.dart';
import '../models/prompt/random_category.dart';
import '../models/prompt/random_preset.dart';
import '../models/prompt/random_prompt_result.dart';
import '../models/prompt/random_tag_group.dart';
import '../models/prompt/tag_category.dart';
import '../models/prompt/tag_group.dart';
import '../models/prompt/tag_library.dart';
import '../models/prompt/tag_scope.dart';
import '../models/prompt/weighted_tag.dart';
import 'bracket_formatter.dart';
import 'character_count_resolver.dart';
import 'sequential_state_service.dart';
import 'strategies/nai_style_generator_strategy.dart';
import 'strategies/preset_generator_strategy.dart';
import 'strategies/wordlist_generator_strategy.dart';
import 'tag_library_service.dart';
import 'variable_replacement_service.dart';
import 'weighted_selector.dart';
import 'wordlist_service.dart';

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
  final WordlistService? _wordlistService;
  final WeightedSelector _weightedSelector;
  final BracketFormatter _bracketFormatter;
  final CharacterCountResolver _characterCountResolver;
  final VariableReplacementService _variableReplacementService;
  final NaiStyleGeneratorStrategy _naiStyleGenerator;
  final PresetGeneratorStrategy _presetGeneratorStrategy;
  final WordlistGeneratorStrategy _wordlistGeneratorStrategy;

  RandomPromptGenerator(
    this._libraryService,
    this._sequentialService,
    this._tagGroupCacheService,
    this._poolCacheService, [
    this._wordlistService,
  ])  : _weightedSelector = WeightedSelector(),
        _bracketFormatter = BracketFormatter(),
        _characterCountResolver = CharacterCountResolver(),
        _variableReplacementService = VariableReplacementService(),
        _naiStyleGenerator = NaiStyleGeneratorStrategy(),
        _presetGeneratorStrategy = PresetGeneratorStrategy(),
        _wordlistGeneratorStrategy = WordlistGeneratorStrategy();

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
    return _weightedSelector.select(
      tags,
      context: context,
      random: random,
    );
  }

  /// 从整数权重列表中选择（用于角色数量等）
  int getWeightedChoiceInt(List<List<int>> weights, {Random? random}) {
    return _weightedSelector.selectInt(weights, random: random);
  }

  /// 决定角色数量
  int determineCharacterCount({Random? random}) {
    return _characterCountResolver.determineCharacterCount(random: random);
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

    // 使用 NaiStyleGeneratorStrategy 生成提示词
    return _naiStyleGenerator.generate(
      library: library,
      random: random,
      filterConfig: categoryFilterConfig,
      seed: seed,
      isV4Model: isV4Model,
    );
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
    return _characterCountResolver.getCountTag(genders);
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

    // 1. 从预设的 algorithmConfig 获取 characterCountConfig
    final characterCountConfig = preset.algorithmConfig.characterCountConfig ??
        CharacterCountConfig.naiDefault;

    // 2. 使用 PresetGeneratorStrategy 生成结果
    final result = await _presetGeneratorStrategy.generateFromPreset(
      preset: preset,
      config: characterCountConfig,
      random: random,
      seed: seed,
      isV4Model: isV4Model,
    );

    return result;
  }

  /// 从预设类别列表生成标签
  ///
  /// [targetScope] 目标作用域，用于过滤类别和词组
  /// [characterGender] 角色性别（槽位名称），用于过滤性别限定的类别和词组（仅角色提示词时传入）
  Future<List<String>> _generateFromPresetCategories(
    RandomPreset preset,
    Random random, {
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

    // 应用变量替换
    return _applyVariableReplacement(results, preset, random);
  }

  /// 从单个类别生成标签
  ///
  /// [targetScope] 目标作用域，用于过滤词组
  /// [characterGender] 角色性别（槽位名称），用于过滤性别限定的词组
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
    final selectedPosts =
        _poolCacheService.getRandomPosts(poolId, postCount, random);
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
      SelectionMode.multipleNum =>
        _selectByCount(items, count, random, weightGetter),
      SelectionMode.multipleProb => _selectByProbability(items, random, (item) {
          // 对于 RandomTagGroup 使用其 probability 属性
          if (item is RandomTagGroup) return item.probability;
          // 对于 WeightedTag 使用归一化的权重作为概率
          if (item is WeightedTag) return item.weight / 10.0;
          // 其他类型默认 50%
          return 0.5;
        }),
      SelectionMode.sequential => [
          _getSequentialItem(items, sequentialKey ?? 'default'),
        ],
    };
  }

  /// 加权随机选择单个项目
  T _weightedSelect<T>(
    List<T> items,
    Random random,
    double Function(T) weightGetter,
  ) {
    if (items.length == 1) return items.first;

    final totalWeight =
        items.fold<double>(0, (sum, t) => sum + weightGetter(t));
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
    return items
        .where((item) => random.nextDouble() < probabilityGetter(item))
        .toList();
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
  String _applyBrackets(
    String tag,
    int bracketMin,
    int bracketMax,
    Random random,
  ) {
    return _bracketFormatter.applyBrackets(
      tag,
      bracketMin,
      bracketMax,
      random: random,
    );
  }

  // ========== 变量替换系统 ==========

  /// 创建变量解析器
  ///
  /// 为 VariableReplacementService 创建解析器函数
  /// 该解析器会在预设的类别和词组中查找变量名
  Future<String?> _createVariableResolver(
    RandomPreset preset,
    Random random,
    String varName,
  ) async {
    // 在类别中查找匹配（按名称或 key）
    for (final category in preset.categories) {
      // 检查类别本身
      if (category.name == varName || category.key == varName) {
        final generated = await _generateFromCategory(category, random);
        return generated.join(', ');
      }

      // 在词组中查找匹配
      for (final group in category.groups) {
        if (group.name == varName) {
          final generated = await _generateFromGroup(
            group,
            category,
            random,
          );
          return generated.join(', ');
        }
      }
    }

    // 未找到匹配，返回 null 保持原样
    return null;
  }

  /// 对生成结果进行变量替换
  Future<List<String>> _applyVariableReplacement(
    List<String> tags,
    RandomPreset preset,
    Random random,
  ) async {
    // 使用 VariableReplacementService 批量替换
    return _variableReplacementService.replaceListAsync(
      tags,
      (varName) => _createVariableResolver(preset, random, varName),
    );
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

    // Builtin 类型：从 TagLibrary 读取内置词库标签
    if (group.sourceType == TagGroupSourceType.builtin) {
      final sourceId = group.sourceId;
      if (sourceId == null || sourceId.isEmpty) {
        AppLogger.w(
          'Builtin group ${group.name} has no sourceId',
          'RandomGen',
        );
        return [];
      }

      // 根据 sourceId 获取对应的 TagSubCategory
      final category = TagSubCategory.values.cast<TagSubCategory?>().firstWhere(
            (c) => c?.name == sourceId,
            orElse: () => null,
          );
      if (category == null) {
        AppLogger.w(
          'Invalid builtin category: $sourceId',
          'RandomGen',
        );
        return [];
      }

      // 从 TagLibrary 获取标签（排除 Danbooru 补充标签）
      final library = await _libraryService.getAvailableLibrary();
      return library
          .getCategory(category)
          .where((t) => !t.isDanbooruSupplement)
          .toList();
    }

    return group.tags;
  }

  /// 将 TagGroupEntry 列表转换为 WeightedTag 列表
  List<WeightedTag> _convertTagGroupEntriesToWeightedTags(
    List<TagGroupEntry> entries,
  ) {
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

  // ========== CSV 词库生成方法 ==========

  /// 使用 CSV 词库生成随机提示词
  ///
  /// [config] 算法配置
  /// [seed] 随机种子（可选）
  Future<RandomPromptResult> generateFromWordlist({
    AlgorithmConfig config = const AlgorithmConfig(),
    int? seed,
  }) async {
    if (_wordlistService == null) {
      throw StateError('WordlistService not available');
    }

    // 确保词库已加载
    if (!_wordlistService.isInitialized) {
      await _wordlistService.initialize();
    }

    final random = seed != null ? Random(seed) : Random();
    final wordlistType = _getWordlistType(config.wordlistType);

    AppLogger.d(
      'Generating from wordlist: ${wordlistType.fileName}',
      'RandomGen',
    );

    // 检查全局时间条件
    if (!config.isGlobalTimeConditionActive()) {
      AppLogger.d('Global time condition not active', 'RandomGen');
    }

    // 使用 WordlistGeneratorStrategy 生成提示词
    return _wordlistGeneratorStrategy.generate(
      wordlistService: _wordlistService,
      type: wordlistType,
      config: config,
      random: random,
      seed: seed,
      isV4Model: config.isV4Model,
    );
  }

  /// 从配置中获取词库类型
  WordlistType _getWordlistType(String typeName) {
    switch (typeName.toLowerCase()) {
      case 'legacy':
        return WordlistType.legacy;
      case 'furry':
        return WordlistType.furry;
      default:
        return WordlistType.v4;
    }
  }

  /// 应用强调括号
  List<String> _applyEmphasis(
    List<String> tags,
    double probability,
    int bracketCount,
    Random random,
  ) {
    return _bracketFormatter.applyEmphasis(
      tags,
      probability: probability,
      bracketCount: bracketCount,
      random: random,
    );
  }

  /// 从字符串转换性别枚举
  CharacterGender _genderFromString(String gender) {
    return _characterCountResolver.genderFromString(gender);
  }
}

/// Provider
@Riverpod(keepAlive: true)
RandomPromptGenerator randomPromptGenerator(Ref ref) {
  final libraryService = ref.watch(tagLibraryServiceProvider);
  final sequentialService = ref.watch(sequentialStateServiceProvider);
  final tagGroupCacheService = ref.watch(tagGroupCacheServiceProvider);
  final poolCacheService = ref.watch(poolCacheServiceProvider);
  final wordlistService = ref.watch(wordlistServiceProvider);
  return RandomPromptGenerator(
    libraryService,
    sequentialService,
    tagGroupCacheService,
    poolCacheService,
    wordlistService,
  );
}
