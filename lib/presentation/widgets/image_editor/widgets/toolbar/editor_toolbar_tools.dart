import 'package:flutter/widgets.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../core/editor_state.dart';
import '../../core/editor_tool_groups.dart';
import '../../tools/tool_base.dart';
import 'editor_toolbar_flyout.dart';

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

String? editorToolShortcutLabel(EditorTool tool) {
  final label = tool.shortcutKey?.keyLabel;
  return label == null || label.isEmpty ? null : label.toUpperCase();
}

List<EditorToolbarFlyoutItem> editorToolSlotFlyoutItems(
  BuildContext context,
  EditorState state,
  EditorToolSlot slot,
) {
  return [
    for (final entry in slot.entries)
      EditorToolbarFlyoutItem(
        key: ValueKey('editor-tool-flyout-${entry.key}'),
        icon: entry.tool.icon,
        label: editorToolLabel(context, entry.tool, entry.targetRole),
        shortcutLabel: editorToolShortcutLabel(entry.tool),
        selected: isEditorToolEntrySelected(state, entry),
        onActivate: () => activateEditorToolEntry(state, entry),
      ),
  ];
}
