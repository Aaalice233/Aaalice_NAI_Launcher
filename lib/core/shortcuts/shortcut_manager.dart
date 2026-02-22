import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'shortcut_config.dart';

/// 快捷键管理器
/// 负责解析快捷键、创建ShortcutActivator、处理平台适配
class AppShortcutManager {
  /// 解析快捷键字符串为Flutter的ShortcutActivator
  /// 格式: "ctrl+shift+enter" 或 "alt+f1"
  static ShortcutActivator? parseActivator(String? shortcut) {
    if (shortcut == null || shortcut.isEmpty) return null;

    final parsed = ShortcutParser.parse(shortcut);
    if (parsed == null) return null;

    // 构建LogicalKeySet
    final keys = <LogicalKeyboardKey>{};

    // 添加修饰键
    if (parsed.modifiers.contains(ShortcutModifier.control)) {
      keys.add(LogicalKeyboardKey.control);
    }
    if (parsed.modifiers.contains(ShortcutModifier.alt)) {
      keys.add(LogicalKeyboardKey.alt);
    }
    if (parsed.modifiers.contains(ShortcutModifier.shift)) {
      keys.add(LogicalKeyboardKey.shift);
    }
    if (parsed.modifiers.contains(ShortcutModifier.meta)) {
      keys.add(LogicalKeyboardKey.meta);
    }

    // 添加主键
    final mainKey = _getLogicalKey(parsed.key);
    if (mainKey == null) return null;

    keys.add(mainKey);

    return LogicalKeySet.fromSet(keys);
  }

  /// 将ShortcutKey转换为Flutter的LogicalKeyboardKey
  static LogicalKeyboardKey? _getLogicalKey(ShortcutKey key) => switch (key) {
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

  /// 获取快捷键的显示文本（平台适配）
  /// Windows/Linux: Ctrl+Shift+A
  /// Mac: ⌘⇧A
  static String getDisplayLabel(String? shortcut, {bool useSymbols = false}) {
    if (shortcut == null || shortcut.isEmpty) return '';

    final parsed = ShortcutParser.parse(shortcut);
    if (parsed == null) return shortcut;

    if (useSymbols) {
      // 使用符号表示（适合Mac）
      final parts = <String>[];
      if (parsed.modifiers.contains(ShortcutModifier.control)) {
        parts.add('⌃');
      }
      if (parsed.modifiers.contains(ShortcutModifier.alt)) {
        parts.add('⌥');
      }
      if (parsed.modifiers.contains(ShortcutModifier.shift)) {
        parts.add('⇧');
      }
      if (parsed.modifiers.contains(ShortcutModifier.meta)) {
        parts.add('⌘');
      }
      parts.add(parsed.key.displayName);
      return parts.join();
    } else {
      // 使用文本表示（适合Windows/Linux）
      return parsed.displayLabel;
    }
  }

  /// 检查快捷键是否有效
  static bool isValidShortcut(String shortcut) {
    return ShortcutParser.parse(shortcut) != null;
  }

  /// 规范化快捷键字符串
  static String normalize(String shortcut) {
    final parsed = ShortcutParser.parse(shortcut);
    if (parsed == null) return shortcut;
    return ShortcutParser.serialize(parsed);
  }

  /// 创建ShortcutMap（用于Shortcuts widget）
  /// 从配置和动作映射创建快捷键映射
  static Map<ShortcutActivator, Intent> buildShortcutMap(
    ShortcutConfig config,
    Map<String, Intent> actionIntents,
  ) {
    final map = <ShortcutActivator, Intent>{};

    for (final entry in actionIntents.entries) {
      final shortcutId = entry.key;
      final intent = entry.value;

      final shortcut = config.getEffectiveShortcut(shortcutId);
      if (shortcut == null) continue;

      final activator = parseActivator(shortcut);
      if (activator == null) continue;

      map[activator] = intent;
    }

    return map;
  }

  /// 创建Actions Map
  static Map<Type, Action<Intent>> buildActionsMap(
    Map<Type, Action<Intent>> actionMap,
  ) {
    return actionMap;
  }
}

/// 通用快捷键Intent基类
abstract class AppShortcutIntent extends Intent {
  const AppShortcutIntent();
}

/// 页面导航Intents
class NavigateToGenerationIntent extends AppShortcutIntent {
  const NavigateToGenerationIntent();
}

class NavigateToLocalGalleryIntent extends AppShortcutIntent {
  const NavigateToLocalGalleryIntent();
}

class NavigateToOnlineGalleryIntent extends AppShortcutIntent {
  const NavigateToOnlineGalleryIntent();
}

class NavigateToRandomConfigIntent extends AppShortcutIntent {
  const NavigateToRandomConfigIntent();
}

class NavigateToTagLibraryIntent extends AppShortcutIntent {
  const NavigateToTagLibraryIntent();
}

class NavigateToStatisticsIntent extends AppShortcutIntent {
  const NavigateToStatisticsIntent();
}

class NavigateToSettingsIntent extends AppShortcutIntent {
  const NavigateToSettingsIntent();
}

/// 生成页面Intents
class GenerateImageIntent extends AppShortcutIntent {
  const GenerateImageIntent();
}

class CancelGenerationIntent extends AppShortcutIntent {
  const CancelGenerationIntent();
}

class AddToQueueIntent extends AppShortcutIntent {
  const AddToQueueIntent();
}

class RandomPromptIntent extends AppShortcutIntent {
  const RandomPromptIntent();
}

class ClearPromptIntent extends AppShortcutIntent {
  const ClearPromptIntent();
}

class TogglePromptModeIntent extends AppShortcutIntent {
  const TogglePromptModeIntent();
}

class OpenTagLibraryIntent extends AppShortcutIntent {
  const OpenTagLibraryIntent();
}

class SaveImageIntent extends AppShortcutIntent {
  const SaveImageIntent();
}

class UpscaleImageIntent extends AppShortcutIntent {
  const UpscaleImageIntent();
}

class CopyImageIntent extends AppShortcutIntent {
  const CopyImageIntent();
}

class FullscreenPreviewIntent extends AppShortcutIntent {
  const FullscreenPreviewIntent();
}

class OpenParamsPanelIntent extends AppShortcutIntent {
  const OpenParamsPanelIntent();
}

class OpenHistoryPanelIntent extends AppShortcutIntent {
  const OpenHistoryPanelIntent();
}

class ReuseParamsIntent extends AppShortcutIntent {
  const ReuseParamsIntent();
}

/// 画廊查看器Intents
class PreviousImageIntent extends AppShortcutIntent {
  const PreviousImageIntent();
}

class NextImageIntent extends AppShortcutIntent {
  const NextImageIntent();
}

class ZoomInIntent extends AppShortcutIntent {
  const ZoomInIntent();
}

class ZoomOutIntent extends AppShortcutIntent {
  const ZoomOutIntent();
}

class ResetZoomIntent extends AppShortcutIntent {
  const ResetZoomIntent();
}

class ToggleFullscreenIntent extends AppShortcutIntent {
  const ToggleFullscreenIntent();
}

class CloseViewerIntent extends AppShortcutIntent {
  const CloseViewerIntent();
}

class ToggleFavoriteIntent extends AppShortcutIntent {
  const ToggleFavoriteIntent();
}

class CopyPromptIntent extends AppShortcutIntent {
  const CopyPromptIntent();
}

class ReuseGalleryParamsIntent extends AppShortcutIntent {
  const ReuseGalleryParamsIntent();
}

class DeleteImageIntent extends AppShortcutIntent {
  const DeleteImageIntent();
}

/// 全局Intents
class ShowShortcutHelpIntent extends AppShortcutIntent {
  const ShowShortcutHelpIntent();
}

class MinimizeToTrayIntent extends AppShortcutIntent {
  const MinimizeToTrayIntent();
}

class QuitAppIntent extends AppShortcutIntent {
  const QuitAppIntent();
}

class ToggleQueueIntent extends AppShortcutIntent {
  const ToggleQueueIntent();
}

class ToggleQueuePauseIntent extends AppShortcutIntent {
  const ToggleQueuePauseIntent();
}

class ToggleThemeIntent extends AppShortcutIntent {
  const ToggleThemeIntent();
}

/// 通用动作回调Intent
class ShortcutCallbackIntent extends AppShortcutIntent {
  final VoidCallback callback;

  const ShortcutCallbackIntent(this.callback);
}

/// 通用回调Action
class ShortcutCallbackAction extends Action<ShortcutCallbackIntent> {
  @override
  void invoke(ShortcutCallbackIntent intent) {
    intent.callback();
  }
}

/// Vibe库导入Intent
/// 触发Vibe导入对话框或流程
class VibeImportIntent extends AppShortcutIntent {
  const VibeImportIntent();
}

/// Vibe库导出Intent
/// 触发Vibe导出对话框或流程
class VibeExportIntent extends AppShortcutIntent {
  const VibeExportIntent();
}
