import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../providers/image_generation_provider.dart';
import '../../../../widgets/common/themed_divider.dart';

/// 批量设置按钮（批次大小）
class BatchSettingsButton extends ConsumerWidget {
  const BatchSettingsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final batchSize = ref.watch(imagesPerRequestProvider);
    final batchCount = ref.watch(generationParamsNotifierProvider).nSamples;
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      tooltip: l10n.batchSize_tooltip(batchSize),
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$batchSize',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      onPressed: () => _showBatchSettingsDialog(
        context,
        ref,
        theme,
        l10n,
        batchSize,
        batchCount,
      ),
    );
  }

  void _showBatchSettingsDialog(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    AppLocalizations l10n,
    int currentBatchSize,
    int batchCount,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final totalImages = batchCount * currentBatchSize;

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.burst_mode, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(l10n.batchSize_title),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.batchSize_description,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),

                  // 批次大小选择
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (int i = 1; i <= 4; i++)
                        _buildBatchOption(theme, i, currentBatchSize, () {
                          ref.read(imagesPerRequestProvider.notifier).set(i);
                          setState(() => currentBatchSize = i);
                        }),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const ThemedDivider(),
                  const SizedBox(height: 12),

                  // 计算公式
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.batchSize_formula(
                            batchCount,
                            currentBatchSize,
                            totalImages,
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  Text(
                    l10n.batchSize_hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  if (currentBatchSize > 1) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.batchSize_costWarning,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.common_close),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBatchOption(
    ThemeData theme,
    int value,
    int current,
    VoidCallback onTap,
  ) {
    final isSelected = value == current;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
