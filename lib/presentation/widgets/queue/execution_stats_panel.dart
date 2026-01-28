import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';

/// 执行统计面板 - 紧凑精致的现代设计
class ExecutionStatsPanel extends ConsumerWidget {
  const ExecutionStatsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    // 安全获取状态
    QueueExecutionState executionState = const QueueExecutionState();
    try {
      executionState = ref.watch(queueExecutionNotifierProvider);
    } catch (e) {
      // Provider 未初始化
    }

    ReplicationQueueState queueState = const ReplicationQueueState();
    try {
      queueState = ref.watch(replicationQueueNotifierProvider);
    } catch (e) {
      // Provider 未初始化
    }

    final total = executionState.totalTasksInSession;
    final completed = executionState.completedCount;
    final failed = executionState.failedCount;
    final remaining = queueState.count;
    final progress = executionState.progress;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.queue_executionProgress,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              _buildStatusChip(context, l10n, executionState),
            ],
          ),

          const SizedBox(height: 12),

          // 统计数字行
          Row(
            children: [
              _buildStatCard(
                context,
                label: l10n.queue_totalTasks,
                value: total.toString(),
                icon: Icons.format_list_numbered_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                context,
                label: l10n.queue_completedTasks,
                value: completed.toString(),
                icon: Icons.check_circle_outline_rounded,
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                context,
                label: l10n.queue_failedTasks,
                value: failed.toString(),
                icon: Icons.error_outline_rounded,
                color: failed > 0 ? Colors.red : theme.disabledColor,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                context,
                label: l10n.queue_remainingTasks,
                value: remaining.toString(),
                icon: Icons.pending_outlined,
                color: theme.colorScheme.secondary,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 进度条
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(progress * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (executionState.sessionStartTime != null && completed > 0)
                    Text(
                      _estimateRemainingTime(context, l10n, executionState, remaining),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建统计卡片
  Widget _buildStatCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建状态标签
  Widget _buildStatusChip(
    BuildContext context,
    dynamic l10n,
    QueueExecutionState state,
  ) {
    final (label, color, icon) = _getStatusInfo(l10n, state.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 获取状态信息
  (String, Color, IconData) _getStatusInfo(dynamic l10n, QueueExecutionStatus status) {
    switch (status) {
      case QueueExecutionStatus.idle:
        return (l10n.queue_idle, Colors.grey, Icons.pause_circle_outline_rounded);
      case QueueExecutionStatus.ready:
        return (l10n.queue_ready, Colors.blue, Icons.play_circle_outline_rounded);
      case QueueExecutionStatus.running:
        return (l10n.queue_running, Colors.blue, Icons.sync_rounded);
      case QueueExecutionStatus.paused:
        return (l10n.queue_paused, Colors.orange, Icons.pause_circle_rounded);
      case QueueExecutionStatus.completed:
        return (l10n.queue_completed, Colors.green, Icons.check_circle_rounded);
    }
  }

  /// 估算剩余时间
  String _estimateRemainingTime(
    BuildContext context,
    dynamic l10n,
    QueueExecutionState state,
    int remaining,
  ) {
    if (state.sessionStartTime == null || state.completedCount == 0) {
      return '';
    }

    final elapsed = DateTime.now().difference(state.sessionStartTime!);
    final avgTimePerTask = elapsed.inSeconds / state.completedCount;
    final estimatedRemaining = (avgTimePerTask * remaining).round();

    String timeStr;
    if (estimatedRemaining < 60) {
      timeStr = l10n.queue_seconds(estimatedRemaining);
    } else if (estimatedRemaining < 3600) {
      final minutes = (estimatedRemaining / 60).round();
      timeStr = l10n.queue_minutes(minutes);
    } else {
      final hours = estimatedRemaining ~/ 3600;
      final minutes = (estimatedRemaining % 3600) ~/ 60;
      timeStr = l10n.queue_hours(hours, minutes);
    }
    return l10n.queue_estimatedTime(timeStr);
  }
}
