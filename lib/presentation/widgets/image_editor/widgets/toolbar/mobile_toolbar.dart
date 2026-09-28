import 'package:nai_launcher/presentation/widgets/common/horizontal_action_strip.dart';
import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../core/editor_state.dart';
import '../../core/editor_tool_groups.dart';
import '../../tools/tool_base.dart';
import '../../../../widgets/common/themed_divider.dart';
import 'editor_tool_group_section.dart';
import 'editor_toolbar_tools.dart';

/// 移动端底部工具栏
class MobileToolbar extends StatelessWidget {
  final EditorState state;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onClear;
  final VoidCallback? onLayersPressed;

  const MobileToolbar({
    super.key,
    required this.state,
    this.onUndo,
    this.onRedo,
    this.onClear,
    this.onLayersPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.24),
          ),
        ),
      ),
      child: Row(
        children: [
          // 撤销/重做/清空 - 监听历史、图层内容与当前图层
          ListenableBuilder(
            listenable: Listenable.merge([
              state.historyManager,
              state.layerManager,
              state.layerManager.activeLayerNotifier,
            ]),
            builder: (context, _) {
              return Row(
                children: [
                  _ActionButton(
                    icon: Icons.undo,
                    tooltip: context.l10n.editor_undo,
                    enabled: state.canUndo,
                    onTap: onUndo ?? () => state.undo(),
                  ),
                  _ActionButton(
                    icon: Icons.redo,
                    tooltip: context.l10n.editor_redo,
                    enabled: state.canRedo,
                    onTap: onRedo ?? () => state.redo(),
                  ),
                  _ActionButton(
                    icon: Icons.delete_outline,
                    tooltip: clearToolbarTooltip(context, state),
                    enabled: canClearFromToolbar(state),
                    onTap: onClear ?? state.clearActiveLayerWithHistory,
                  ),
                ],
              );
            },
          ),

          const ThemedDivider(
            height: 1,
            vertical: true,
            indent: 12,
            endIndent: 12,
          ),

          // 工具分组 - 监听工具切换与当前图层
          Expanded(
            child: ListenableBuilder(
              listenable: editorToolAvailability(state),
              builder: (context, _) => HorizontalActionStrip(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _MobileToolSections(state: state),
              ),
            ),
          ),

          const ThemedDivider(
            height: 1,
            vertical: true,
            indent: 12,
            endIndent: 12,
          ),

          // 图层按钮
          _ActionButton(
            icon: Icons.layers,
            tooltip: context.l10n.editor_layers,
            onTap: onLayersPressed ?? () {},
          ),
        ],
      ),
    );
  }
}

class _MobileToolSections extends StatelessWidget {
  const _MobileToolSections({required this.state});

  final EditorState state;

  static const double _sectionGap = 6;

  @override
  Widget build(BuildContext context) {
    final showTitles = showsEditorToolGroupTitles(state);
    final sections = editorToolSections(state);
    return Row(
      children: [
        for (final (index, section) in sections.indexed) ...[
          if (index > 0) const SizedBox(width: _sectionGap),
          EditorToolGroupSection(
            key: ValueKey('editor-tool-group-${section.group.name}'),
            axis: Axis.horizontal,
            title: showTitles
                ? editorToolGroupLabel(context, section.group)
                : null,
            children: [
              for (final entry in section.entries)
                _MobileToolButton(
                  key: ValueKey('editor-tool-${entry.key}'),
                  tool: entry.tool,
                  label: editorToolLabel(context, entry.tool, entry.targetRole),
                  isSelected: isEditorToolEntrySelected(state, entry),
                  onTap: () => activateEditorToolEntry(state, entry),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 移动端工具按钮
class _MobileToolButton extends StatelessWidget {
  final EditorTool tool;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MobileToolButton({
    super.key,
    required this.tool,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          selected: isSelected,
          label: label,
          child: Material(
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  tool.icon,
                  size: 22,
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
}

/// 操作按钮
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: SizedBox(
              width: 48,
              height: 56,
              child: Icon(
                icon,
                size: 22,
                color: enabled
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
