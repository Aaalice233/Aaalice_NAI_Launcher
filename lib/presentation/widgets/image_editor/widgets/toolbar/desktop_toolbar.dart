import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../adaptive/interaction_policy.dart';
import '../../core/editor_state.dart';
import '../../core/editor_tool_groups.dart';
import '../../core/editor_view_action.dart';
import '../../tools/tool_base.dart';
import '../../../../widgets/common/themed_divider.dart';
import 'editor_tool_group_section.dart';
import 'editor_toolbar_tools.dart';
import 'editor_view_menu.dart';

/// 桌面端垂直工具栏
class DesktopToolbar extends StatelessWidget {
  final EditorState state;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onClear;

  const DesktopToolbar({
    super.key,
    required this.state,
    this.onUndo,
    this.onRedo,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minimumControlExtent = context.interactionPolicy.minimumControlExtent;

    return Container(
      width: minimumControlExtent + 8,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.24),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final editing = _buildEditingSections(
              context,
              minimumControlExtent,
            );
            final view = _ViewControls(
              state: state,
              minimumExtent: minimumControlExtent,
            );
            if (constraints.maxHeight >=
                _ViewControls.pinnedHeightFor(minimumControlExtent)) {
              return Column(
                children: [
                  Expanded(child: SingleChildScrollView(child: editing)),
                  view,
                ],
              );
            }
            return SingleChildScrollView(
              child: Column(children: [editing, view]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEditingSections(
    BuildContext context,
    double minimumControlExtent,
  ) {
    return Column(
      children: [
        // 工具分组 - 监听工具切换与当前图层
        ListenableBuilder(
          listenable: editorToolAvailability(state),
          builder: (context, _) =>
              _ToolSections(state: state, minimumExtent: minimumControlExtent),
        ),
        const ThemedDivider(height: 16),
        // 撤销/重做/清空 - 监听历史、图层内容与当前图层
        ListenableBuilder(
          listenable: Listenable.merge([
            state.historyManager,
            state.layerManager,
            state.layerManager.activeLayerNotifier,
          ]),
          builder: (context, _) {
            return Column(
              children: [
                _ActionButton(
                  minimumExtent: minimumControlExtent,
                  icon: Icons.undo,
                  tooltip: context.l10n.editor_shortcutUndo,
                  enabled: state.canUndo,
                  onTap: onUndo ?? () => state.undo(),
                ),
                _ActionButton(
                  minimumExtent: minimumControlExtent,
                  icon: Icons.redo,
                  tooltip: context.l10n.editor_shortcutRedo,
                  enabled: state.canRedo,
                  onTap: onRedo ?? () => state.redo(),
                ),
                _ActionButton(
                  minimumExtent: minimumControlExtent,
                  icon: Icons.delete_outline,
                  tooltip: clearToolbarTooltip(context, state),
                  enabled: canClearFromToolbar(state),
                  onTap: onClear ?? () => state.clearActiveLayerWithHistory(),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ToolSections extends StatelessWidget {
  const _ToolSections({required this.state, required this.minimumExtent});

  final EditorState state;
  final double minimumExtent;

  static const double _sectionGap = 8;

  @override
  Widget build(BuildContext context) {
    final showTitles = showsEditorToolGroupTitles(state);
    final sections = editorToolSections(state);
    return Column(
      children: [
        for (final (index, section) in sections.indexed) ...[
          if (index > 0) const SizedBox(height: _sectionGap),
          EditorToolGroupSection(
            key: ValueKey('editor-tool-group-${section.group.name}'),
            axis: Axis.vertical,
            title: showTitles
                ? editorToolGroupLabel(context, section.group)
                : null,
            children: [
              for (final entry in section.entries)
                _ToolButton(
                  key: ValueKey('editor-tool-${entry.key}'),
                  tool: entry.tool,
                  label: editorToolLabel(context, entry.tool, entry.targetRole),
                  isSelected: isEditorToolEntrySelected(state, entry),
                  minimumExtent: minimumExtent,
                  onTap: () => activateEditorToolEntry(state, entry),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 缩放与视图方向控制，缩放比例本身是完整视图菜单的入口
class _ViewControls extends StatelessWidget {
  const _ViewControls({required this.state, required this.minimumExtent});

  final EditorState state;
  final double minimumExtent;

  static const _orientationActions = [
    EditorViewAction.fitToWindow,
    EditorViewAction.rotateLeft,
    EditorViewAction.rotateRight,
    EditorViewAction.mirror,
    EditorViewAction.resetView,
  ];

  static const _dividerHeight = 16.0;

  /// 放大、缩放比例、缩小
  static const _zoomControlRows = 3;

  static final int _rowCount = _zoomControlRows + _orientationActions.length;

  // 固定在底部后工具区至少还要露出四个按钮，否则整列一起滚动
  static const _minimumVisibleToolRows = 4;

  static double pinnedHeightFor(double minimumExtent) =>
      (_rowCount + _minimumVisibleToolRows) *
          _ActionButton.rowExtent(minimumExtent) +
      _dividerHeight;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state.canvasController,
      builder: (context, _) {
        final controller = state.canvasController;
        return Column(
          children: [
            const ThemedDivider(height: _dividerHeight),
            _ActionButton(
              minimumExtent: minimumExtent,
              icon: Icons.zoom_in,
              tooltip: context.l10n.editor_zoomIn,
              onTap: () => controller.zoomIn(),
            ),
            _ZoomMenuButton(state: state, minimumExtent: minimumExtent),
            _ActionButton(
              minimumExtent: minimumExtent,
              icon: Icons.zoom_out,
              tooltip: context.l10n.editor_zoomOut,
              onTap: () => controller.zoomOut(),
            ),
            for (final action in _orientationActions)
              _ActionButton(
                key: ValueKey('editor-view-button-${action.name}'),
                minimumExtent: minimumExtent,
                icon: action.icon,
                tooltip: action.tooltip(context),
                toggled: action.isToggle ? action.isActiveIn(controller) : null,
                onTap: () => action.perform(state),
              ),
          ],
        );
      },
    );
  }
}

/// 显示缩放比例；没有键盘时 100%、适应宽高、单独重置旋转都从这里进入
class _ZoomMenuButton extends StatelessWidget {
  const _ZoomMenuButton({required this.state, required this.minimumExtent});

  final EditorState state;
  final double minimumExtent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _ActionButton.spacing),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: PopupMenuButton<VoidCallback>(
          key: const ValueKey('editor-view-zoom-menu'),
          tooltip: context.l10n.editor_viewOptions,
          onSelected: (action) => action(),
          itemBuilder: (menuContext) =>
              editorViewMenuEntries(menuContext, state),
          child: Container(
            width: minimumExtent,
            constraints: BoxConstraints(minHeight: minimumExtent),
            alignment: Alignment.center,
            child: Text(
              '${(state.canvasController.scale * 100).round()}%',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// 工具按钮
class _ToolButton extends StatelessWidget {
  final EditorTool tool;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final double minimumExtent;

  const _ToolButton({
    super.key,
    required this.tool,
    required this.label,
    required this.isSelected,
    required this.minimumExtent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: _buildTooltipMessage(context),
        child: Semantics(
          button: true,
          selected: isSelected,
          child: Material(
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: minimumExtent,
                height: minimumExtent,
                alignment: Alignment.center,
                child: Icon(
                  tool.icon,
                  size: 20,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getShortcutLabel(EditorTool tool) {
    final key = tool.shortcutKey;
    if (key == null) return '';
    final keyLabel = key.keyLabel;
    return keyLabel.isNotEmpty ? keyLabel.toUpperCase() : '';
  }

  String _buildTooltipMessage(BuildContext context) {
    final shortcut = tool.shortcutKey != null
        ? ' (${_getShortcutLabel(tool)})'
        : '';
    final base = '$label$shortcut';

    if (tool.id == 'color_picker') {
      return '$base\n${context.l10n.editor_tempColorPickerShortcut}';
    }

    return base;
  }
}

/// 操作按钮
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;
  final double minimumExtent;

  /// 非空时按开关呈现，true 为选中
  final bool? toggled;

  const _ActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.minimumExtent,
    this.enabled = true,
    this.toggled,
  });

  static const double spacing = 2;

  static double rowExtent(double minimumExtent) => minimumExtent + spacing * 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = toggled ?? false;
    final foreground = !enabled
        ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
        : selected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: spacing),
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          toggled: toggled,
          child: Material(
            color: selected
                ? theme.colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: minimumExtent,
                height: minimumExtent,
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
