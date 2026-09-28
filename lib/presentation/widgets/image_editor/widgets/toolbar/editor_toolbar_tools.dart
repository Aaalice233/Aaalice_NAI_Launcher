import 'package:flutter/widgets.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../core/editor_state.dart';
import '../../tools/tool_base.dart';

/// 桌面与移动工具栏共用：当前会话与当前图层可用的工具
List<EditorTool> visibleEditorTools(EditorState state) {
  return state.tools.where((tool) => tool.isAvailableIn(state)).toList();
}

/// 清空按钮：蒙版层上是重置蒙版，图片层上是清空当前图层
bool canClearFromToolbar(EditorState state) {
  final active = state.layerManager.activeLayer;
  if (active == null) return false;
  if (active.isMask) {
    return state.layerManager.maskLayers.any((layer) => layer.hasContent);
  }
  return state.rolePolicy.canClear(active);
}

String clearToolbarTooltip(BuildContext context, EditorState state) {
  return state.isMaskLayerActive
      ? context.l10n.editor_resetMask
      : context.l10n.editor_clearLayer;
}

/// 工具可用性随会话与当前图层变化，工具栏需要同时监听这些来源
Listenable editorToolAvailability(EditorState state) {
  return Listenable.merge([
    state.toolNotifier,
    state.layerManager.activeLayerNotifier,
    state.layerManager,
  ]);
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
    'move' => context.l10n.editor_toolMove,
    _ => tool.name,
  };
}
