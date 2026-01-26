import 'dart:math';

import '../../models/character/character_prompt.dart';
import '../../models/prompt/category_filter_config.dart';
import '../../models/prompt/random_prompt_result.dart';
import '../../models/prompt/tag_category.dart';
import '../../models/prompt/tag_library.dart';
import '../../models/prompt/weighted_tag.dart';
import '../character_count_resolver.dart';
import '../strategies/character_tag_generator.dart';
import '../weighted_selector.dart';

/// NAI 风格生成策略
///
/// 负责使用 TagLibrary 生成 NAI 官网风格的随机提示词。
/// 支持多角色（V4+模式）和单角色（传统模式）生成。
/// 从 RandomPromptGenerator.generateNaiStyle 提取。
///
/// ## 主要功能
///
/// - 复刻 NAI 官网的随机提示词生成逻辑
/// - 支持三种生成模式：无人场景、单角色、多角色
/// - 使用 NAI 官网的角色数量权重分布
/// - 自动生成人数标签（solo, 2girls, 1girl, 1boy 等）
/// - 支持分类级 Danbooru 补充标签
///
/// ## 生成模式
///
/// **无人场景** (5% 概率):
/// - 添加 "no humans" 标签
/// - 必选：场景标签
/// - 90%：背景标签
/// - 50%：风格标签
/// - 50%：额外 1-3 个场景元素
///
/// **单角色** (70% 概率):
/// - 添加 "solo" 标签
/// - 生成单个角色的特征标签
/// - V4+ 模式：分离的主提示词和角色提示词
/// - 传统模式：合并为单个提示词
///
/// **多角色** (25% 概率，2人20% + 3人7%):
/// - 生成对应人数标签（2girls, 2boys, 1girl, 1boy 等）
/// - 为每个角色生成独立特征
/// - 支持混合性别组合
///
/// ## 角色数量权重
///
/// 使用 NAI 官网分布：
/// - 1 人: 70%
/// - 2 人: 20%
/// - 3 人: 7%
/// - 无人: 5%
///
/// ## 使用示例
///
/// ```dart
/// final strategy = NaiStyleGeneratorStrategy();
/// final library = await _libraryService.getAvailableLibrary();
/// final result = await strategy.generate(
///   library: library,
///   random: Random(42),
///   filterConfig: CategoryFilterConfig(),
/// );
///
/// // V4+ 模式：返回主提示词 + 角色提示词
/// print(result.mainPrompt);
/// print(result.characters);
/// ```
class NaiStyleGeneratorStrategy {
  /// 加权选择器
  final WeightedSelector _weightedSelector;

  /// 角色数量解析器
  final CharacterCountResolver _countResolver;

  /// 角色标签生成器
  final CharacterTagGenerator _characterTagGenerator;

  /// 角色数量权重分布（来自 NAI 官网）
  /// [[1,70], [2,20], [3,7], [0,5]]
  static const List<List<int>> characterCountWeights = [
    [1, 70], // 1人 70%
    [2, 20], // 2人 20%
    [3, 7], // 3人 7%
    [0, 5], // 无人 5%
  ];

  /// 创建 NAI 风格生成策略
  ///
  /// [weightedSelector] 加权选择器（可选，默认创建新实例）
  /// [countResolver] 角色数量解析器（可选，默认创建新实例）
  /// [characterTagGenerator] 角色标签生成器（可选，默认创建新实例）
  NaiStyleGeneratorStrategy({
    WeightedSelector? weightedSelector,
    CharacterCountResolver? countResolver,
    CharacterTagGenerator? characterTagGenerator,
  })  : _weightedSelector = weightedSelector ?? WeightedSelector(),
        _countResolver = countResolver ?? CharacterCountResolver(),
        _characterTagGenerator = characterTagGenerator ?? CharacterTagGenerator();

  /// 生成 NAI 风格随机提示词
  ///
  /// [library] 标签词库
  /// [random] 随机数生成器
  /// [filterConfig] 分类级 Danbooru 补充配置
  /// [seed] 随机种子（可选，用于结果追踪）
  /// [isV4Model] 是否为 V4+ 模型（支持多角色，默认 true）
  ///
  /// 返回生成的提示词结果
  ///
  /// 示例：
  /// ```dart
  /// final strategy = NaiStyleGeneratorStrategy();
  /// final library = await _libraryService.getAvailableLibrary();
  /// final result = await strategy.generate(
  ///   library: library,
  ///   random: Random(42),
  ///   filterConfig: CategoryFilterConfig(),
  /// );
  /// ```
  Future<RandomPromptResult> generate({
    required TagLibrary library,
    required Random random,
    required CategoryFilterConfig filterConfig,
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
      return _generateNoHumanPrompt(
        library,
        random,
        filterConfig,
        seed,
      );
    }

    if (!isV4Model) {
      // 传统模式：生成合并的单提示词
      return _generateLegacyPrompt(
        library,
        random,
        characterCount,
        filterConfig,
        seed,
      );
    }

    // V4+ 模式：生成主提示词 + 角色提示词
    return _generateMultiCharacterPrompt(
      library,
      random,
      characterCount,
      filterConfig,
      seed,
    );
  }

  /// 生成无人物场景提示词
  RandomPromptResult _generateNoHumanPrompt(
    TagLibrary library,
    Random random,
    CategoryFilterConfig filterConfig,
    int? seed,
  ) {
    final tags = <String>['no humans'];

    // 添加场景（必选）
    final sceneTags = _getFilteredCategory(
      library,
      TagSubCategory.scene,
      filterConfig,
    );
    if (sceneTags.isNotEmpty) {
      tags.add(_weightedSelector.select(sceneTags, random: random));
    }

    // 添加背景（90%）
    if (random.nextDouble() < 0.9) {
      final bgTags = _getFilteredCategory(
        library,
        TagSubCategory.background,
        filterConfig,
      );
      if (bgTags.isNotEmpty) {
        tags.add(_weightedSelector.select(bgTags, random: random));
      }
    }

    // 添加风格（50%）
    if (random.nextDouble() < 0.5) {
      final styleTags = _getFilteredCategory(
        library,
        TagSubCategory.style,
        filterConfig,
      );
      if (styleTags.isNotEmpty) {
        tags.add(_weightedSelector.select(styleTags, random: random));
      }
    }

    // 额外添加1-3个场景元素（50%）
    if (random.nextDouble() < 0.5) {
      final sceneTagsExtra = _getFilteredCategory(
        library,
        TagSubCategory.scene,
        filterConfig,
      );
      if (sceneTagsExtra.length > 1) {
        final count = random.nextInt(3) + 1;
        final selected = <String>{};
        for (var i = 0; i < count && selected.length < sceneTagsExtra.length; i++) {
          final tag = _weightedSelector.select(sceneTagsExtra, random: random);
          if (!tags.contains(tag)) {
            selected.add(tag);
          }
        }
        tags.addAll(selected);
      }
    }

    return RandomPromptResult(
      mainPrompt: tags.join(', '),
      noHumans: true,
      seed: seed,
      mode: RandomGenerationMode.naiOfficial,
    );
  }

  /// 生成传统模式提示词（合并为单提示词）
  RandomPromptResult _generateLegacyPrompt(
    TagLibrary library,
    Random random,
    int characterCount,
    CategoryFilterConfig filterConfig,
    int? seed,
  ) {
    // 生成角色列表
    final characters = <GeneratedCharacter>[];
    final genders = <CharacterGender>[];

    for (var i = 0; i < characterCount; i++) {
      // 随机分配性别
      final gender =
          random.nextBool() ? CharacterGender.female : CharacterGender.male;
      final genderTag = gender == CharacterGender.female ? '1girl' : '1boy';

      genders.add(gender);

      // 生成角色标签
      final charTags = _generateCharacterTags(
        library,
        random,
        gender,
        filterConfig,
      );

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
    final mainTags = <String>[
      _countResolver.getCountTag(genders),
    ];

    // 添加风格（30%）
    if (random.nextDouble() < 0.3) {
      final styleTags = _getFilteredCategory(
        library,
        TagSubCategory.style,
        filterConfig,
      );
      if (styleTags.isNotEmpty) {
        mainTags.add(_weightedSelector.select(styleTags, random: random));
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
        final bg = _weightedSelector.select(bgTags, random: random);
        mainTags.add(bg);

        // 如果是详细背景，添加额外场景元素
        if (bg.contains('detailed') || bg.contains('amazing')) {
          final sceneTags = _getFilteredCategory(
            library,
            TagSubCategory.scene,
            filterConfig,
          );
          if (sceneTags.isNotEmpty) {
            final count = random.nextInt(2) + 1;
            for (var i = 0; i < count; i++) {
              mainTags.add(_weightedSelector.select(sceneTags, random: random));
            }
          }
        }
      }
    }

    // 合并所有标签为单提示词
    final allTags = [
      ...mainTags,
      ...characters.map((c) => c.prompt),
    ];

    return RandomPromptResult(
      mainPrompt: allTags.join(', '),
      characters: characters,
      seed: seed,
      mode: RandomGenerationMode.naiOfficial,
    );
  }

  /// 生成多角色提示词（V4+ 模式）
  RandomPromptResult _generateMultiCharacterPrompt(
    TagLibrary library,
    Random random,
    int characterCount,
    CategoryFilterConfig filterConfig,
    int? seed,
  ) {
    // 生成角色列表
    final characters = <GeneratedCharacter>[];
    final genders = <CharacterGender>[];

    for (var i = 0; i < characterCount; i++) {
      // 随机分配性别
      final gender =
          random.nextBool() ? CharacterGender.female : CharacterGender.male;
      final genderTag = gender == CharacterGender.female ? '1girl' : '1boy';

      genders.add(gender);

      // 生成角色标签
      final charTags = _generateCharacterTags(
        library,
        random,
        gender,
        filterConfig,
      );

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
    final mainTags = <String>[
      _countResolver.getCountTag(genders),
    ];

    // 添加风格（30%）
    if (random.nextDouble() < 0.3) {
      final styleTags = _getFilteredCategory(
        library,
        TagSubCategory.style,
        filterConfig,
      );
      if (styleTags.isNotEmpty) {
        mainTags.add(_weightedSelector.select(styleTags, random: random));
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
        final bg = _weightedSelector.select(bgTags, random: random);
        mainTags.add(bg);

        // 如果是详细背景，添加额外场景元素
        if (bg.contains('detailed') || bg.contains('amazing')) {
          final sceneTags = _getFilteredCategory(
            library,
            TagSubCategory.scene,
            filterConfig,
          );
          if (sceneTags.isNotEmpty) {
            final count = random.nextInt(2) + 1;
            for (var i = 0; i < count; i++) {
              mainTags.add(_weightedSelector.select(sceneTags, random: random));
            }
          }
        }
      }
    }

    return RandomPromptResult(
      mainPrompt: mainTags.join(', '),
      characters: characters,
      seed: seed,
      mode: RandomGenerationMode.naiOfficial,
    );
  }

  /// 生成单个角色的特征标签
  ///
  /// 使用 CharacterTagGenerator 生成角色特征标签
  List<String> _generateCharacterTags(
    TagLibrary library,
    Random random,
    CharacterGender gender,
    CategoryFilterConfig filterConfig,
  ) {
    // 准备类别标签映射
    final categoryTags = <TagSubCategory, List<WeightedTag>>{};

    // 发色
    final hairColors = _getFilteredCategory(
      library,
      TagSubCategory.hairColor,
      filterConfig,
    );
    if (hairColors.isNotEmpty) {
      categoryTags[TagSubCategory.hairColor] = hairColors;
    }

    // 瞳色
    final eyeColors = _getFilteredCategory(
      library,
      TagSubCategory.eyeColor,
      filterConfig,
    );
    if (eyeColors.isNotEmpty) {
      categoryTags[TagSubCategory.eyeColor] = eyeColors;
    }

    // 发型
    final hairStyles = _getFilteredCategory(
      library,
      TagSubCategory.hairStyle,
      filterConfig,
    );
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
    final poses = _getFilteredCategory(
      library,
      TagSubCategory.pose,
      filterConfig,
    );
    if (poses.isNotEmpty) {
      categoryTags[TagSubCategory.pose] = poses;
    }

    // 使用 CharacterTagGenerator 生成标签
    return _characterTagGenerator.generate(
      categoryTags: categoryTags,
      random: random,
    );
  }

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
}
