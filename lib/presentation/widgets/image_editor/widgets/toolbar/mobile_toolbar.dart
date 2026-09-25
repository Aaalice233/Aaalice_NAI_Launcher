import 'package:nai_launcher/presentation/widgets/common/horizontal_action_strip.dart';
import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../core/editor_state.dart';
import '../../tools/tool_base.dart';
import '../../../../widgets/common/themed_divider.dart';
import 'editor_toolbar_tools.dart';

/// 移动端底部工具栏
class MobileToolbar extends StatelessWidget {
  final EditorState state;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onClear;
  final VoidCallback? onFillMask;
  final bool Function()? canFillMask;
  final VoidCallback? onLayersPressed;
  final Set<String>? allowedToolIds;

  const MobileToolbar({
    super.key,
    required this.state,
    this.onUndo,
    this.onRedo,
    this.onClear,
    this.onFillMask,
    this.canFillMask,
    this.onLayersPressed,
    this.allowedToolIds,
  });

  List<EditorTool> get _visibleTools =>
      visibleEditorTools(state, allowedToolIds);

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
          // 撤销/重做 - 监听历史管理器
          ListenableBuilder(
            listenable: Listenable.merge([
              state.historyManager,
              state.layerManager,
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
                  if (onClear != null)
                    _ActionButton(
                      icon: Icons.delete_outline,
                      tooltip: context.l10n.editor_clearLayer,
                      enabled: true,
                      onTap: onClear!,
                    ),
                  if (onFillMask != null)
                    _ActionButton(
                      icon: Icons.format_color_fill,
                      tooltip: context.l10n.editor_fillClosedRegion,
                      enabled: canFillMask?.call() ?? false,
                      onTap: onFillMask!,
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

          // 工具列表 - 监听工具切换
          Expanded(
            child: ValueListenableBuilder<String?>(
              valueListenable: state.toolNotifier,
              builder: (context, currentToolId, _) {
                return HorizontalActionStrip(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: _visibleTools.map((tool) {
                      return _MobileToolButton(
                        tool: tool,
                        isSelected: tool.id == currentToolId,
                        onTap: () => state.setTool(tool),
                      );
                    }).toList(),
                  ),
                );
              },
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

/// 移动端工具按钮
class _MobileToolButton extends StatelessWidget {
  final EditorTool tool;
  final bool isSelected;
  final VoidCallback onTap;

  const _MobileToolButton({
    required this.tool,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizedName = localizedEditorToolName(context, tool);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: localizedName,
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          selected: isSelected,
          label: localizedName,
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
