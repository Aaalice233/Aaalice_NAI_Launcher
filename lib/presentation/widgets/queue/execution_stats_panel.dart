import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../common/app_toast.dart';

/// 执行统计面板 - 紧凑精致的现代设计
class ExecutionStatsPanel extends ConsumerStatefulWidget {
  final VoidCallback? onQueueStarted;
  final VoidCallback? onAddCurrentTask;

  const ExecutionStatsPanel({
    super.key,
    this.onQueueStarted,
    this.onAddCurrentTask,
  });

  @override
  ConsumerState<ExecutionStatsPanel> createState() =>
      _ExecutionStatsPanelState();
}

class _ExecutionStatsPanelState extends ConsumerState<ExecutionStatsPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_disableAnimations == disableAnimations) return;
    _disableAnimations = disableAnimations;
    if (disableAnimations) {
      _animController
        ..stop()
        ..reset();
    }
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final needsStackedLayout =
            constraints.maxWidth < 300 || textScale > 1.6;
        final statCards = [
          _buildStatCard(
            context,
            label: l10n.queue_totalTasks,
            value: total.toString(),
            icon: Icons.format_list_numbered_rounded,
            color: theme.colorScheme.primary,
          ),
          _buildStatCard(
            context,
            label: l10n.queue_completedTasks,
            value: completed.toString(),
            icon: Icons.check_circle_outline_rounded,
            color: Colors.green,
          ),
          _buildStatCard(
            context,
            label: l10n.queue_failedTasks,
            value: failed.toString(),
            icon: Icons.error_outline_rounded,
            color: failed > 0 ? Colors.red : theme.disabledColor,
          ),
          _buildStatCard(
            context,
            label: l10n.queue_remainingTasks,
            value: remaining.toString(),
            icon: Icons.pending_outlined,
            color: theme.colorScheme.secondary,
          ),
        ];

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题行
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          l10n.queue_executionProgress,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildStatusChip(context, l10n, executionState),
                ],
              ),

              const SizedBox(height: 12),

              // 统计数字行
              if (needsStackedLayout)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final card in statCards)
                      SizedBox(
                        width: (constraints.maxWidth - 56) / 2,
                        child: card,
                      ),
                  ],
                )
              else
                Row(
                  children: [
                    for (var index = 0; index < statCards.length; index++) ...[
                      Expanded(child: statCards[index]),
                      if (index < statCards.length - 1)
                        const SizedBox(width: 8),
                    ],
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
                      if (executionState.sessionStartTime != null &&
                          completed > 0)
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
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              if (needsStackedLayout)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildExecutionButton(context, executionState, queueState),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      key: const Key('queue-add-current-task'),
                      onPressed: widget.onAddCurrentTask,
                      icon: const Icon(Icons.playlist_add_rounded, size: 19),
                      label: Text(l10n.queue_addCurrentTask),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _buildExecutionButton(
                        context,
                        executionState,
                        queueState,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const Key('queue-add-current-task'),
                        onPressed: widget.onAddCurrentTask,
                        icon: const Icon(Icons.playlist_add_rounded, size: 19),
                        label: Text(l10n.queue_addCurrentTask),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
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
    final usesLargeText = MediaQuery.textScalerOf(context).scale(14) / 14 > 1.3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
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
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            maxLines: usesLargeText ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 状态只负责展示；队列控制使用下方含义明确的主按钮。
  Widget _buildStatusChip(
    BuildContext context,
    AppLocalizations l10n,
    QueueExecutionState executionState,
  ) {
    final (label, color, icon) = _getStatusInfo(l10n, executionState.status);
    _updateAnimationState(executionState);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
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
        ],
      ),
    );
  }

  void _updateAnimationState(QueueExecutionState executionState) {
    final shouldAnimate = executionState.isRunning && !_disableAnimations;
    if (shouldAnimate && !_animController.isAnimating) {
      _animController.repeat();
    } else if (!shouldAnimate && _animController.isAnimating) {
      _animController
        ..stop()
        ..reset();
    }
  }

  Widget _buildAnimatedIcon(IconData icon, Color color, bool isRunning) {
    if (!isRunning || _disableAnimations) {
      return Icon(icon, size: 16, color: color);
    }
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) => Transform.rotate(
        angle: _animController.value * 2 * 3.14159,
        child: child,
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  Widget _buildExecutionButton(
    BuildContext context,
    QueueExecutionState executionState,
    ReplicationQueueState queueState,
  ) {
    final l10n = context.l10n;
    final notifier = ref.read(queueExecutionNotifierProvider.notifier);

    if (executionState.isRunning || executionState.isReady) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          onPressed: notifier.pause,
          icon: const Icon(Icons.pause_rounded),
          label: Text(l10n.queue_pauseExecution),
        ),
      );
    }

    if (executionState.isPaused) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: notifier.resume,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(l10n.queue_resumeExecution),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: queueState.isEmpty
            ? null
            : () async {
                final result = await notifier.startQueue();
                if (!context.mounted) return;
                switch (result) {
                  case QueueStartResult.started:
                    widget.onQueueStarted?.call();
                    return;
                  case QueueStartResult.empty:
                    AppToast.warning(context, l10n.queue_noTasksToStart);
                    return;
                  case QueueStartResult.busy:
                    AppToast.warning(context, l10n.queue_generationBusy);
                    return;
                  case QueueStartResult.authRequired:
                    return;
                }
              },
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(l10n.queue_startExecution),
      ),
    );
  }

  /// 获取状态信息
  (String, Color, IconData) _getStatusInfo(
    AppLocalizations l10n,
    QueueExecutionStatus status,
  ) {
    switch (status) {
      case QueueExecutionStatus.idle:
        return (
          l10n.queue_idle,
          Colors.grey,
          Icons.pause_circle_outline_rounded,
        );
      case QueueExecutionStatus.ready:
        return (
          l10n.queue_ready,
          Colors.blue,
          Icons.play_circle_outline_rounded,
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
    AppLocalizations l10n,
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
