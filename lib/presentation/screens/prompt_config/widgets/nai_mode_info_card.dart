import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/tag_group.dart';
import '../../../providers/random_preset_provider.dart';
import '../../../providers/tag_group_sync_provider.dart';
import '../../../providers/tag_library_provider.dart';
import '../../../../core/services/tag_counting_service.dart';

/// NAI模式信息卡片组件
/// 显示NAI模式的概览信息和操作按钮
class NaiModeInfoCard extends ConsumerWidget {
  final VoidCallback onSync;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final VoidCallback onToggleExpand;
  final VoidCallback onAddCategory;
  final bool allExpanded;

  const NaiModeInfoCard({
    super.key,
    required this.onSync,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onToggleExpand,
    required this.onAddCategory,
    required this.allExpanded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final libraryState = ref.watch(tagLibraryNotifierProvider);
    final syncState = ref.watch(tagGroupSyncNotifierProvider);
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    final tagCountingService = ref.watch(tagCountingServiceProvider);

    final tagGroupMappings = preset?.tagGroupMappings ?? [];
    final categories = preset?.categories ?? [];

    // 计算已启用的标签组数量
    final builtinGroupCount =
        tagCountingService.calculateEnabledBuiltinCategoryCount(
      categories,
      libraryState.categoryFilterConfig.isBuiltinEnabled,
    );
    final syncGroupCount = tagCountingService.calculateEnabledSyncGroupCount(
      tagGroupMappings,
      categories,
    );
    final enabledMappingCount = builtinGroupCount + syncGroupCount;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.3),
            theme.colorScheme.secondaryContainer.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.naiMode_title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '已启用 $enabledMappingCount 个标签组',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 同步进度（如果正在同步）
          if (syncState.isSyncing && syncState.syncProgress != null) ...[
            _buildSyncProgress(theme, syncState.syncProgress!),
            const SizedBox(height: 12),
          ],

          // 操作按钮行
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionChip(
                icon: Icons.sync,
                label: '同步数据',
                onTap: onSync,
                isLoading: syncState.isSyncing,
              ),
              _ActionChip(
                icon: Icons.select_all,
                label: '全选',
                onTap: onSelectAll,
              ),
              _ActionChip(
                icon: Icons.deselect,
                label: '全不选',
                onTap: onDeselectAll,
              ),
              _ActionChip(
                icon: allExpanded ? Icons.unfold_less : Icons.unfold_more,
                label: allExpanded ? '折叠全部' : '展开全部',
                onTap: onToggleExpand,
              ),
              _ActionChip(
                icon: Icons.add,
                label: '添加类别',
                onTap: onAddCategory,
                isPrimary: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncProgress(
      ThemeData theme, TagGroupSyncProgress syncProgress,) {
    final progressValue = syncProgress.progress;
    final currentGroup = syncProgress.currentGroup;
    final completed = syncProgress.completedGroups;
    final total = syncProgress.totalGroups;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  currentGroup ?? '同步中...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (total > 0)
                Text(
                  '$completed / $total',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressValue,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

/// 操作按钮芯片
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isPrimary;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: isPrimary
          ? colorScheme.primary.withOpacity(0.15)
          : colorScheme.surfaceContainerHighest.withOpacity(0.6),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      isPrimary
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Icon(
                  icon,
                  size: 16,
                  color: isPrimary
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isPrimary
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: isPrimary ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
