import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';

/// 执行统计面板 - 紧凑精致的现代设计
class ExecutionStatsPanel extends ConsumerStatefulWidget {
  const ExecutionStatsPanel({super.key});

  @override
  ConsumerState<ExecutionStatsPanel> createState() =>
      _ExecutionStatsPanelState();
}

class _ExecutionStatsPanelState extends ConsumerState<ExecutionStatsPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// 安全地 watch provider 状态
  T _watchState<T>(ProviderListenable<T> provider, T defaultValue) {
    try {
      return ref.watch(provider);
    } catch (e) {
      return defaultValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    final executionState = _watchState(
      queueExecutionNotifierProvider,
      const QueueExecutionState(),
    );
    final queueState = _watchState(
      replicationQueueNotifierProvider,
      const ReplicationQueueState(),
    );

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
                      _estimateRemainingTime(
                        context,
                        l10n,
                        executionState,
                        remaining,
                      ),
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

  /// 构建交互式状态按钮
  Widget _buildStatusChip(
    BuildContext context,
    dynamic l10n,
    QueueExecutionState executionState,
  ) {
    final queueState = ref.watch(replicationQueueNotifierProvider);
    final (label, color, icon) = _getStatusInfo(l10n, executionState.status);
    final isClickable = _isStatusClickable(executionState.status, queueState);
    final tooltip = _getStatusTooltip(l10n, executionState.status, queueState);

    _updateAnimationState(executionState);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isClickable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: isClickable
            ? () => _handleStatusTap(executionState.status, queueState)
            : null,
        child: Tooltip(
          message: tooltip,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            tween: Tween(
              begin: 1.0,
              end: _isPressed ? 0.97 : (_isHovered && isClickable ? 1.02 : 1.0),
            ),
            builder: (context, scale, child) => Transform.scale(
              scale: scale,
              child: child,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: _statusChipDecoration(color, isClickable),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAnimatedIcon(icon, color, executionState.isRunning),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  if (isClickable) ...[
                    const SizedBox(width: 4),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isHovered ? 1.0 : 0.5,
                      child: Icon(
                        Icons.touch_app_rounded,
                        size: 12,
                        color: color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 更新动画状态
  void _updateAnimationState(QueueExecutionState executionState) {
    final shouldAnimate = executionState.isRunning;
    final isAnimating = _animController.isAnimating;

    if (shouldAnimate && !isAnimating) {
      _animController.repeat();
    } else if (!shouldAnimate && isAnimating) {
      _animController.stop();
      _animController.reset();
    }
  }

  /// 状态按钮装饰
  BoxDecoration _statusChipDecoration(Color color, bool isClickable) {
    return BoxDecoration(
      color: color.withOpacity(_isHovered && isClickable ? 0.2 : 0.12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: color.withOpacity(_isHovered && isClickable ? 0.5 : 0.2),
        width: 1.5,
      ),
      boxShadow: _isHovered && isClickable
          ? [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
    );
  }

  /// 构建动画图标
  Widget _buildAnimatedIcon(IconData icon, Color color, bool isRunning) {
    if (isRunning) {
      return AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return Transform.rotate(
            angle: _animController.value * 2 * 3.14159,
            child: child,
          );
        },
        child: Icon(icon, size: 16, color: color),
      );
    }
    return Icon(icon, size: 16, color: color);
  }

  /// 判断状态是否可点击
  bool _isStatusClickable(
    QueueExecutionStatus status,
    ReplicationQueueState queueState,
  ) {
    switch (status) {
      case QueueExecutionStatus.idle:
        return queueState.tasks.isNotEmpty; // 有任务才能开始
      case QueueExecutionStatus.ready:
        return true; // ready 状态可以暂停
      case QueueExecutionStatus.running:
        return true; // 运行中可以暂停
      case QueueExecutionStatus.paused:
        return true; // 暂停可以继续
      case QueueExecutionStatus.completed:
        return queueState.tasks.isNotEmpty; // 完成后如果有新任务可以重新开始
    }
  }

  /// 获取状态提示
  String _getStatusTooltip(
    dynamic l10n,
    QueueExecutionStatus status,
    ReplicationQueueState queueState,
  ) {
    switch (status) {
      case QueueExecutionStatus.idle:
        return queueState.tasks.isNotEmpty
            ? l10n.queue_clickToStart
            : l10n.queue_noTasksToStart;
      case QueueExecutionStatus.ready:
        return l10n.queue_clickToPause;
      case QueueExecutionStatus.running:
        return l10n.queue_clickToPause;
      case QueueExecutionStatus.paused:
        return l10n.queue_clickToResume;
      case QueueExecutionStatus.completed:
        return queueState.tasks.isNotEmpty
            ? l10n.queue_clickToStart
            : l10n.queue_allTasksCompleted;
    }
  }

  /// 处理状态按钮点击
  void _handleStatusTap(
    QueueExecutionStatus status,
    ReplicationQueueState queueState,
  ) {
    final notifier = ref.read(queueExecutionNotifierProvider.notifier);

    switch (status) {
      case QueueExecutionStatus.idle:
      case QueueExecutionStatus.completed:
        if (queueState.tasks.isNotEmpty) {
          notifier.prepareNextTask();
        }
        break;
      case QueueExecutionStatus.ready:
      case QueueExecutionStatus.running:
        notifier.pause();
        break;
      case QueueExecutionStatus.paused:
        notifier.resume();
        break;
    }
  }

  /// 获取状态信息
  (String, Color, IconData) _getStatusInfo(
    dynamic l10n,
    QueueExecutionStatus status,
  ) {
    switch (status) {
      case QueueExecutionStatus.idle:
        return (
          l10n.queue_idle,
          Colors.grey,
          Icons.pause_circle_outline_rounded
        );
      case QueueExecutionStatus.ready:
        return (
          l10n.queue_ready,
          Colors.blue,
          Icons.play_circle_outline_rounded
        );
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
