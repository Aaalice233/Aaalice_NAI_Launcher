import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/services/tag_database_connection.dart';
import '../../../../data/models/cache/data_source_cache_meta.dart';
import '../../../providers/data_source_cache_provider.dart';
import '../../../widgets/common/app_toast.dart';

/// Provider for TagDatabaseConnection
final tagDatabaseConnectionProvider = Provider((ref) => TagDatabaseConnection());

/// 数据源缓存管理设置组件
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Danbooru 标签设置区域
          const Padding(
            padding: EdgeInsets.all(16),
            child: _TagCompletionDataSection(),
          ),

          // 分隔线
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              height: 24,
            ),
          ),

          // 清除所有缓存按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _ClearAllCacheButton(
              onClearAll: () => _showClearAllDialog(context),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示清除所有缓存确认对话框
  Future<void> _showClearAllDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: theme.colorScheme.error,
          size: 32,
        ),
        title: const Text('清除 Danbooru 标签缓存'),
        content: const Text(
          '确定要清除 Danbooru 标签缓存吗？\n\n'
          '这将删除已下载的标签补全数据，清除后需要重新同步。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('确认清除'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // 等待确认对话框完全关闭
      await Future.delayed(Duration.zero);
      if (context.mounted) {
        await _clearAllCaches(context);
      }
    }
  }

  /// 关闭对话框（如果存在且有效）
  void _closeDialog(BuildContext? ctx) {
    if (ctx != null && ctx.mounted) {
      Navigator.of(ctx).pop();
    }
  }

  /// 清除 Danbooru 标签缓存
  Future<void> _clearAllCaches(BuildContext context) async {
    // 保存根 context，用于显示 Toast
    final rootContext = context;

    // 使用自定义对话框控制器
    BuildContext? dialogContextOrNull;

    if (!context.mounted) return;

    // 显示进度指示器
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        dialogContextOrNull = dialogCtx;
        return const PopScope(
          canPop: false,
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在清除缓存...'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    // 等待一帧确保对话框已显示
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      // 关闭数据库连接并删除数据库文件
      final dbConnection = ref.read(tagDatabaseConnectionProvider);
      await dbConnection.deleteDatabase();

      // 清除 Danbooru 标签缓存
      await ref
          .read(danbooruTagsCacheNotifierProvider.notifier)
          .clearCache();

      // 刷新状态
      ref.invalidate(danbooruTagsCacheNotifierProvider);

      // 关闭进度对话框并延迟显示成功提示
      if (dialogContextOrNull != null && dialogContextOrNull!.mounted) {
        _closeDialog(dialogContextOrNull);
      }
      await Future.delayed(const Duration(milliseconds: 100));

      if (rootContext.mounted) {
        AppToast.success(rootContext, '数据库已重置，下次启动时将重新导入');
      }
    } catch (e) {
      // 关闭进度对话框并延迟显示错误提示
      if (dialogContextOrNull != null && dialogContextOrNull!.mounted) {
        _closeDialog(dialogContextOrNull);
      }
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
    final theme = Theme.of(context);
    final state = ref.watch(danbooruTagsCacheNotifierProvider);

    // 同步处理函数
    Future<void> handleSync() async {
      final notifier = ref.read(danbooruTagsCacheNotifierProvider.notifier);
      await notifier.refresh();
    }

    // 取消同步处理
    void handleCancel() {
      ref.read(danbooruTagsCacheNotifierProvider.notifier).cancelSync();
    }

    // 判断是否正在同步
    final isSyncing = state.isRefreshing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 状态信息 - 显示标签数量
        _StatusRow(
          isLoaded: state.totalTags > 0,
          loadedText: '已加载 ${state.totalTags} 个标签',
          notLoadedText: '未加载',
          lastUpdate: state.lastUpdate,
        ),
        const SizedBox(height: 12),

        // 热度档位选择
        _HotPresetSelector(
          preset: state.hotPreset,
          customThreshold: state.customThreshold,
          onPresetChanged: (preset, customThreshold) {
            ref
                .read(danbooruTagsCacheNotifierProvider.notifier)
                .setHotPreset(preset, customThreshold: customThreshold);
          },
        ),
        const SizedBox(height: 12),

        // 自动刷新间隔设置
        _RefreshIntervalSelector(
          value: state.refreshInterval,
          onChanged: (interval) {
            ref
                .read(danbooruTagsCacheNotifierProvider.notifier)
                .setRefreshInterval(interval);
          },
        ),
        const SizedBox(height: 12),

        // 进度条（标签同步）
        if (isSyncing) ...[
          _SyncProgressIndicator(
            progress: state.progress,
            message: state.message,
          ),
          const SizedBox(height: 12),
        ],

        // 错误信息
        if (state.error != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 操作按钮 - 合并的同步按钮
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: isSyncing ? Icons.stop : Icons.refresh,
                label: isSyncing ? '取消同步' : '立即同步',
                isLoading: false,
                onPressed: isSyncing ? handleCancel : handleSync,
              ),
            ),
            const SizedBox(width: 8),
            _ActionButton(
              icon: Icons.delete_outline,
              label: '清除',
              isDestructive: true,
              onPressed: isSyncing
                  ? null
                  : () async {
                      await ref
                          .read(danbooruTagsCacheNotifierProvider.notifier)
                          .clearCache();
                      if (context.mounted) {
                        AppToast.info(context, '标签缓存已清除');
                      }
                    },
            ),
          ],
        ),
      ],
    );
  }
}

/// 状态行
class _StatusRow extends StatelessWidget {
  final bool isLoaded;
  final String loadedText;
  final String notLoadedText;
  final DateTime? lastUpdate;

  const _StatusRow({
    required this.isLoaded,
    required this.loadedText,
    required this.notLoadedText,
    this.lastUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isLoaded ? Icons.check_circle : Icons.cloud_off,
            size: 16,
            color: isLoaded
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoaded ? loadedText : notLoadedText,
                  style: theme.textTheme.bodyMedium,
                ),
                if (lastUpdate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '上次更新: ${timeago.format(lastUpdate!, locale: 'zh')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
        // 标签行
        Text(
          '热度筛选',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        // 档位选择
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TagHotPreset.values.map((p) {
            final isSelected = p == preset;
            return ChoiceChip(
              label: Text(p.displayName),
              selected: isSelected,
              onSelected: (_) => onPresetChanged(p, null),
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
        // 自定义阈值滑块
        if (preset == TagHotPreset.custom) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '阈值: $customThreshold',
                style: theme.textTheme.bodySmall,
              ),
              Expanded(
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
        ],
      ],
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
        Text(
          '自动刷新间隔',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: AutoRefreshInterval.values.map((interval) {
            final isSelected = interval == value;
            return ChoiceChip(
              label: Text(interval.displayName),
              selected: isSelected,
              onSelected: (_) => onChanged(interval),
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                fontSize: 12,
              ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress > 0 ? progress : null,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 4),
          Text(
            message!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ],
    );
  }
}

/// 操作按钮
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLoading;
  final bool isDestructive;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.isLoading = false,
    this.isDestructive = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isDestructive) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.error,
          side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: onPressed,
      icon: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.onPrimary,
              ),
            )
          : Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

/// 清除所有缓存按钮
class _ClearAllCacheButton extends StatelessWidget {
  final VoidCallback onClearAll;

  const _ClearAllCacheButton({required this.onClearAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedButton.icon(
      onPressed: onClearAll,
      icon: Icon(
        Icons.delete_sweep_outlined,
        color: theme.colorScheme.error,
      ),
      label: Text(
        '清除标签缓存',
        style: TextStyle(color: theme.colorScheme.error),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.error,
        side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
        minimumSize: const Size(double.infinity, 44),
      ),
    );
  }
}
