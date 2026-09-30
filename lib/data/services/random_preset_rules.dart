import '../models/prompt/diy_category_references.dart';
import '../models/prompt/random_category.dart';
import '../models/prompt/random_preset.dart';
import '../models/prompt/visibility_rule.dart';
import 'random_preset_generation_context.dart';

/// 一次预设生成中 DIY 规则的作用范围与求值。
///
/// 类别引用统一换成类别 ID；词组上以类别为目标的可见性规则归到目标类别，
/// 与全局规则一样决定整个类别是否生成。
class RandomPresetRules {
  factory RandomPresetRules(RandomPreset preset) {
    final resolver = DiyCategoryReferenceResolver(preset.categories);
    final resolved = preset.copyWith(
      algorithmConfig: preset.algorithmConfig.mapCategoryReferences(
        resolver.canonicalId,
      ),
      categories: preset.categories
          .map(
            (category) => category.mapCategoryReferences(resolver.canonicalId),
          )
          .toList(),
    );
    return RandomPresetRules._(
      resolved,
      _collectCategoryVisibilityRules(resolved.categories),
    );
  }

  RandomPresetRules._(this.preset, this._categoryVisibility);

  /// 类别引用已换成 ID 的预设，生成全程使用它
  final RandomPreset preset;

  final Map<String, VisibilityRuleSet> _categoryVisibility;

  bool isCategoryVisible(
    RandomCategory category,
    RandomPresetGenerationContext context,
  ) {
    final tags = context.tagContext;
    final config = preset.algorithmConfig;
    final groupRules = _categoryVisibility[category.id];
    return config.isCategoryGloballyVisible(category.id, tags) &&
        config.isCategoryGloballyVisible(category.key, tags) &&
        (groupRules == null || groupRules.isCategoryVisible(category.id, tags));
  }

  // 停用的词组或类别不再施加自己的规则
  static Map<String, VisibilityRuleSet> _collectCategoryVisibilityRules(
    List<RandomCategory> categories,
  ) {
    final categoryIds = {for (final category in categories) category.id};
    final rulesByTarget = <String, List<VisibilityRule>>{};
    for (final category in categories) {
      if (!category.enabled) continue;
      for (final group in category.groups) {
        if (!group.enabled) continue;
        for (final rule in group.visibilityRules) {
          if (!categoryIds.contains(rule.targetCategoryId)) continue;
          rulesByTarget.putIfAbsent(rule.targetCategoryId, () => []).add(rule);
        }
      }
    }
    return {
      for (final entry in rulesByTarget.entries)
        entry.key: VisibilityRuleSet(rules: entry.value),
    };
  }
}
