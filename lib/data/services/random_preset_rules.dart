import '../models/prompt/diy_category_references.dart';
import '../models/prompt/post_process_rule.dart';
import '../models/prompt/random_category.dart';
import '../models/prompt/random_preset.dart';
import '../models/prompt/random_tag_group.dart';
import '../models/prompt/visibility_rule.dart';
import 'random_preset_generation_context.dart';

/// 一次预设生成中 DIY 规则的作用范围与求值。
///
/// 类别引用统一换成类别 ID；词组上以类别为目标的可见性规则归到目标类别，
/// 词组上的后处理规则与全局规则一起作用于整轮生成结果。
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
      PostProcessRuleSet(
        rules: [
          ...?resolved.algorithmConfig.globalPostProcessRules?.rules,
          for (final group in _activeGroups(resolved.categories))
            ...group.postProcessRules,
        ],
      ),
    );
  }

  RandomPresetRules._(this.preset, this._categoryVisibility, this._postProcess);

  /// 类别引用已换成 ID 的预设，生成全程使用它
  final RandomPreset preset;

  final Map<String, VisibilityRuleSet> _categoryVisibility;
  final PostProcessRuleSet _postProcess;

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

  List<String> applyPostProcess(
    List<String> tags,
    RandomPresetGenerationContext context,
  ) {
    return _postProcess.applyAll(
      tags,
      context.tagContext,
      variables: context.variables,
    );
  }

  // 停用的类别、词组或子词组不再施加自己的规则
  static Iterable<RandomTagGroup> _activeGroups(
    List<RandomCategory> categories,
  ) sync* {
    Iterable<RandomTagGroup> withChildren(RandomTagGroup group) sync* {
      yield group;
      for (final child in group.children) {
        if (child.enabled) yield* withChildren(child);
      }
    }

    for (final category in categories) {
      if (!category.enabled) continue;
      for (final group in category.groups) {
        if (group.enabled) yield* withChildren(group);
      }
    }
  }

  // 子词组生成时不求值可见性，这里与之一致只收集顶层词组的规则
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
