import 'default_shortcuts.dart';
import 'shortcut_config.dart';

/// 录制快捷键时判断按键组合是否成立。
/// 带修饰键一律放行；无修饰键只放行导航/功能键和出厂默认裸用过的主键。

class ShortcutRecordingPolicy {
  const ShortcutRecordingPolicy._();

  /// 不会产生正常文本输入的键，与出厂默认无关
  static const Set<ShortcutKey> _navigationKeys = {
    ShortcutKey.escape,
    ShortcutKey.delete,
    ShortcutKey.space,
    ShortcutKey.enter,
    ShortcutKey.arrowup,
    ShortcutKey.arrowdown,
    ShortcutKey.arrowleft,
    ShortcutKey.arrowright,
  };

  /// f 后面跟数字才是功能键，ShortcutKey.keyF 的 'f' 是字母
  static final RegExp _functionKeyPattern = RegExp(r'^f\d+$');

  /// 出厂默认里裸用的主键，例如 equal、minus、pageup，用户必须能录回去
  static final Set<ShortcutKey> modifierlessDefaultKeys = DefaultShortcuts
      .all
      .values
      .map(_modifierlessKeyOf)
      .whereType<ShortcutKey>()
      .toSet();

  static bool allows(Set<ShortcutModifier> modifiers, ShortcutKey key) =>
      modifiers.isNotEmpty || allowsModifierless(key);

  static bool allowsModifierless(ShortcutKey key) =>
      _navigationKeys.contains(key) ||
      _functionKeyPattern.hasMatch(key.logicalKey) ||
      modifierlessDefaultKeys.contains(key);

  static ShortcutKey? _modifierlessKeyOf(String shortcut) {
    final parsed = ShortcutParser.parse(shortcut);
    if (parsed == null || parsed.modifiers.isNotEmpty) return null;
    return parsed.key;
  }
}
