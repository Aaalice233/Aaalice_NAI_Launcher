import 'dart:math';

import '../../models/character/character_prompt.dart';
import '../../models/prompt/tag_category.dart';
import '../../models/prompt/weighted_tag.dart';
import '../bracket_formatter.dart';
import '../weighted_selector.dart';

/// 角色标签生成策略
///
/// 负责生成单个角色的特征标签，包括：
/// - 发色 (hair_color)
/// - 瞳色 (eye_color)
/// - 发型 (hair_style)
/// - 表情 (expression)
/// - 姿势 (pose)
///
/// 使用策略模式，支持不同的生成概率和权重配置。
/// 从 RandomPromptGenerator._generateCharacterTags 提取。
class CharacterTagGenerator {
  /// 加权选择器
  final WeightedSelector _weightedSelector;

  /// 括号格式化器
  final BracketFormatter _bracketFormatter;

  /// 类别概率配置（类别名 -> 生成概率 0.0-1.0）
  final Map<String, double> _categoryProbabilities;

  /// 创建角色标签生成器
  ///
  /// [weightedSelector] 加权选择器（可选，默认创建新实例）
  /// [bracketFormatter] 括号格式化器（可选，默认创建新实例）
  /// [categoryProbabilities] 类别概率配置（可选，使用默认值）
  CharacterTagGenerator({
    WeightedSelector? weightedSelector,
    BracketFormatter? bracketFormatter,
    Map<String, double>? categoryProbabilities,
  })  : _weightedSelector = weightedSelector ?? WeightedSelector(),
        _bracketFormatter = bracketFormatter ?? BracketFormatter(),
        _categoryProbabilities = categoryProbabilities ??
            {
              TagSubCategory.hairColor.name: 0.8,
              TagSubCategory.eyeColor.name: 0.8,
              TagSubCategory.hairStyle.name: 0.5,
              TagSubCategory.expression.name: 0.6,
              TagSubCategory.pose.name: 0.5,
            };

  /// 生成角色标签
  ///
  /// [categoryTags] 各类别的标签映射（类别名 -> 标签列表）
  /// [random] 随机数生成器
  /// [applyBrackets] 是否应用权重括号（默认 false）
  /// [bracketMin] 括号最小层数（默认 0）
  /// [bracketMax] 括号最大层数（默认 0）
  ///
  /// 返回角色特征标签列表
  ///
  /// 示例：
  /// ```dart
  /// final generator = CharacterTagGenerator();
  /// final categoryTags = {
  ///   'hairColor': [WeightedTag.simple('blonde hair', 10)],
  ///   'eyeColor': [WeightedTag.simple('blue eyes', 9)],
  /// };
  /// final tags = generator.generate(
  ///   categoryTags: categoryTags,
  ///   random: Random(42),
  /// );
  /// // ['blonde hair', 'blue eyes']
  /// ```
  List<String> generate({
    required Map<TagSubCategory, List<WeightedTag>> categoryTags,
    required Random random,
    bool applyBrackets = false,
    int bracketMin = 0,
    int bracketMax = 0,
  }) {
    final tags = <String>[];

    // 发色（默认 80%）
    if (_shouldGenerateCategory(TagSubCategory.hairColor.name, random)) {
      final hairColors = categoryTags[TagSubCategory.hairColor] ?? [];
      if (hairColors.isNotEmpty) {
        final tag = _weightedSelector.select(hairColors, random: random);
        final formattedTag = applyBrackets
            ? _bracketFormatter.applyBrackets(
                tag,
                bracketMin,
                bracketMax,
                random: random,
              )
            : tag;
        tags.add(formattedTag);
      }
    }

    // 瞳色（默认 80%）
    if (_shouldGenerateCategory(TagSubCategory.eyeColor.name, random)) {
      final eyeColors = categoryTags[TagSubCategory.eyeColor] ?? [];
      if (eyeColors.isNotEmpty) {
        final tag = _weightedSelector.select(eyeColors, random: random);
        final formattedTag = applyBrackets
            ? _bracketFormatter.applyBrackets(
                tag,
                bracketMin,
                bracketMax,
                random: random,
              )
            : tag;
        tags.add(formattedTag);
      }
    }

    // 发型（默认 50%）
    if (_shouldGenerateCategory(TagSubCategory.hairStyle.name, random)) {
      final hairStyles = categoryTags[TagSubCategory.hairStyle] ?? [];
      if (hairStyles.isNotEmpty) {
        final tag = _weightedSelector.select(hairStyles, random: random);
        final formattedTag = applyBrackets
            ? _bracketFormatter.applyBrackets(
                tag,
                bracketMin,
                bracketMax,
                random: random,
              )
            : tag;
        tags.add(formattedTag);
      }
    }

    // 表情（默认 60%）
    if (_shouldGenerateCategory(TagSubCategory.expression.name, random)) {
      final expressions = categoryTags[TagSubCategory.expression] ?? [];
      if (expressions.isNotEmpty) {
        final tag = _weightedSelector.select(expressions, random: random);
        final formattedTag = applyBrackets
            ? _bracketFormatter.applyBrackets(
                tag,
                bracketMin,
                bracketMax,
                random: random,
              )
            : tag;
        tags.add(formattedTag);
      }
    }

    // 姿势（默认 50%）
    if (_shouldGenerateCategory(TagSubCategory.pose.name, random)) {
      final poses = categoryTags[TagSubCategory.pose] ?? [];
      if (poses.isNotEmpty) {
        final tag = _weightedSelector.select(poses, random: random);
        final formattedTag = applyBrackets
            ? _bracketFormatter.applyBrackets(
                tag,
                bracketMin,
                bracketMax,
                random: random,
              )
            : tag;
        tags.add(formattedTag);
      }
    }

    return tags;
  }

  /// 判断是否应该生成指定类别
  ///
  /// [category] 类别名称
  /// [random] 随机数生成器
  ///
  /// 返回是否生成
  bool _shouldGenerateCategory(String category, Random random) {
    final probability = _categoryProbabilities[category] ?? 0.5;
    return random.nextDouble() < probability;
  }

  /// 更新类别概率
  ///
  /// [category] 类别
  /// [probability] 生成概率（0.0-1.0）
  ///
  /// 返回更新后的生成器
  CharacterTagGenerator withCategoryProbability(
    TagSubCategory category,
    double probability,
  ) {
    final newProbabilities = Map<String, double>.from(_categoryProbabilities);
    newProbabilities[category.name] = probability.clamp(0.0, 1.0);
    return CharacterTagGenerator(
      weightedSelector: _weightedSelector,
      bracketFormatter: _bracketFormatter,
      categoryProbabilities: newProbabilities,
    );
  }

  /// 获取类别概率
  ///
  /// [category] 类别
  ///
  /// 返回生成概率（如果未设置则返回 null）
  double? getCategoryProbability(TagSubCategory category) {
    return _categoryProbabilities[category.name];
  }

  /// 设置所有类别概率为 1.0（始终生成）
  CharacterTagGenerator get alwaysGenerate {
    return CharacterTagGenerator(
      weightedSelector: _weightedSelector,
      bracketFormatter: _bracketFormatter,
      categoryProbabilities: {
        TagSubCategory.hairColor.name: 1.0,
        TagSubCategory.eyeColor.name: 1.0,
        TagSubCategory.hairStyle.name: 1.0,
        TagSubCategory.expression.name: 1.0,
        TagSubCategory.pose.name: 1.0,
      },
    );
  }

  /// 设置所有类别概率为 0.0（永不生成）
  CharacterTagGenerator get neverGenerate {
    return CharacterTagGenerator(
      weightedSelector: _weightedSelector,
      bracketFormatter: _bracketFormatter,
      categoryProbabilities: {
        TagSubCategory.hairColor.name: 0.0,
        TagSubCategory.eyeColor.name: 0.0,
        TagSubCategory.hairStyle.name: 0.0,
        TagSubCategory.expression.name: 0.0,
        TagSubCategory.pose.name: 0.0,
      },
    );
  }
}
