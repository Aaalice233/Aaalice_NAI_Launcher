import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/services/tag_database_connection.dart';
import '../../../../data/models/cache/data_source_cache_meta.dart';
import '../../../providers/data_source_cache_provider.dart';
import '../../../widgets/common/app_toast.dart';

/// Provider for TagDatabaseConnection
final tagDatabaseConnectionProvider =
    Provider((ref) => TagDatabaseConnection());

/// 标签补全数据源管理设置组件
///
/// 用于设置页面，管理 Danbooru 标签缓存
/// - 标签补全数据（Danbooru API）
class DataSourceCacheSettings extends ConsumerStatefulWidget {
  const DataSourceCacheSettings({super.key});

  @override
  ConsumerState<DataSourceCacheSettings> createState() =>
      _DataSourceCacheSettingsState();
}

class _DataSourceCacheSettingsState
    extends ConsumerState<DataSourceCacheSettings> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 主内容卡片（标题已在外部settings_screen中显示）
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
                  // 标签补全数据部分
                  const _TagCompletionDataSection(),

                  // 分隔线
                  Divider(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                  ),

                  // 清除所有缓存按钮
                  _ClearAllCacheButton(
                    onClearAll: () => _showClearAllDialog(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 显示清除所有缓存确认对话框
  Future<void> _showClearAllDialog(BuildContext context) async {
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
        title: const Text('清除标签数据源'),
        content: Text(
          '确定要清除所有标签数据源吗？\n\n'
          '这将清空以下数据：\n'
          '• Danbooru 标签补全数据\n'
          '• 中英文标签翻译\n'
          '• 标签共现关系\n\n'
          '清除后下次启动时将自动重新加载数据。',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('确认清除'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _clearAllCaches(context);
    }
  }

  void _closeDialog(BuildContext? ctx) {
    if (ctx?.mounted ?? false) {
      Navigator.of(ctx!).pop();
    }
  }

  /// 清除 Danbooru 标签缓存
  Future<void> _clearAllCaches(BuildContext context) async {
    final rootContext = context;
    BuildContext? dialogContext;

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 32,
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '正在清除数据...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final dbConnection = ref.read(tagDatabaseConnectionProvider);
      await dbConnection.clearAllTables();
      await ref.read(danbooruTagsCacheNotifierProvider.notifier).clearCache();
      ref.invalidate(danbooruTagsCacheNotifierProvider);

      _closeDialog(dialogContext);
      await Future.delayed(const Duration(milliseconds: 100));

      if (rootContext.mounted) {
        AppToast.success(rootContext, '标签数据已清除，下次启动时将重新加载');
      }
    } catch (e) {
      _closeDialog(dialogContext);
      await Future.delayed(const Duration(milliseconds: 100));

      if (rootContext.mounted) {
        AppToast.error(rootContext, '重置失败: $e');
      }
    }
  }
}

/// 标签补全数据部分
class _TagCompletionDataSection extends ConsumerWidget {
  const _TagCompletionDataSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(danbooruTagsCacheNotifierProvider);
    final isSyncing = state.isRefreshing;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部信息区域
          _buildHeader(context, state),
          const SizedBox(height: 20),

          // 热度档位选择 + 自动刷新间隔（横向并排，顶部对齐）
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：热度筛选
              Expanded(
                child: _HotPresetSelector(
                  preset: state.hotPreset,
                  customThreshold: state.customThreshold,
                  onPresetChanged: (preset, customThreshold) {
                    ref
                        .read(danbooruTagsCacheNotifierProvider.notifier)
                        .setHotPreset(preset, customThreshold: customThreshold);
                  },
                ),
              ),
              const SizedBox(width: 24),
              // 右侧：自动刷新间隔
              Expanded(
                child: _RefreshIntervalSelector(
                  value: state.refreshInterval,
                  onChanged: (interval) {
                    ref
                        .read(danbooruTagsCacheNotifierProvider.notifier)
                        .setRefreshInterval(interval);
                  },
                ),
              ),
            ],
          ),

          // 进度条（仅在同步时显示）
          if (isSyncing) ...[
            const SizedBox(height: 20),
            _SyncProgressIndicator(
              progress: state.progress,
              message: state.message,
            ),
          ],

          // 错误信息
          if (state.error != null) ...[
            const SizedBox(height: 16),
            _ErrorMessage(message: state.error!),
          ],

          const SizedBox(height: 20),

          // 操作按钮（包含画师同步开关）
          _buildActionButtons(context, ref, state),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DanbooruTagsCacheState state) {
    final theme = Theme.of(context);
    final isLoaded = state.totalTags > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLoaded
              ? [
                  theme.colorScheme.primaryContainer.withOpacity(0.3),
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                ]
              : [
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLoaded
              ? theme.colorScheme.primary.withOpacity(0.2)
              : theme.colorScheme.outlineVariant.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isLoaded
                  ? theme.colorScheme.primary.withOpacity(0.15)
                  : theme.colorScheme.outline.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isLoaded ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              size: 24,
              color: isLoaded
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoaded ? '数据源已就绪' : '数据源未加载',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isLoaded
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                if (isLoaded) ...[
                  Text(
                    '已缓存 ${_formatNumber(state.totalTags)} 个标签',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (state.lastUpdate != null)
                    Text(
                      '上次更新: ${timeago.format(state.lastUpdate!, locale: 'zh')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                ] else
                  Text(
                    '点击"立即同步"下载标签数据',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  Widget _buildActionButtons(
      BuildContext context, WidgetRef ref, DanbooruTagsCacheState state,) {
    final isSyncing = state.isRefreshing;

    return Row(
      children: [
        // 同步画师开关（移到左边，宽度紧凑）
        _ArtistSyncCheckbox(
          value: state.syncArtists,
          isSyncing: isSyncing,
          onChanged: (value) => ref
              .read(danbooruTagsCacheNotifierProvider.notifier)
              .setSyncArtists(value),
        ),
        const SizedBox(width: 12),
        // 立即同步按钮
        Expanded(
          child: _ActionButton(
            icon: isSyncing ? Icons.stop_circle_outlined : Icons.sync_outlined,
            label: isSyncing ? '取消同步' : '立即同步',
            isPrimary: true,
            onPressed: isSyncing
                ? () => ref
                    .read(danbooruTagsCacheNotifierProvider.notifier)
                    .cancelSync()
                : () => ref
                    .read(danbooruTagsCacheNotifierProvider.notifier)
                    .refresh(),
          ),
        ),
      ],
    );
  }
}

/// 热度档位选择器
class _HotPresetSelector extends StatelessWidget {
  final TagHotPreset preset;
  final int customThreshold;
  final void Function(TagHotPreset preset, int? customThreshold)
      onPresetChanged;

  const _HotPresetSelector({
    required this.preset,
    required this.customThreshold,
    required this.onPresetChanged,
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
              Icons.local_fire_department_outlined,
              size: 16,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Text(
              '热度筛选',
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
          children: TagHotPreset.values.map((p) {
            final isSelected = p == preset;
            return _PresetChip(
              label: p.displayName,
              isSelected: isSelected,
              onSelected: () => onPresetChanged(p, null),
            );
          }).toList(),
        ),
        if (preset == TagHotPreset.custom) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '自定义阈值',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        customThreshold.toString(),
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
                    inactiveTrackColor:
                        theme.colorScheme.surfaceContainerHighest,
                    thumbColor: theme.colorScheme.primary,
                    overlayColor: theme.colorScheme.primary.withOpacity(0.1),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: customThreshold.toDouble(),
                    min: 10,
                    max: 50000,
                    divisions: 100,
                    onChanged: (v) => onPresetChanged(preset, v.toInt()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 预设选择芯片
class _PresetChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _PresetChip({
    required this.label,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

/// 自动刷新间隔选择器
class _RefreshIntervalSelector extends StatelessWidget {
  final AutoRefreshInterval value;
  final ValueChanged<AutoRefreshInterval> onChanged;

  const _RefreshIntervalSelector({
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
              Icons.schedule_outlined,
              size: 16,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Text(
              '自动刷新间隔',
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
          children: AutoRefreshInterval.values.map((interval) {
            final isSelected = interval == value;
            return _PresetChip(
              label: interval.displayName,
              isSelected: isSelected,
              onSelected: () => onChanged(interval),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// 同步进度指示器
class _SyncProgressIndicator extends StatelessWidget {
  final double progress;
  final String? message;

  const _SyncProgressIndicator({
    required this.progress,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
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
                  strokeWidth: 2.5,
                  value: progress > 0 ? progress : null,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '正在同步标签数据...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (progress > 0)
                Text(
                  '${(progress * 100).toInt()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 错误信息组件
class _ErrorMessage extends StatelessWidget {
  final String message;

  const _ErrorMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 同步画师复选框（紧凑样式）
class _ArtistSyncCheckbox extends StatelessWidget {
  final bool value;
  final bool isSyncing;
  final ValueChanged<bool> onChanged;

  const _ArtistSyncCheckbox({
    required this.value,
    required this.isSyncing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: value
          ? theme.colorScheme.primaryContainer.withOpacity(0.3)
          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: isSyncing ? null : () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: value
                  ? theme.colorScheme.primary.withOpacity(0.5)
                  : theme.colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                value ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
                color: isSyncing
                    ? theme.colorScheme.outline
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '同步画师',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSyncing
                      ? theme.colorScheme.outline
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 操作按钮
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.isPrimary = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isPrimary
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isPrimary
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.primary,
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

/// 清除所有缓存按钮（实心背景 + 悬停动效）
class _ClearAllCacheButton extends StatefulWidget {
  final VoidCallback onClearAll;

  const _ClearAllCacheButton({required this.onClearAll});

  @override
  State<_ClearAllCacheButton> createState() => _ClearAllCacheButtonState();
}

class _ClearAllCacheButtonState extends State<_ClearAllCacheButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            // 实心背景：使用 errorContainer 作为基础色
            color: _isHovered
                ? theme.colorScheme.errorContainer.withOpacity(0.8)
                : theme.colorScheme.errorContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            // 边框：悬停时更明显
            border: Border.all(
              color: _isHovered
                  ? theme.colorScheme.error.withOpacity(0.6)
                  : theme.colorScheme.error.withOpacity(0.3),
              width: _isHovered ? 2 : 1.5,
            ),
            // 阴影：悬停时添加发光效果
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: theme.colorScheme.error.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: widget.onClearAll,
              borderRadius: BorderRadius.circular(12),
              // 自定义涟漪颜色
              splashColor: theme.colorScheme.error.withOpacity(0.1),
              highlightColor: theme.colorScheme.error.withOpacity(0.05),
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(
                  vertical: _isHovered ? 16 : 14,
                  horizontal: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 图标：悬停时有轻微缩放
                    AnimatedScale(
                      scale: _isHovered ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.delete_sweep_outlined,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 文字：悬停时更亮
                    Text(
                      '清除所有标签数据',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                        // 悬停时稍微增大字体
                        fontSize: _isHovered ? 15 : 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // 悬停时显示箭头提示
                    AnimatedOpacity(
                      opacity: _isHovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: theme.colorScheme.error.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
