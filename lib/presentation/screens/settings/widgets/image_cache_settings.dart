import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/memory_aware_cache_config.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../providers/cache_settings_provider.dart';
import '../../../widgets/common/app_toast.dart';

/// 图片缓存设置组件
///
/// 用于设置页面，管理图片缓存的配置选项和统计信息
/// - 最大内存限制
/// - 最大对象数量
/// - 缓存淘汰策略
/// - 内存监控开关
/// - 内存阈值百分比
class ImageCacheSettingsWidget extends ConsumerStatefulWidget {
  const ImageCacheSettingsWidget({super.key});

  @override
  ConsumerState<ImageCacheSettingsWidget> createState() =>
      _ImageCacheSettingsWidgetState();
}

class _ImageCacheSettingsWidgetState
    extends ConsumerState<ImageCacheSettingsWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsState = ref.watch(cacheSettingsNotifierProvider);
    final statisticsState = ref.watch(cacheStatisticsNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 主内容卡片
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 缓存统计信息区域
                  _CacheStatisticsSection(
                    currentMemoryMB: statisticsState.currentMemoryMB,
                    objectCount: statisticsState.objectCount,
                    hitRate: statisticsState.hitRate,
                    maxMemoryMB: settingsState.maxMemoryMB,
                    onRefresh: () => ref
                        .read(cacheStatisticsNotifierProvider.notifier)
                        .refresh(),
                  ),

                  // 分隔线
                  Divider(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                  ),

                  // 缓存设置区域
                  _CacheSettingsSection(
                    maxMemoryMB: settingsState.maxMemoryMB,
                    maxObjectCount: settingsState.maxObjectCount,
                    evictionPolicy: settingsState.evictionPolicy,
                    enableMemoryMonitoring:
                        settingsState.enableMemoryMonitoring,
                    memoryThresholdPercentage:
                        settingsState.memoryThresholdPercentage,
                    onMaxMemoryChanged: (value) => ref
                        .read(cacheSettingsNotifierProvider.notifier)
                        .setMaxMemoryMB(value),
                    onMaxObjectCountChanged: (value) => ref
                        .read(cacheSettingsNotifierProvider.notifier)
                        .setMaxObjectCount(value),
                    onEvictionPolicyChanged: (policy) => ref
                        .read(cacheSettingsNotifierProvider.notifier)
                        .setEvictionPolicy(policy),
                    onMemoryMonitoringChanged: (value) => ref
                        .read(cacheSettingsNotifierProvider.notifier)
                        .setEnableMemoryMonitoring(value),
                    onThresholdChanged: (value) => ref
                        .read(cacheSettingsNotifierProvider.notifier)
                        .setMemoryThresholdPercentage(value),
                  ),

                  // 分隔线
                  Divider(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                  ),

                  // 操作按钮区域
                  _CacheActionButtons(
                    onClearCache: () => _showClearCacheDialog(context),
                    onResetStats: () => _resetStatistics(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 显示清除缓存确认对话框
  Future<void> _showClearCacheDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.error,
            size: 28,
          ),
        ),
        title: Text(context.l10n.imageCache_clearCacheTitle),
        content: Text(
          context.l10n.imageCache_clearCacheMessage,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(context.l10n.imageCache_cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(context.l10n.imageCache_confirmClear),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _clearCache(context);
    }
  }

  /// 清除缓存
  Future<void> _clearCache(BuildContext context) async {
    try {
      await ref.read(cacheStatisticsNotifierProvider.notifier).clearCache();
      if (context.mounted) {
        AppToast.success(context, context.l10n.imageCache_cacheCleared);
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.imageCache_clearFailed(e.toString()));
      }
    }
  }

  /// 重置统计信息
  Future<void> _resetStatistics(BuildContext context) async {
    try {
      ref.read(cacheStatisticsNotifierProvider.notifier).resetStatistics();
      if (context.mounted) {
        AppToast.success(context, context.l10n.imageCache_statisticsReset);
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.imageCache_resetFailed(e.toString()));
      }
    }
  }
}

/// 缓存统计信息区域
class _CacheStatisticsSection extends StatelessWidget {
  final double currentMemoryMB;
  final int objectCount;
  final double hitRate;
  final int maxMemoryMB;
  final VoidCallback onRefresh;

  const _CacheStatisticsSection({
    required this.currentMemoryMB,
    required this.objectCount,
    required this.hitRate,
    required this.maxMemoryMB,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usagePercentage = maxMemoryMB > 0
        ? (currentMemoryMB / maxMemoryMB * 100).clamp(0, 100)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.imageCache_cacheStatus,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: onRefresh,
                icon: Icon(
                  Icons.refresh_outlined,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
                tooltip: context.l10n.imageCache_refreshStatistics,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 内存使用卡片
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primaryContainer.withOpacity(0.3),
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 内存使用进度条
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.imageCache_memoryUsage,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${currentMemoryMB.toStringAsFixed(1)} MB / $maxMemoryMB MB',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: usagePercentage / 100,
                    minHeight: 8,
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getProgressColor(usagePercentage, theme),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 统计信息行
                Row(
                  children: [
                    _StatItem(
                      icon: Icons.photo_library_outlined,
                      label: context.l10n.imageCache_cachedObjects,
                      value: '$objectCount',
                      theme: theme,
                    ),
                    const SizedBox(width: 24),
                    _StatItem(
                      icon: Icons.speed_outlined,
                      label: context.l10n.imageCache_hitRate,
                      value: '${(hitRate * 100).toStringAsFixed(1)}%',
                      theme: theme,
                    ),
                    const SizedBox(width: 24),
                    _StatItem(
                      icon: Icons.data_usage_outlined,
                      label: context.l10n.imageCache_usageRate,
                      value: '${usagePercentage.toStringAsFixed(1)}%',
                      theme: theme,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double percentage, ThemeData theme) {
    if (percentage < 50) {
      return theme.colorScheme.primary;
    } else if (percentage < 80) {
      return Colors.orange;
    } else {
      return theme.colorScheme.error;
    }
  }
}

/// 统计信息项
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 缓存设置区域
class _CacheSettingsSection extends StatelessWidget {
  final int maxMemoryMB;
  final int maxObjectCount;
  final EvictionPolicy evictionPolicy;
  final bool enableMemoryMonitoring;
  final int memoryThresholdPercentage;
  final ValueChanged<int> onMaxMemoryChanged;
  final ValueChanged<int> onMaxObjectCountChanged;
  final ValueChanged<EvictionPolicy> onEvictionPolicyChanged;
  final ValueChanged<bool> onMemoryMonitoringChanged;
  final ValueChanged<int> onThresholdChanged;

  const _CacheSettingsSection({
    required this.maxMemoryMB,
    required this.maxObjectCount,
    required this.evictionPolicy,
    required this.enableMemoryMonitoring,
    required this.memoryThresholdPercentage,
    required this.onMaxMemoryChanged,
    required this.onMaxObjectCountChanged,
    required this.onEvictionPolicyChanged,
    required this.onMemoryMonitoringChanged,
    required this.onThresholdChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Icon(
                Icons.settings_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.imageCache_cacheConfiguration,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 最大内存限制
          _MemoryLimitSlider(
            value: maxMemoryMB,
            onChanged: onMaxMemoryChanged,
          ),
          const SizedBox(height: 20),

          // 最大对象数量
          _ObjectCountSlider(
            value: maxObjectCount,
            onChanged: onMaxObjectCountChanged,
          ),
          const SizedBox(height: 20),

          // 淘汰策略选择
          _EvictionPolicySelector(
            value: evictionPolicy,
            onChanged: onEvictionPolicyChanged,
          ),
          const SizedBox(height: 20),

          // 内存监控开关
          _MemoryMonitoringSwitch(
            value: enableMemoryMonitoring,
            onChanged: onMemoryMonitoringChanged,
          ),
          const SizedBox(height: 16),

          // 内存阈值（仅在开启监控时显示）
          if (enableMemoryMonitoring) ...[
            _MemoryThresholdSlider(
              value: memoryThresholdPercentage,
              onChanged: onThresholdChanged,
            ),
          ],
        ],
      ),
    );
  }
}

/// 内存限制滑块
class _MemoryLimitSlider extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _MemoryLimitSlider({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storage_outlined,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Text(
                  context.l10n.imageCache_maxMemoryLimit,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$value MB',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: theme.colorScheme.primary,
            inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
            thumbColor: theme.colorScheme.primary,
            overlayColor: theme.colorScheme.primary.withOpacity(0.1),
            trackHeight: 4,
          ),
          child: Slider(
            value: value.toDouble(),
            min: 50,
            max: 500,
            divisions: 9,
            onChanged: (v) => onChanged(v.toInt()),
          ),
        ),
        // 预设按钮
        Wrap(
          spacing: 8,
          children: [
            _PresetButton(
              label: '50MB',
              onPressed: () => onChanged(50),
              isSelected: value == 50,
            ),
            _PresetButton(
              label: '100MB',
              onPressed: () => onChanged(100),
              isSelected: value == 100,
            ),
            _PresetButton(
              label: '200MB',
              onPressed: () => onChanged(200),
              isSelected: value == 200,
            ),
            _PresetButton(
              label: '500MB',
              onPressed: () => onChanged(500),
              isSelected: value == 500,
            ),
          ],
        ),
      ],
    );
  }
}

/// 对象数量滑块
class _ObjectCountSlider extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _ObjectCountSlider({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.photo_outlined,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Text(
                  context.l10n.imageCache_maxCacheCount,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$value',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: theme.colorScheme.primary,
            inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
            thumbColor: theme.colorScheme.primary,
            overlayColor: theme.colorScheme.primary.withOpacity(0.1),
            trackHeight: 4,
          ),
          child: Slider(
            value: value.toDouble(),
            min: 100,
            max: 2000,
            divisions: 19,
            onChanged: (v) => onChanged(v.toInt()),
          ),
        ),
      ],
    );
  }
}

/// 淘汰策略选择器
class _EvictionPolicySelector extends StatelessWidget {
  final EvictionPolicy value;
  final ValueChanged<EvictionPolicy> onChanged;

  const _EvictionPolicySelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_fix_high_outlined,
              size: 16,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Text(
              context.l10n.imageCache_evictionPolicy,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: EvictionPolicy.values.map((policy) {
            final isSelected = policy == value;
            return _PresetChip(
              label: policy.displayName,
              sublabel: _getPolicyDescription(context, policy),
              isSelected: isSelected,
              onSelected: () => onChanged(policy),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _getPolicyDescription(BuildContext context, EvictionPolicy policy) {
    switch (policy) {
      case EvictionPolicy.lru:
        return context.l10n.imageCache_policyLru;
      case EvictionPolicy.fifo:
        return context.l10n.imageCache_policyFifo;
      case EvictionPolicy.lfu:
        return context.l10n.imageCache_policyLfu;
    }
  }
}

/// 内存监控开关
class _MemoryMonitoringSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _MemoryMonitoringSwitch({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: value
          ? theme.colorScheme.primaryContainer.withOpacity(0.3)
          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: value
                  ? theme.colorScheme.primary.withOpacity(0.3)
                  : theme.colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                value
                    ? Icons.memory_outlined
                    : Icons.memory_outlined,
                size: 20,
                color: value
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.imageCache_autoMemoryMonitoring,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      context.l10n.imageCache_autoCleanSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 内存阈值滑块
class _MemoryThresholdSlider extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _MemoryThresholdSlider({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.imageCache_cleanupThreshold,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$value%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
              thumbColor: theme.colorScheme.primary,
              overlayColor: theme.colorScheme.primary.withOpacity(0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.toDouble(),
              min: 50,
              max: 95,
              divisions: 9,
              onChanged: (v) => onChanged(v.toInt()),
            ),
          ),
          Text(
            context.l10n.imageCache_thresholdDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// 预设按钮
class _PresetButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isSelected;

  const _PresetButton({
    required this.label,
    required this.onPressed,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// 预设选择芯片
class _PresetChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool isSelected;
  final VoidCallback onSelected;

  const _PresetChip({
    required this.label,
    required this.sublabel,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              Text(
                sublabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary.withOpacity(0.8)
                      : theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 缓存操作按钮
class _CacheActionButtons extends StatelessWidget {
  final VoidCallback onClearCache;
  final VoidCallback onResetStats;

  const _CacheActionButtons({
    required this.onClearCache,
    required this.onResetStats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // 重置统计按钮
          Expanded(
            child: _ActionButton(
              icon: Icons.restart_alt_outlined,
              label: context.l10n.imageCache_resetStatistics,
              onPressed: onResetStats,
            ),
          ),
          const SizedBox(width: 12),
          // 清除缓存按钮（主要操作）
          Expanded(
            child: _ActionButton(
              icon: Icons.delete_sweep_outlined,
              label: context.l10n.imageCache_clearCache,
              isDestructive: true,
              onPressed: onClearCache,
            ),
          ),
        ],
      ),
    );
  }
}

/// 操作按钮
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.isDestructive = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bgColor = isDestructive
        ? theme.colorScheme.errorContainer.withOpacity(0.5)
        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5);
    final fgColor = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fgColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
