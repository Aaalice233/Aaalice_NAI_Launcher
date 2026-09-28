import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../common/horizontal_action_strip.dart';
import '../core/editor_state.dart';

/// 桌面编辑器底部状态栏：缩放、画布尺寸、图层数、选区与视图方向
class EditorStatusBar extends StatelessWidget {
  const EditorStatusBar({super.key, required this.state});

  final EditorState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        state.canvasController,
        state.canvasSizeNotifier,
        state.layerManager,
        state.selectionManager,
      ]),
      builder: (context, _) {
        final controller = state.canvasController;
        final textStyle = theme.textTheme.bodySmall;
        final viewStateStyle = textStyle?.copyWith(
          color: theme.colorScheme.secondary,
        );
        return Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.24),
              ),
            ),
          ),
          // 窄窗口叠加旋转与镜像提示时一行放不下，横向滚动而不是溢出
          child: HorizontalActionStrip(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.editor_statusZoom(
                    (controller.scale * 100).round(),
                  ),
                  style: textStyle,
                ),
                const SizedBox(width: 16),
                Text(
                  context.l10n.editor_statusCanvas(
                    state.canvasSize.width.toInt(),
                    state.canvasSize.height.toInt(),
                  ),
                  style: textStyle,
                ),
                const SizedBox(width: 16),
                Text(
                  context.l10n.editor_statusLayers(
                    state.layerManager.layerCount,
                  ),
                  style: textStyle,
                ),
                if (state.selectionPath != null) ...[
                  const SizedBox(width: 16),
                  Text(
                    context.l10n.editor_statusHasSelection,
                    style: textStyle?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
                if (controller.rotation != 0) ...[
                  const SizedBox(width: 16),
                  Text(
                    context.l10n.editor_statusRotation(
                      (controller.rotation * 180 / math.pi).round(),
                    ),
                    style: viewStateStyle,
                  ),
                ],
                if (controller.isMirroredHorizontally) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.flip,
                    size: 14,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.editor_statusMirrored,
                    style: viewStateStyle,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
