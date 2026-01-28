import 'package:flutter/material.dart';

import '../../core/editor_state.dart';
import '../tool_base.dart';
import '../../../../widgets/common/themed_divider.dart';

/// 选区工具基类
/// 提供所有选区工具的共享功能
abstract class BaseSelectionTool extends EditorTool {
  @override
  bool get isSelectionTool => true;

  @override
  void onPointerCancel(EditorState state) {
    onSelectionCancel();
    state.clearPreview();
    state.cancelStroke();
  }

  /// 子类实现：取消选区时清理内部状态
  void onSelectionCancel();

  @override
  Widget buildSettingsPanel(BuildContext context, EditorState state) {
    return SelectionSettingsPanel(
      title: name,
      state: state,
      helpText: helpText,
    );
  }

  /// 子类可重写：提供帮助文本
  String? get helpText => null;
}

/// 形状选区工具基类
/// 用于矩形、椭圆等两点确定形状的选区工具
abstract class ShapeSelectionTool extends BaseSelectionTool {
  /// 起始点
  Offset? startPoint;

  @override
  void onPointerDown(PointerDownEvent event, EditorState state) {
    // 开始绘制时清除旧选区
    state.clearSelection(saveHistory: false);
    state.clearPreview();
    startPoint = event.localPosition;
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {
    if (startPoint != null) {
      final currentPoint = event.localPosition;
      final rect = Rect.fromPoints(startPoint!, currentPoint);
      final path = createShapePath(rect);
      state.setPreviewPath(path);
    }
  }

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {
    if (startPoint != null) {
      final endPoint = event.localPosition;
      final rect = Rect.fromPoints(startPoint!, endPoint);

      if (rect.width > 2 && rect.height > 2) {
        final path = createShapePath(rect);
        state.setSelection(path); // 确认选区（自动清除预览）
      } else {
        state.clearPreview();
      }
    }
    startPoint = null;
  }

  @override
  void onSelectionCancel() {
    startPoint = null;
  }

  /// 子类实现：根据矩形创建形状路径
  Path createShapePath(Rect rect);
}

/// 选区设置面板
/// 所有选区工具共享的设置面板
class SelectionSettingsPanel extends StatelessWidget {
  final String title;
  final EditorState state;
  final String? helpText;

  const SelectionSettingsPanel({
    super.key,
    required this.title,
    required this.state,
    this.helpText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const ThemedDivider(height: 1),

        // 帮助文本（可选）
        if (helpText != null) ...[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      helpText!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const ThemedDivider(height: 1),
        ],

        // 操作按钮
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => state.clearSelection(),
                icon: const Icon(Icons.deselect, size: 16),
                label: const Text('清除选区'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: theme.textTheme.bodySmall,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => state.invertSelection(),
                icon: const Icon(Icons.flip, size: 16),
                label: const Text('反转选区'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
