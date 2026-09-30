import 'dart:math' as math;

import 'package:freezed_annotation/freezed_annotation.dart';

import 'rule_tag_match.dart';

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
    // 生成结果可能带权重括号，用户输入可能用下划线，按比较键匹配
    final sourceValues = (context[sourceCategoryId] ?? const <String>[])
        .map(ruleTagMatchKey)
        .toList();
    final expected = ruleTagMatchKey(conditionValue);

    switch (conditionType) {
      case VisibilityConditionType.tagExists:
        return sourceValues.contains(expected);

      case VisibilityConditionType.tagNotExists:
        return !sourceValues.contains(expected);

      case VisibilityConditionType.valueEquals:
        return sourceValues.isNotEmpty && sourceValues.first == expected;

      case VisibilityConditionType.valueNotEquals:
        return sourceValues.isEmpty || sourceValues.first != expected;

      case VisibilityConditionType.valueInList:
        final expectedValues = ruleTagMatchKeysOfList(conditionValue);
        return sourceValues.any(expectedValues.contains);

      case VisibilityConditionType.valueNotInList:
        final excludedValues = ruleTagMatchKeysOfList(conditionValue);
        return !sourceValues.any(excludedValues.contains);
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

  /// 检查目标是否可见
  ///
  /// 命中的规则中最高优先级一档决定结果，同档只要有一条隐藏即隐藏；
  /// 一条都没命中时，存在"条件匹配时可见"的规则就说明目标只在其条件成立时出现。
  /// [categoryId] 目标类别ID
  /// [context] 当前上下文
  bool isCategoryVisible(String categoryId, Map<String, List<String>> context) {
    final applicableRules = rules
        .where((r) => r.targetCategoryId == categoryId && r.enabled)
        .toList();
    if (applicableRules.isEmpty) return true;

    final matchedRules = applicableRules
        .where((r) => r.checkCondition(context))
        .toList();
    if (matchedRules.isEmpty) {
      return !applicableRules.any((r) => r.visibleWhenMatched);
    }

    final topPriority = matchedRules.map((r) => r.priority).reduce(math.max);
    return matchedRules
        .where((r) => r.priority == topPriority)
        .every((r) => r.visibleWhenMatched);
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
