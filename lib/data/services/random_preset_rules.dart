import '../models/prompt/conditional_branch_targets.dart';
import '../models/prompt/diy_category_references.dart';
import '../models/prompt/post_process_rule.dart';
import '../models/prompt/random_category.dart';
import '../models/prompt/random_preset.dart';
import '../models/prompt/random_tag_group.dart';
import '../models/prompt/tag_scope.dart';
import '../models/prompt/visibility_rule.dart';
import 'random_preset_generation_context.dart';

/// 一次预设生成中 DIY 规则的作用范围与求值：类别引用统一换成 ID，
/// 词组上以类别为目标的可见性规则归到目标类别，词组后处理与全局规则一起作用于整轮结果，
/// 依赖按源的结果数或已选值求值（角色数量源读取本次生成的人数），
/// 由启用分支输出的词组不参与类别的常规抽取。
class RandomPresetRules {
  factory RandomPresetRules(RandomPreset preset) {
    final resolver = DiyCategoryReferenceResolver(preset.categories);
    final resolved = preset.copyWith(
      algorithmConfig: preset.algorithmConfig.mapCategoryReferences(
        resolver.canonicalId,
      ),
      categories: preset.categories
          .map((category) => category.canonicalizeReferences(resolver))
          .toList(),
    );
    return RandomPresetRules._(
      resolved,
      _collectCategoryVisibilityRules(resolved.categories),
      {
        for (final category in resolved.categories)
          category.id: category.branchOwnedGroupIds,
      },
      PostProcessRuleSet(
        rules: [
          ...?resolved.algorithmConfig.globalPostProcessRules?.rules,
          for (final group in _activeGroups(resolved.categories))
            ...group.postProcessRules,
        ],
      ),
    );
  }

  RandomPresetRules._(
    this.preset,
    this._categoryVisibility,
    this._branchOwnedGroupIds,
    this._postProcess,
  );

  /// 类别引用已换成 ID 的预设，生成全程使用它
  final RandomPreset preset;

  final Map<String, VisibilityRuleSet> _categoryVisibility;
  final Map<String, Set<String>> _branchOwnedGroupIds;
  final PostProcessRuleSet _postProcess;

  /// 词组是否只经由同类别启用分支输出
  bool isBranchOwned(RandomCategory category, RandomTagGroup group) =>
      _branchOwnedGroupIds[category.id]?.contains(group.id) ?? false;

  /// 类别能否参与本轮生成：启用、作用域、角色性别与可见性
  bool isCategoryEligible(
    RandomCategory category,
    RandomPresetGenerationContext context, {
    TagScope scope = TagScope.all,
  }) {
    if (!category.enabled || !category.isApplicableToScope(scope)) {
      return false;
    }
    final gender = context.characterGender;
    if (gender != null && !category.isApplicableToGender(gender)) return false;
    return _isCategoryVisible(category, context);
  }

  /// 词组能否参与抽取：启用、作用域、角色性别、时间、可见性与依赖
  ///
  /// 常规抽取、子词组与分支输出都经由这里求值；[scope] 为本轮的目标作用域
  bool isGroupEligible(
    RandomTagGroup group,
    RandomPresetGenerationContext context, {
    TagScope scope = TagScope.all,
  }) {
    if (!group.enabled || !group.isApplicableToScope(scope)) return false;
    final gender = context.characterGender;
    if (gender != null && !group.isApplicableToGender(gender)) return false;
    return group.isTimeConditionActive(context.generationTime) &&
        group.checkVisibility(context.tagContext) &&
        _isDependencySatisfied(group, context);
  }

  bool _isCategoryVisible(
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

  bool _isDependencySatisfied(
    RandomTagGroup group,
    RandomPresetGenerationContext context,
  ) {
    final dependency = group.dependencyConfig;
    if (dependency == null || !dependency.enabled) return true;
    return dependency.isSatisfiedBy(
      context.countFor(dependency.sourceCategoryId),
    );
  }

  /// 数量与值依赖算出的选取数量；词组不受依赖控制数量时为 null
  int? dependentSelectionCount(
    RandomTagGroup group,
    RandomPresetGenerationContext context,
    int Function() randomInt,
  ) {
    final dependency = group.dependencyConfig;
    if (dependency == null ||
        !dependency.enabled ||
        !dependency.controlsSelectionCount) {
      return null;
    }

    final source = dependency.sourceCategoryId;
    final variable = dependency.sourceVariable;
    if (variable != null) {
      final value = context.firstValueFor(variable);
      return dependency.getCount(
        value.isEmpty ? '${context.countFor(source)}' : value,
        randomInt,
      );
    }
    return dependency.getCountForResult(
      dependency.getResultForSource(
        sourceCount: context.countFor(source),
        sourceValues: context.valuesFor(source),
      ),
      randomInt,
    );
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

  static Map<String, VisibilityRuleSet> _collectCategoryVisibilityRules(
    List<RandomCategory> categories,
  ) {
    final categoryIds = {for (final category in categories) category.id};
    final rulesByTarget = <String, List<VisibilityRule>>{};
    for (final group in _activeGroups(categories)) {
      for (final rule in group.visibilityRules) {
        if (!categoryIds.contains(rule.targetCategoryId)) continue;
        rulesByTarget.putIfAbsent(rule.targetCategoryId, () => []).add(rule);
      }
    }
    return {
      for (final entry in rulesByTarget.entries)
        entry.key: VisibilityRuleSet(rules: entry.value),
    };
  }
}
