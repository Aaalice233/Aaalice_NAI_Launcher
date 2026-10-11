import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 图片粘贴与系统文本粘贴同键，各入口先取图片，取不到再交还文本粘贴。
Map<ShortcutActivator, Intent> imagePasteShortcuts(Intent intent) =>
    <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.keyV, control: true): intent,
      const SingleActivator(LogicalKeyboardKey.keyV, meta: true): intent,
    };

/// 按键时记下焦点，异步读完剪贴板后再把文本粘贴交给它。
VoidCallback? textPasteFallbackFor(BuildContext? focusedContext) {
  if (focusedContext == null) return null;
  return () {
    if (!focusedContext.mounted) return;
    Actions.maybeInvoke(
      focusedContext,
      const PasteTextIntent(SelectionChangedCause.keyboard),
    );
  };
}
