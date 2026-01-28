import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/random_preset.dart';
import '../../../../core/services/tag_counting_service.dart';
import '../../../providers/random_preset_provider.dart';
import '../../../providers/tag_group_sync_provider.dart';
import '../../../providers/tag_library_provider.dart';
import '../utils/tag_count_helpers.dart';
import 'global_post_count_toolbar.dart';
import 'sync_progress_indicator.dart';

/// NAI 模式头部信息组件
/// 包含预设名称、描述、统计信息和操作按钮
class NaiInfoHeader extends ConsumerWidget {
  final VoidCallback onEditPresetName;
  final VoidCallback onEditDescription;
  final VoidCallback onResetPreset;
  final VoidCallback onAddCategory;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final VoidCallback onToggleExpand;
  final bool allExpanded;
  final int expandedCategoryCount;

  const NaiInfoHeader({
    super.key,
    required this.onEditPresetName,
    required this.onEditDescription,
    required this.onResetPreset,
    required this.onAddCategory,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onToggleExpand,
    required this.allExpanded,
    required this.expandedCategoryCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final libraryState = ref.watch(tagLibraryNotifierProvider);
    final syncState = ref.watch(tagGroupSyncNotifierProvider);
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    final tagGroupMappings = preset?.tagGroupMappings ?? [];
    final tagCountingService = ref.watch(tagCountingServiceProvider);

    final categories = preset?.categories ?? [];
    final library = libraryState.library;

    // 计算已启用的 tag group 数量
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

    // 计算总标签数
    final builtinTagCount = TagCountHelpers.calculateBuiltinLibraryTagCount(
      library,
      categories,
      libraryState.categoryFilterConfig,
    );
    final tagCount = builtinTagCount +
        tagCountingService.calculateTotalTagCount(
          tagGroupMappings,
          categories,
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 预设名称和描述
          if (preset != null) ...[
            _buildPresetHeader(context, theme, preset),
            const SizedBox(height: 12),
          ],

          // 添加描述按钮（仅非默认预设且无描述时）
          if (preset != null &&
              !preset.isDefault &&
              (preset.description == null || preset.description!.isEmpty))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextButton.icon(
                onPressed: onEditDescription,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('添加描述'),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ),

          // 统计信息和操作按钮
          GlobalPostCountToolbar(
            tagCount: tagCount,
            enabledMappingCount: enabledMappingCount,
            totalMappingCount: categories.length + tagGroupMappings.length,
            onToggleSelectAll: () {
              final allSelected = builtinGroupCount == categories.length &&
                  tagGroupMappings.every((m) => m.enabled);
              if (allSelected) {
                onDeselectAll();
              } else {
                onSelectAll();
              }
            },
            allExpanded: allExpanded,
            onToggleExpand: onToggleExpand,
            onResetPreset: onResetPreset,
            onAddCategory: onAddCategory,
            showResetPreset: preset?.isDefault ?? false,
          ),

          // 同步进度
          if ((libraryState.isSyncing && libraryState.syncProgress != null) ||
              (syncState.isSyncing && syncState.syncProgress != null)) ...[
            const SizedBox(height: 16),
            SyncProgressIndicator(
              tagLibrarySyncProgress:
                  libraryState.isSyncing ? libraryState.syncProgress : null,
              tagGroupSyncProgress:
                  syncState.isSyncing ? syncState.syncProgress : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetHeader(
    BuildContext context,
    ThemeData theme,
    RandomPreset preset,
  ) {
    return Row(
      children: [
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: preset.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: preset.isDefault
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                if (preset.description != null &&
                    preset.description!.isNotEmpty) ...[
                  TextSpan(
                    text: '  ·  ',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                  TextSpan(
                    text: preset.description!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // 编辑按钮（仅非默认预设）
        if (!preset.isDefault) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            onPressed: onEditPresetName,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: context.l10n.preset_rename,
          ),
          if (preset.description != null && preset.description!.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.edit_note_outlined,
                size: 18,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              onPressed: onEditDescription,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: '编辑描述',
            ),
        ],
      ],
    );
  }
}
