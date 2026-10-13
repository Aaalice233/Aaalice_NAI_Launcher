import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../adaptive/interaction_policy.dart';
import '../../core/editor_state.dart';
import '../../core/editor_tool_groups.dart';
import '../../core/editor_view_action.dart';
import '../../tools/tool_base.dart';
import '../../../../widgets/common/themed_divider.dart';
import 'editor_tool_group_section.dart';
import 'editor_toolbar_flyout.dart';
import 'editor_toolbar_tools.dart';
import 'editor_view_menu.dart';

// 相邻按钮间只留 2px：1080p 最大化窗口里重绘会话的整列按钮才能不滚动
const double _buttonSpacing = 1;

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
              for (final slot in section.slots)
                _ToolSlot(
                  key: ValueKey('editor-tool-slot-${slot.key}'),
                  state: state,
                  slot: slot,
                  minimumExtent: minimumExtent,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 折叠按钮显示该族当前或最近用过的工具，其余同族工具从侧边二级菜单进入
class _ToolSlot extends StatelessWidget {
  const _ToolSlot({
    super.key,
    required this.state,
    required this.slot,
    required this.minimumExtent,
  });

  final EditorState state;
  final EditorToolSlot slot;
  final double minimumExtent;

  @override
  Widget build(BuildContext context) {
    final entry = displayedEntryOf(state, slot);
    final button = _ToolButton(
      key: ValueKey('editor-tool-${entry.key}'),
      tool: entry.tool,
      label: editorToolLabel(context, entry.tool, entry.targetRole),
      isSelected: isEditorToolEntrySelected(state, entry),
      minimumExtent: minimumExtent,
      folded: slot.isFolded,
      onTap: () => activateEditorToolEntry(state, entry),
    );
    if (!slot.isFolded) return button;
    return EditorToolbarFlyout(
      placement: EditorToolbarFlyoutPlacement.side,
      items: editorToolSlotFlyoutItems(context, state, slot),
      child: button,
    );
  }
}

/// 缩放与视图方向控制，缩放比例本身是完整视图菜单的入口
class _ViewControls extends StatelessWidget {
  const _ViewControls({required this.state, required this.minimumExtent});

  final EditorState state;
  final double minimumExtent;

  static const _dividerHeight = 16.0;

  /// 缩放比例、适应窗口与视图方向折叠按钮；放大缩小在缩放比例菜单里
  static const _rowCount = 3;

  // 固定在底部后工具区至少还要露出四个按钮，否则整列一起滚动
  static const _minimumVisibleToolRows = 4;

  static double pinnedHeightFor(double minimumExtent) =>
      (_rowCount + _minimumVisibleToolRows) *
          _ActionButton.rowExtent(minimumExtent) +
      _dividerHeight;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        state.canvasController,
        state.toolbarSlotMemory,
      ]),
      builder: (context, _) {
        return Column(
          children: [
            const ThemedDivider(height: _dividerHeight),
            _ZoomMenuButton(state: state, minimumExtent: minimumExtent),
            _ActionButton(
              key: ValueKey(
                'editor-view-button-${EditorViewAction.fitToWindow.name}',
              ),
              minimumExtent: minimumExtent,
              icon: EditorViewAction.fitToWindow.icon,
              tooltip: EditorViewAction.fitToWindow.tooltip(context),
              onTap: () => EditorViewAction.fitToWindow.perform(state),
            ),
            _OrientationSlot(
              key: const ValueKey('editor-view-slot-orientation'),
              state: state,
              minimumExtent: minimumExtent,
            ),
          ],
        );
      },
    );
  }
}

/// 旋转、镜像与重置视图收进一个按钮，显示最近用过的那个
class _OrientationSlot extends StatelessWidget {
  const _OrientationSlot({
    super.key,
    required this.state,
    required this.minimumExtent,
  });

  final EditorState state;
  final double minimumExtent;

  static const _actions = [
    EditorViewAction.rotateLeft,
    EditorViewAction.rotateRight,
    EditorViewAction.mirror,
    EditorViewAction.resetView,
  ];

  static const _slotKey = 'view:orientation';

  void _perform(EditorViewAction action) {
    state.toolbarSlotMemory.remember(_slotKey, action.name);
    action.perform(state);
  }

  @override
  Widget build(BuildContext context) {
    final controller = state.canvasController;
    // 镜像是持续状态而不是当前动作，开着时不霸占按钮，旋转仍能一键重复
    final displayed =
        _actions[state.toolbarSlotMemory.displayedIndex(_slotKey, [
          for (final action in _actions) action.name,
        ])];
    return EditorToolbarFlyout(
      placement: EditorToolbarFlyoutPlacement.side,
      items: [
        for (final action in _actions)
          EditorToolbarFlyoutItem(
            key: ValueKey('editor-view-flyout-${action.name}'),
            icon: action.icon,
            label: action.label(context),
            shortcutLabel: action.shortcutLabel,
            selected: action.isActiveIn(controller),
            onActivate: () => _perform(action),
          ),
      ],
      child: _ActionButton(
        key: ValueKey('editor-view-button-${displayed.name}'),
        minimumExtent: minimumExtent,
        icon: displayed.icon,
        tooltip: displayed.tooltip(context),
        toggled: displayed.isToggle ? displayed.isActiveIn(controller) : null,
        folded: true,
        onTap: () => _perform(displayed),
      ),
    );
  }
}

/// 显示缩放比例；没有滚轮和键盘时放大缩小、100%、适应宽高、单独重置旋转都从这里进入
class _ZoomMenuButton extends StatelessWidget {
  const _ZoomMenuButton({required this.state, required this.minimumExtent});

  final EditorState state;
  final double minimumExtent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _buttonSpacing),
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

  /// 同族还有其他工具，可展开二级菜单
  final bool folded;

  const _ToolButton({
    super.key,
    required this.tool,
    required this.label,
    required this.isSelected,
    required this.minimumExtent,
    required this.onTap,
    this.folded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = isSelected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;
    final message = _buildTooltipMessage(context);

    final button = Semantics(
      button: true,
      selected: isSelected,
      // 折叠按钮的说明交给二级菜单，没有 Tooltip 提供读屏名称
      label: folded ? message : null,
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox.square(
            dimension: minimumExtent,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(child: Icon(tool.icon, size: 20, color: foreground)),
                if (folded) EditorToolbarFoldIndicator(color: foreground),
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _buttonSpacing),
      child: folded ? button : Tooltip(message: message, child: button),
    );
  }

  String _buildTooltipMessage(BuildContext context) {
    final shortcut = editorToolShortcutLabel(tool);
    final message = shortcut == null ? label : '$label ($shortcut)';

    if (tool.id == 'color_picker') {
      return '$message\n${context.l10n.editor_tempColorPickerShortcut}';
    }

    return message;
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

  /// 收着同组的其他操作，可展开二级菜单
  final bool folded;

  const _ActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.minimumExtent,
    this.enabled = true,
    this.toggled,
    this.folded = false,
  });

  static double rowExtent(double minimumExtent) =>
      minimumExtent + _buttonSpacing * 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = toggled ?? false;
    final foreground = !enabled
        ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
        : selected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    final button = Semantics(
      toggled: toggled,
      // 折叠按钮的说明交给二级菜单，没有 Tooltip 提供读屏名称
      label: folded ? tooltip : null,
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox.square(
            dimension: minimumExtent,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(child: Icon(icon, size: 20, color: foreground)),
                if (folded) EditorToolbarFoldIndicator(color: foreground),
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _buttonSpacing),
      child: folded ? button : Tooltip(message: tooltip, child: button),
    );
  }
}
