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
import '../models/prompt/wordlist_entry.dart';
import 'bracket_formatter.dart';
import 'character_count_resolver.dart';
import 'sequential_state_service.dart';
import 'strategies/character_tag_generator.dart';
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
  final CharacterTagGenerator _characterTagGenerator;
  final NaiStyleGeneratorStrategy _naiStyleGenerator;
  final PresetGeneratorStrategy _presetGeneratorStrategy;
  final WordlistGeneratorStrategy _wordlistGeneratorStrategy;

  RandomPromptGenerator(
    this._libraryService,
    this._sequentialService,
    this._tagGroupCacheService,
    this._poolCacheService, [
    this._wordlistService,
  ]) : _weightedSelector = WeightedSelector(),
       _bracketFormatter = BracketFormatter(),
       _characterCountResolver = CharacterCountResolver(),
       _variableReplacementService = VariableReplacementService(),
       _characterTagGenerator = CharacterTagGenerator(),
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

  /// 生成无人物场景提示词
  RandomPromptResult _generateNoHumanPrompt(
    TagLibrary library,
    Random random,
    int? seed,
    CategoryFilterConfig filterConfig,
  ) {
    final tags = <String>['no humans'];

    // 添加场景（必选）
    final sceneTags =
        _getFilteredCategory(library, TagSubCategory.scene, filterConfig);
    if (sceneTags.isNotEmpty) {
      tags.add(getWeightedChoice(sceneTags, random: random));
    }

    // 添加背景（90%）
    if (random.nextDouble() < 0.9) {
      final bgTags = _getFilteredCategory(
        library,
        TagSubCategory.background,
        filterConfig,
      );
      if (bgTags.isNotEmpty) {
        tags.add(getWeightedChoice(bgTags, random: random));
      }
    }

    // 添加风格（50%）
    if (random.nextDouble() < 0.5) {
      final styleTags =
          _getFilteredCategory(library, TagSubCategory.style, filterConfig);
      if (styleTags.isNotEmpty) {
        tags.add(getWeightedChoice(styleTags, random: random));
      }
    }

    // 额外添加1-3个场景元素（50%）
    if (random.nextDouble() < 0.5) {
      final sceneTagsExtra =
          _getFilteredCategory(library, TagSubCategory.scene, filterConfig);
      if (sceneTagsExtra.length > 1) {
        final count = random.nextInt(3) + 1;
        final selected = <String>{};
        for (var i = 0;
            i < count && selected.length < sceneTagsExtra.length;
            i++) {
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
    final charTags = _generateCharacterTags(
      library,
      random,
      CharacterGender.female,
      filterConfig,
    );
    tags.addAll(charTags);

    // 添加背景
    if (random.nextDouble() < 0.9) {
      final bgTags = _getFilteredCategory(
        library,
        TagSubCategory.background,
        filterConfig,
      );
      if (bgTags.isNotEmpty) {
        tags.add(getWeightedChoice(bgTags, random: random));
      }
    }

    // 添加场景
    if (random.nextDouble() < 0.5) {
      final sceneTags =
          _getFilteredCategory(library, TagSubCategory.scene, filterConfig);
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
  ///
  /// [characterCountConfig] 可选的人数类别配置，如果为空则使用默认逻辑
  RandomPromptResult _generateMultiCharacterPrompt(
    TagLibrary library,
    Random random,
    int characterCount,
    int? seed,
    CategoryFilterConfig filterConfig, {
    CharacterCountConfig? characterCountConfig,
  }) {
    // 根据角色数量生成角色列表
    final characters = <GeneratedCharacter>[];
    final genders = <CharacterGender>[];

    // 如果有配置，尝试从配置中获取匹配的类别和标签选项
    CharacterTagOption? selectedTagOption;
    if (characterCountConfig != null) {
      // 查找匹配人数的类别
      final matchingCategory = characterCountConfig.categories
          .where((c) => c.count == characterCount && c.enabled && c.weight > 0)
          .toList();

      if (matchingCategory.isNotEmpty) {
        // 按权重选择一个类别
        final category = _selectWeightedCategory(matchingCategory, random);
        // 从类别中按权重选择一个标签选项
        final enabledOptions = category.enabledTagOptions;
        if (enabledOptions.isNotEmpty) {
          selectedTagOption = _selectWeightedTagOption(enabledOptions, random);
        }
      }
    }

    // 根据选中的标签选项或默认逻辑生成角色
    for (var i = 0; i < characterCount; i++) {
      CharacterGender gender;
      String genderTag;

      if (selectedTagOption != null && i < selectedTagOption.slotTags.length) {
        // 使用配置中的槽位标签
        genderTag = selectedTagOption.slotTags[i].characterTag;
        gender = genderTag.contains('girl')
            ? CharacterGender.female
            : CharacterGender.male;
      } else {
        // 默认逻辑：随机分配性别
        gender =
            random.nextBool() ? CharacterGender.female : CharacterGender.male;
        genderTag = gender == CharacterGender.female ? '1girl' : '1boy';
      }

      genders.add(gender);
      final charTags =
          _generateCharacterTags(library, random, gender, filterConfig);

      // 添加人物标签到开头
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

    // 使用配置中的主提示词标签，或根据性别组合生成
    if (selectedTagOption != null &&
        selectedTagOption.mainPromptTags.isNotEmpty) {
      mainTags.add(selectedTagOption.mainPromptTags);
    } else {
      mainTags.add(_getCountTagForCharacters(genders));
    }

    // 添加风格（30%）
    if (random.nextDouble() < 0.3) {
      final styleTags =
          _getFilteredCategory(library, TagSubCategory.style, filterConfig);
      if (styleTags.isNotEmpty) {
        mainTags.add(getWeightedChoice(styleTags, random: random));
      }
    }

    // 添加背景（90%）
    if (random.nextDouble() < 0.9) {
      final bgTags = _getFilteredCategory(
        library,
        TagSubCategory.background,
        filterConfig,
      );
      if (bgTags.isNotEmpty) {
        final bg = getWeightedChoice(bgTags, random: random);
        mainTags.add(bg);

        // 如果是详细背景，添加额外场景元素
        if (bg.contains('detailed') || bg.contains('amazing')) {
          final sceneTags =
              _getFilteredCategory(library, TagSubCategory.scene, filterConfig);
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

  /// 按权重选择人数类别
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

  /// 生成单个角色的特征标签
  List<String> _generateCharacterTags(
    TagLibrary library,
    Random random,
    CharacterGender gender,
    CategoryFilterConfig filterConfig,
  ) {
    // 准备类别标签映射
    final categoryTags = <TagSubCategory, List<WeightedTag>>{};

    // 发色
    final hairColors =
        _getFilteredCategory(library, TagSubCategory.hairColor, filterConfig);
    if (hairColors.isNotEmpty) {
      categoryTags[TagSubCategory.hairColor] = hairColors;
    }

    // 瞳色
    final eyeColors =
        _getFilteredCategory(library, TagSubCategory.eyeColor, filterConfig);
    if (eyeColors.isNotEmpty) {
      categoryTags[TagSubCategory.eyeColor] = eyeColors;
    }

    // 发型
    final hairStyles =
        _getFilteredCategory(library, TagSubCategory.hairStyle, filterConfig);
    if (hairStyles.isNotEmpty) {
      categoryTags[TagSubCategory.hairStyle] = hairStyles;
    }

    // 表情
    final expressions = _getFilteredCategory(
      library,
      TagSubCategory.expression,
      filterConfig,
    );
    if (expressions.isNotEmpty) {
      categoryTags[TagSubCategory.expression] = expressions;
    }

    // 姿势
    final poses =
        _getFilteredCategory(library, TagSubCategory.pose, filterConfig);
    if (poses.isNotEmpty) {
      categoryTags[TagSubCategory.pose] = poses;
    }

    // 使用 CharacterTagGenerator 生成标签
    return _characterTagGenerator.generate(
      categoryTags: categoryTags,
      random: random,
    );
  }

  /// 获取人数标签
  ///
  /// 注意: "duo" 和 "trio" 是 Danbooru 已废弃的标签，不应使用
  /// 参考: https://danbooru.donmai.us/wiki_pages/duo
  /// NAI 官网使用具体的角色组合标签如 2girls, 1girl 1boy 等
  String _getCountTag(int count) {
    return switch (count) {
      1 => 'solo',
      2 => '2girls', // 默认使用 2girls，V4模式会根据实际性别生成
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

    // 2. 按权重选择人数类别和标签选项
    final (category, tagOption) = _selectCharacterCountAndOption(
      characterCountConfig,
      random,
    );

    AppLogger.d(
      'Selected character count: ${category.count} (${category.label}), '
          'tag: ${tagOption?.mainPromptTags ?? "none"}',
      'RandomGen',
    );

    // 3. 根据人数分支处理
    if (category.count == 0) {
      // 无人场景
      return _generateNoHumanFromPreset(preset, random, seed, tagOption);
    }

    if (!isV4Model) {
      // 非 V4 模型：传统单提示词模式
      return _generateLegacyFromPreset(preset, random, seed, tagOption);
    }

    // V4+ 模型：多角色模式
    return _generateMultiCharacterFromPreset(preset, random, seed, tagOption);
  }

  /// 选择人数类别和标签选项
  (CharacterCountCategory, CharacterTagOption?) _selectCharacterCountAndOption(
    CharacterCountConfig config,
    Random random,
  ) {
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

  /// 从预设生成多角色结果（V4+ 模型）
  Future<RandomPromptResult> _generateMultiCharacterFromPreset(
    RandomPreset preset,
    Random random,
    int? seed,
    CharacterTagOption? tagOption,
  ) async {
    final mainTags = <String>[];
    final characters = <GeneratedCharacter>[];

    // 1. 添加人数标签到主提示词（如 "solo", "2girls"）
    if (tagOption != null && tagOption.mainPromptTags.isNotEmpty) {
      mainTags.add(tagOption.mainPromptTags);
    }

    // 2. 生成全局标签（scope: global 或 all）
    final globalTags = await _generateFromPresetCategories(
      preset,
      random,
      targetScope: TagScope.global,
    );
    mainTags.addAll(globalTags);

    // 3. 为每个角色槽位生成角色提示词
    AppLogger.d(
      'Generating characters: tagOption=${tagOption?.label}, slotTags=${tagOption?.slotTags.length ?? 0}',
      'RandomGen',
    );
    if (tagOption != null && tagOption.slotTags.isNotEmpty) {
      for (final slotTag in tagOption.slotTags) {
        final charTags = <String>[];

        // 确定性别标签（如 "1girl" 或 "1boy"）
        final genderTag = _getGenderTag(slotTag.characterTag);
        charTags.add(genderTag);

        // 生成角色特征标签（scope: character，按性别过滤）
        final characterFeatures = await _generateFromPresetCategories(
          preset,
          random,
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
      final charTags = await _generateFromPresetCategories(
        preset,
        random,
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
      seed: seed,
    );
  }

  /// 从预设生成传统单提示词结果（非 V4 模型）
  Future<RandomPromptResult> _generateLegacyFromPreset(
    RandomPreset preset,
    Random random,
    int? seed,
    CharacterTagOption? tagOption,
  ) async {
    final allTags = <String>[];

    // 添加人数标签
    if (tagOption != null && tagOption.mainPromptTags.isNotEmpty) {
      allTags.add(tagOption.mainPromptTags);
    }

    // 添加性别标签
    if (tagOption != null && tagOption.slotTags.isNotEmpty) {
      for (final slotTag in tagOption.slotTags) {
        allTags.add(_getGenderTag(slotTag.characterTag));
      }
    }

    // 生成所有类别的标签（不区分 scope）
    final tags = await _generateFromPresetCategories(preset, random);
    allTags.addAll(tags);

    return RandomPromptResult(
      mainPrompt: allTags.join(', '),
      mode: RandomGenerationMode.naiOfficial,
      seed: seed,
    );
  }

  /// 从预设生成无人场景结果
  Future<RandomPromptResult> _generateNoHumanFromPreset(
    RandomPreset preset,
    Random random,
    int? seed,
    CharacterTagOption? tagOption,
  ) async {
    final mainTags = <String>[];

    // 添加 "no humans" 标签
    if (tagOption != null && tagOption.mainPromptTags.isNotEmpty) {
      mainTags.add(tagOption.mainPromptTags);
    } else {
      mainTags.add('no humans');
    }

    // 仅生成全局标签（背景、场景、风格等）
    final globalTags = await _generateFromPresetCategories(
      preset,
      random,
      targetScope: TagScope.global,
    );
    mainTags.addAll(globalTags);

    return RandomPromptResult(
      mainPrompt: mainTags.join(', '),
      noHumans: true,
      mode: RandomGenerationMode.naiOfficial,
      seed: seed,
    );
  }

  /// 根据槽位标签获取性别标签
  ///
  /// 例如: "girl" -> "1girl", "boy" -> "1boy"
  String _getGenderTag(String slotTag) {
    // 如果已经包含数字前缀，直接返回
    if (RegExp(r'^\d').hasMatch(slotTag)) {
      return slotTag;
    }
    // 添加 "1" 前缀
    return '1$slotTag';
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

    // 决定角色数量
    final characterCount = _determineCharacterCountFromConfig(config, random);

    AppLogger.d('Character count: $characterCount', 'RandomGen');

    if (characterCount == 0) {
      return _generateNoHumanFromWordlist(wordlistType, config, random, seed);
    }

    if (!config.isV4Model) {
      return _generateLegacyFromWordlist(
        wordlistType,
        config,
        random,
        characterCount,
        seed,
      );
    }

    return _generateMultiCharacterFromWordlist(
      wordlistType,
      config,
      random,
      characterCount,
      seed,
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

  /// 从配置决定角色数量
  int _determineCharacterCountFromConfig(
    AlgorithmConfig config,
    Random random,
  ) {
    final weights = config.characterCountWeights;
    if (weights.isEmpty) {
      return _characterCountResolver.determineCharacterCount(random: random);
    }

    return _characterCountResolver.determineCharacterCountFromWeights(
      weights,
      random: random,
    );
  }

  /// 从词库按变量和分类选择标签
  String? _selectFromWordlist(
    WordlistType type,
    String variable,
    String category,
    Random random, {
    Map<String, List<String>>? context,
  }) {
    final entries = _wordlistService!.getEntriesByVariableAndCategory(
      type,
      variable,
      category,
    );

    if (entries.isEmpty) return null;

    // 使用 WordlistGeneratorStrategy 进行选择（包含规则应用和加权随机选择）
    return _wordlistGeneratorStrategy.select(
      entries: entries,
      random: random,
      context: context,
    );
  }

  /// 应用词库条目的 exclude/require 规则
  List<WordlistEntry> _applyWordlistRules(
    List<WordlistEntry> entries,
    Map<String, List<String>>? context,
  ) {
    if (context == null || context.isEmpty) return entries;

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

  /// 从词库生成无人物场景
  RandomPromptResult _generateNoHumanFromWordlist(
    WordlistType type,
    AlgorithmConfig config,
    Random random,
    int? seed,
  ) {
    final tags = <String>['no humans'];
    final context = <String, List<String>>{};

    // 添加场景
    final scene = _selectFromWordlist(type, 'tk', 'scene', random);
    if (scene != null) {
      tags.add(scene);
      context['scene'] = [scene];
    }

    // 添加背景 (90%)
    if (random.nextDouble() < 0.9) {
      final bg = _selectFromWordlist(
        type,
        'tk',
        'background',
        random,
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
        type,
        'tk',
        'style',
        random,
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

  /// 从词库生成传统单提示词
  RandomPromptResult _generateLegacyFromWordlist(
    WordlistType type,
    AlgorithmConfig config,
    Random random,
    int characterCount,
    int? seed,
  ) {
    final tags = <String>[];
    final context = <String, List<String>>{};

    // 添加人数标签
    tags.add(_getCountTag(characterCount));

    // 决定性别
    final gender = config.selectGender(() => random.nextInt(1 << 30));
    context['gender'] = [gender];

    // 生成角色标签
    final charTags = _generateCharacterTagsFromWordlist(
      type,
      config,
      random,
      gender,
      context,
    );
    tags.addAll(charTags);

    // 添加背景
    if (random.nextDouble() < 0.9) {
      final bg = _selectFromWordlist(
        type,
        'tk',
        'background',
        random,
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

  /// 从词库生成多角色提示词
  RandomPromptResult _generateMultiCharacterFromWordlist(
    WordlistType type,
    AlgorithmConfig config,
    Random random,
    int characterCount,
    int? seed,
  ) {
    final characters = <GeneratedCharacter>[];
    final globalContext = <String, List<String>>{};

    for (var i = 0; i < characterCount; i++) {
      final gender = config.selectGender(() => random.nextInt(1 << 30));
      final charContext = <String, List<String>>{
        'gender': [gender],
      };

      final charTags = _generateCharacterTagsFromWordlist(
        type,
        config,
        random,
        gender,
        charContext,
      );

      // 应用强调概率
      final emphasizedTags = _applyEmphasis(
        charTags,
        config.globalEmphasisProbability,
        config.globalEmphasisBracketCount,
        random,
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
        type,
        'tk',
        'background',
        random,
        context: globalContext,
      );
      if (bg != null) mainTags.add(bg);
    }

    // 添加场景
    if (random.nextDouble() < 0.5) {
      final scene = _selectFromWordlist(
        type,
        'tk',
        'scene',
        random,
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

  /// 从词库生成角色标签
  List<String> _generateCharacterTagsFromWordlist(
    WordlistType type,
    AlgorithmConfig config,
    Random random,
    String gender,
    Map<String, List<String>> context,
  ) {
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
        type,
        'char',
        category,
        random,
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
  double _getCategoryProbability(String category, AlgorithmConfig config) {
    // 可以从 config.categoryProbabilities 获取，这里使用默认值
    switch (category) {
      case 'hair_color':
      case 'eye_color':
        return 0.95;
      case 'hair_style':
      case 'expression':
        return 0.8;
      case 'pose':
        return 0.7;
      case 'clothing':
        return 0.9;
      case 'accessory':
        return 0.5;
      default:
        return 0.8;
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
