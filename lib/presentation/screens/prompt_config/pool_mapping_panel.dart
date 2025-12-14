import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/pool_mapping.dart';
import '../../../data/models/prompt/pool_sync_config.dart';
import '../../../data/models/prompt/tag_category.dart';
import '../../providers/pool_mapping_provider.dart';
import '../../widgets/common/app_toast.dart';
import 'pool_search_dialog.dart';

/// Pool 映射管理面板
class PoolMappingPanel extends ConsumerWidget {
  const PoolMappingPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(poolMappingNotifierProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 启用开关
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.l10n.poolMapping_enableSync,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            context.l10n.poolMapping_enableSyncDesc,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          value: state.config.enabled,
          onChanged: (value) {
            ref.read(poolMappingNotifierProvider.notifier).setEnabled(value);
          },
        ),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),

        // 映射列表标题
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.poolMapping_title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () => _confirmResetToDefault(context, ref),
                  icon: const Icon(Icons.restore, size: 18),
                  label: Text(context.l10n.poolMapping_resetToDefault),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showAddMappingDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.l10n.poolMapping_addMapping),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 8),

        // 映射列表
        if (state.config.mappings.isEmpty)
          _buildEmptyState(context, theme)
        else
          _buildMappingList(context, ref, theme, state.config.mappings),

        // 同步进度
        if (state.isSyncing && state.syncProgress != null) ...[
          const SizedBox(height: 16),
          _buildSyncProgress(theme, state.syncProgress!),
        ],
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.collections_bookmark_outlined,
            size: 48,
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.poolMapping_noMappings,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.poolMapping_noMappingsHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMappingList(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    List<PoolMapping> mappings,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: mappings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final mapping = mappings[index];
          return _buildMappingCard(context, ref, theme, mapping);
        },
      ),
    );
  }

  Widget _buildMappingCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    PoolMapping mapping,
  ) {
    final categoryName = TagSubCategoryHelper.getDisplayName(mapping.targetCategory);
    final syncInfo = mapping.lastSyncedAt != null
        ? context.l10n.poolMapping_tagCount(mapping.lastSyncedTagCount.toString())
        : context.l10n.poolMapping_neverSynced;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 启用/禁用开关
            Checkbox(
              value: mapping.enabled,
              onChanged: (value) {
                ref
                    .read(poolMappingNotifierProvider.notifier)
                    .toggleMappingEnabled(mapping.id);
              },
            ),
            const SizedBox(width: 8),

            // 映射信息
            Expanded(
              child: Opacity(
                opacity: mapping.enabled ? 1.0 : 0.5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${mapping.poolDisplayName}  →  $categoryName',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      syncInfo,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 删除按钮
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: theme.colorScheme.error,
              onPressed: () => _confirmRemoveMapping(context, ref, mapping),
              tooltip: context.l10n.common_delete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncProgress(ThemeData theme, PoolSyncProgress progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              progress.currentPool ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress.totalCount > 0
              ? progress.completedCount / progress.totalCount
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          '${progress.completedCount} / ${progress.totalCount}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  void _showAddMappingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const PoolSearchDialog(),
    );
  }

  void _confirmResetToDefault(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.poolMapping_resetToDefault),
        content: Text(context.l10n.poolMapping_resetConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(poolMappingNotifierProvider.notifier).resetToDefault();
              AppToast.success(context, context.l10n.poolMapping_resetSuccess);
            },
            child: Text(context.l10n.common_confirm),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveMapping(
    BuildContext context,
    WidgetRef ref,
    PoolMapping mapping,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.common_confirm),
        content: Text(context.l10n.poolMapping_removeConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref
                  .read(poolMappingNotifierProvider.notifier)
                  .removeMapping(mapping.id);
              AppToast.success(context, context.l10n.poolMapping_removeSuccess);
            },
            child: Text(context.l10n.common_confirm),
          ),
        ],
      ),
    );
  }
}
