import 'algorithm_config.dart';
import 'conditional_branch.dart';
import 'dependency_config.dart';
import 'post_process_rule.dart';
import 'random_category.dart';
import 'random_tag_group.dart';
import 'visibility_rule.dart';

/// 代表角色人数的特殊引用，依赖源与生成变量共用，不指向任何类别
const characterCountReference = 'character_count';

/// 生成角色提示词时记录角色性别（槽位名称）的变量
const characterGenderVariable = 'character_gender';

/// 记录本轮所选角色人数分类的变量
const characterCountCategoryVariable = 'character_count_category';

const _generationVariables = {
  characterCountReference,
  characterGenderVariable,
  characterCountCategoryVariable,
};

/// 把 DIY 规则中的类别引用与分支条件变量解析为预设内的类别或词组
///
/// 规则按类别 ID 存储；生成器同样认得类别键名；存量数据里还有按类别名称保存的引用。
class DiyCategoryReferenceResolver {
  DiyCategoryReferenceResolver(Iterable<RandomCategory> categories)
    : this._(List.of(categories));

  DiyCategoryReferenceResolver._(List<RandomCategory> categories)
    : _byId = _uniqueIndex(categories, (category) => category.id),
      _byKey = _uniqueIndex(categories, (category) => category.key),
      _byName = _uniqueIndex(categories, (category) => category.name),
      _branchGroupByName = _uniqueIndex(
        _branchGroups(categories),
        (group) => group.name,
      );

  final Map<String, RandomCategory?> _byId;
  final Map<String, RandomCategory?> _byKey;
  final Map<String, RandomCategory?> _byName;
  final Map<String, RandomTagGroup?> _branchGroupByName;

  RandomCategory? resolve(String reference) {
    if (reference.isEmpty) return null;
    return _byId[reference] ?? _byKey[reference] ?? _byName[reference];
  }

  /// 能唯一定位到类别时返回其 ID，否则原样保留以便界面标记为已失效
  String canonicalId(String reference) => resolve(reference)?.id ?? reference;

  /// 分支条件的变量键统一为类别或词组 ID，角色变量与无法定位的键原样保留
  ///
  /// 生成器按类别 ID、键名和分支词组的 ID、名称写入变量，从不按类别名称写入，
  /// 所以类别名称排在分支词组名称之后；某一层重名时无法确定指向，不再往下解析
  String canonicalConditionKey(String key) {
    if (_generationVariables.contains(key)) return key;
    if (_byId.containsKey(key)) return key;
    if (_byKey.containsKey(key)) return _byKey[key]?.id ?? key;
    if (_branchGroupByName.containsKey(key)) {
      return _branchGroupByName[key]?.id ?? key;
    }
    return _byName[key]?.id ?? key;
  }

  static Iterable<RandomTagGroup> _branchGroups(
    List<RandomCategory> categories,
  ) sync* {
    Iterable<RandomTagGroup> withChildren(RandomTagGroup group) sync* {
      yield group;
      for (final child in group.children) {
        yield* withChildren(child);
      }
    }

    for (final category in categories) {
      for (final group in category.groups.expand(withChildren)) {
        if (group.conditionalBranchConfig != null) yield group;
      }
    }
  }

  // 重名的键或名称无法确定指向哪个对象，记为 null
  static Map<String, T?> _uniqueIndex<T>(
    Iterable<T> items,
    String Function(T item) keyOf,
  ) {
    final index = <String, T?>{};
    for (final item in items) {
      final key = keyOf(item);
      if (key.isEmpty) continue;
      index[key] = index.containsKey(key) ? null : item;
    }
    return index;
  }
}

typedef ReferenceMapper = String Function(String reference);

extension DependencyConfigCategoryReferences on DependencyConfig {
  DependencyConfig mapCategoryReferences(ReferenceMapper map) {
    if (sourceCategoryId == characterCountReference) return this;
    return copyWith(sourceCategoryId: map(sourceCategoryId));
  }
}

extension VisibilityRuleCategoryReferences on VisibilityRule {
  VisibilityRule mapCategoryReferences(ReferenceMapper map) {
    return copyWith(
      sourceCategoryId: map(sourceCategoryId),
      targetCategoryId: map(targetCategoryId),
    );
  }
}

extension PostProcessRuleCategoryReferences on PostProcessRule {
  PostProcessRule mapCategoryReferences(ReferenceMapper map) {
    return copyWith(
      triggerCategoryIds: triggerCategoryIds.map(map).toList(),
      targetCategoryIds: targetCategoryIds.map(map).toList(),
    );
  }
}

extension RandomTagGroupReferences on RandomTagGroup {
  RandomTagGroup mapCategoryReferences(ReferenceMapper map) {
    return copyWith(
      dependencyConfig: dependencyConfig?.mapCategoryReferences(map),
      visibilityRules: visibilityRules
          .map((rule) => rule.mapCategoryReferences(map))
          .toList(),
      postProcessRules: postProcessRules
          .map((rule) => rule.mapCategoryReferences(map))
          .toList(),
      children: children
          .map((child) => child.mapCategoryReferences(map))
          .toList(),
    );
  }

  /// 改写本词组与子词组的分支输出与分支条件变量
  RandomTagGroup mapBranchReferences(ReferenceMapper map) => _mapBranches(
    (branch) => branch.copyWith(
      tagGroupIds: branch.tagGroupIds.map(map).toList(),
      conditions: _mapConditionKeys(branch.conditions, map),
    ),
  );

  /// 规则里的类别引用与分支条件变量按 [resolver] 统一为 ID
  RandomTagGroup canonicalizeReferences(DiyCategoryReferenceResolver resolver) {
    return mapCategoryReferences(resolver.canonicalId)._mapBranches(
      (branch) => branch.copyWith(
        conditions: _mapConditionKeys(
          branch.conditions,
          resolver.canonicalConditionKey,
        ),
      ),
    );
  }

  RandomTagGroup _mapBranches(
    ConditionalBranch Function(ConditionalBranch branch) map,
  ) {
    final config = conditionalBranchConfig;
    return copyWith(
      conditionalBranchConfig: config?.copyWith(
        branches: config.branches.map(map).toList(),
      ),
      children: children.map((child) => child._mapBranches(map)).toList(),
    );
  }
}

// 两个键改写成同一个键时会丢掉其中一条条件，此时保留原有的键
Map<String, String> _mapConditionKeys(
  Map<String, String> conditions,
  ReferenceMapper map,
) {
  final mapped = {
    for (final condition in conditions.entries)
      map(condition.key): condition.value,
  };
  return mapped.length == conditions.length ? mapped : conditions;
}

extension RandomCategoryReferences on RandomCategory {
  RandomCategory mapCategoryReferences(ReferenceMapper map) {
    return copyWith(
      groups: groups.map((group) => group.mapCategoryReferences(map)).toList(),
    );
  }

  RandomCategory mapBranchReferences(ReferenceMapper map) {
    return copyWith(
      groups: groups.map((group) => group.mapBranchReferences(map)).toList(),
    );
  }

  RandomCategory canonicalizeReferences(DiyCategoryReferenceResolver resolver) {
    return copyWith(
      groups: groups
          .map((group) => group.canonicalizeReferences(resolver))
          .toList(),
    );
  }
}

extension AlgorithmConfigCategoryReferences on AlgorithmConfig {
  AlgorithmConfig mapCategoryReferences(ReferenceMapper map) {
    final visibility = globalVisibilityRules;
    final postProcess = globalPostProcessRules;
    return copyWith(
      globalVisibilityRules: visibility?.copyWith(
        rules: visibility.rules
            .map((rule) => rule.mapCategoryReferences(map))
            .toList(),
      ),
      globalPostProcessRules: postProcess?.copyWith(
        rules: postProcess.rules
            .map((rule) => rule.mapCategoryReferences(map))
            .toList(),
      ),
    );
  }
}
