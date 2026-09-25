import 'package:flutter/widgets.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../core/editor_state.dart';
import '../../tools/tool_base.dart';

/// 桌面与移动工具栏共用：当前会话可用、且在模式白名单内的工具
List<EditorTool> visibleEditorTools(
  EditorState state,
  Set<String>? allowedToolIds,
) {
  final allowed = allowedToolIds;
  return state.tools
      .where((tool) => tool.isAvailableIn(state))
      .where(
        (tool) =>
            allowed == null || allowed.isEmpty || allowed.contains(tool.id),
      )
      .toList();
}

String localizedEditorToolName(BuildContext context, EditorTool tool) {
  return switch (tool.id) {
    'brush' => context.l10n.editor_toolBrush,
    'eraser' => context.l10n.editor_toolEraser,
    'fill' => context.l10n.editor_toolFill,
    'magic_wand' => context.l10n.editor_toolMagicWand,
    'line' => context.l10n.editor_toolLine,
    'rect_selection' => context.l10n.editor_toolRectSelect,
    'ellipse_selection' => context.l10n.editor_toolEllipseSelect,
    'lasso_selection' => context.l10n.editor_toolLassoSelect,
    'color_picker' => context.l10n.editor_toolColorPicker,
    'clone_stamp' => context.l10n.editor_toolCloneStamp,
    'blur' => context.l10n.editor_toolBlur,
    'frame' => context.l10n.editor_toolFrame,
    _ => tool.name,
  };
}
