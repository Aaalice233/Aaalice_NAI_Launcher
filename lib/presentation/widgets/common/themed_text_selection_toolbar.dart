/// 跟随主题字体的文本选择工具栏（选中文字后的右键菜单）。
///
/// Flutter 自带的工具栏按钮会绕开主题字体，且三个平台各有各的绕法：
/// - 桌面端 [DesktopTextSelectionToolbarButton.text] 与 macOS 的
///   [CupertinoDesktopTextSelectionToolbarButton.text] 都使用了带
///   `inherit: false` 的常量样式，连 [DefaultTextStyle] 都不继承；
/// - Android 的 [TextSelectionToolbarTextButton] 则把 TextButton 的
///   `textStyle` 整体替换成只含 `fontWeight` 的常量。
///
/// 三者都不带 `fontFamily`，于是右键菜单永远落到系统默认字体，用户在设置里
/// 选的字体对它无效。[AdaptiveTextSelectionToolbar.buttonItems] 内部正是走
/// 这些命名构造，所以这里改为自己构造按钮，把字体显式补回去。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 用主题字体构建文本选择工具栏。
///
/// 容器仍交给 [AdaptiveTextSelectionToolbar] 按平台自适应，只接管按钮。
Widget buildThemedTextSelectionToolbar(
  BuildContext context, {
  required TextSelectionToolbarAnchors anchors,
  required List<ContextMenuButtonItem> buttonItems,
}) {
  return AdaptiveTextSelectionToolbar(
    anchors: anchors,
    children: [
      for (var i = 0; i < buttonItems.length; i++)
        _themedToolbarButton(context, buttonItems[i], i, buttonItems.length),
    ],
  );
}

Widget _themedToolbarButton(
  BuildContext context,
  ContextMenuButtonItem item,
  int index,
  int total,
) {
  final label = AdaptiveTextSelectionToolbar.getButtonLabel(context, item);
  // 只覆盖 fontFamily：颜色、字号、字重仍由各平台按钮自己决定，
  // 这样观感不变，只把字体拉回主题。
  final child = Text(
    label,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontFamily: Theme.of(context).textTheme.labelLarge?.fontFamily,
    ),
  );

  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
      return CupertinoDesktopTextSelectionToolbarButton(
        onPressed: item.onPressed,
        child: child,
      );
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return DesktopTextSelectionToolbarButton(
        onPressed: item.onPressed,
        child: child,
      );
    case TargetPlatform.iOS:
      return CupertinoTextSelectionToolbarButton(
        onPressed: item.onPressed,
        child: child,
      );
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
      return TextSelectionToolbarTextButton(
        padding: TextSelectionToolbarTextButton.getPadding(index, total),
        onPressed: item.onPressed,
        child: child,
      );
  }
}

/// 供 [EditableText.contextMenuBuilder] 直接使用的默认实现。
Widget themedContextMenuBuilder(
  BuildContext context,
  EditableTextState editableTextState,
) {
  return buildThemedTextSelectionToolbar(
    context,
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: editableTextState.contextMenuButtonItems,
  );
}
