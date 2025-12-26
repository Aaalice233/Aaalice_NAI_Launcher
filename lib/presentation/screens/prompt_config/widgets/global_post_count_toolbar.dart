import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/tag_group_mapping.dart';
import '../../../providers/random_preset_provider.dart';
import '../../../providers/tag_group_sync_provider.dart';
import '../../../widgets/prompt/global_settings_dialog.dart';
import '../../../widgets/settings/cache_management_dialog.dart';

/// 全局热度阈值工具栏
///
/// 显示并控制全局热度阈值、标签统计信息、同步按钮等
class GlobalPostCountToolbar extends ConsumerStatefulWidget {
  final int tagCount;
  final int originalTagCount;
  final int enabledMappingCount;
  final int totalMappingCount;
  final bool isSyncing;
  final VoidCallback onSync;
  final VoidCallback onToggleSelectAll;
  final bool allExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onResetPreset;

  const GlobalPostCountToolbar({
    super.key,
    required this.tagCount,
    required this.originalTagCount,
    required this.enabledMappingCount,
    required this.totalMappingCount,
    required this.isSyncing,
    required this.onSync,
    required this.onToggleSelectAll,
    required this.allExpanded,
    required this.onToggleExpand,
    required this.onResetPreset,
  });

  @override
  ConsumerState<GlobalPostCountToolbar> createState() =>
      _GlobalPostCountToolbarState();
}

class _GlobalPostCountToolbarState
    extends ConsumerState<GlobalPostCountToolbar> {
  double? _draggingValue;

  double _postCountToSlider(int postCount) {
    const minLog = 2.0;
    const maxLog = 4.699;
    final log = math.log(postCount.clamp(100, 50000).toDouble()) / math.ln10;
    return ((log - minLog) / (maxLog - minLog)).clamp(0.0, 1.0);
  }

  int _sliderToPostCount(double value) {
    const minLog = 2.0;
    const maxLog = 4.699;
    final log = minLog + value * (maxLog - minLog);
    final count = math.pow(10, log).round();
    return _snapToCommonValue(count);
  }

  int _snapToCommonValue(int value) {
    const commonValues = [100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000];
    for (final cv in commonValues) {
      if ((value - cv).abs() < cv * 0.15) {
        return cv;
      }
    }
    return ((value / 100).round() * 100).clamp(100, 50000);
  }

  String _formatPostCount(int count) {
    if (count >= 10000) {
      return '${count ~/ 1000}K';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    final tagGroupMappings = preset?.tagGroupMappings ?? [];
    // 使用预设的 popularityThreshold (0-100) 转换为 post count (100-50000)
    final currentValue = (preset?.popularityThreshold ?? 50) * 100;
    final displayValue = _draggingValue ?? _postCountToSlider(currentValue);
    final displayPostCount = _sliderToPostCount(displayValue);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：热度阈值 + 统计信息 + 同步按钮
          Row(
            children: [
              // 热度阈值标签
              Text(
                context.l10n.tagGroup_minPostCount,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(width: 8),
              // 当前值徽章
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatPostCount(displayPostCount),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 已选择的组数量
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  context.l10n.tagGroup_selectedCount(
                    widget.enabledMappingCount.toString(),
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 总tag数量 - 悬浮提示显示过滤前后数量
              Tooltip(
                message: context.l10n.tagGroup_totalTagsTooltip(
                  widget.originalTagCount.toString(),
                  widget.tagCount.toString(),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        theme.colorScheme.secondaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    context.l10n.naiMode_totalTags(widget.tagCount.toString()),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // 全选/取消选择切换按钮
              Builder(
                builder: (context) {
                  final allSelected =
                      widget.enabledMappingCount == widget.totalMappingCount;
                  return _buildCompactToggleButton(
                    theme: theme,
                    icon: allSelected ? Icons.deselect : Icons.select_all,
                    label: allSelected
                        ? context.l10n.common_deselectAll
                        : context.l10n.common_selectAll,
                    onTap: widget.onToggleSelectAll,
                  );
                },
              ),
              const SizedBox(width: 8),
              // 展开/收起按钮
              _buildCompactToggleButton(
                theme: theme,
                icon:
                    widget.allExpanded ? Icons.unfold_less : Icons.unfold_more,
                label: widget.allExpanded
                    ? context.l10n.common_collapseAll
                    : context.l10n.common_expandAll,
                onTap: widget.onToggleExpand,
              ),
              const SizedBox(width: 12),
              // 缓存管理按钮
              _buildCompactToggleButton(
                theme: theme,
                icon: Icons.storage_outlined,
                label: context.l10n.cache_manage,
                onTap: () => CacheManagementDialog.show(context),
              ),
              const SizedBox(width: 8),
              // 重置为默认按钮
              _buildCompactToggleButton(
                theme: theme,
                icon: Icons.restart_alt,
                label: context.l10n.preset_resetToDefault,
                onTap: widget.onResetPreset,
              ),
              const SizedBox(width: 8),
              // 总览设置按钮
              _buildCompactToggleButton(
                theme: theme,
                icon: Icons.tune,
                label: context.l10n.globalSettings_title,
                onTap: () => GlobalSettingsDialog.show(context),
              ),
              const SizedBox(width: 8),
              // 同步按钮 - 添加 Tooltip 显示上次同步时间
              Tooltip(
                message: _getLastSyncTooltip(context, tagGroupMappings),
                child: FilledButton.icon(
                  onPressed: widget.isSyncing ? null : widget.onSync,
                  icon: widget.isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.sync, size: 18),
                  label: Text(context.l10n.tagLibrary_syncNow),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 滑块
          SizedBox(
            height: 24,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: theme.colorScheme.primary,
                inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
                thumbColor: theme.colorScheme.primary,
                overlayColor: theme.colorScheme.primary.withOpacity(0.1),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: displayValue,
                min: 0,
                max: 1,
                onChanged: (value) {
                  setState(() {
                    _draggingValue = value;
                  });
                },
                onChangeEnd: (value) {
                  final postCount = _sliderToPostCount(value);
                  // 将 post count 转换为 popularity threshold (0-100)
                  ref
                      .read(tagGroupSyncNotifierProvider.notifier)
                      .setPopularityThreshold(postCount ~/ 100);
                  setState(() {
                    _draggingValue = null;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取上次同步时间的 Tooltip 文本
  String _getLastSyncTooltip(
    BuildContext context,
    List<TagGroupMapping> mappings,
  ) {
    // 找出最近的同步时间
    DateTime? lastSync;
    for (final mapping in mappings.where((m) => m.enabled)) {
      if (mapping.lastSyncedAt != null) {
        if (lastSync == null || mapping.lastSyncedAt!.isAfter(lastSync)) {
          lastSync = mapping.lastSyncedAt;
        }
      }
    }

    if (lastSync == null) {
      return context.l10n.tagLibrary_neverSynced;
    }

    // 格式化时间
    return context.l10n.naiMode_lastSync(_formatSyncTime(context, lastSync));
  }

  /// 格式化同步时间为人性化文本
  String _formatSyncTime(BuildContext context, DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return context.l10n.timeAgo_justNow;
    } else if (diff.inMinutes < 60) {
      return context.l10n.timeAgo_minutes(diff.inMinutes.toString());
    } else if (diff.inHours < 24) {
      return context.l10n.timeAgo_hours(diff.inHours.toString());
    } else if (diff.inDays < 7) {
      return context.l10n.timeAgo_days(diff.inDays.toString());
    } else {
      return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildCompactToggleButton({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
