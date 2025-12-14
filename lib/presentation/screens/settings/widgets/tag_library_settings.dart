import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/sync_config.dart';
import '../../../providers/tag_library_provider.dart';
import '../../../widgets/common/app_toast.dart';

/// 词库设置组件
///
/// 用于设置页面，管理 Danbooru 词库的同步配置
class TagLibrarySettings extends ConsumerWidget {
  const TagLibrarySettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tagLibraryNotifierProvider);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Icon(Icons.library_books, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.tagLibrary_title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 词库状态
            _buildLibraryStatus(context, state, theme),
            const Divider(height: 24),

            // 自动同步开关
            _buildAutoSyncSwitch(context, ref, state, theme),
            const SizedBox(height: 12),

            // 同步间隔
            if (state.syncConfig.autoSyncEnabled)
              _buildSyncIntervalSelector(context, ref, state, theme),
            const SizedBox(height: 12),

            // 数据范围
            _buildDataRangeSelector(context, ref, state, theme),
            const SizedBox(height: 16),

            // 同步按钮
            _buildSyncButton(context, ref, state, theme),

            // 同步进度
            if (state.isSyncing && state.syncProgress != null)
              _buildSyncProgress(context, state, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryStatus(
    BuildContext context,
    TagLibraryState state,
    ThemeData theme,
  ) {
    final library = state.library;
    final config = state.syncConfig;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                library != null ? Icons.check_circle : Icons.info_outline,
                size: 16,
                color: library != null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Text(
                library != null
                    ? context.l10n.tagLibrary_tagCount(library.totalTagCount.toString())
                    : context.l10n.tagLibrary_usingBuiltin,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            config.lastSyncTime != null
                ? context.l10n.tagLibrary_lastSync(config.formatLastSyncTime())
                : context.l10n.tagLibrary_neverSynced,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoSyncSwitch(
    BuildContext context,
    WidgetRef ref,
    TagLibraryState state,
    ThemeData theme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.tagLibrary_autoSync, style: theme.textTheme.bodyLarge),
              Text(
                context.l10n.tagLibrary_autoSyncHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: state.syncConfig.autoSyncEnabled,
          onChanged: (value) {
            ref.read(tagLibraryNotifierProvider.notifier).setAutoSyncEnabled(value);
          },
        ),
      ],
    );
  }

  Widget _buildSyncIntervalSelector(
    BuildContext context,
    WidgetRef ref,
    TagLibraryState state,
    ThemeData theme,
  ) {
    final intervals = [7, 15, 30, 60];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.tagLibrary_syncInterval, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: List.generate(intervals.length, (index) {
            final selected = state.syncConfig.syncIntervalDays == intervals[index];
            return ChoiceChip(
              label: Text(context.l10n.tagLibrary_syncIntervalDays(intervals[index].toString())),
              selected: selected,
              onSelected: (value) {
                if (value) {
                  ref
                      .read(tagLibraryNotifierProvider.notifier)
                      .setSyncInterval(intervals[index]);
                }
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDataRangeSelector(
    BuildContext context,
    WidgetRef ref,
    TagLibraryState state,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.tagLibrary_dataRange, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: DataRange.values.map((range) {
            final selected = state.syncConfig.dataRange == range;
            final label = switch (range) {
              DataRange.popular => context.l10n.tagLibrary_dataRangePopular,
              DataRange.medium => context.l10n.tagLibrary_dataRangeMedium,
              DataRange.full => context.l10n.tagLibrary_dataRangeFull,
            };
            return ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (value) {
                if (value) {
                  ref.read(tagLibraryNotifierProvider.notifier).setDataRange(range);
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.tagLibrary_dataRangeHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildSyncButton(
    BuildContext context,
    WidgetRef ref,
    TagLibraryState state,
    ThemeData theme,
  ) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: state.isSyncing
            ? null
            : () async {
                final success = await ref
                    .read(tagLibraryNotifierProvider.notifier)
                    .syncLibrary();
                if (context.mounted) {
                  if (success) {
                    AppToast.success(context, context.l10n.tagLibrary_syncSuccess);
                  } else {
                    AppToast.error(
                      context,
                      state.error ?? context.l10n.tagLibrary_syncFailed,
                    );
                  }
                }
              },
        icon: state.isSyncing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.sync),
        label: Text(state.isSyncing ? context.l10n.tagLibrary_syncing : context.l10n.tagLibrary_syncNow),
      ),
    );
  }

  Widget _buildSyncProgress(
    BuildContext context,
    TagLibraryState state,
    ThemeData theme,
  ) {
    final progress = state.syncProgress!;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: progress.progress,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 4),
          Text(
            progress.message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// 词库设置对话框
class TagLibrarySettingsDialog extends StatelessWidget {
  const TagLibrarySettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const TagLibrarySettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(context.l10n.tagLibrary_title),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SingleChildScrollView(
              child: TagLibrarySettings(),
            ),
          ],
        ),
      ),
    );
  }
}
