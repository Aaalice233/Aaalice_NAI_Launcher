import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../core/editor_state.dart';
import '../../tools/tool_base.dart';
import '../../../../widgets/common/themed_divider.dart';

/// 检查是否可以清空当前图层
bool _canClearActiveLayer(EditorState state) {
  final layer = state.layerManager.activeLayer;
  return layer != null && !layer.locked && layer.hasContent;
}

/// 桌面端垂直工具栏
class DesktopToolbar extends StatelessWidget {
  final EditorState state;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onClear;
  final VoidCallback? onFillMask;
  final bool Function()? canFillMask;
  final Set<String>? allowedToolIds;

  const DesktopToolbar({
    super.key,
    required this.state,
    this.onUndo,
    this.onRedo,
    this.onClear,
    this.onFillMask,
    this.canFillMask,
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
      width: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.24),
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 工具按钮 - 监听工具切换
                  ValueListenableBuilder<String?>(
                    valueListenable: state.toolNotifier,
                    builder: (context, currentToolId, _) {
                      return Column(
                        children: _visibleTools
                            .map(
                              (tool) => _ToolButton(
                                tool: tool,
                                isSelected: tool.id == currentToolId,
                                onTap: () => state.setTool(tool),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                  const ThemedDivider(height: 16),
                  // 撤销/重做/清空 - 监听历史管理器和图层管理器
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      state.historyManager,
                      state.layerManager,
                    ]),
                    builder: (context, _) {
                      return Column(
                        children: [
                          _ActionButton(
                            icon: Icons.undo,
                            tooltip: context.l10n.editor_shortcutUndo,
                            enabled: state.canUndo,
                            onTap: onUndo ?? () => state.undo(),
                          ),
                          _ActionButton(
                            icon: Icons.redo,
                            tooltip: context.l10n.editor_shortcutRedo,
                            enabled: state.canRedo,
                            onTap: onRedo ?? () => state.redo(),
                          ),
                          _ActionButton(
                            icon: Icons.delete_outline,
                            tooltip: onClear != null
                                ? context.l10n.editor_resetMask
                                : context.l10n.editor_clearLayer,
                            enabled: _canClearActiveLayer(state),
                            onTap:
                                onClear ??
                                () => state.clearActiveLayerWithHistory(),
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
                ],
              ),
            ),
          ),

          // 缩放控制 - 监听画布控制器
          ListenableBuilder(
            listenable: state.canvasController,
            builder: (context, _) {
              return Column(
                children: [
                  _ActionButton(
                    icon: Icons.zoom_in,
                    tooltip: context.l10n.editor_zoomIn,
                    onTap: () => state.canvasController.zoomIn(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${(state.canvasController.scale * 100).round()}%',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  _ActionButton(
                    icon: Icons.zoom_out,
                    tooltip: context.l10n.editor_zoomOut,
                    onTap: () => state.canvasController.zoomOut(),
                  ),
                  _ActionButton(
                    icon: Icons.fit_screen,
                    tooltip: context.l10n.editor_fitToWindow,
                    onTap: () =>
                        state.canvasController.fitToViewport(state.canvasSize),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 工具按钮
class _ToolButton extends StatelessWidget {
  final EditorTool tool;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToolButton({
    required this.tool,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: _buildTooltipMessage(context),
        child: Material(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 40,
              height: 40,
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
    final base = '${_localizedToolName(context)}$shortcut';

    if (tool.id == 'color_picker') {
      return '$base\n${context.l10n.editor_tempColorPickerShortcut}';
    }

    return base;
  }

  String _localizedToolName(BuildContext context) {
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
      _ => tool.name,
    };
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 20,
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
