import 'package:freezed_annotation/freezed_annotation.dart';

/// 标签作用域
///
/// 控制类别/词组应用于主提示词还是角色提示词
enum TagScope {
  /// 仅全局/主提示词
  @JsonValue('global')
  global,

  /// 仅角色提示词
  @JsonValue('character')
  character,

  /// 两者都适用（默认）
  @JsonValue('all')
  all,
}

/// TagScope 扩展方法
extension TagScopeExtension on TagScope {
  /// 获取显示名称的键（用于国际化）
  String get l10nKey => switch (this) {
        TagScope.global => 'scope_global',
        TagScope.character => 'scope_character',
        TagScope.all => 'scope_all',
      };

  /// 获取描述的键（用于国际化）
  String get descL10nKey => switch (this) {
        TagScope.global => 'scope_globalDesc',
        TagScope.character => 'scope_characterDesc',
        TagScope.all => 'scope_allDesc',
      };

  /// 检查是否适用于目标作用域
  ///
  /// 逻辑规则：
  /// - 如果类别/词组的 scope 是 all，适用于任何目标
  /// - 如果目标 scope 是 all，任何类别/词组都适用
  /// - 否则需要精确匹配
  ///
  /// 示例：
  /// - character.isApplicableTo(all) → true（all 目标接受所有）
  /// - global.isApplicableTo(all) → true（all 目标接受所有）
  /// - all.isApplicableTo(character) → true（all 类别适用于任何目标）
  /// - character.isApplicableTo(global) → false（需要精确匹配）
  bool isApplicableTo(TagScope targetScope) {
    // 类别/词组设置为 all，适用于任何目标
    if (this == TagScope.all) return true;
    // 目标作用域为 all，接受任何类别/词组
    if (targetScope == TagScope.all) return true;
    // 精确匹配
    return this == targetScope;
  }
}
