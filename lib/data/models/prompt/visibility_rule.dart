import 'package:freezed_annotation/freezed_annotation.dart';

part 'visibility_rule.freezed.dart';
part 'visibility_rule.g.dart';

/// 可见性条件类型
enum VisibilityConditionType {
  /// 标签存在时可见
  tagExists,

  /// 标签不存在时可见
  tagNotExists,

  /// 变量值等于时可见
  valueEquals,

  /// 变量值不等于时可见
  valueNotEquals,

  /// 变量值在列表中时可见
  valueInList,

  /// 变量值不在列表中时可见
  valueNotInList,
}

/// 可见性规则模型
///
/// 根据构图决定是否生成某类别
/// 例如: portrait 时不生成下装, full body 时才生成鞋子
@freezed
class VisibilityRule with _$VisibilityRule {
  const VisibilityRule._();

  const factory VisibilityRule({
    /// 规则ID
    required String id,

    /// 规则名称
    required String name,

    /// 条件类型
    @Default(VisibilityConditionType.tagExists)
    VisibilityConditionType conditionType,

    /// 目标类别ID（受此规则影响的类别）
    required String targetCategoryId,

    /// 源类别ID（条件检查的类别）
    required String sourceCategoryId,

    /// 条件值
    /// - tagExists/tagNotExists: 标签名
    /// - valueEquals/valueNotEquals: 期望值
    /// - valueInList/valueNotInList: 逗号分隔的值列表
    required String conditionValue,

    /// 规则结果 - true 表示可见，false 表示隐藏
    @Default(true) bool visibleWhenMatched,

    /// 优先级（数字越大优先级越高）
    @Default(0) int priority,

    /// 是否启用
    @Default(true) bool enabled,

    /// 描述
    String? description,
  }) = _VisibilityRule;

  factory VisibilityRule.fromJson(Map<String, dynamic> json) =>
      _$VisibilityRuleFromJson(json);

  /// 检查规则是否匹配
  ///
  /// [context] 当前上下文，包含已选择的标签
  /// 返回 true 如果条件匹配
  bool checkCondition(Map<String, List<String>> context) {
    final sourceValues = context[sourceCategoryId] ?? [];
    final sourceSet = sourceValues.toSet();

    switch (conditionType) {
      case VisibilityConditionType.tagExists:
        return sourceSet.contains(conditionValue);

      case VisibilityConditionType.tagNotExists:
        return !sourceSet.contains(conditionValue);

      case VisibilityConditionType.valueEquals:
        return sourceValues.isNotEmpty && sourceValues.first == conditionValue;

      case VisibilityConditionType.valueNotEquals:
        return sourceValues.isEmpty || sourceValues.first != conditionValue;

      case VisibilityConditionType.valueInList:
        final expectedValues =
            conditionValue.split(',').map((s) => s.trim()).toSet();
        return sourceValues.any((v) => expectedValues.contains(v));

      case VisibilityConditionType.valueNotInList:
        final excludedValues =
            conditionValue.split(',').map((s) => s.trim()).toSet();
        return !sourceValues.any((v) => excludedValues.contains(v));
    }
  }

  /// 获取目标类别的可见性
  ///
  /// [context] 当前上下文
  /// 返回 true 如果目标类别应该可见
  bool isTargetVisible(Map<String, List<String>> context) {
    if (!enabled) return true; // 规则禁用时默认可见

    final conditionMatched = checkCondition(context);
    return conditionMatched ? visibleWhenMatched : !visibleWhenMatched;
  }
}

/// 可见性规则管理器
///
/// 管理多个可见性规则
@freezed
class VisibilityRuleSet with _$VisibilityRuleSet {
  const VisibilityRuleSet._();

  const factory VisibilityRuleSet({
    /// 规则列表
    @Default([]) List<VisibilityRule> rules,
  }) = _VisibilityRuleSet;

  factory VisibilityRuleSet.fromJson(Map<String, dynamic> json) =>
      _$VisibilityRuleSetFromJson(json);

  /// 检查类别是否可见
  ///
  /// [categoryId] 目标类别ID
  /// [context] 当前上下文
  bool isCategoryVisible(String categoryId, Map<String, List<String>> context) {
    // 获取所有针对该类别的规则，按优先级排序
    final applicableRules = rules
        .where((r) => r.targetCategoryId == categoryId && r.enabled)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    if (applicableRules.isEmpty) return true; // 无规则时默认可见

    // 使用最高优先级的匹配规则
    for (final rule in applicableRules) {
      if (rule.checkCondition(context)) {
        return rule.visibleWhenMatched;
      }
    }

    // 没有规则匹配时默认可见
    return true;
  }

  /// 获取所有可见的类别ID
  ///
  /// [allCategoryIds] 所有类别ID列表
  /// [context] 当前上下文
  List<String> getVisibleCategories(
    List<String> allCategoryIds,
    Map<String, List<String>> context,
  ) {
    return allCategoryIds
        .where((id) => isCategoryVisible(id, context))
        .toList();
  }
}
