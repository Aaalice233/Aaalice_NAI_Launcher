import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../providers/background_task_provider.dart' show BackgroundTask, backgroundTaskNotifierProvider;

/// 后台任务进度指示器
///
/// 显示在屏幕右下角，展示当前后台任务的进度
/// 例如：画师标签同步进度
class BackgroundTaskIndicator extends ConsumerWidget {
  const BackgroundTaskIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(backgroundTaskNotifierProvider);
    final runningTasks = taskState.runningTasks;

    if (runningTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final task = runningTasks.first;
    if (task.progress >= 1.0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Positioned(
      right: 16,
      bottom: 80,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        color: colorScheme.surfaceContainerHighest.withOpacity(0.95),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, task, colorScheme, ref),
              const SizedBox(height: 8),
              _buildProgressBar(task.progress, colorScheme),
              const SizedBox(height: 4),
              _buildProgressInfo(context, task, theme, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    BackgroundTask task,
    ColorScheme colorScheme,
    WidgetRef ref,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            task.displayName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (task.id == 'artist_tags_sync')
          InkWell(
            onTap: () => ref.read(backgroundTaskNotifierProvider.notifier).pause(),
            child: Icon(
              Icons.close,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _buildProgressBar(double progress, ColorScheme colorScheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress > 0 ? progress : null,
        backgroundColor: colorScheme.surfaceContainerHigh,
        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
        minHeight: 6,
      ),
    );
  }

  Widget _buildProgressInfo(
    BuildContext context,
    BackgroundTask task,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _getProgressText(context, task),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (task.progress > 0)
          Text(
            '${(task.progress * 100).toInt()}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  /// 获取进度文本
  /// 优先级：localized count text > message > percentage
  String _getProgressText(BuildContext context, BackgroundTask task) {
    final l10n = context.l10n;

    // 如果有处理数量，显示本地化计数文本
    if (task.processedCount != null && task.processedCount! > 0) {
      if (task.totalCount != null && task.totalCount! > 0) {
        return l10n.backgroundTask_downloadedCountWithTotal(
          task.processedCount!,
          task.totalCount!,
        );
      }
      return l10n.backgroundTask_downloadedCount(task.processedCount!);
    }

    // 回退到消息或百分比
    return task.message ?? '${(task.progress * 100).toInt()}%';
  }
}

/// 桌面端后台任务进度指示器
class DesktopBackgroundTaskIndicator extends ConsumerWidget {
  const DesktopBackgroundTaskIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const BackgroundTaskIndicator();
  }
}

/// 移动端后台任务进度指示器
class MobileBackgroundTaskIndicator extends ConsumerWidget {
  const MobileBackgroundTaskIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(backgroundTaskNotifierProvider);
    final runningTasks = taskState.runningTasks;

    if (runningTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final task = runningTasks.first;
    if (task.progress >= 1.0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 80,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        color: colorScheme.surfaceContainerHighest.withOpacity(0.95),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.displayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: task.progress > 0 ? task.progress : null,
                        backgroundColor: colorScheme.surfaceContainerHigh,
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (task.progress > 0)
                Text(
                  '${(task.progress * 100).toInt()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
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
