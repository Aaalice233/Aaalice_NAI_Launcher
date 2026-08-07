import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'prompt_regex_rule.freezed.dart';
part 'prompt_regex_rule.g.dart';

/// 提示词正则替换规则
///
/// 用户自定义的「匹配 → 替换」规则，在输入框失焦时按顺序作用于提示词全文。
/// [pattern] 是 Dart [RegExp] 语法，[replacement] 支持 `$1` / `${name}` 捕获组引用。
@freezed
class PromptRegexRule with _$PromptRegexRule {
  const PromptRegexRule._();

  const factory PromptRegexRule({
    /// 唯一标识
    required String id,

    /// 规则名称（可为空，列表中回退显示匹配式）
    @Default('') String name,

    /// 匹配用的正则表达式源串
    @Default('') String pattern,

    /// 替换目标，支持 `$1`、`${name}` 引用捕获组，`$$` 表示字面量 `$`
    @Default('') String replacement,

    /// 是否启用
    @Default(true) bool enabled,

    /// 是否区分大小写
    @Default(false) bool caseSensitive,

    /// 排序顺序（决定多条规则的应用先后）
    @Default(0) int sortOrder,
  }) = _PromptRegexRule;

  factory PromptRegexRule.fromJson(Map<String, dynamic> json) =>
      _$PromptRegexRuleFromJson(json);

  /// 创建新规则
  factory PromptRegexRule.create({
    String name = '',
    String pattern = '',
    String replacement = '',
    bool enabled = true,
    bool caseSensitive = false,
    int sortOrder = 0,
  }) {
    return PromptRegexRule(
      id: const Uuid().v4(),
      name: name.trim(),
      pattern: pattern,
      replacement: replacement,
      enabled: enabled,
      caseSensitive: caseSensitive,
      sortOrder: sortOrder,
    );
  }

  /// 编译正则表达式，语法非法或匹配式为空时返回 null
  ///
  /// 每次调用都会重新编译。调用方如需在循环中复用，应自行缓存结果。
  RegExp? tryCompile() {
    if (pattern.isEmpty) return null;
    try {
      return RegExp(pattern, caseSensitive: caseSensitive);
    } on FormatException {
      return null;
    }
  }

  /// 正则语法是否可用
  bool get isValid => tryCompile() != null;

  /// 列表中显示的标题：优先规则名，其次匹配式
  String get displayLabel {
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) return trimmedName;
    return pattern;
  }
}

/// 正则规则列表扩展
extension PromptRegexRuleListExtension on List<PromptRegexRule> {
  /// 按 [PromptRegexRule.sortOrder] 排列
  List<PromptRegexRule> sortedByOrder() {
    final sorted = [...this];
    sorted.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sorted;
  }

  /// 按当前列表顺序重新分配 sortOrder
  List<PromptRegexRule> reindex() {
    return asMap().entries
        .map((entry) => entry.value.copyWith(sortOrder: entry.key))
        .toList();
  }

  /// 启用中的规则
  List<PromptRegexRule> get activeRules =>
      where((rule) => rule.enabled).toList();
}
