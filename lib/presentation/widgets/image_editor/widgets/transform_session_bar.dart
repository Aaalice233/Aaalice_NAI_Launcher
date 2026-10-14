import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../themes/core/layered_surface_style.dart';
import '../core/editor_state.dart';

/// 自由变换进行中时浮在画布底部的取消与应用，不依赖键盘也能结束变换
class TransformSessionBar extends StatelessWidget {
  const TransformSessionBar({super.key, required this.state});

  final EditorState state;

  @override
  Widget build(BuildContext context) {
    final transformer = state.layerTransformer;
    return ListenableBuilder(
      listenable: transformer,
      builder: (context, _) {
        if (!transformer.isActive) return const SizedBox.shrink();
        final colorScheme = Theme.of(context).colorScheme;
        final l10n = context.l10n;
        return Material(
          key: const ValueKey('transform-session-bar'),
          color: overlaySurfaceColor(colorScheme),
          elevation: 4,
          shadowColor: colorScheme.shadow.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: transformer.isDragging ? null : transformer.cancel,
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(l10n.editor_transformCancel),
                ),
                FilledButton.icon(
                  onPressed: transformer.isDragging ? null : transformer.apply,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(l10n.editor_transformApply),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
