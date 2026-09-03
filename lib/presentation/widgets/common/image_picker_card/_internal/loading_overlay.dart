import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';

/// 加载状态覆盖层
///
/// 点击选择文件后立即显示，解决"等待感"问题
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final progress = SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
                value: MediaQuery.disableAnimationsOf(context) ? 0.72 : null,
              ),
            );
            final label = Text(
              context.l10n.common_opening,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            );
            final scaledLabelHeight = MediaQuery.textScalerOf(
              context,
            ).scale(11);

            return Center(
              child: scaledLabelHeight > 22 || constraints.maxHeight < 72
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          progress,
                          const SizedBox(width: 8),
                          Flexible(child: label),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [progress, const SizedBox(height: 8), label],
                    ),
            );
          },
        ),
      ),
    );
  }
}
