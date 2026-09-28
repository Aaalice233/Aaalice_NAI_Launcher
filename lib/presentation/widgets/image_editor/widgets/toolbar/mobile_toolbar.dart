import 'package:nai_launcher/presentation/widgets/common/horizontal_action_strip.dart';
import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../core/editor_state.dart';
import '../../tools/tool_base.dart';
import '../../../../widgets/common/themed_divider.dart';

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

  List<EditorTool> get _visibleTools {
    if (allowedToolIds == null || allowedToolIds!.isEmpty) {
      return state.tools;
    }
    return state.tools
        .where((tool) => allowedToolIds!.contains(tool.id))
        .toList();
  }

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
    final localizedName = switch (tool.id) {
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
      _ => tool.name,
    };

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

/// 移动端工具设置底部面板
class MobileToolSettingsSheet extends StatelessWidget {
  final EditorState state;

  const MobileToolSettingsSheet({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tool = state.currentTool;

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动指示器
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 工具设置内容
          if (tool != null)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: tool.buildSettingsPanel(context, state),
              ),
            ),
        ],
      ),
    );
  }
}
