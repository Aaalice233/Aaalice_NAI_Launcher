import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/gallery_cache_manager.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/gallery_performance_monitor.dart';
import '../../../core/utils/localization_extension.dart';

/// 缓存监控状态
class CacheMonitorState {
  final bool isLoading;
  final CacheStatistics? statistics;
  final Map<String, CacheStats> performanceStats;
  final String? error;
  final DateTime? lastRefreshTime;

  const CacheMonitorState({
    this.isLoading = false,
    this.statistics,
    this.performanceStats = const {},
    this.error,
    this.lastRefreshTime,
  });

  CacheMonitorState copyWith({
    bool? isLoading,
    CacheStatistics? statistics,
    Map<String, CacheStats>? performanceStats,
    String? error,
    bool clearError = false,
    DateTime? lastRefreshTime,
  }) {
    return CacheMonitorState(
      isLoading: isLoading ?? this.isLoading,
      statistics: statistics ?? this.statistics,
      performanceStats: performanceStats ?? this.performanceStats,
      error: clearError ? null : (error ?? this.error),
      lastRefreshTime: lastRefreshTime ?? this.lastRefreshTime,
    );
  }
}

/// 缓存监控状态管理器
class CacheMonitorController extends StateNotifier<CacheMonitorState> {
  Timer? _refreshTimer;

  CacheMonitorController() : super(const CacheMonitorState()) {
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    // 每 5 秒自动刷新一次
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      refresh();
    });
    // 立即刷新一次
    refresh();
  }

  Future<void> refresh() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final cacheManager = GalleryCacheManager();
      final statistics = await cacheManager.getStatistics();
      final performanceStats = performanceMonitor.getAllCacheStats();

      state = state.copyWith(
        isLoading: false,
        statistics: statistics,
        performanceStats: performanceStats,
        clearError: true,
        lastRefreshTime: DateTime.now(),
      );
    } catch (e, stack) {
      AppLogger.e('刷新缓存统计失败', e, stack, 'CacheMonitorController');
      state = state.copyWith(
        isLoading: false,
        error: '刷新失败: $e',
        lastRefreshTime: DateTime.now(),
      );
    }
  }

  Future<void> clearAllCache() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final cacheManager = GalleryCacheManager();
      await cacheManager.clearAll();
      await refresh();
      AppLogger.i('所有缓存已清除', 'CacheMonitorController');
    } catch (e, stack) {
      AppLogger.e('清除缓存失败', e, stack, 'CacheMonitorController');
      state = state.copyWith(isLoading: false, error: '清除缓存失败: $e');
    }
  }

  Future<void> clearL1MemoryCache() async {
    state = state.copyWith(isLoading: true);

    try {
      final cacheManager = GalleryCacheManager();
      await cacheManager.clearL1MemoryCache();
      await refresh();
      AppLogger.i('L1 内存缓存已清除', 'CacheMonitorController');
    } catch (e, stack) {
      AppLogger.e('清除 L1 缓存失败', e, stack, 'CacheMonitorController');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> clearL2HiveCache() async {
    state = state.copyWith(isLoading: true);

    try {
      final cacheManager = GalleryCacheManager();
      await cacheManager.clearL2HiveCache();
      await refresh();
      AppLogger.i('L2 Hive 缓存已清除', 'CacheMonitorController');
    } catch (e, stack) {
      AppLogger.e('清除 L2 缓存失败', e, stack, 'CacheMonitorController');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> resetStatistics() async {
    try {
      final cacheManager = GalleryCacheManager();
      cacheManager.resetStatistics();
      performanceMonitor.clearAll();
      await refresh();
      AppLogger.i('缓存统计已重置', 'CacheMonitorController');
    } catch (e, stack) {
      AppLogger.e('重置统计失败', e, stack, 'CacheMonitorController');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

/// 缓存监控 Provider
final cacheMonitorProvider =
    StateNotifierProvider<CacheMonitorController, CacheMonitorState>(
      (ref) => CacheMonitorController(),
    );

/// 缓存监控 Widget
///
/// 实时显示缓存统计信息，提供手动清理和调试功能。
/// 主要用于开发调试和性能分析。
class CacheMonitorWidget extends ConsumerWidget {
  final bool compact;
  final VoidCallback? onClose;

  const CacheMonitorWidget({super.key, this.compact = false, this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cacheMonitorProvider);
    final controller = ref.read(cacheMonitorProvider.notifier);

    if (compact) {
      return _buildCompactView(context, state, controller);
    }

    return _buildFullView(context, state, controller);
  }

  Widget _buildCompactView(
    BuildContext context,
    CacheMonitorState state,
    CacheMonitorController controller,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stats = state.statistics;

    return Card(
      margin: const EdgeInsets.all(8),
      child: InkWell(
        onTap: () => _showFullDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.storage_outlined,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              if (state.isLoading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                )
              else if (stats != null) ...[
                Text(
                  'L1: ${stats.l1MemorySize}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'L2: ${stats.l2HiveSize}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'DB: ${stats.l3DatabaseImageCount}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else
                Text(
                  context.l10n.common_clickToRefresh,
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullView(
    BuildContext context,
    CacheMonitorState state,
    CacheMonitorController controller,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.localGallery_cacheMonitor,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (state.isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: controller.refresh,
                    tooltip: context.l10n.common_refresh,
                  ),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                    tooltip: context.l10n.common_close,
                  ),
              ],
            ),
            const Divider(),
            // 错误提示
            if (state.error != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.error,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // 缓存统计
            if (state.statistics != null)
              _CacheStatisticsPanel(
                statistics: state.statistics!,
                lastRefreshTime: state.lastRefreshTime,
              ),
            // 性能监控统计
            if (state.performanceStats.isNotEmpty) ...[
              const SizedBox(height: 16),
              _PerformanceStatsPanel(stats: state.performanceStats),
            ],
            const SizedBox(height: 16),
            // 操作按钮
            _ActionButtons(controller: controller),
          ],
        ),
      ),
    );
  }

  void _showFullDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 500,
          child: CacheMonitorWidget(
            compact: false,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}

/// 缓存统计面板
class _CacheStatisticsPanel extends StatelessWidget {
  final CacheStatistics statistics;
  final DateTime? lastRefreshTime;

  const _CacheStatisticsPanel({required this.statistics, this.lastRefreshTime});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.localGallery_threeLayerCacheStats,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (lastRefreshTime != null)
              Text(
                l10n.localGallery_updatedAt(
                  _formatTime(context, lastRefreshTime!),
                ),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // L1 内存缓存
        _CacheLevelCard(
          level: 'L1',
          name: l10n.localGallery_memoryCache,
          size: statistics.l1MemorySize,
          hitRate: statistics.l1HitRate,
          color: Colors.blue,
          icon: Icons.memory,
        ),
        const SizedBox(height: 8),
        // L2 Hive 缓存
        _CacheLevelCard(
          level: 'L2',
          name: l10n.localGallery_hiveCache,
          size: statistics.l2HiveSize,
          hitRate: statistics.l2HitRate,
          color: Colors.green,
          icon: Icons.storage,
        ),
        const SizedBox(height: 8),
        // L3 数据库缓存
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'L3',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.storage,
                color: Colors.orange.withValues(alpha: 0.7),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.localGallery_sqliteDatabase,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${statistics.l3DatabaseImageCount} ${l10n.localGallery_imageUnit} | ${statistics.l3DatabaseMetadataCount} ${l10n.localGallery_metadataUnit}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(BuildContext context, DateTime time) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 10) {
      return l10n.common_justNow;
    } else if (diff.inSeconds < 60) {
      return l10n.common_minutesAgo(1);
    } else if (diff.inMinutes < 60) {
      return l10n.common_minutesAgo(diff.inMinutes);
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// 缓存层级卡片
class _CacheLevelCard extends StatelessWidget {
  final String level;
  final String name;
  final int size;
  final double hitRate;
  final Color color;
  final IconData icon;

  const _CacheLevelCard({
    required this.level,
    required this.name,
    required this.size,
    required this.hitRate,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              level,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, color: color.withValues(alpha: 0.7), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  '$size ${l10n.localGallery_entriesUnit}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(hitRate * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getHitRateColor(hitRate),
                ),
              ),
              Text(
                l10n.localGallery_hitRate,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getHitRateColor(double rate) {
    if (rate >= 0.8) return Colors.green;
    if (rate >= 0.5) return Colors.orange;
    return Colors.red;
  }
}

/// 性能统计面板
class _PerformanceStatsPanel extends StatelessWidget {
  final Map<String, CacheStats> stats;

  const _PerformanceStatsPanel({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.localGallery_performanceStats,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...stats.entries.map((entry) {
          final stat = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    entry.key,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: _buildStatChip(
                    l10n.localGallery_cacheHit,
                    stat.hitCount,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatChip(
                    l10n.localGallery_cacheMiss,
                    stat.missCount,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: Text(
                    '${(stat.hitRate * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: stat.hitRate >= 0.8 ? Colors.green : Colors.orange,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text('$count', style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}

/// 操作按钮面板
class _ActionButtons extends StatelessWidget {
  final CacheMonitorController controller;

  const _ActionButtons({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildActionButton(
          context,
          label: l10n.localGallery_clearL1,
          icon: Icons.memory,
          color: Colors.blue,
          onPressed: controller.clearL1MemoryCache,
        ),
        _buildActionButton(
          context,
          label: l10n.localGallery_clearL2,
          icon: Icons.storage,
          color: Colors.green,
          onPressed: controller.clearL2HiveCache,
        ),
        _buildActionButton(
          context,
          label: l10n.localGallery_clearAll,
          icon: Icons.delete_forever,
          color: Colors.red,
          onPressed: () => _showClearAllConfirm(context),
        ),
        _buildActionButton(
          context,
          label: l10n.localGallery_resetStats,
          icon: Icons.restart_alt,
          color: Colors.orange,
          onPressed: controller.resetStatistics,
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  void _showClearAllConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.localGallery_confirmClearCache),
        content: Text(context.l10n.localGallery_confirmClearCacheContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              controller.clearAllCache();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.l10n.common_clear),
          ),
        ],
      ),
    );
  }
}

/// 悬浮缓存监控按钮
///
/// 用于在开发模式下快速访问缓存监控
class FloatingCacheMonitorButton extends StatelessWidget {
  const FloatingCacheMonitorButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: SizedBox(
              width: 500,
              height: 600,
              child: CacheMonitorWidget(
                compact: false,
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        );
      },
      tooltip: context.l10n.localGallery_cacheMonitor,
      child: const Icon(Icons.analytics_outlined),
    );
  }
}
