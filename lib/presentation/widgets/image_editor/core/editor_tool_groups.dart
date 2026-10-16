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

/// 工具栏上的一个按钮；同组同族的入口折叠在一起，多于一个时可展开
@immutable
class EditorToolSlot {
  const EditorToolSlot({required this.group, required this.entries})
    : assert(entries.length > 0);

  final EditorToolGroup group;
  final List<EditorToolEntry> entries;

  EditorToolFamily? get family => entries.first.tool.family;

  bool get isFolded => entries.length > 1;

  /// 折叠按钮的身份不随显示的工具变化
  String get key {
    final family = this.family;
    return isFolded ? editorToolSlotKey(group, family!) : entries.single.key;
  }
}

String editorToolSlotKey(EditorToolGroup group, EditorToolFamily family) =>
    '${group.name}:family:${family.name}';

@immutable
class EditorToolSection {
  const EditorToolSection({required this.group, required this.slots});

  final EditorToolGroup group;
  final List<EditorToolSlot> slots;
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
      add(_sharedToolGroup(tool, rolesEnabled: rolesEnabled), tool, null);
    } else if (!rolesEnabled) {
      if (tool.supportsRole(LayerRole.image)) {
        add(EditorToolGroup.edit, tool, null);
      }
    } else {
      for (final role in const [LayerRole.mask, LayerRole.image]) {
        if (tool.supportsRole(role) && presentRoles.contains(role)) {
          add(_roleGroup(role), tool, role);
        }
      }
    }
  }

  return [
    for (final group in EditorToolGroup.values)
      if (entriesByGroup[group]!.isNotEmpty)
        EditorToolSection(
          group: group,
          slots: _foldIntoSlots(group, entriesByGroup[group]!),
        ),
  ];
}

EditorToolGroup _roleGroup(LayerRole role) => switch (role) {
  LayerRole.mask => EditorToolGroup.inpaint,
  LayerRole.image => EditorToolGroup.edit,
};

EditorToolGroup _sharedToolGroup(
  EditorTool tool, {
  required bool rolesEnabled,
}) {
  return rolesEnabled && tool.belongsToInpaintGroup
      ? EditorToolGroup.inpaint
      : EditorToolGroup.common;
}

// 重绘组是主任务，蒙版工具都要一键可达，不折叠
bool _foldsFamilies(EditorToolGroup group) => group != EditorToolGroup.inpaint;

/// 族里第一个工具的位置决定折叠按钮的位置
List<EditorToolSlot> _foldIntoSlots(
  EditorToolGroup group,
  List<EditorToolEntry> entries,
) {
  final folds = _foldsFamilies(group);
  final membersByKey = <Object, List<EditorToolEntry>>{};
  for (final entry in entries) {
    final family = folds ? entry.tool.family : null;
    (membersByKey[family ?? entry] ??= []).add(entry);
  }
  return [
    for (final members in membersByKey.values)
      EditorToolSlot(group: group, entries: List.unmodifiable(members)),
  ];
}

/// 当前工具此刻落在哪一组；与 [editorToolSections] 的归组规则一致
EditorToolGroup editorToolGroupOf(EditorState state, EditorTool tool) {
  final rolesEnabled = state.rolePolicy.rolesEnabled;
  if (!tool.followsLayerRole) {
    return _sharedToolGroup(tool, rolesEnabled: rolesEnabled);
  }
  return rolesEnabled
      ? _roleGroup(state.activeLayerRole)
      : EditorToolGroup.edit;
}

/// 快捷键、图层切换等任何途径选中折叠工具，都让它成为该按钮之后显示的工具
void rememberSelectedToolSlot(EditorState state) {
  final tool = state.currentTool;
  final family = tool?.family;
  if (tool == null || family == null) return;
  final group = editorToolGroupOf(state, tool);
  if (!_foldsFamilies(group)) return;
  state.toolbarSlotMemory.remember(editorToolSlotKey(group, family), tool.id);
}

EditorToolEntry displayedEntryOf(EditorState state, EditorToolSlot slot) {
  final entries = slot.entries;
  if (!slot.isFolded) return entries.single;
  final selected = entries.indexWhere(
    (entry) => isEditorToolEntrySelected(state, entry),
  );
  final index = state.toolbarSlotMemory.displayedIndex(
    slot.key,
    [for (final entry in entries) entry.tool.id],
    selectedIndex: selected < 0 ? null : selected,
  );
  return entries[index];
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
