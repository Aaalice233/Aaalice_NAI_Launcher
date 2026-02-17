import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/background_task_provider.dart';

/// 后台加载进度指示器
/// 显示在主界面顶部或底部
class BackgroundLoadingIndicator extends ConsumerWidget {
  final bool showWhenIdle;

  const BackgroundLoadingIndicator({
    super.key,
    this.showWhenIdle = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backgroundTaskNotifierProvider);

    // 如果没有任务，或所有任务完成且不显示空闲状态，返回空
    if (state.tasks.isEmpty || (state.allComplete && !showWhenIdle)) {
      return const SizedBox.shrink();
    }

    // 所有任务完成
    if (state.allComplete) {
      return _buildCompletedIndicator(context, ref);
    }

    // 优先显示画师标签同步任务进度
    final artistTask = state.tasks.firstWhere(
      (t) => t.id == 'artist_tags_isolate_fetch' && t.status == BackgroundTaskStatus.running,
      orElse: () => state.tasks.firstWhere(
        (t) => t.id == 'artist_tags_isolate_fetch' && t.status == BackgroundTaskStatus.pending,
        orElse: () => state.tasks.first,
      ),
    );

    if (artistTask.id == 'artist_tags_isolate_fetch' && !artistTask.isDone) {
      return _buildArtistTagProgressIndicator(context, artistTask);
    }

    // 显示当前任务进度
    final currentTask = state.runningTasks.firstOrNull ?? state.pendingTasks.firstOrNull;
    if (currentTask == null) return const SizedBox.shrink();

    return _buildProgressIndicator(context, currentTask, state.overallProgress);
  }

  /// 画师标签同步专用进度指示器
  Widget _buildArtistTagProgressIndicator(BuildContext context, BackgroundTask task) {
    final theme = Theme.of(context);

    return Material(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            bottom: BorderSide(color: theme.dividerColor),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.palette,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '同步画师标签: ${(task.progress * 100).toInt()}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (task.message != null && task.message!.isNotEmpty)
                    Text(
                      task.message!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context, BackgroundTask task, double overallProgress) {
    final theme = Theme.of(context);

    return Material(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            bottom: BorderSide(color: theme.dividerColor),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${task.displayName}: ${task.message ?? '加载中...'}',
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: task.progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              minHeight: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedIndicator(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final failedCount = ref.watch(backgroundTaskNotifierProvider).failedTasks.length;

    if (failedCount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: theme.colorScheme.errorContainer,
        child: Row(
          children: [
            Icon(Icons.warning_amber, size: 16, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$failedCount 个后台任务失败',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                ref.read(backgroundTaskNotifierProvider.notifier).retryFailed();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.primaryContainer,
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '后台加载完成',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 可收起/展开的后台加载面板
class CollapsibleBackgroundPanel extends ConsumerStatefulWidget {
  const CollapsibleBackgroundPanel({super.key});

  @override
  ConsumerState<CollapsibleBackgroundPanel> createState() => _CollapsibleBackgroundPanelState();
}

class _CollapsibleBackgroundPanelState extends ConsumerState<CollapsibleBackgroundPanel> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(backgroundTaskNotifierProvider);

    if (state.tasks.isEmpty || state.allComplete) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        title: Text('后台加载 (${state.runningTasks.length} 个进行中)'),
        subtitle: LinearProgressIndicator(
          value: state.overallProgress,
          minHeight: 4,
        ),
        children: state.tasks.map((task) {
          return ListTile(
            dense: true,
            leading: _buildTaskIcon(task),
            title: Text(task.displayName),
            subtitle: Text(task.message ?? '等待中...'),
            trailing: Text('${(task.progress * 100).toInt()}%'),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTaskIcon(BackgroundTask task) {
    switch (task.status) {
      case BackgroundTaskStatus.running:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case BackgroundTaskStatus.completed:
        return const Icon(Icons.check, size: 16, color: Colors.green);
      case BackgroundTaskStatus.failed:
        return const Icon(Icons.error, size: 16, color: Colors.red);
      default:
        return const Icon(Icons.hourglass_empty, size: 16);
    }
  }
}
