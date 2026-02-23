import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/database/datasources/danbooru_tag_data_source_provider.dart';
import '../../../../core/services/cache_clear_service.dart';
import '../../../../core/services/danbooru_tags_lazy_service.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../data/models/cache/data_source_cache_meta.dart';
import '../../../providers/data_source_cache_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../widgets/settings_card.dart';

/// 标签补全数据源管理设置组件
class DataSourceCacheSettings extends ConsumerStatefulWidget {
  const DataSourceCacheSettings({super.key});

  @override
  ConsumerState<DataSourceCacheSettings> createState() =>
      _DataSourceCacheSettingsState();
}

/// 清除数据对话框
class _ClearingDialog extends StatelessWidget {
  const _ClearingDialog();

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _DataSourceCacheSettingsState
    extends ConsumerState<DataSourceCacheSettings> {
  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(danbooruTagsCacheNotifierProvider);

    // 日志追踪：UI 状态决策
    asyncState.when(
      loading: () => AppLogger.i(
        '[UI] Provider状态: loading - 显示加载指示器',
        'DataSourceCacheSettings',
      ),
      error: (error, stack) => AppLogger.w(
        '[UI] Provider状态: error - 错误: $error',
        'DataSourceCacheSettings',
      ),
      data: (state) {
        final isLoaded = state.totalTags > 0;
        AppLogger.i(
          '[UI] Provider状态: data - '
              'totalTags=${state.totalTags}, '
              'isLoaded=$isLoaded, '
              'lastUpdate=${state.lastUpdate}, '
              'categoryStats=${state.categoryStats.toString()}',
          'DataSourceCacheSettings',
        );
      },
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 数据源状态卡片
          asyncState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _ErrorStateCard(message: error.toString()),
            data: (state) => Column(
              children: [
                _StatusCard(state: state),
                const SizedBox(height: 16),
                // 2. 同步设置卡片
                _SyncSettingsCard(
                  state: state,
                  onGeneralThresholdChanged: (preset, customThreshold) {
                    ref
                        .read(danbooruTagsCacheNotifierProvider.notifier)
                        .setGeneralThreshold(
                          preset,
                          customThreshold: customThreshold,
                        );
                  },
                  onArtistThresholdChanged: (preset, customThreshold) {
                    ref
                        .read(danbooruTagsCacheNotifierProvider.notifier)
                        .setArtistThreshold(
                          preset,
                          customThreshold: customThreshold,
                        );
                  },
                  onCharacterThresholdChanged: (preset, customThreshold) {
                    ref
                        .read(danbooruTagsCacheNotifierProvider.notifier)
                        .setCharacterThreshold(
                          preset,
                          customThreshold: customThreshold,
                        );
                  },
                  onCopyrightThresholdChanged: (preset, customThreshold) {
                    ref
                        .read(danbooruTagsCacheNotifierProvider.notifier)
                        .setCopyrightThreshold(
                          preset,
                          customThreshold: customThreshold,
                        );
                  },
                  onMetaThresholdChanged: (preset, customThreshold) {
                    ref
                        .read(danbooruTagsCacheNotifierProvider.notifier)
                        .setMetaThreshold(
                          preset,
                          customThreshold: customThreshold,
                        );
                  },
                  onRefreshIntervalChanged: (interval) {
                    ref
                        .read(danbooruTagsCacheNotifierProvider.notifier)
                        .setRefreshInterval(interval);
                  },
                ),
                const SizedBox(height: 16),
                // 3. 操作区域
                if (state.isRefreshing) ...[
                  _SyncProgressCard(
                    progress: state.progress,
                    message: state.message,
                    onCancel: () => ref
                        .read(danbooruTagsCacheNotifierProvider.notifier)
                        .cancelSync(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (state.error != null) ...[
                  _ErrorMessageCard(message: state.error!),
                  const SizedBox(height: 16),
                ],
                _ActionCard(
                  isSyncing: state.isRefreshing,
                  onSync: () => ref
                      .read(danbooruTagsCacheNotifierProvider.notifier)
                      .refresh(),
                  onCancel: () => ref
                      .read(danbooruTagsCacheNotifierProvider.notifier)
                      .cancelSync(),
                ),
                const SizedBox(height: 24),
                // 4. 危险操作区域
                _DangerZoneCard(
                  onClearAll: () => _showClearAllDialog(context),
                ),
              ],
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
          '确定要清除 Danbooru 标签补全数据吗？\n\n'
          '这将清空以下数据：\n'
          '• Danbooru 标签补全数据\n\n'
          '以下数据将保留：\n'
          '• 中英文标签翻译\n'
          '• 标签共现关系\n\n'
          '清除后下次启动时将自动重新加载标签数据。',
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
      await Future.delayed(const Duration(milliseconds: 150));
      if (context.mounted) {
        await _clearAllCaches(context);
      }
    }
  }

  /// 清除 Danbooru 标签缓存 - 使用新架构
  Future<void> _clearAllCaches(BuildContext context) async {
    if (!context.mounted) return;

    // 设置 Ref 以启用新架构
    cacheClearService.setRef(ref);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: Center(child: _ClearingDialog()),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 200));

    try {
      // 获取服务实例
      final service = await ref.read(danbooruTagsLazyServiceProvider.future);

      // 使用统一的清除服务，传入服务层清除回调
      final result = await cacheClearService.clearAllCache(
        serviceClearCallback: () => service.clearCache(),
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (result.success) {
        AppLogger.i(
          '[CacheSettings] Clear success: ${result.totalRemoved} rows removed',
          'CacheSettings',
        );

        if (context.mounted) {
          AppToast.success(
            context,
            '已清除 ${result.totalRemoved} 条数据，下次启动时将自动恢复',
          );
        }

        // 关键修复：无论新旧架构，都必须使 Provider 失效
        // 因为清除操作会重置 ConnectionPoolHolder，缓存的 Provider 仍持有旧连接
        await Future.delayed(const Duration(milliseconds: 300));
        if (context.mounted) {
          // 按依赖顺序失效：先失效数据源 Provider，再失效服务 Provider
          ref.invalidate(danbooruTagDataSourceProvider);
          ref.invalidate(danbooruTagsLazyServiceProvider);
          ref.invalidate(danbooruTagsCacheNotifierProvider);
          AppLogger.i(
            '[CacheSettings] Providers invalidated after cache clear',
            'CacheSettings',
          );
        }
      } else {
        // 清除失败（如数据库损坏已自动修复）
        if (context.mounted) {
          AppToast.warning(context, result.error ?? '清除失败，请重试');
        }
      }
    } catch (e, stack) {
      AppLogger.e(
          '[CacheSettings] Clear cache error', e, stack, 'CacheSettings',);

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        AppToast.error(context, '清除失败: $e');
      }
    }
  }
}

/// 数据源状态卡片
class _StatusCard extends StatelessWidget {
  final DanbooruTagsCacheState state;

  const _StatusCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoaded = state.totalTags > 0;

    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // 头部状态信息
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isLoaded
                          ? theme.colorScheme.primary.withOpacity(0.15)
                          : theme.colorScheme.outline.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isLoaded
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                      size: 28,
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
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isLoaded
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isLoaded
                              ? '已缓存 ${_formatNumber(state.totalTags)} 个标签'
                              : '点击"立即同步"下载标签数据',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        // 预构建数据库统计
                        if (isLoaded && 
                            (state.translationCount > 0 || state.cooccurrenceCount > 0)) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.translate,
                                size: 14,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_formatNumber(state.translationCount)} 翻译',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_formatNumber(state.cooccurrenceCount)} 共现',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 分类统计
            if (isLoaded) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // 始终显示所有5个类别，确保加起来等于总数
                    _CategoryChip(
                      label: context.l10n.tagCategory_general,
                      count: state.categoryStats.general,
                      color: Colors.blue,
                    ),
                    _CategoryChip(
                      label: context.l10n.tagCategory_artist,
                      count: state.categoryStats.artist,
                      color: Colors.orange,
                    ),
                    _CategoryChip(
                      label: context.l10n.tagCategory_character,
                      count: state.categoryStats.character,
                      color: Colors.purple,
                    ),
                    _CategoryChip(
                      label: context.l10n.tagCategory_copyright,
                      count: state.categoryStats.copyright,
                      color: Colors.green,
                    ),
                    _CategoryChip(
                      label: context.l10n.tagCategory_meta,
                      count: state.categoryStats.meta,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ],
            // 上次更新时间
            if (state.lastUpdate != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  '上次更新: ${timeago.format(state.lastUpdate!, locale: 'zh')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

/// 分类统计芯片
class _CategoryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CategoryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label ${_formatNumber(count)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color.withOpacity(0.9),
              fontWeight: FontWeight.w500,
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
}

/// 同步设置卡片
class _SyncSettingsCard extends StatelessWidget {
  final DanbooruTagsCacheState state;
  final void Function(TagHotPreset preset, int? customThreshold)
      onGeneralThresholdChanged;
  final void Function(TagHotPreset preset, int? customThreshold)
      onArtistThresholdChanged;
  final void Function(TagHotPreset preset, int? customThreshold)
      onCharacterThresholdChanged;
  final void Function(TagHotPreset preset, int? customThreshold)
      onCopyrightThresholdChanged;
  final void Function(TagHotPreset preset, int? customThreshold)
      onMetaThresholdChanged;
  final ValueChanged<AutoRefreshInterval> onRefreshIntervalChanged;

  const _SyncSettingsCard({
    required this.state,
    required this.onGeneralThresholdChanged,
    required this.onArtistThresholdChanged,
    required this.onCharacterThresholdChanged,
    required this.onCopyrightThresholdChanged,
    required this.onMetaThresholdChanged,
    required this.onRefreshIntervalChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: null,
      showDivider: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 热度阈值区域
          _buildThresholdSection(context),
          const SizedBox(height: 24),
          // 其他设置行
          _buildSecondarySettingsRow(context),
        ],
      ),
    );
  }

  Widget _buildThresholdSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Row(
          children: [
            Icon(
              Icons.local_fire_department_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '热度阈值',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '选择不同类别标签的热度阈值',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 16),
        // 五个分类分两行
        Row(
          children: [
            Expanded(
              child: _CategoryThresholdBox(
                icon: Icons.label_outline,
                iconColor: Colors.blue,
                label: '一般',
                preset: state.categoryThresholds.generalPreset,
                customThreshold:
                    state.categoryThresholds.generalCustomThreshold,
                onChanged: onGeneralThresholdChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CategoryThresholdBox(
                icon: Icons.brush_outlined,
                iconColor: Colors.orange,
                label: '画师',
                preset: state.categoryThresholds.artistPreset,
                customThreshold: state.categoryThresholds.artistCustomThreshold,
                onChanged: onArtistThresholdChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CategoryThresholdBox(
                icon: Icons.person_outline,
                iconColor: Colors.purple,
                label: '角色',
                preset: state.categoryThresholds.characterPreset,
                customThreshold:
                    state.categoryThresholds.characterCustomThreshold,
                onChanged: onCharacterThresholdChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CategoryThresholdBox(
                icon: Icons.copyright_outlined,
                iconColor: Colors.green,
                label: '版权',
                preset: state.categoryThresholds.copyrightPreset,
                customThreshold:
                    state.categoryThresholds.copyrightCustomThreshold,
                onChanged: onCopyrightThresholdChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CategoryThresholdBox(
                icon: Icons.code_outlined,
                iconColor: Colors.grey,
                label: '元标签',
                preset: state.categoryThresholds.metaPreset,
                customThreshold: state.categoryThresholds.metaCustomThreshold,
                onChanged: onMetaThresholdChanged,
              ),
            ),
            const SizedBox(width: 12),
            // 占位保持对齐
            Expanded(
              child: Container(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecondarySettingsRow(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // 自动刷新间隔
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '自动刷新间隔',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: AutoRefreshInterval.values.map((interval) {
                  final isSelected = interval == state.refreshInterval;
                  return _ChoiceChip(
                    label: interval.displayName,
                    isSelected: isSelected,
                    onSelected: () => onRefreshIntervalChanged(interval),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 分类阈值选择框
class _CategoryThresholdBox extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final TagHotPreset preset;
  final int customThreshold;
  final void Function(TagHotPreset preset, int? customThreshold) onChanged;

  const _CategoryThresholdBox({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.preset,
    required this.customThreshold,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  preset == TagHotPreset.custom
                      ? '>$customThreshold'
                      : preset.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: iconColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 选项按钮
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: TagHotPreset.values.map((p) {
              final isSelected = p == preset;
              return _SmallChoiceChip(
                label: p.displayName,
                isSelected: isSelected,
                accentColor: iconColor,
                onSelected: () =>
                    onChanged(p, p.isCustom ? customThreshold : null),
              );
            }).toList(),
          ),
          // 自定义滑块
          if (preset == TagHotPreset.custom) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: iconColor,
                      inactiveTrackColor:
                          theme.colorScheme.surfaceContainerHighest,
                      thumbColor: iconColor,
                      overlayColor: iconColor.withOpacity(0.1),
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: customThreshold.toDouble(),
                      min: 10,
                      max: 10000,
                      divisions: 100,
                      onChanged: (v) => onChanged(preset, v.toInt()),
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    customThreshold.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 选择芯片
class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _ChoiceChip({
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
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// 小型选择芯片
class _SmallChoiceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onSelected;

  const _SmallChoiceChip({
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? accentColor.withOpacity(0.2)
          : theme.colorScheme.surface.withOpacity(0.5),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color:
                  isSelected ? accentColor : theme.colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

/// 操作卡片
class _ActionCard extends StatelessWidget {
  final bool isSyncing;
  final VoidCallback onSync;
  final VoidCallback onCancel;

  const _ActionCard({
    required this.isSyncing,
    required this.onSync,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isSyncing ? onCancel : onSync,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSyncing ? Icons.stop_circle_outlined : Icons.sync_outlined,
                  size: 20,
                  color: theme.colorScheme.onPrimary,
                ),
                const SizedBox(width: 10),
                Text(
                  isSyncing ? '取消同步' : '立即同步',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 同步进度卡片
class _SyncProgressCard extends StatelessWidget {
  final double progress;
  final String? message;
  final VoidCallback onCancel;

  const _SyncProgressCard({
    required this.progress,
    this.message,
    required this.onCancel,
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
                width: 20,
                height: 20,
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

/// 错误信息卡片
class _ErrorMessageCard extends StatelessWidget {
  final String message;

  const _ErrorMessageCard({required this.message});

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

/// 错误状态卡片
class _ErrorStateCard extends StatelessWidget {
  final String message;

  const _ErrorStateCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 28,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '加载失败: $message',
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

/// 危险区域卡片
class _DangerZoneCard extends StatefulWidget {
  final VoidCallback onClearAll;

  const _DangerZoneCard({required this.onClearAll});

  @override
  State<_DangerZoneCard> createState() => _DangerZoneCardState();
}

class _DangerZoneCardState extends State<_DangerZoneCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: _isHovered
              ? theme.colorScheme.errorContainer.withOpacity(0.6)
              : theme.colorScheme.errorContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered
                ? theme.colorScheme.error.withOpacity(0.5)
                : theme.colorScheme.error.withOpacity(0.3),
            width: _isHovered ? 2 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: widget.onClearAll,
            borderRadius: BorderRadius.circular(12),
            splashColor: theme.colorScheme.error.withOpacity(0.1),
            highlightColor: theme.colorScheme.error.withOpacity(0.05),
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(
                vertical: _isHovered ? 14 : 12,
                horizontal: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                  Text(
                    '清除标签补全数据',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
