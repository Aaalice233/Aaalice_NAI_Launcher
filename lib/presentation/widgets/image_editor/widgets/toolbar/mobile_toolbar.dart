import 'package:flutter/material.dart';

import '../../core/editor_state.dart';
import '../../tools/tool_base.dart';
import '../../../../widgets/common/themed_divider.dart';

/// 移动端底部工具栏
class MobileToolbar extends StatelessWidget {
  final EditorState state;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onLayersPressed;

  const MobileToolbar({
    super.key,
    required this.state,
    this.onUndo,
    this.onRedo,
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
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 撤销/重做 - 监听历史管理器
          ListenableBuilder(
            listenable: state.historyManager,
            builder: (context, _) {
              return Row(
                children: [
                  _ActionButton(
                    icon: Icons.undo,
                    enabled: state.canUndo,
                    onTap: onUndo ?? () => state.undo(),
                  ),
                  _ActionButton(
                    icon: Icons.redo,
                    enabled: state.canRedo,
                    onTap: onRedo ?? () => state.redo(),
                  ),
                ],
              );
            },
          ),

          const ThemedDivider(height: 1, vertical: true, indent: 12, endIndent: 12),

          // 工具列表 - 监听工具切换
          Expanded(
            child: ValueListenableBuilder<String?>(
              valueListenable: state.toolNotifier,
              builder: (context, currentToolId, _) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: state.tools.map((tool) {
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

          const ThemedDivider(height: 1, vertical: true, indent: 12, endIndent: 12),

          // 图层按钮
          _ActionButton(
            icon: Icons.layers,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
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
    );
  }
}

/// 操作按钮
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 48,
          height: 56,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 22,
            color: enabled
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withOpacity(0.3),
          ),
        ),
      ),
    );
  }
}

/// 移动端工具设置底部面板
class MobileToolSettingsSheet extends StatelessWidget {
  final EditorState state;

  const MobileToolSettingsSheet({
    super.key,
    required this.state,
  });

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
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
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
