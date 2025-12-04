import 'package:flutter/material.dart';

import '../../core/editor_state.dart';
import '../../tools/tool_base.dart';

/// 桌面端垂直工具栏
class DesktopToolbar extends StatelessWidget {
  final EditorState state;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;

  const DesktopToolbar({
    super.key,
    required this.state,
    this.onUndo,
    this.onRedo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // 工具按钮 - 监听工具切换
          ValueListenableBuilder<String?>(
            valueListenable: state.toolNotifier,
            builder: (context, currentToolId, _) {
              return Column(
                children: state.tools.map((tool) => _ToolButton(
                  tool: tool,
                  isSelected: tool.id == currentToolId,
                  onTap: () => state.setTool(tool),
                )).toList(),
              );
            },
          ),

          const Divider(height: 16),

          // 撤销/重做 - 监听历史管理器
          ListenableBuilder(
            listenable: state.historyManager,
            builder: (context, _) {
              return Column(
                children: [
                  _ActionButton(
                    icon: Icons.undo,
                    tooltip: '撤销 (Ctrl+Z)',
                    enabled: state.canUndo,
                    onTap: onUndo ?? () => state.undo(),
                  ),
                  _ActionButton(
                    icon: Icons.redo,
                    tooltip: '重做 (Ctrl+Y)',
                    enabled: state.canRedo,
                    onTap: onRedo ?? () => state.redo(),
                  ),
                ],
              );
            },
          ),

          const Spacer(),

          // 缩放控制 - 监听画布控制器
          ListenableBuilder(
            listenable: state.canvasController,
            builder: (context, _) {
              return Column(
                children: [
                  _ActionButton(
                    icon: Icons.zoom_in,
                    tooltip: '放大',
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
                    tooltip: '缩小',
                    onTap: () => state.canvasController.zoomOut(),
                  ),
                  _ActionButton(
                    icon: Icons.fit_screen,
                    tooltip: '适应窗口',
                    onTap: () => state.canvasController.fitToViewport(state.canvasSize),
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
        message: '${tool.name}${tool.shortcutKey != null ? ' (${_getShortcutLabel(tool)})' : ''}',
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
                    : theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
