import 'package:flutter/material.dart';
import 'shortcut_config.dart';
import 'shortcut_key_mapping.dart';

/// 快捷键管理器
/// 负责解析快捷键、创建ShortcutActivator、处理平台适配
class AppShortcutManager {
  /// 解析快捷键字符串为Flutter的ShortcutActivator
  /// 格式: "ctrl+shift+enter" 或 "alt+f1"
  static ShortcutActivator? parseActivator(String? shortcut) {
    if (shortcut == null || shortcut.isEmpty) return null;

    final parsed = ShortcutParser.parse(shortcut);
    if (parsed == null) return null;

    return LogicalKeySet.fromSet(parsed.logicalKeys);
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
