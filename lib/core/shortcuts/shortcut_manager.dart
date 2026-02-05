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
  static LogicalKeyboardKey? _getLogicalKey(ShortcutKey key) {
    switch (key) {
      // 字母键
      case ShortcutKey.keyA:
        return LogicalKeyboardKey.keyA;
      case ShortcutKey.keyB:
        return LogicalKeyboardKey.keyB;
      case ShortcutKey.keyC:
        return LogicalKeyboardKey.keyC;
      case ShortcutKey.keyD:
        return LogicalKeyboardKey.keyD;
      case ShortcutKey.keyE:
        return LogicalKeyboardKey.keyE;
      case ShortcutKey.keyF:
        return LogicalKeyboardKey.keyF;
      case ShortcutKey.keyG:
        return LogicalKeyboardKey.keyG;
      case ShortcutKey.keyH:
        return LogicalKeyboardKey.keyH;
      case ShortcutKey.keyI:
        return LogicalKeyboardKey.keyI;
      case ShortcutKey.keyJ:
        return LogicalKeyboardKey.keyJ;
      case ShortcutKey.keyK:
        return LogicalKeyboardKey.keyK;
      case ShortcutKey.keyL:
        return LogicalKeyboardKey.keyL;
      case ShortcutKey.keyM:
        return LogicalKeyboardKey.keyM;
      case ShortcutKey.keyN:
        return LogicalKeyboardKey.keyN;
      case ShortcutKey.keyO:
        return LogicalKeyboardKey.keyO;
      case ShortcutKey.keyP:
        return LogicalKeyboardKey.keyP;
      case ShortcutKey.keyQ:
        return LogicalKeyboardKey.keyQ;
      case ShortcutKey.keyR:
        return LogicalKeyboardKey.keyR;
      case ShortcutKey.keyS:
        return LogicalKeyboardKey.keyS;
      case ShortcutKey.keyT:
        return LogicalKeyboardKey.keyT;
      case ShortcutKey.keyU:
        return LogicalKeyboardKey.keyU;
      case ShortcutKey.keyV:
        return LogicalKeyboardKey.keyV;
      case ShortcutKey.keyW:
        return LogicalKeyboardKey.keyW;
      case ShortcutKey.keyX:
        return LogicalKeyboardKey.keyX;
      case ShortcutKey.keyY:
        return LogicalKeyboardKey.keyY;
      case ShortcutKey.keyZ:
        return LogicalKeyboardKey.keyZ;

      // 数字键
      case ShortcutKey.digit0:
        return LogicalKeyboardKey.digit0;
      case ShortcutKey.digit1:
        return LogicalKeyboardKey.digit1;
      case ShortcutKey.digit2:
        return LogicalKeyboardKey.digit2;
      case ShortcutKey.digit3:
        return LogicalKeyboardKey.digit3;
      case ShortcutKey.digit4:
        return LogicalKeyboardKey.digit4;
      case ShortcutKey.digit5:
        return LogicalKeyboardKey.digit5;
      case ShortcutKey.digit6:
        return LogicalKeyboardKey.digit6;
      case ShortcutKey.digit7:
        return LogicalKeyboardKey.digit7;
      case ShortcutKey.digit8:
        return LogicalKeyboardKey.digit8;
      case ShortcutKey.digit9:
        return LogicalKeyboardKey.digit9;

      // 功能键
      case ShortcutKey.f1:
        return LogicalKeyboardKey.f1;
      case ShortcutKey.f2:
        return LogicalKeyboardKey.f2;
      case ShortcutKey.f3:
        return LogicalKeyboardKey.f3;
      case ShortcutKey.f4:
        return LogicalKeyboardKey.f4;
      case ShortcutKey.f5:
        return LogicalKeyboardKey.f5;
      case ShortcutKey.f6:
        return LogicalKeyboardKey.f6;
      case ShortcutKey.f7:
        return LogicalKeyboardKey.f7;
      case ShortcutKey.f8:
        return LogicalKeyboardKey.f8;
      case ShortcutKey.f9:
        return LogicalKeyboardKey.f9;
      case ShortcutKey.f10:
        return LogicalKeyboardKey.f10;
      case ShortcutKey.f11:
        return LogicalKeyboardKey.f11;
      case ShortcutKey.f12:
        return LogicalKeyboardKey.f12;

      // 特殊键
      case ShortcutKey.enter:
        return LogicalKeyboardKey.enter;
      case ShortcutKey.escape:
        return LogicalKeyboardKey.escape;
      case ShortcutKey.space:
        return LogicalKeyboardKey.space;
      case ShortcutKey.tab:
        return LogicalKeyboardKey.tab;
      case ShortcutKey.backspace:
        return LogicalKeyboardKey.backspace;
      case ShortcutKey.delete:
        return LogicalKeyboardKey.delete;
      case ShortcutKey.insert:
        return LogicalKeyboardKey.insert;
      case ShortcutKey.home:
        return LogicalKeyboardKey.home;
      case ShortcutKey.end:
        return LogicalKeyboardKey.end;
      case ShortcutKey.pageup:
        return LogicalKeyboardKey.pageUp;
      case ShortcutKey.pagedown:
        return LogicalKeyboardKey.pageDown;

      // 方向键
      case ShortcutKey.arrowup:
        return LogicalKeyboardKey.arrowUp;
      case ShortcutKey.arrowdown:
        return LogicalKeyboardKey.arrowDown;
      case ShortcutKey.arrowleft:
        return LogicalKeyboardKey.arrowLeft;
      case ShortcutKey.arrowright:
        return LogicalKeyboardKey.arrowRight;

      // 符号键
      case ShortcutKey.comma:
        return LogicalKeyboardKey.comma;
      case ShortcutKey.period:
        return LogicalKeyboardKey.period;
      case ShortcutKey.slash:
        return LogicalKeyboardKey.slash;
      case ShortcutKey.semicolon:
        return LogicalKeyboardKey.semicolon;
      case ShortcutKey.quote:
        return LogicalKeyboardKey.quoteSingle;
      case ShortcutKey.bracketleft:
        return LogicalKeyboardKey.bracketLeft;
      case ShortcutKey.bracketright:
        return LogicalKeyboardKey.bracketRight;
      case ShortcutKey.backslash:
        return LogicalKeyboardKey.backslash;
      case ShortcutKey.minus:
        return LogicalKeyboardKey.minus;
      case ShortcutKey.equal:
        return LogicalKeyboardKey.equal;
      case ShortcutKey.backquote:
        return LogicalKeyboardKey.backquote;
    }
  }

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
        parts.add('⌘');
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
