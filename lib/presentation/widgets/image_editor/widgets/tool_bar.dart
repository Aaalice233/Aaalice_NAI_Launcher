import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../image_editor_controller.dart';
import '../tools/tool_type.dart';
import 'color_picker.dart';

/// 左侧垂直工具栏（展开版：图标+文字）
class EditorToolBar extends StatelessWidget {
  final ImageEditorController controller;

  const EditorToolBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return Container(
          width: 130,
          decoration: BoxDecoration(
            color: const Color(0xFF2d2d2d),
            border: Border(
              right: BorderSide(
                color: Colors.black.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // 绘画工具组
              _buildSectionHeader(context, context.l10n.editor_paintTools),
              _ToolButton(
                tool: ToolType.brush,
                label: context.l10n.editor_toolBrush,
                isSelected: controller.currentTool == ToolType.brush,
                onTap: () => controller.setTool(ToolType.brush),
              ),
              _ToolButton(
                tool: ToolType.eraser,
                label: context.l10n.editor_toolEraser,
                isSelected: controller.currentTool == ToolType.eraser,
                onTap: () => controller.setTool(ToolType.eraser),
              ),

              const _Divider(),

              // 选区工具组（遮罩）
              _buildSectionHeader(context, context.l10n.editor_selectionTools),
              _ToolButton(
                tool: ToolType.rectSelect,
                label: context.l10n.editor_toolRectSelect,
                isSelected: controller.currentTool == ToolType.rectSelect,
                onTap: () => controller.setTool(ToolType.rectSelect),
              ),
              _ToolButton(
                tool: ToolType.ellipseSelect,
                label: context.l10n.editor_toolEllipseSelect,
                isSelected: controller.currentTool == ToolType.ellipseSelect,
                onTap: () => controller.setTool(ToolType.ellipseSelect),
              ),

              const _Divider(),

              // 颜色选择器（仅绘画工具可用）
              if (controller.currentTool.isPaintTool) ...[
                _ColorButton(
                  color: controller.currentColor,
                  onColorChanged: controller.setColor,
                ),
                const _Divider(),
              ],

              const Spacer(),

              // 撤销/重做
              _ActionButton(
                icon: Icons.undo,
                label: context.l10n.editor_undo,
                enabled: controller.canUndo,
                onTap: () => controller.undo(),
              ),
              _ActionButton(
                icon: Icons.redo,
                label: context.l10n.editor_redo,
                enabled: controller.canRedo,
                onTap: () => controller.redo(),
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 分隔线
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Divider(
        color: Colors.white24,
        height: 1,
      ),
    );
  }
}

/// 工具按钮（图标+文字）
class _ToolButton extends StatelessWidget {
  final ToolType tool;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToolButton({
    required this.tool,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4a90d9) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              tool.icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 颜色按钮（点击弹出颜色选择器）
class _ColorButton extends StatelessWidget {
  final Color color;
  final ValueChanged<Color> onColorChanged;

  const _ColorButton({
    required this.color,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showColorPicker(context),
      child: Container(
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white54, width: 1.5),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: Text(
          context.l10n.editor_color,
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 280,
          child: HSVColorPicker(
            color: color,
            onColorChanged: onColorChanged,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.editor_done),
          ),
        ],
      ),
    );
  }
}

/// 操作按钮（撤销/重做）
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: enabled ? Colors.white70 : Colors.white24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: enabled ? Colors.white70 : Colors.white24,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
