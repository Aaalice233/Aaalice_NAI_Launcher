import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../widgets/prompt/diy/dialogs/diy_guide_dialog.dart';
import '../../../widgets/prompt/diy/dialogs/nai_rules_dialog.dart';
import '../../../widgets/prompt/global_settings_dialog.dart';
import '../../../widgets/settings/cache_management_dialog.dart';

/// 全局工具栏
///
/// 显示标签统计信息和操作按钮
class GlobalPostCountToolbar extends StatelessWidget {
  final int tagCount;
  final int enabledMappingCount;
  final int totalMappingCount;
  final VoidCallback onToggleSelectAll;
  final bool allExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onResetPreset;
  final VoidCallback? onAddCategory;
  final VoidCallback? onManageLibrary;
  final bool showResetPreset;

  const GlobalPostCountToolbar({
    super.key,
    required this.tagCount,
    required this.enabledMappingCount,
    required this.totalMappingCount,
    required this.onToggleSelectAll,
    required this.allExpanded,
    required this.onToggleExpand,
    required this.onResetPreset,
    this.onAddCategory,
    this.onManageLibrary,
    this.showResetPreset = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 已选择的组数量
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              context.l10n.tagGroup_selectedCount(
                enabledMappingCount.toString(),
              ),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 总tag数量
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              context.l10n.naiMode_totalTags(tagCount.toString()),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 重置为默认按钮（放在统计徽章旁边）- 仅默认预设显示
          if (showResetPreset)
            _buildDangerButton(
              theme: theme,
              icon: Icons.restart_alt,
              label: context.l10n.preset_resetToDefault,
              onTap: onResetPreset,
            ),
          const Spacer(),
          // 全选/取消选择切换按钮
          Builder(
            builder: (context) {
              final allSelected = enabledMappingCount == totalMappingCount;
              return _buildCompactButton(
                theme: theme,
                icon: allSelected ? Icons.deselect : Icons.select_all,
                label: allSelected
                    ? context.l10n.common_deselectAll
                    : context.l10n.common_selectAll,
                onTap: onToggleSelectAll,
              );
            },
          ),
          const SizedBox(width: 8),
          // 展开/收起按钮
          _buildCompactButton(
            theme: theme,
            icon: allExpanded ? Icons.unfold_less : Icons.unfold_more,
            label: allExpanded
                ? context.l10n.common_collapseAll
                : context.l10n.common_expandAll,
            onTap: onToggleExpand,
          ),
          const SizedBox(width: 8),
          // 缓存管理按钮
          _buildCompactButton(
            theme: theme,
            icon: Icons.storage_outlined,
            label: context.l10n.cache_manage,
            onTap: () => CacheManagementDialog.show(context),
          ),
          const SizedBox(width: 8),
          // 人数组合配置按钮
          _buildCompactButton(
            theme: theme,
            icon: Icons.tune,
            label: context.l10n.characterCountConfig_title,
            onTap: () => GlobalSettingsDialog.show(context),
          ),
          const SizedBox(width: 8),
          // NAI 规则说明按钮
          _buildCompactButton(
            theme: theme,
            icon: Icons.info_outline,
            label: 'NAI 规则',
            onTap: () => NaiRulesDialog.show(context),
          ),
          const SizedBox(width: 8),
          // DIY 指南按钮
          _buildCompactButton(
            theme: theme,
            icon: Icons.help_outline,
            label: 'DIY 指南',
            onTap: () => DiyGuideDialog.show(context),
          ),
          const SizedBox(width: 8),
          // 管理词库按钮
          if (onManageLibrary != null)
            _buildCompactButton(
              theme: theme,
              icon: Icons.library_books_outlined,
              label: context.l10n.manageLibrary,
              onTap: onManageLibrary!,
            ),
          // 分隔线
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: 1,
              height: 24,
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          // 新增类别按钮
          if (onAddCategory != null)
            _buildPrimaryButton(
              theme: theme,
              icon: Icons.add,
              label: context.l10n.category_addNew,
              onTap: onAddCategory!,
            ),
        ],
      ),
    );
  }

  /// 普通按钮样式
  Widget _buildCompactButton({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 主要操作按钮样式（新增类别）
  Widget _buildPrimaryButton({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: theme.colorScheme.primary.withOpacity(0.15),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 危险操作按钮样式（重置为默认）
  Widget _buildDangerButton({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: theme.colorScheme.error.withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
