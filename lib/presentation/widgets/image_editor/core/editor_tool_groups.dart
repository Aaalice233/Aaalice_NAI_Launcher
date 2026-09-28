import 'package:flutter/widgets.dart';

import '../../../../core/utils/localization_extension.dart';
import '../layers/layer_role.dart';
import '../tools/closed_region_fill_tool.dart';
import '../tools/frame_tool.dart';
import '../tools/tool_base.dart';
import 'editor_state.dart';

/// 重绘组改蒙版，编辑组改图片，通用组作用于当前图层
enum EditorToolGroup { inpaint, edit, common }

/// 工具栏上的一个入口；重绘会话里同一工具在重绘组与编辑组各有一个
@immutable
class EditorToolEntry {
  const EditorToolEntry({
    required this.group,
    required this.tool,
    this.targetRole,
  });

  final EditorToolGroup group;
  final EditorTool tool;

  /// 点入口时切到的图层角色；为空时沿用当前图层
  final LayerRole? targetRole;

  String get key => '${group.name}:${tool.id}';
}

@immutable
class EditorToolSection {
  const EditorToolSection({required this.group, required this.entries});

  final EditorToolGroup group;
  final List<EditorToolEntry> entries;
}

/// 编辑会话的图层没有角色，随角色变化的工具只归入编辑组，也不分出重绘组；
/// 重绘会话里还没有某种角色的图层时，对应入口无处可切，整组不显示
List<EditorToolSection> editorToolSections(EditorState state) {
  final rolesEnabled = state.rolePolicy.rolesEnabled;
  final presentRoles = {
    for (final layer in state.layerManager.layers) layer.role,
  };
  final entriesByGroup = {
    for (final group in EditorToolGroup.values) group: <EditorToolEntry>[],
  };

  void add(EditorToolGroup group, EditorTool tool, LayerRole? role) {
    entriesByGroup[group]!.add(
      EditorToolEntry(group: group, tool: tool, targetRole: role),
    );
  }

  for (final tool in state.tools) {
    if (!tool.isEnabledInSession(state)) continue;
    if (!tool.followsLayerRole) {
      add(EditorToolGroup.common, tool, null);
    } else if (!rolesEnabled) {
      if (tool.supportsRole(LayerRole.image)) {
        add(EditorToolGroup.edit, tool, null);
      }
    } else {
      if (tool.supportsRole(LayerRole.mask) &&
          presentRoles.contains(LayerRole.mask)) {
        add(EditorToolGroup.inpaint, tool, LayerRole.mask);
      }
      if (tool.supportsRole(LayerRole.image) &&
          presentRoles.contains(LayerRole.image)) {
        add(EditorToolGroup.edit, tool, LayerRole.image);
      }
    }
  }

  return [
    for (final group in EditorToolGroup.values)
      if (entriesByGroup[group]!.isNotEmpty)
        EditorToolSection(group: group, entries: entriesByGroup[group]!),
  ];
}

/// 只有重绘会话需要组标题区分改蒙版还是改图片
bool showsEditorToolGroupTitles(EditorState state) =>
    state.rolePolicy.rolesEnabled;

bool isEditorToolEntrySelected(EditorState state, EditorToolEntry entry) {
  if (state.currentTool != entry.tool) return false;
  final role = entry.targetRole;
  return role == null || role == state.activeLayerRole;
}

/// 先切图层再切工具：切图层时当前图层用不了的工具会被退回画笔
void activateEditorToolEntry(EditorState state, EditorToolEntry entry) {
  final role = entry.targetRole;
  if (role != null && state.activeLayerRole != role) {
    final layer = state.layerManager.preferredLayerFor(role);
    if (layer == null) return;
    state.layerManager.setActiveLayer(layer.id);
  }
  state.setTool(entry.tool);
}

/// [role] 为蒙版时给出蒙版版本的名称；工具栏、提示与设置面板标题共用
String editorToolLabel(BuildContext context, EditorTool tool, LayerRole? role) {
  final l10n = context.l10n;
  if (role == LayerRole.mask) {
    final maskLabel = switch (tool.id) {
      'brush' => l10n.editor_toolMaskBrush,
      'eraser' => l10n.editor_toolMaskEraser,
      'fill' => l10n.editor_toolMaskColorFill,
      'magic_wand' => l10n.editor_toolMaskMagicWand,
      ClosedRegionFillTool.toolId => l10n.editor_fillClosedRegion,
      _ => null,
    };
    if (maskLabel != null) return maskLabel;
  }
  return switch (tool.id) {
    'brush' => l10n.editor_toolBrush,
    'eraser' => l10n.editor_toolEraser,
    'fill' => l10n.editor_toolFill,
    'magic_wand' => l10n.editor_toolMagicWand,
    'line' => l10n.editor_toolLine,
    'rect_selection' => l10n.editor_toolRectSelect,
    'ellipse_selection' => l10n.editor_toolEllipseSelect,
    'lasso_selection' => l10n.editor_toolLassoSelect,
    'color_picker' => l10n.editor_toolColorPicker,
    'clone_stamp' => l10n.editor_toolCloneStamp,
    'blur' => l10n.editor_toolBlur,
    FrameTool.toolId => l10n.editor_toolFrame,
    'move' => l10n.editor_toolMove,
    ClosedRegionFillTool.toolId => l10n.editor_fillClosedRegion,
    _ => tool.name,
  };
}

String editorToolGroupLabel(BuildContext context, EditorToolGroup group) {
  final l10n = context.l10n;
  return switch (group) {
    EditorToolGroup.inpaint => l10n.editor_toolGroupInpaint,
    EditorToolGroup.edit => l10n.editor_toolGroupEdit,
    EditorToolGroup.common => l10n.editor_toolGroupCommon,
  };
}
