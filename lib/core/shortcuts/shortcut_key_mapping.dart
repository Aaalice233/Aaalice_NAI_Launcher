import 'package:flutter/services.dart';

import 'shortcut_config.dart';

/// ShortcutKey / ShortcutModifier 到 Flutter LogicalKeyboardKey 的唯一映射。
/// 新增枚举值时穷尽 switch 会直接编译报错，避免各处映射表漏改。

extension ShortcutKeyLogicalMapping on ShortcutKey {
  LogicalKeyboardKey get logicalKeyboardKey => switch (this) {
    // 字母键
    ShortcutKey.keyA => LogicalKeyboardKey.keyA,
    ShortcutKey.keyB => LogicalKeyboardKey.keyB,
    ShortcutKey.keyC => LogicalKeyboardKey.keyC,
    ShortcutKey.keyD => LogicalKeyboardKey.keyD,
    ShortcutKey.keyE => LogicalKeyboardKey.keyE,
    ShortcutKey.keyF => LogicalKeyboardKey.keyF,
    ShortcutKey.keyG => LogicalKeyboardKey.keyG,
    ShortcutKey.keyH => LogicalKeyboardKey.keyH,
    ShortcutKey.keyI => LogicalKeyboardKey.keyI,
    ShortcutKey.keyJ => LogicalKeyboardKey.keyJ,
    ShortcutKey.keyK => LogicalKeyboardKey.keyK,
    ShortcutKey.keyL => LogicalKeyboardKey.keyL,
    ShortcutKey.keyM => LogicalKeyboardKey.keyM,
    ShortcutKey.keyN => LogicalKeyboardKey.keyN,
    ShortcutKey.keyO => LogicalKeyboardKey.keyO,
    ShortcutKey.keyP => LogicalKeyboardKey.keyP,
    ShortcutKey.keyQ => LogicalKeyboardKey.keyQ,
    ShortcutKey.keyR => LogicalKeyboardKey.keyR,
    ShortcutKey.keyS => LogicalKeyboardKey.keyS,
    ShortcutKey.keyT => LogicalKeyboardKey.keyT,
    ShortcutKey.keyU => LogicalKeyboardKey.keyU,
    ShortcutKey.keyV => LogicalKeyboardKey.keyV,
    ShortcutKey.keyW => LogicalKeyboardKey.keyW,
    ShortcutKey.keyX => LogicalKeyboardKey.keyX,
    ShortcutKey.keyY => LogicalKeyboardKey.keyY,
    ShortcutKey.keyZ => LogicalKeyboardKey.keyZ,
    // 数字键
    ShortcutKey.digit0 => LogicalKeyboardKey.digit0,
    ShortcutKey.digit1 => LogicalKeyboardKey.digit1,
    ShortcutKey.digit2 => LogicalKeyboardKey.digit2,
    ShortcutKey.digit3 => LogicalKeyboardKey.digit3,
    ShortcutKey.digit4 => LogicalKeyboardKey.digit4,
    ShortcutKey.digit5 => LogicalKeyboardKey.digit5,
    ShortcutKey.digit6 => LogicalKeyboardKey.digit6,
    ShortcutKey.digit7 => LogicalKeyboardKey.digit7,
    ShortcutKey.digit8 => LogicalKeyboardKey.digit8,
    ShortcutKey.digit9 => LogicalKeyboardKey.digit9,
    // 功能键
    ShortcutKey.f1 => LogicalKeyboardKey.f1,
    ShortcutKey.f2 => LogicalKeyboardKey.f2,
    ShortcutKey.f3 => LogicalKeyboardKey.f3,
    ShortcutKey.f4 => LogicalKeyboardKey.f4,
    ShortcutKey.f5 => LogicalKeyboardKey.f5,
    ShortcutKey.f6 => LogicalKeyboardKey.f6,
    ShortcutKey.f7 => LogicalKeyboardKey.f7,
    ShortcutKey.f8 => LogicalKeyboardKey.f8,
    ShortcutKey.f9 => LogicalKeyboardKey.f9,
    ShortcutKey.f10 => LogicalKeyboardKey.f10,
    ShortcutKey.f11 => LogicalKeyboardKey.f11,
    ShortcutKey.f12 => LogicalKeyboardKey.f12,
    // 特殊键
    ShortcutKey.enter => LogicalKeyboardKey.enter,
    ShortcutKey.escape => LogicalKeyboardKey.escape,
    ShortcutKey.space => LogicalKeyboardKey.space,
    ShortcutKey.tab => LogicalKeyboardKey.tab,
    ShortcutKey.backspace => LogicalKeyboardKey.backspace,
    ShortcutKey.delete => LogicalKeyboardKey.delete,
    ShortcutKey.insert => LogicalKeyboardKey.insert,
    ShortcutKey.home => LogicalKeyboardKey.home,
    ShortcutKey.end => LogicalKeyboardKey.end,
    ShortcutKey.pageup => LogicalKeyboardKey.pageUp,
    ShortcutKey.pagedown => LogicalKeyboardKey.pageDown,
    // 方向键
    ShortcutKey.arrowup => LogicalKeyboardKey.arrowUp,
    ShortcutKey.arrowdown => LogicalKeyboardKey.arrowDown,
    ShortcutKey.arrowleft => LogicalKeyboardKey.arrowLeft,
    ShortcutKey.arrowright => LogicalKeyboardKey.arrowRight,
    // 符号键
    ShortcutKey.comma => LogicalKeyboardKey.comma,
    ShortcutKey.period => LogicalKeyboardKey.period,
    ShortcutKey.slash => LogicalKeyboardKey.slash,
    ShortcutKey.semicolon => LogicalKeyboardKey.semicolon,
    ShortcutKey.quote => LogicalKeyboardKey.quoteSingle,
    ShortcutKey.bracketleft => LogicalKeyboardKey.bracketLeft,
    ShortcutKey.bracketright => LogicalKeyboardKey.bracketRight,
    ShortcutKey.backslash => LogicalKeyboardKey.backslash,
    ShortcutKey.minus => LogicalKeyboardKey.minus,
    ShortcutKey.equal => LogicalKeyboardKey.equal,
    ShortcutKey.backquote => LogicalKeyboardKey.backquote,
  };
}

extension ShortcutModifierLogicalMapping on ShortcutModifier {
  /// 用左右不敏感的合成键，保证任意一侧修饰键都能命中
  LogicalKeyboardKey get logicalKeyboardKey => switch (this) {
    ShortcutModifier.control => LogicalKeyboardKey.control,
    ShortcutModifier.alt => LogicalKeyboardKey.alt,
    ShortcutModifier.shift => LogicalKeyboardKey.shift,
    ShortcutModifier.meta => LogicalKeyboardKey.meta,
  };
}

extension ParsedShortcutLogicalKeys on ParsedShortcut {
  /// LogicalKeySet 语义：修饰键与主键同时出现在集合里
  Set<LogicalKeyboardKey> get logicalKeys => {
    for (final modifier in modifiers) modifier.logicalKeyboardKey,
    key.logicalKeyboardKey,
  };
}
