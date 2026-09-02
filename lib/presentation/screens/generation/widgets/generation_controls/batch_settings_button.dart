import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_presenter.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_divider.dart';

/// 批量设置按钮（批次大小）
class BatchSettingsButton extends ConsumerWidget {
  const BatchSettingsButton({super.key, this.showLabel = false});

  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final batchSize = ref.watch(imagesPerRequestProvider);
    final batchCount = ref.watch(generationParamsNotifierProvider).nSamples;
    final l10n = context.l10n;

    void openSettings() => _showBatchSettingsDialog(
      context,
      ref,
      theme,
      l10n,
      batchSize,
      batchCount,
    );

    if (showLabel) {
      return FilledButton.tonalIcon(
        onPressed: openSettings,
        icon: const Icon(Icons.burst_mode_rounded),
        label: Text('${l10n.batchSize_title}: $batchSize'),
      );
    }

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
      onPressed: openSettings,
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
    AdaptivePresenter.showForm<void>(
      context: context,
      titleBuilder: (context) => Row(
        children: [
          Icon(Icons.burst_mode, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(child: Text(l10n.batchSize_title)),
        ],
      ),
      sideSheetWidth: 440,
      builder: (context, scrollController) => StatefulBuilder(
        builder: (context, setState) {
          final totalImages = batchCount * currentBatchSize;
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Text(
                l10n.batchSize_description,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 1; i <= 4; i++)
                    _buildBatchOption(context, theme, i, currentBatchSize, () {
                      ref.read(imagesPerRequestProvider.notifier).set(i);
                      setState(() => currentBatchSize = i);
                    }),
                ],
              ),
              const SizedBox(height: 16),
              const ThemedDivider(),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
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
              const SizedBox(height: 20),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.common_close),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBatchOption(
    BuildContext context,
    ThemeData theme,
    int value,
    int current,
    VoidCallback onTap,
  ) {
    final isSelected = value == current;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 140),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }
}
