import 'package:freezed_annotation/freezed_annotation.dart';
import 'default_shortcuts.dart';

part 'shortcut_config.freezed.dart';
part 'shortcut_config.g.dart';

/// 快捷键绑定配置
@freezed
class ShortcutBinding with _$ShortcutBinding {
  const factory ShortcutBinding({
    required String id,
    required String actionKey,
    required String defaultShortcut,
    String? customShortcut,
    @Default(ShortcutContext.global) ShortcutContext context,
    @Default(true) bool enabled,
  }) = _ShortcutBinding;

  const ShortcutBinding._();

  factory ShortcutBinding.fromJson(Map<String, dynamic> json) =>
      _$ShortcutBindingFromJson(json);

  /// 获取当前有效的快捷键（优先使用自定义，否则使用默认）
  String? get effectiveShortcut {
    if (!enabled) return null;
    return customShortcut ?? defaultShortcut;
  }

  /// 检查是否有自定义快捷键
  bool get hasCustomShortcut =>
      customShortcut != null && customShortcut!.isNotEmpty;

  /// 重置为默认快捷键
  ShortcutBinding resetToDefault() => copyWith(customShortcut: null);
}

/// 快捷键配置
@freezed
class ShortcutConfig with _$ShortcutConfig {
  const factory ShortcutConfig({
    @Default({}) Map<String, ShortcutBinding> bindings,
    @Default(true) bool showShortcutBadges,
    @Default(true) bool showShortcutInTooltip,
    @Default(true) bool enableShortcuts,
    @Default(false) bool showInMenus,
  }) = _ShortcutConfig;

  const ShortcutConfig._();

  factory ShortcutConfig.fromJson(Map<String, dynamic> json) =>
      _$ShortcutConfigFromJson(json);

  /// 创建默认配置
  factory ShortcutConfig.createDefault() {
    final bindings = <String, ShortcutBinding>{};

    for (final entry in DefaultShortcuts.all.entries) {
      final id = entry.key;
      final defaultShortcut = entry.value;

      bindings[id] = ShortcutBinding(
        id: id,
        actionKey: DefaultShortcuts.getI18nKey(id),
        defaultShortcut: defaultShortcut,
        context: DefaultShortcuts.getContext(id),
        enabled: DefaultShortcuts.isEnabledByDefault(id),
      );
    }

    return ShortcutConfig(bindings: bindings);
  }

  /// 获取指定ID的快捷键绑定
  ShortcutBinding? getBinding(String id) => bindings[id];

  /// 获取指定ID的有效快捷键字符串
  String? getEffectiveShortcut(String id) => bindings[id]?.effectiveShortcut;

  /// 更新快捷键绑定
  ShortcutConfig updateBinding(ShortcutBinding binding) =>
      copyWith(bindings: {...bindings, binding.id: binding});

  /// 重置所有快捷键为默认
  ShortcutConfig resetAllToDefault() {
    return copyWith(
      bindings: bindings.map(
        (id, binding) => MapEntry(id, binding.resetToDefault()),
      ),
    );
  }

  /// 重置指定快捷键为默认
  ShortcutConfig resetToDefault(String id) {
    final binding = bindings[id];
    if (binding == null) return this;

    return copyWith(
      bindings: {...bindings, id: binding.resetToDefault()},
    );
  }

  /// 设置自定义快捷键
  ShortcutConfig setCustomShortcut(String id, String? shortcut) {
    final binding = bindings[id];
    if (binding == null) return this;

    return copyWith(
      bindings: {...bindings, id: binding.copyWith(customShortcut: shortcut)},
    );
  }

  /// 启用/禁用快捷键
  ShortcutConfig setEnabled(String id, bool enabled) {
    final binding = bindings[id];
    if (binding == null) return this;

    return copyWith(
      bindings: {...bindings, id: binding.copyWith(enabled: enabled)},
    );
  }

  /// 检查快捷键是否有冲突
  /// 返回冲突的快捷键ID列表
  List<String> findConflicts(String shortcut, {String? excludeId}) {
    final conflicts = <String>[];

    for (final entry in bindings.entries) {
      if (entry.key == excludeId) continue;
      if (!entry.value.enabled) continue;

      final effective = entry.value.effectiveShortcut;
      if (effective != null &&
          _normalizeShortcut(effective) == _normalizeShortcut(shortcut)) {
        conflicts.add(entry.key);
      }
    }

    return conflicts;
  }

  /// 按上下文分组获取快捷键
  Map<ShortcutContext, List<ShortcutBinding>> getBindingsByContext() {
    final result = <ShortcutContext, List<ShortcutBinding>>{};

    for (final context in ShortcutContext.values) {
      result[context] = [];
    }

    for (final binding in bindings.values) {
      result[binding.context]?.add(binding);
    }

    // 按ID排序
    for (final list in result.values) {
      list.sort((a, b) => a.id.compareTo(b.id));
    }

    return result;
  }

  /// 搜索快捷键
  List<ShortcutBinding> search(String query) {
    final lowerQuery = query.toLowerCase();
    return bindings.values
        .where(
          (binding) =>
              binding.id.toLowerCase().contains(lowerQuery) ||
              binding.actionKey.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }

  /// 规范化快捷键字符串用于比较
  static String _normalizeShortcut(String shortcut) {
    return shortcut.toLowerCase().replaceAll(' ', '');
  }
}

/// 快捷键解析结果
class ParsedShortcut {
  final Set<ShortcutModifier> modifiers;
  final ShortcutKey key;
  final String raw;

  const ParsedShortcut({
    required this.modifiers,
    required this.key,
    required this.raw,
  });

  /// 检查是否包含修饰键
  bool hasModifier(ShortcutModifier modifier) => modifiers.contains(modifier);

  /// 获取显示文本
  String get displayLabel {
    final parts = <String>[
      if (modifiers.contains(ShortcutModifier.control)) 'Ctrl',
      if (modifiers.contains(ShortcutModifier.alt)) 'Alt',
      if (modifiers.contains(ShortcutModifier.shift)) 'Shift',
      if (modifiers.contains(ShortcutModifier.meta)) '⌘',
      key.displayName,
    ];

    return parts.join('+');
  }

  /// 转换为ShortcutActivator字符串格式
  String toActivatorString() {
    final parts = <String>[
      if (modifiers.contains(ShortcutModifier.control)) 'control',
      if (modifiers.contains(ShortcutModifier.alt)) 'alt',
      if (modifiers.contains(ShortcutModifier.shift)) 'shift',
      if (modifiers.contains(ShortcutModifier.meta)) 'meta',
      key.logicalKey,
    ];

    return parts.join('+');
  }
}

/// 修饰键枚举
enum ShortcutModifier {
  control,
  alt,
  shift,
  meta,
}

/// 快捷键键枚举
enum ShortcutKey {
  // 字母键
  keyA('a', 'A'),
  keyB('b', 'B'),
  keyC('c', 'C'),
  keyD('d', 'D'),
  keyE('e', 'E'),
  keyF('f', 'F'),
  keyG('g', 'G'),
  keyH('h', 'H'),
  keyI('i', 'I'),
  keyJ('j', 'J'),
  keyK('k', 'K'),
  keyL('l', 'L'),
  keyM('m', 'M'),
  keyN('n', 'N'),
  keyO('o', 'O'),
  keyP('p', 'P'),
  keyQ('q', 'Q'),
  keyR('r', 'R'),
  keyS('s', 'S'),
  keyT('t', 'T'),
  keyU('u', 'U'),
  keyV('v', 'V'),
  keyW('w', 'W'),
  keyX('x', 'X'),
  keyY('y', 'Y'),
  keyZ('z', 'Z'),

  // 数字键
  digit0('0', '0'),
  digit1('1', '1'),
  digit2('2', '2'),
  digit3('3', '3'),
  digit4('4', '4'),
  digit5('5', '5'),
  digit6('6', '6'),
  digit7('7', '7'),
  digit8('8', '8'),
  digit9('9', '9'),

  // 功能键
  f1('f1', 'F1'),
  f2('f2', 'F2'),
  f3('f3', 'F3'),
  f4('f4', 'F4'),
  f5('f5', 'F5'),
  f6('f6', 'F6'),
  f7('f7', 'F7'),
  f8('f8', 'F8'),
  f9('f9', 'F9'),
  f10('f10', 'F10'),
  f11('f11', 'F11'),
  f12('f12', 'F12'),

  // 特殊键
  enter('enter', 'Enter'),
  escape('escape', 'Esc'),
  space('space', 'Space'),
  tab('tab', 'Tab'),
  backspace('backspace', 'Backspace'),
  delete('delete', 'Delete'),
  insert('insert', 'Insert'),
  home('home', 'Home'),
  end('end', 'End'),
  pageup('pageup', 'PageUp'),
  pagedown('pagedown', 'PageDown'),

  // 方向键
  arrowup('arrowup', '↑'),
  arrowdown('arrowdown', '↓'),
  arrowleft('arrowleft', '←'),
  arrowright('arrowright', '→'),

  // 符号键
  comma('comma', ','),
  period('period', '.'),
  slash('slash', '/'),
  semicolon('semicolon', ';'),
  quote('quote', "'"),
  bracketleft('bracketleft', '['),
  bracketright('bracketright', ']'),
  backslash('backslash', '\\'),
  minus('minus', '-'),
  equal('equal', '='),
  backquote('backquote', '`');

  final String logicalKey;
  final String displayName;

  const ShortcutKey(this.logicalKey, this.displayName);

  /// 从字符串解析
  static ShortcutKey? fromString(String value) {
    final normalized = value.toLowerCase().trim();
    return ShortcutKey.values.firstWhere(
      (key) => key.logicalKey == normalized,
      orElse: () => throw ArgumentError('Unknown shortcut key: $value'),
    );
  }
}

/// 快捷键解析器
class ShortcutParser {
  /// 解析快捷键字符串
  /// 格式: "ctrl+shift+enter" 或 "alt+f1" 或 "escape"
  static ParsedShortcut? parse(String shortcut) {
    if (shortcut.isEmpty) return null;

    final parts = shortcut.toLowerCase().split('+');
    final modifiers = <ShortcutModifier>{};
    ShortcutKey? key;

    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      // 检查是否是修饰键
      switch (trimmed) {
        case 'ctrl':
        case 'control':
          modifiers.add(ShortcutModifier.control);
          continue;
        case 'alt':
          modifiers.add(ShortcutModifier.alt);
          continue;
        case 'shift':
          modifiers.add(ShortcutModifier.shift);
          continue;
        case 'meta':
        case 'cmd':
        case 'command':
          modifiers.add(ShortcutModifier.meta);
          continue;
      }

      // 尝试解析为主键
      try {
        key = ShortcutKey.fromString(trimmed);
      } catch (_) {
        // 尝试一些别名
        key = _tryParseAlias(trimmed);
      }
    }

    if (key == null) return null;

    return ParsedShortcut(
      modifiers: modifiers,
      key: key,
      raw: shortcut,
    );
  }

  /// 尝试解析别名
  static ShortcutKey? _tryParseAlias(String value) => switch (value) {
    'left' => ShortcutKey.arrowleft,
    'right' => ShortcutKey.arrowright,
    'up' => ShortcutKey.arrowup,
    'down' => ShortcutKey.arrowdown,
    'esc' => ShortcutKey.escape,
    'del' => ShortcutKey.delete,
    'pgup' => ShortcutKey.pageup,
    'pgdown' => ShortcutKey.pagedown,
    'plus' || '=' => ShortcutKey.equal,
    'minus' || '-' => ShortcutKey.minus,
    _ => null,
  };

  /// 将ParsedShortcut转换回字符串
  static String serialize(ParsedShortcut shortcut) {
    final parts = <String>[
      if (shortcut.modifiers.contains(ShortcutModifier.control)) 'ctrl',
      if (shortcut.modifiers.contains(ShortcutModifier.alt)) 'alt',
      if (shortcut.modifiers.contains(ShortcutModifier.shift)) 'shift',
      if (shortcut.modifiers.contains(ShortcutModifier.meta)) 'meta',
      shortcut.key.logicalKey,
    ];

    return parts.join('+');
  }
}
