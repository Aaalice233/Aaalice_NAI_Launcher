import 'dart:math';

import '../../../core/utils/app_logger.dart';
import '../../models/character/character_prompt.dart';
import '../../models/prompt/algorithm_config.dart';
import '../../models/prompt/random_prompt_result.dart';
import '../../models/prompt/weighted_tag.dart';
import '../../models/prompt/wordlist_entry.dart';
import '../bracket_formatter.dart';
import '../character_count_resolver.dart';
import '../weighted_selector.dart';
import '../wordlist_service.dart';

/// 词库生成策略
///
/// 负责从 CSV 词库生成标签。
/// 支持按变量名和分类选择标签，应用 exclude/require 规则，
/// 并进行加权随机选择。
/// 从 RandomPromptGenerator._selectFromWordlist 提取。
///
/// ## 主要功能
///
/// - 从词库条目列表中进行加权随机选择
/// - 支持选择多个不重复的标签
/// - 应用 exclude/require 规则过滤
/// - 检查条目在给定上下文中的可用性
/// - 生成多角色提示词（V4+ 模型）
///
/// ## 规则系统
///
/// **Require 规则**:
/// - 只有当上下文中包含 require 列表中的任一标签时，此条目才会被选中
/// - 用于实现条件逻辑（如：只有在选择"长发"时才选择"束发"）
///
/// **Exclude 规则**:
/// - 如果上下文中包含 exclude 列表中的任一标签，此条目不会被选中
/// - 用于避免冲突（如：选择了"短发"时排除"长发"相关标签）
///
/// ## 使用示例
///
/// ```dart
/// final strategy = WordlistGeneratorStrategy();
///
/// // 单个选择
/// final tag = strategy.select(
///   entries: hairEntries,
///   random: Random(42),
///   context: {'hair_style': ['long hair']}, // 上下文
/// );
///
/// // 多个选择（不重复）
/// final tags = strategy.selectMultiple(
///   entries: colorEntries,
///   count: 3,
///   random: Random(42),
/// );
///
/// // 检查可用性
/// final available = strategy.isEntryAvailable(
///   entry,
///   context: {'hair_color': ['blonde']},
/// );
///
/// // 生成多角色提示词（V4+ 模型）
/// final result = strategy.generateMultiCharacter(
///   wordlistService: wordlistService,
///   type: WordlistType.v4,
///   config: AlgorithmConfig(),
///   random: Random(42),
///   characterCount: 2,
///   seed: 42,
/// );
///
/// // 生成传统单提示词（非 V4 模型）
/// final legacyResult = strategy.generateLegacy(
///   wordlistService: wordlistService,
///   type: WordlistType.v4,
///   config: AlgorithmConfig(),
///   random: Random(42),
///   characterCount: 1,
///   seed: 42,
/// );
///
/// // 生成无人物场景
/// final noHumanResult = strategy.generateNoHuman(
///   wordlistService: wordlistService,
///   type: WordlistType.v4,
///   config: AlgorithmConfig(),
///   random: Random(42),
///   seed: 42,
/// );
/// ```
///
/// ## 性能特性
///
/// - 时间复杂度: O(n) 单次选择, O(k * n) 多次选择（k 为选择数量）
/// - 使用过滤+选择的两阶段算法
/// - 支持大规模词库（> 10000 条目）
class WordlistGeneratorStrategy {
  /// 加权选择器
  final WeightedSelector _weightedSelector;

  /// 括号格式化器
  final BracketFormatter _bracketFormatter;

  /// 角色数量解析器
  final CharacterCountResolver _countResolver;

  /// 角色数量权重分布（来自 NAI 官网）
  /// [[1,70], [2,20], [3,7], [0,5]]
  static const List<List<int>> characterCountWeights = [
    [1, 70], // 1人 70%
    [2, 20], // 2人 20%
    [3, 7], // 3人 7%
    [0, 5], // 无人 5%
  ];

  /// 创建词库生成策略
  ///
  /// [weightedSelector] 加权选择器（可选，默认创建新实例）
  /// [bracketFormatter] 括号格式化器（可选，默认创建新实例）
  /// [countResolver] 角色数量解析器（可选，默认创建新实例）
  WordlistGeneratorStrategy({
    WeightedSelector? weightedSelector,
    BracketFormatter? bracketFormatter,
    CharacterCountResolver? countResolver,
  })  : _weightedSelector = weightedSelector ?? WeightedSelector(),
        _bracketFormatter = bracketFormatter ?? BracketFormatter(),
        _countResolver = countResolver ?? CharacterCountResolver();

  /// 生成随机提示词（主入口方法）
  ///
  /// [wordlistService] 词库服务，用于获取词库条目
  /// [type] 词库类型
  /// [config] 算法配置
  /// [random] 随机数生成器
  /// [seed] 随机种子（可选）
  /// [isV4Model] 是否为 V4+ 模型（支持多角色，默认 true）
  ///
  /// 返回生成的提示词结果
  ///
  /// 示例：
  /// ```dart
  /// final strategy = WordlistGeneratorStrategy();
  /// final result = await strategy.generate(
  ///   wordlistService: wordlistService,
  ///   type: WordlistType.v4,
  ///   config: AlgorithmConfig(),
  ///   random: Random(42),
  ///   seed: 42,
  ///   isV4Model: true,
  /// );
  /// ```
  Future<RandomPromptResult> generate({
    required WordlistService wordlistService,
    required WordlistType type,
    required AlgorithmConfig config,
    required Random random,
    int? seed,
    bool isV4Model = true,
  }) async {
    // 决定角色数量
    final characterCount = _countResolver.determineCharacterCountFromWeights(
      characterCountWeights,
      random: random,
    );

    if (characterCount == 0) {
      // 无人物场景
      return generateNoHuman(
        wordlistService: wordlistService,
        type: type,
        config: config,
        random: random,
        seed: seed,
      );
    }

    if (!isV4Model) {
      // 传统模式：生成合并的单提示词
      return generateLegacy(
        wordlistService: wordlistService,
        type: type,
        config: config,
        random: random,
        characterCount: characterCount,
        seed: seed,
      );
    }

    // V4+ 模式：生成主提示词 + 角色提示词
    return generateMultiCharacter(
      wordlistService: wordlistService,
      type: type,
      config: config,
      random: random,
      characterCount: characterCount,
      seed: seed,
    );
  }

  /// 从词库条目列表中选择标签
  ///
  /// [entries] 词库条目列表
  /// [random] 随机数生成器
  /// [context] 已选择的标签上下文（用于应用 exclude/require 规则）
  ///
  /// 返回选中的标签文本，如果列表为空或规则过滤后无可用标签则返回 null
  ///
  /// 示例：
  /// ```dart
  /// final strategy = WordlistGeneratorStrategy();
  /// final entries = [
  ///   WordlistEntry(
  ///     variable: 'char',
  ///     category: 'hair_color',
  ///     tag: 'blonde hair',
  ///     weight: 10,
  ///   ),
  /// ];
  /// final tag = strategy.select(
  ///   entries: entries,
  ///   random: Random(42),
  /// );
  /// // 'blonde hair'
  /// ```
  String? select({
    required List<WordlistEntry> entries,
    required Random random,
    Map<String, List<String>>? context,
  }) {
    if (entries.isEmpty) return null;

    // 应用 exclude/require 规则
    final filtered = _applyWordlistRules(entries, context);
    if (filtered.isEmpty) return null;

    // 转换为 WeightedTag 进行加权随机选择
    final weightedTags = filtered.map((e) => WeightedTag(
      tag: e.tag,
      weight: e.weight,
    ),).toList();

    return _weightedSelector.select(weightedTags, random: random);
  }

  /// 从词库条目列表中选择多个标签（不重复）
  ///
  /// [entries] 词库条目列表
  /// [count] 选择数量
  /// [random] 随机数生成器
  /// [context] 已选择的标签上下文
  ///
  /// 返回选中的标签文本列表
  ///
  /// 示例：
  /// ```dart
  /// final strategy = WordlistGeneratorStrategy();
  /// final entries = [/* ... */];
  /// final tags = strategy.selectMultiple(
  ///   entries: entries,
  ///   count: 3,
  ///   random: Random(42),
  /// );
  /// ```
  List<String> selectMultiple({
    required List<WordlistEntry> entries,
    required int count,
    required Random random,
    Map<String, List<String>>? context,
  }) {
    if (entries.isEmpty) return [];

    // 应用 exclude/require 规则
    var filtered = _applyWordlistRules(entries, context);
    if (filtered.isEmpty) return [];

    final selected = <String>[];
    final actualCount = count.clamp(1, filtered.length);

    for (int i = 0; i < actualCount && filtered.isNotEmpty; i++) {
      // 转换为 WeightedTag 进行加权随机选择
      final weightedTags = filtered.map((e) => WeightedTag(
        tag: e.tag,
        weight: e.weight,
      ),).toList();

      final tag = _weightedSelector.select(weightedTags, random: random);
      selected.add(tag);

      // 移除已选标签（避免重复）
      filtered = filtered.where((e) => e.tag != tag).toList();
    }

    return selected;
  }

  /// 应用词库条目的 exclude/require 规则
  ///
  /// [entries] 词库条目列表
  /// [context] 已选择的标签上下文（类别 -> 标签列表）
  ///
  /// 返回符合规则的条目列表
  ///
  /// 规则说明：
  /// - require: 只有当上下文中包含 require 列表中的任一标签时，此条目才会被选中
  /// - exclude: 如果上下文中包含 exclude 列表中的任一标签，此条目不会被选中
  List<WordlistEntry> _applyWordlistRules(
    List<WordlistEntry> entries,
    Map<String, List<String>>? context,
  ) {
    if (context == null || context.isEmpty) return entries;

    // 收集所有已选择的标签
    final selectedTags = context.values.expand((v) => v).toSet();

    return entries.where((entry) {
      // 检查 require 规则
      if (entry.hasRequireRules) {
        final hasRequired = entry.require.any(
          (req) => selectedTags.contains(req),
        );
        if (!hasRequired) return false;
      }

      // 检查 exclude 规则
      if (entry.hasExcludeRules) {
        final hasExcluded = entry.exclude.any(
          (exc) => selectedTags.contains(exc),
        );
        if (hasExcluded) return false;
      }

      return true;
    }).toList();
  }

  /// 检查指定条目在给定上下文中是否可用
  ///
  /// [entry] 词库条目
  /// [context] 已选择的标签上下文
  ///
  /// 返回是否可用
  bool isEntryAvailable(
    WordlistEntry entry,
    Map<String, List<String>>? context,
  ) {
    if (context == null || context.isEmpty) return true;

    final filtered = _applyWordlistRules([entry], context);
    return filtered.isNotEmpty;
  }

  /// 获取指定上下文中可用的条目数量
  ///
  /// [entries] 词库条目列表
  /// [context] 已选择的标签上下文
  ///
  /// 返回可用条目数量
  int getAvailableEntryCount(
    List<WordlistEntry> entries,
    Map<String, List<String>>? context,
  ) {
    return _applyWordlistRules(entries, context).length;
  }

  // ========== 多角色生成方法 ==========

  /// 从词库生成多角色提示词
  ///
  /// [wordlistService] 词库服务，用于获取词库条目
  /// [type] 词库类型
  /// [config] 算法配置
  /// [random] 随机数生成器
  /// [characterCount] 角色数量
  /// [seed] 随机种子（可选）
  ///
  /// 返回多角色随机提示词结果
  ///
  /// 示例：
  /// ```dart
  /// final result = strategy.generateMultiCharacter(
  ///   wordlistService: wordlistService,
  ///   type: WordlistType.v4,
  ///   config: AlgorithmConfig(),
  ///   random: Random(42),
  ///   characterCount: 2,
  ///   seed: 42,
  /// );
  /// // result.mainPrompt: 主提示词
  /// // result.characters: 角色列表
  /// ```
  RandomPromptResult generateMultiCharacter({
    required WordlistService wordlistService,
    required WordlistType type,
    required AlgorithmConfig config,
    required Random random,
    required int characterCount,
    int? seed,
  }) {
    final characters = <GeneratedCharacter>[];
    final globalContext = <String, List<String>>{};

    for (var i = 0; i < characterCount; i++) {
      final gender = config.selectGender(() => random.nextInt(1 << 30));
      final charContext = <String, List<String>>{
        'gender': [gender],
      };

      final charTags = _generateCharacterTags(
        wordlistService: wordlistService,
        type: type,
        config: config,
        random: random,
        gender: gender,
        context: charContext,
      );

      // 应用强调概率
      final emphasizedTags = _bracketFormatter.applyEmphasis(
        charTags,
        probability: config.globalEmphasisProbability,
        bracketCount: config.globalEmphasisBracketCount,
        random: random,
      );

      characters.add(
        GeneratedCharacter(
          prompt: emphasizedTags.join(', '),
          gender: _genderFromString(gender),
        ),
      );

      // 合并到全局上下文
      charContext.forEach((key, value) {
        globalContext.putIfAbsent(key, () => []).addAll(value);
      });
    }

    // 生成主提示词
    final mainTags = <String>[];

    // 添加背景
    if (random.nextDouble() < 0.9) {
      final bg = _selectFromWordlist(
        wordlistService: wordlistService,
        type: type,
        variable: 'tk',
        category: 'background',
        random: random,
        context: globalContext,
      );
      if (bg != null) mainTags.add(bg);
    }

    // 添加场景
    if (random.nextDouble() < 0.5) {
      final scene = _selectFromWordlist(
        wordlistService: wordlistService,
        type: type,
        variable: 'tk',
        category: 'scene',
        random: random,
        context: globalContext,
      );
      if (scene != null) mainTags.add(scene);
    }

    return RandomPromptResult(
      mainPrompt: mainTags.join(', '),
      characters: characters,
      seed: seed,
    );
  }

  /// 从词库按变量和分类选择标签
  ///
  /// [wordlistService] 词库服务
  /// [type] 词库类型
  /// [variable] 变量名
  /// [category] 分类名
  /// [random] 随机数生成器
  /// [context] 上下文（用于 exclude/require 规则）
  ///
  /// 返回选中的标签，如果没有可用标签则返回 null
  String? _selectFromWordlist({
    required WordlistService wordlistService,
    required WordlistType type,
    required String variable,
    required String category,
    required Random random,
    Map<String, List<String>>? context,
  }) {
    final entries = wordlistService.getEntriesByVariableAndCategory(
      type,
      variable,
      category,
    );

    if (entries.isEmpty) return null;

    // 使用 select 方法进行选择（包含规则应用和加权随机选择）
    return select(
      entries: entries,
      random: random,
      context: context,
    );
  }

  /// 从词库生成角色标签
  ///
  /// [wordlistService] 词库服务
  /// [type] 词库类型
  /// [config] 算法配置
  /// [random] 随机数生成器
  /// [gender] 性别
  /// [context] 上下文（会被修改以记录已选标签）
  ///
  /// 返回角色标签列表
  List<String> _generateCharacterTags({
    required WordlistService wordlistService,
    required WordlistType type,
    required AlgorithmConfig config,
    required Random random,
    required String gender,
    required Map<String, List<String>> context,
  }) {
    final tags = <String>[];

    // 角色类别列表（按优先级）
    final categories = [
      'hair_color',
      'eye_color',
      'hair_style',
      'expression',
      'pose',
      'clothing',
      'accessory',
    ];

    for (final category in categories) {
      // 检查全局可见性
      if (!config.isCategoryGloballyVisible(category, context)) {
        continue;
      }

      // 根据类别概率决定是否生成
      final prob = _getCategoryProbability(category, config);
      if (random.nextDouble() >= prob) continue;

      final tag = _selectFromWordlist(
        wordlistService: wordlistService,
        type: type,
        variable: 'char',
        category: category,
        random: random,
        context: context,
      );

      if (tag != null) {
        tags.add(tag);
        context[category] = [tag];
      }
    }

    return tags;
  }

  /// 获取类别生成概率
  ///
  /// [category] 类别名称
  /// [config] 算法配置（保留参数以匹配原函数签名，供将来扩展使用）
  ///
  /// 返回生成概率 (0.0-1.0)
  double _getCategoryProbability(
    String category,
    AlgorithmConfig config,
  ) {
    // 注意: config 参数保留供将来支持自定义概率配置时使用
    // 当前使用默认概率分布
    return switch (category) {
      'hair_color' || 'eye_color' => 0.95,
      'hair_style' || 'expression' => 0.8,
      'pose' => 0.7,
      'clothing' => 0.9,
      'accessory' => 0.5,
      _ => 0.8,
    };
  }

  /// 从字符串转换性别枚举
  ///
  /// [gender] 性别字符串（如 'female', 'male', 'other'）
  ///
  /// 返回对应的 CharacterGender 枚举值
  CharacterGender _genderFromString(String gender) {
    switch (gender.toLowerCase()) {
      case 'female':
      case 'f':
      case 'girl':
      case '1girl':
        return CharacterGender.female;
      case 'male':
      case 'm':
      case 'boy':
      case '1boy':
        return CharacterGender.male;
      default:
        return CharacterGender.other;
    }
  }

  // ========== 传统模式和无人场景生成方法 ==========

  /// 生成无人物场景提示词
  ///
  /// [wordlistService] 词库服务
  /// [type] 词库类型
  /// [config] 算法配置
  /// [random] 随机数生成器
  /// [seed] 随机种子（可选）
  ///
  /// 返回无人物场景随机提示词结果
  ///
  /// 示例：
  /// ```dart
  /// final result = strategy.generateNoHuman(
  ///   wordlistService: wordlistService,
  ///   type: WordlistType.v4,
  ///   config: AlgorithmConfig(),
  ///   random: Random(42),
  ///   seed: 42,
  /// );
  /// // result.mainPrompt: "no humans, landscape, sunset..."
  /// ```
  RandomPromptResult generateNoHuman({
    required WordlistService wordlistService,
    required WordlistType type,
    required AlgorithmConfig config,
    required Random random,
    int? seed,
  }) {
    final tags = <String>['no humans'];
    final context = <String, List<String>>{};

    // 添加场景
    final scene = _selectFromWordlist(
      wordlistService: wordlistService,
      type: type,
      variable: 'tk',
      category: 'scene',
      random: random,
    );
    if (scene != null) {
      tags.add(scene);
      context['scene'] = [scene];
    }

    // 添加背景 (90%)
    if (random.nextDouble() < 0.9) {
      final bg = _selectFromWordlist(
        wordlistService: wordlistService,
        type: type,
        variable: 'tk',
        category: 'background',
        random: random,
        context: context,
      );
      if (bg != null) {
        tags.add(bg);
        context['background'] = [bg];
      }
    }

    // 添加风格 (50%)
    if (random.nextDouble() < 0.5) {
      final style = _selectFromWordlist(
        wordlistService: wordlistService,
        type: type,
        variable: 'tk',
        category: 'style',
        random: random,
        context: context,
      );
      if (style != null) {
        tags.add(style);
        context['style'] = [style];
      }
    }

    // 应用全局后处理规则
    final processedTags = config.applyGlobalPostProcessRules(tags, context);

    return RandomPromptResult.noHuman(
      prompt: processedTags.join(', '),
      seed: seed,
    );
  }

  /// 生成传统单提示词（用于非 V4 模型）
  ///
  /// [wordlistService] 词库服务
  /// [type] 词库类型
  /// [config] 算法配置
  /// [random] 随机数生成器
  /// [characterCount] 角色数量
  /// [seed] 随机种子（可选）
  ///
  /// 返回传统单提示词结果（所有标签合并到一个提示词中）
  ///
  /// 示例：
  /// ```dart
  /// final result = strategy.generateLegacy(
  ///   wordlistService: wordlistService,
  ///   type: WordlistType.v4,
  ///   config: AlgorithmConfig(),
  ///   random: Random(42),
  ///   characterCount: 1,
  ///   seed: 42,
  /// );
  /// // result.mainPrompt: "solo, 1girl, blonde hair..."
  /// ```
  RandomPromptResult generateLegacy({
    required WordlistService wordlistService,
    required WordlistType type,
    required AlgorithmConfig config,
    required Random random,
    required int characterCount,
    int? seed,
  }) {
    final tags = <String>[];
    final context = <String, List<String>>{};

    // 添加人数标签
    tags.add(_getCountTag(characterCount));

    // 决定性别
    final gender = config.selectGender(() => random.nextInt(1 << 30));
    context['gender'] = [gender];

    // 生成角色标签
    final charTags = _generateCharacterTags(
      wordlistService: wordlistService,
      type: type,
      config: config,
      random: random,
      gender: gender,
      context: context,
    );
    tags.addAll(charTags);

    // 添加背景
    if (random.nextDouble() < 0.9) {
      final bg = _selectFromWordlist(
        wordlistService: wordlistService,
        type: type,
        variable: 'tk',
        category: 'background',
        random: random,
        context: context,
      );
      if (bg != null) {
        tags.add(bg);
        context['background'] = [bg];
      }
    }

    // 应用全局后处理规则
    final processedTags = config.applyGlobalPostProcessRules(tags, context);

    return RandomPromptResult(
      mainPrompt: processedTags.join(', '),
      seed: seed,
    );
  }

  /// 获取人数标签
  ///
  /// [count] 角色数量
  ///
  /// 返回对应的人数标签
  ///
  /// 注意: "duo" 和 "trio" 是 Danbooru 已废弃的标签，不应使用
  /// 参考: https://danbooru.donmai.us/wiki_pages/duo
  /// NAI 官网使用具体的角色组合标签如 2girls, 1girl 1boy 等
  String _getCountTag(int count) {
    return switch (count) {
      1 => 'solo',
      2 => '2girls',
      3 => 'multiple girls',
      _ => 'group',
    };
  }
}
