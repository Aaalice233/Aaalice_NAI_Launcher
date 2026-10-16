import 'package:collection/collection.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../../data/models/prompt/conditional_branch.dart';
import '../../../../data/models/prompt/conditional_branch_targets.dart';
import '../../../../data/models/prompt/diy_category_references.dart';
import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/random_tag_group.dart';
import '../diy/diy_category_field.dart';
import '../diy/panels/branch_conditions_editor.dart';
import 'random_config_l10n.dart';

/// 由预设类别与正在编辑的词组推导 DIY 面板的候选类别、分支目标与条件来源
class TagGroupDiyOptions {
  TagGroupDiyOptions({
    required this.l10n,
    required this.presetCategories,
    required this.categoryId,
    required this.editingGroup,
  }) : categoryResolver = DiyCategoryReferenceResolver(presetCategories);

  final AppLocalizations l10n;
  final List<RandomCategory> presetCategories;
  final String categoryId;
  final RandomTagGroup editingGroup;

  /// 按 ID、键名或名称定位预设内的类别，重名的键名与名称不解析
  final DiyCategoryReferenceResolver categoryResolver;

  RandomCategory? get _editingCategory => presetCategories.firstWhereOrNull(
    (category) => category.id == categoryId,
  );

  /// DIY 规则按类别 ID 引用，界面显示本地化名称；重名时附上键名区分
  List<DiyCategoryOption> get categoryOptions {
    final categories = <String, RandomCategory>{
      for (final category in presetCategories)
        if (category.id.isNotEmpty) category.id: category,
    }.values.toList();
    final labels = categories.map(l10n.randomCategoryName).toList();
    return [
      for (var i = 0; i < categories.length; i++)
        DiyCategoryOption(
          id: categories[i].id,
          label: labels.where((label) => label == labels[i]).length > 1
              ? '${labels[i]} (${categories[i].key})'
              : labels[i],
        ),
    ];
  }

  /// 分支可输出本词组的子词组，以及同类别中的其他词组
  List<DiyCategoryOption> get branchTargetOptions {
    return [
      for (final child in editingGroup.children)
        DiyCategoryOption(
          id: child.id,
          label: l10n.diy_branchTargetChild(l10n.randomTagGroupName(child)),
        ),
      for (final group in _editingCategory?.groups ?? const <RandomTagGroup>[])
        if (group.id != editingGroup.id)
          DiyCategoryOption(
            id: group.id,
            label: l10n.randomTagGroupName(group),
          ),
    ];
  }

  Set<String> get cyclicBranchTargetIds {
    final category = _editingCategory;
    if (category == null) return const {};
    return {
      for (final group in category.groups)
        if (category.branchTargetCreatesCycle(editingGroup.id, group.id))
          group.id,
    };
  }

  /// 分支条件可引用的变量；按类别键名、类别名称或词组名称保存的存量条件对应到同一来源
  List<BranchConditionSource> get branchConditionSources {
    final options = categoryOptions;
    final branchGroups = _otherBranchGroups;
    final sources = [
      for (final option in options)
        BranchConditionSource(
          id: option.id,
          label: option.label,
          kind: BranchConditionSourceKind.category,
        ),
      BranchConditionSource(
        id: characterGenderVariable,
        label: l10n.diy_conditionSourceGender,
        kind: BranchConditionSourceKind.characterGender,
      ),
      BranchConditionSource(
        id: characterCountReference,
        label: l10n.diy_sourceCharacterCount,
        kind: BranchConditionSourceKind.characterCount,
      ),
      for (final group in branchGroups)
        BranchConditionSource(
          id: group.id,
          label: _branchLabel(group),
          kind: BranchConditionSourceKind.branch,
        ),
    ];
    final knownIds = {for (final source in sources) source.id};
    final usedKeys = {
      for (final branch
          in editingGroup.conditionalBranchConfig?.branches ??
              const <ConditionalBranch>[])
        ...branch.conditions.keys,
    }.where((key) => !knownIds.contains(key));
    final categoryLabels = {
      for (final option in options) option.id: option.label,
    };
    final groupsByName = groupBy(branchGroups, (group) => group.name);
    for (final key in usedKeys) {
      final source =
          _legacyCategorySource(key, categoryLabels) ??
          _legacyBranchSource(key, groupsByName);
      if (source != null) sources.add(source);
    }
    return sources;
  }

  List<RandomTagGroup> get _otherBranchGroups => [
    for (final category in presetCategories)
      for (final group in category.groups)
        if (group.id != editingGroup.id &&
            group.conditionalBranchConfig != null)
          group,
  ];

  String _branchLabel(RandomTagGroup group) =>
      l10n.diy_conditionSourceBranch(l10n.randomTagGroupName(group));

  BranchConditionSource? _legacyCategorySource(
    String key,
    Map<String, String> categoryLabels,
  ) {
    final label = categoryLabels[categoryResolver.resolve(key)?.id];
    if (label == null) return null;
    return BranchConditionSource(
      id: key,
      label: label,
      kind: BranchConditionSourceKind.category,
    );
  }

  // 重名的词组无法确定条件指向哪个分支，与类别引用一样不解析
  BranchConditionSource? _legacyBranchSource(
    String key,
    Map<String, List<RandomTagGroup>> groupsByName,
  ) {
    final group = groupsByName[key]?.singleOrNull;
    if (group == null) return null;
    return BranchConditionSource(
      id: key,
      label: _branchLabel(group),
      kind: BranchConditionSourceKind.branch,
    );
  }
}
