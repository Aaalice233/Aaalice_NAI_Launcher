import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../image_editor_controller.dart';
import '../tools/tool_type.dart';

/// 移动端底部工具栏
class MobileBottomBar extends StatelessWidget {
  final ImageEditorController controller;
  final VoidCallback onSettingsTap;

  const MobileBottomBar({
    super.key,
    required this.controller,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2d2d2d),
            border: Border(
              top: BorderSide(
                color: Colors.black.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 第一行：工具按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 所有工具
                    ...ToolType.values.map(
                      (tool) => _MobileToolButton(
                        tool: tool,
                        isSelected: controller.currentTool == tool,
                        onTap: () => controller.setTool(tool),
                      ),
                    ),

                    // 当前颜色（仅绘画工具）
                    if (controller.currentTool.isPaintTool)
                      _MobileColorButton(
                        color: controller.currentColor,
                        onTap: onSettingsTap,
                      ),

                    // 设置按钮
                    _MobileActionButton(
                      icon: Icons.tune,
                      onTap: onSettingsTap,
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // 第二行：笔刷大小滑块 + 撤销/重做
                Row(
                  children: [
                    // 撤销
                    _MobileActionButton(
                      icon: Icons.undo,
                      enabled: controller.canUndo,
                      onTap: () => controller.undo(),
                    ),

                    // 重做
                    _MobileActionButton(
                      icon: Icons.redo,
                      enabled: controller.canRedo,
                      onTap: () => controller.redo(),
                    ),

                    const SizedBox(width: 8),

                    // Size 标签（仅绘画工具显示）
                    if (controller.currentTool.isPaintTool) ...[
                      Text(
                        '${context.l10n.editor_size}:',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),

                      // 大小滑块
                      Expanded(
                        child: SliderTheme(
                          data: const SliderThemeData(
                            activeTrackColor: Color(0xFF4a90d9),
                            inactiveTrackColor: Color(0xFF3a3a3a),
                            thumbColor: Colors.white,
                            overlayColor: Colors.white24,
                            trackHeight: 4,
                            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                          ),
                          child: Slider(
                            value: controller.brushSettings.size,
                            min: 1,
                            max: 200,
                            onChanged: controller.setBrushSize,
                          ),
                        ),
                      ),

                      // 大小数值
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${controller.brushSettings.size.round()}px',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ] else ...[
                      // 选区工具提示
                      Expanded(
                        child: Text(
                          context.l10n.editor_selectionHint,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 移动端工具按钮
class _MobileToolButton extends StatelessWidget {
  final ToolType tool;
  final bool isSelected;
  final VoidCallback onTap;

  const _MobileToolButton({
    required this.tool,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4a90d9) : const Color(0xFF3a3a3a),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          tool.icon,
          size: 22,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 移动端颜色按钮
class _MobileColorButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _MobileColorButton({
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF3a3a3a),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white54, width: 2),
          ),
        ),
      ),
    );
  }
}

/// 移动端操作按钮
class _MobileActionButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _MobileActionButton({
    required this.icon,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          icon,
          size: 22,
          color: enabled ? Colors.white70 : Colors.white24,
        ),
      ),
    );
  }
}
