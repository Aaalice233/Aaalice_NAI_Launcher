import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../image_editor_controller.dart';
import '../tools/tool_type.dart';

/// 右侧工具参数面板（精简版：只显示当前工具参数）
class ToolSettingsPanel extends StatelessWidget {
  final ImageEditorController controller;

  const ToolSettingsPanel({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return Container(
          width: 180,
          decoration: BoxDecoration(
            color: const Color(0xFF2d2d2d),
            border: Border(
              left: BorderSide(
                color: Colors.black.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 根据当前工具显示不同内容
                if (controller.currentTool.isPaintTool)
                  _buildBrushSettings(context)
                else
                  _buildSelectionSettings(context),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 笔刷参数（画笔/橡皮擦工具）
  Widget _buildBrushSettings(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context, context.l10n.editor_brushSettings),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildSlider(
                context: context,
                label: context.l10n.editor_size,
                value: controller.brushSettings.size,
                min: 1,
                max: 200,
                suffix: 'px',
                onChanged: controller.setBrushSize,
              ),
              const SizedBox(height: 16),
              _buildSlider(
                context: context,
                label: context.l10n.editor_opacity,
                value: controller.brushSettings.opacity * 100,
                min: 0,
                max: 100,
                suffix: '%',
                onChanged: (v) => controller.setBrushOpacity(v / 100),
              ),
              const SizedBox(height: 16),
              _buildSlider(
                context: context,
                label: context.l10n.editor_hardness,
                value: controller.brushSettings.hardness * 100,
                min: 0,
                max: 100,
                suffix: '%',
                onChanged: (v) => controller.setBrushHardness(v / 100),
              ),
            ],
          ),
        ),

        // 清除图像层按钮
        _buildHeader(context, context.l10n.editor_actions),
        Padding(
          padding: const EdgeInsets.all(12),
          child: _buildActionButton(
            context: context,
            icon: Icons.delete_outline,
            label: context.l10n.editor_clearImageLayer,
            onTap: () => _confirmClear(context, isImageLayer: true),
          ),
        ),
      ],
    );
  }

  /// 选区参数（矩形/椭圆选框工具）
  Widget _buildSelectionSettings(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context, context.l10n.editor_selectionSettings),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 选区操作按钮
              _buildActionButton(
                context: context,
                icon: Icons.delete_outline,
                label: context.l10n.editor_clearSelection,
                onTap: () => _confirmClear(context, isImageLayer: false),
                enabled: controller.hasMaskChanges,
              ),
              const SizedBox(height: 12),

              // 快捷键提示
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.editor_shortcuts,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildShortcutHint('Shift', context.l10n.editor_addToSelection),
                    const SizedBox(height: 4),
                    _buildShortcutHint('Alt', context.l10n.editor_subtractFromSelection),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSlider({
    required BuildContext context,
    required String label,
    required double value,
    required double min,
    required double max,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
            Text(
              '${value.round()}$suffix',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: const SliderThemeData(
            activeTrackColor: Color(0xFF4a90d9),
            inactiveTrackColor: Color(0xFF3a3a3a),
            thumbColor: Colors.white,
            overlayColor: Colors.white24,
            trackHeight: 4,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF3a3a3a),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: enabled ? Colors.white70 : Colors.white24,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white70 : Colors.white24,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutHint(String key, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF3a3a3a),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            key,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context, {required bool isImageLayer}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.editor_clearConfirm),
        content: Text(
          isImageLayer
              ? context.l10n.editor_clearImageLayerMessage
              : context.l10n.editor_clearSelectionMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.editor_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.editor_clear),
          ),
        ],
      ),
    );
    if (result == true) {
      if (isImageLayer) {
        controller.clearImageLayer();
      } else {
        controller.clearMaskLayer();
      }
    }
  }
}
