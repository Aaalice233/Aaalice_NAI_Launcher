import 'package:flutter/widgets.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../core/editor_state.dart';

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

/// 工具入口的选中态随会话与当前图层变化，工具栏需要同时监听这些来源
Listenable editorToolAvailability(EditorState state) {
  return Listenable.merge([
    state.toolNotifier,
    state.layerManager.activeLayerNotifier,
    state.layerManager,
  ]);
}
