import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/services/cooccurrence_service.dart';
import '../../../../data/models/cache/data_source_cache_meta.dart';
import '../../../providers/data_source_cache_provider.dart';
import '../../../widgets/common/app_toast.dart';

/// 数据源缓存管理设置组件
///
/// 用于设置页面，管理需要从网络拉取的数据缓存
/// - 翻译数据（HuggingFace）
/// - 标签补全数据（Danbooru API）
/// - 共现标签数据（HuggingFace）
class DataSourceCacheSettings extends ConsumerStatefulWidget {
  const DataSourceCacheSettings({super.key});

  @override
  ConsumerState<DataSourceCacheSettings> createState() =>
      _DataSourceCacheSettingsState();
}

class _DataSourceCacheSettingsState
    extends ConsumerState<DataSourceCacheSettings> {
  int _selectedIndex = 0;

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
          // 分段选择器样式的 Tab 栏
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tabWidth = constraints.maxWidth / 3;
                  return Stack(
                    children: [
                      // 滑动的高亮背景
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        left: _selectedIndex * tabWidth,
                        top: 0,
                        bottom: 0,
                        width: tabWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    theme.colorScheme.primary.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 三个选项卡按钮
                      Row(
                        children: [
                          _buildSegmentTab(
                            index: 0,
                            icon: Icons.translate,
                            label: '翻译',
                            theme: theme,
                          ),
                          _buildSegmentTab(
                            index: 1,
                            icon: Icons.auto_awesome,
                            label: '标签补全',
                            theme: theme,
                          ),
                          _buildSegmentTab(
                            index: 2,
                            icon: Icons.hub,
                            label: '共现标签',
                            theme: theme,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          // Tab 内容区域
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildTabContent(_selectedIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTab({
    required int index,
    required IconData icon,
    required String label,
    required ThemeData theme,
  }) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 16,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: theme.textTheme.labelMedium!.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(int index) {
    return Padding(
      key: ValueKey(index),
      padding: const EdgeInsets.all(16),
      child: switch (index) {
        0 => const _TranslationDataSection(),
        1 => const _TagCompletionDataSection(),
        2 => const _CooccurrenceDataSection(),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

// _DataSourceCard 已被 Tab 选项卡替代，不再使用

/// 翻译数据部分
class _TranslationDataSection extends ConsumerWidget {
  const _TranslationDataSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(hFTranslationCacheNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 状态信息
        _StatusRow(
          isLoaded: state.totalTags > 0,
          loadedText: '已加载 ${state.totalTags} 条翻译',
          notLoadedText: '未加载',
          lastUpdate: state.lastUpdate,
        ),
        const SizedBox(height: 12),

        // 自动刷新间隔设置
        _RefreshIntervalSelector(
          value: state.refreshInterval,
          onChanged: (interval) {
            ref
                .read(hFTranslationCacheNotifierProvider.notifier)
                .setRefreshInterval(interval);
          },
        ),
        const SizedBox(height: 12),

        // 进度条（刷新时显示）
        if (state.isRefreshing) ...[
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

        // 操作按钮
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.refresh,
                label: state.isRefreshing ? '同步中...' : '立即同步',
                isLoading: state.isRefreshing,
                onPressed: state.isRefreshing
                    ? null
                    : () => ref
                        .read(hFTranslationCacheNotifierProvider.notifier)
                        .refresh(),
              ),
            ),
            const SizedBox(width: 8),
            _ActionButton(
              icon: Icons.delete_outline,
              label: '清除',
              isDestructive: true,
              onPressed: state.isRefreshing
                  ? null
                  : () async {
                      await ref
                          .read(hFTranslationCacheNotifierProvider.notifier)
                          .clearCache();
                      if (context.mounted) {
                        AppToast.info(context, '翻译缓存已清除');
                      }
                    },
            ),
          ],
        ),
      ],
    );
  }
}

/// 标签补全数据部分
class _TagCompletionDataSection extends ConsumerWidget {
  const _TagCompletionDataSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(danbooruTagsCacheNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 状态信息
        _StatusRow(
          isLoaded: state.totalTags > 0,
          loadedText: '已加载 ${state.totalTags} 个标签',
          notLoadedText: '未加载',
          lastUpdate: state.lastUpdate,
        ),
        const SizedBox(height: 12),

        // 热度档位选择
        _HotPresetSelector(
          value: state.hotPreset,
          customThreshold: state.customThreshold,
          onChanged: (preset, customThreshold) {
            ref
                .read(danbooruTagsCacheNotifierProvider.notifier)
                .setHotPreset(preset, customThreshold: customThreshold);
          },
        ),
        const SizedBox(height: 12),

        // 进度条（刷新时显示）
        if (state.isRefreshing) ...[
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

        // 操作按钮
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: state.isRefreshing ? Icons.stop : Icons.refresh,
                label: state.isRefreshing ? '取消同步' : '立即同步',
                isLoading: false,
                onPressed: state.isRefreshing
                    ? () => ref
                        .read(danbooruTagsCacheNotifierProvider.notifier)
                        .cancelSync()
                    : () => ref
                        .read(danbooruTagsCacheNotifierProvider.notifier)
                        .refresh(),
              ),
            ),
            const SizedBox(width: 8),
            _ActionButton(
              icon: Icons.delete_outline,
              label: '清除',
              isDestructive: true,
              onPressed: state.isRefreshing
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

/// 共现标签数据部分
class _CooccurrenceDataSection extends ConsumerStatefulWidget {
  const _CooccurrenceDataSection();

  @override
  ConsumerState<_CooccurrenceDataSection> createState() =>
      _CooccurrenceDataSectionState();
}

class _CooccurrenceDataSectionState
    extends ConsumerState<_CooccurrenceDataSection> {
  bool _isRefreshing = false;

  Future<void> _download() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final service = ref.read(cooccurrenceServiceProvider);
      final success = await service.download();

      if (mounted) {
        if (success) {
          AppToast.success(context, '共现标签数据已下载');
        } else {
          AppToast.error(context, '下载失败');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '下载失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(cooccurrenceServiceProvider);
    final isLoaded = service.isLoaded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 状态信息
        _StatusRow(
          isLoaded: isLoaded,
          loadedText: '已下载',
          notLoadedText: '未下载',
        ),
        const SizedBox(height: 12),

        // 操作按钮
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.download,
                label: _isRefreshing ? '下载中...' : (isLoaded ? '重新下载' : '下载'),
                isLoading: _isRefreshing,
                onPressed: _isRefreshing ? null : _download,
              ),
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

/// 热度档位选择器
class _HotPresetSelector extends StatelessWidget {
  final TagHotPreset value;
  final int customThreshold;
  final void Function(TagHotPreset preset, int? customThreshold) onChanged;

  const _HotPresetSelector({
    required this.value,
    required this.customThreshold,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '热度筛选',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TagHotPreset.values.map((preset) {
            final isSelected = preset == value;
            return ChoiceChip(
              label: Text(preset.displayName),
              selected: isSelected,
              onSelected: (_) => onChanged(preset, null),
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
        if (value == TagHotPreset.custom) ...[
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
                  onChanged: (v) => onChanged(value, v.toInt()),
                ),
              ),
            ],
          ),
        ],
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
