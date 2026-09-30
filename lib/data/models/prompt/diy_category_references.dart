import 'algorithm_config.dart';
import 'dependency_config.dart';
import 'post_process_rule.dart';
import 'random_category.dart';
import 'random_tag_group.dart';
import 'visibility_rule.dart';

/// 代表角色人数的特殊引用，依赖源与生成变量共用，不指向任何类别
const characterCountReference = 'character_count';

/// 把 DIY 规则中的类别引用解析为预设内的类别
///
/// 规则按类别 ID 存储；生成器同样认得类别键名；存量数据里还有按类别名称保存的引用。
class DiyCategoryReferenceResolver {
  DiyCategoryReferenceResolver(Iterable<RandomCategory> categories)
    : _byId = _uniqueIndex(categories, (category) => category.id),
      _byKey = _uniqueIndex(categories, (category) => category.key),
      _byName = _uniqueIndex(categories, (category) => category.name);

  final Map<String, RandomCategory> _byId;
  final Map<String, RandomCategory> _byKey;
  final Map<String, RandomCategory> _byName;

  RandomCategory? resolve(String reference) {
    if (reference.isEmpty) return null;
    return _byId[reference] ?? _byKey[reference] ?? _byName[reference];
  }

  /// 能唯一定位到类别时返回其 ID，否则原样保留以便界面标记为已失效
  String canonicalId(String reference) => resolve(reference)?.id ?? reference;

  // 重名的键或名称无法确定指向哪个类别，不参与解析
  static Map<String, RandomCategory> _uniqueIndex(
    Iterable<RandomCategory> categories,
    String Function(RandomCategory category) keyOf,
  ) {
    final index = <String, RandomCategory>{};
    final ambiguous = <String>{};
    for (final category in categories) {
      final key = keyOf(category);
      if (key.isEmpty || ambiguous.contains(key)) continue;
      if (index.remove(key) != null) {
        ambiguous.add(key);
        continue;
      }
      index[key] = category;
    }
    return index;
  }
}

typedef CategoryReferenceMapper = String Function(String reference);

extension DependencyConfigCategoryReferences on DependencyConfig {
  DependencyConfig mapCategoryReferences(CategoryReferenceMapper map) {
    if (sourceCategoryId == characterCountReference) return this;
    return copyWith(sourceCategoryId: map(sourceCategoryId));
  }
}

extension VisibilityRuleCategoryReferences on VisibilityRule {
  VisibilityRule mapCategoryReferences(CategoryReferenceMapper map) {
    return copyWith(
      sourceCategoryId: map(sourceCategoryId),
      targetCategoryId: map(targetCategoryId),
    );
  }
}

extension PostProcessRuleCategoryReferences on PostProcessRule {
  PostProcessRule mapCategoryReferences(CategoryReferenceMapper map) {
    return copyWith(
      triggerCategoryIds: triggerCategoryIds.map(map).toList(),
      targetCategoryIds: targetCategoryIds.map(map).toList(),
    );
  }
}

extension RandomTagGroupCategoryReferences on RandomTagGroup {
  RandomTagGroup mapCategoryReferences(CategoryReferenceMapper map) {
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
}

extension RandomCategoryCategoryReferences on RandomCategory {
  RandomCategory mapCategoryReferences(CategoryReferenceMapper map) {
    return copyWith(
      groups: groups.map((group) => group.mapCategoryReferences(map)).toList(),
    );
  }
}

extension AlgorithmConfigCategoryReferences on AlgorithmConfig {
  AlgorithmConfig mapCategoryReferences(CategoryReferenceMapper map) {
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
