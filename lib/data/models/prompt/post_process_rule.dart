import 'package:freezed_annotation/freezed_annotation.dart';

part 'post_process_rule.freezed.dart';
part 'post_process_rule.g.dart';

/// 后处理操作类型
enum PostProcessAction {
  /// 移除标签
  remove,

  /// 替换标签
  replace,

  /// 添加标签
  add,

  /// 移除整个类别
  removeCategory,
}

/// 后处理规则模型
///
/// 根据已选标签移除冲突类别或标签
/// 例如: sleeping/zzz/closed eyes 时移除眼睛颜色
/// 例如: mermaid/centaur/lamia 不穿腿部服装
@freezed
class PostProcessRule with _$PostProcessRule {
  const PostProcessRule._();

  const factory PostProcessRule({
    /// 规则ID
    required String id,

    /// 规则名称
    required String name,

    /// 触发标签列表 - 当这些标签存在时触发规则
    @Default([]) List<String> triggerTags,

    /// 触发类别ID列表 - 当这些类别有选中标签时触发
    @Default([]) List<String> triggerCategoryIds,

    /// 触发变量值映射 - 当变量等于特定值时触发
    @Default({}) Map<String, String> triggerVariables,

    /// 执行操作
    @Default(PostProcessAction.remove) PostProcessAction action,

    /// 目标标签列表（用于 remove/replace 操作）
    @Default([]) List<String> targetTags,

    /// 目标类别ID列表（用于 removeCategory 操作）
    @Default([]) List<String> targetCategoryIds,

    /// 替换为的标签（用于 replace 操作）
    String? replacementTag,

    /// 添加的标签列表（用于 add 操作）
    @Default([]) List<String> addTags,

    /// 优先级（数字越大优先级越高）
    @Default(0) int priority,

    /// 是否启用
    @Default(true) bool enabled,

    /// 描述
    String? description,
  }) = _PostProcessRule;

  factory PostProcessRule.fromJson(Map<String, dynamic> json) =>
      _$PostProcessRuleFromJson(json);

  /// 创建睡眠规则（移除眼睛颜色）
  factory PostProcessRule.sleepingRule({String? id}) => PostProcessRule(
        id: id ?? 'sleeping_rule',
        name: '睡眠规则',
        triggerTags: ['sleeping', 'zzz', 'closed eyes'],
        action: PostProcessAction.removeCategory,
        targetCategoryIds: ['eye_color'],
        description: '当角色睡觉时，移除眼睛颜色描述',
      );

  /// 创建美人鱼规则（不穿腿部服装）
  factory PostProcessRule.mermaidRule({String? id}) => PostProcessRule(
        id: id ?? 'mermaid_rule',
        name: '美人鱼规则',
        triggerTags: ['mermaid', 'centaur', 'lamia'],
        action: PostProcessAction.removeCategory,
        targetCategoryIds: ['legwear', 'footwear', 'pants', 'skirt'],
        description: '美人鱼、半人马、蛇女等不穿腿部服装',
      );

  /// 检查规则是否被触发
  ///
  /// [selectedTags] 已选择的标签列表
  /// [context] 当前上下文，包含类别到标签的映射
  /// [variables] 当前变量值映射
  bool isTriggered({
    required List<String> selectedTags,
    required Map<String, List<String>> context,
    Map<String, String>? variables,
  }) {
    if (!enabled) return false;

    // 检查触发标签
    if (triggerTags.isNotEmpty) {
      final tagSet = selectedTags.toSet();
      if (triggerTags.any((t) => tagSet.contains(t))) {
        return true;
      }
    }

    // 检查触发类别
    if (triggerCategoryIds.isNotEmpty) {
      for (final categoryId in triggerCategoryIds) {
        if (context[categoryId]?.isNotEmpty ?? false) {
          return true;
        }
      }
    }

    // 检查触发变量
    if (triggerVariables.isNotEmpty && variables != null) {
      for (final entry in triggerVariables.entries) {
        if (variables[entry.key] == entry.value) {
          return true;
        }
      }
    }

    return false;
  }

  /// 应用规则到标签列表
  ///
  /// [tags] 当前标签列表
  /// [context] 当前上下文
  /// 返回处理后的标签列表
  List<String> apply(
    List<String> tags,
    Map<String, List<String>> context,
  ) {
    final result = List<String>.from(tags);

    switch (action) {
      case PostProcessAction.remove:
        // 移除目标标签
        result.removeWhere((t) => targetTags.contains(t));
        break;

      case PostProcessAction.replace:
        // 替换目标标签
        if (replacementTag != null) {
          for (var i = 0; i < result.length; i++) {
            if (targetTags.contains(result[i])) {
              result[i] = replacementTag!;
            }
          }
        }
        break;

      case PostProcessAction.add:
        // 添加标签
        result.addAll(addTags);
        break;

      case PostProcessAction.removeCategory:
        // 移除类别中的所有标签
        for (final categoryId in targetCategoryIds) {
          final categoryTags = context[categoryId] ?? [];
          result.removeWhere((t) => categoryTags.contains(t));
        }
        break;
    }

    return result;
  }

  /// 获取显示文本
  String get displayText {
    final triggerText = triggerTags.isNotEmpty
        ? triggerTags.join(', ')
        : triggerCategoryIds.join(', ');

    switch (action) {
      case PostProcessAction.remove:
        return '当 [$triggerText] 时移除 [${targetTags.join(', ')}]';
      case PostProcessAction.replace:
        return '当 [$triggerText] 时替换 [${targetTags.join(', ')}] 为 [$replacementTag]';
      case PostProcessAction.add:
        return '当 [$triggerText] 时添加 [${addTags.join(', ')}]';
      case PostProcessAction.removeCategory:
        return '当 [$triggerText] 时移除类别 [${targetCategoryIds.join(', ')}]';
    }
  }
}

/// 后处理规则集
@freezed
class PostProcessRuleSet with _$PostProcessRuleSet {
  const PostProcessRuleSet._();

  const factory PostProcessRuleSet({
    /// 规则列表
    @Default([]) List<PostProcessRule> rules,
  }) = _PostProcessRuleSet;

  factory PostProcessRuleSet.fromJson(Map<String, dynamic> json) =>
      _$PostProcessRuleSetFromJson(json);

  /// 应用所有匹配的规则
  ///
  /// [tags] 当前标签列表
  /// [context] 当前上下文
  /// [variables] 当前变量值映射
  List<String> applyAll(
    List<String> tags,
    Map<String, List<String>> context, {
    Map<String, String>? variables,
  }) {
    // 按优先级排序
    final sortedRules = rules.where((r) => r.enabled).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    var result = tags;

    for (final rule in sortedRules) {
      if (rule.isTriggered(
        selectedTags: result,
        context: context,
        variables: variables,
      )) {
        result = rule.apply(result, context);
      }
    }

    return result;
  }

  /// 获取会被触发的规则列表
  List<PostProcessRule> getTriggeredRules(
    List<String> tags,
    Map<String, List<String>> context, {
    Map<String, String>? variables,
  }) {
    return rules
        .where((r) => r.enabled)
        .where(
          (r) => r.isTriggered(
            selectedTags: tags,
            context: context,
            variables: variables,
          ),
        )
        .toList();
  }
}
