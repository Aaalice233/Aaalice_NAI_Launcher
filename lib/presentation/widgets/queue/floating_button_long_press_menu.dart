import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';

/// 悬浮球长按菜单
class FloatingButtonLongPressMenu extends ConsumerWidget {
  /// 打开队列管理页面回调
  final VoidCallback? onOpenManagement;

  /// 打开设置回调
  final VoidCallback? onOpenSettings;

  /// 导出队列回调
  final VoidCallback? onExport;

  const FloatingButtonLongPressMenu({
    super.key,
    this.onOpenManagement,
    this.onOpenSettings,
    this.onExport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    // 安全获取执行状态，处理未初始化情况
    QueueExecutionState executionState = const QueueExecutionState();
    try {
      executionState = ref.watch(queueExecutionNotifierProvider);
    } catch (e) {
      // Provider 未初始化，使用默认状态
    }

    // 安全获取队列状态
    ReplicationQueueState queueState = const ReplicationQueueState();
    try {
      queueState = ref.watch(replicationQueueNotifierProvider);
    } catch (e) {
      // Provider 未初始化，使用默认状态
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动指示条
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 队列状态摘要
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildStatusSummary(context, executionState, queueState),
          ),

          const Divider(height: 1),

          // 暂停/继续
          _buildPauseResumeItem(context, ref, executionState),

          // 自动执行开关
          _buildAutoExecuteSwitch(context, ref, executionState),

          const Divider(height: 1),

          // 打开队列管理
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: Text(l10n.queue_management),
            subtitle: Text(l10n.queue_taskCount(queueState.count)),
            onTap: () {
              Navigator.pop(context);
              onOpenManagement?.call();
            },
          ),

          // 清空队列
          ListTile(
            leading: Icon(
              Icons.delete_sweep,
              color: queueState.isEmpty ? theme.disabledColor : null,
            ),
            title: Text(
              l10n.queue_clearQueue,
              style: TextStyle(
                color: queueState.isEmpty ? theme.disabledColor : null,
              ),
            ),
            enabled: !queueState.isEmpty,
            onTap: () => _confirmClearQueue(context, ref),
          ),

          // 导出队列
          if (onExport != null)
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: Text(l10n.queue_export),
              enabled: !queueState.isEmpty,
              onTap: () {
                Navigator.pop(context);
                onExport?.call();
              },
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStatusSummary(
    BuildContext context,
    QueueExecutionState executionState,
    ReplicationQueueState queueState,
  ) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(
          context,
          icon: Icons.check_circle_outline,
          label: l10n.queue_completedTasks,
          value: executionState.completedCount.toString(),
          color: Colors.green,
        ),
        _buildStatItem(
          context,
          icon: Icons.error_outline,
          label: l10n.queue_failed,
          value: executionState.failedCount.toString(),
          color:
              executionState.failedCount > 0 ? Colors.red : theme.disabledColor,
        ),
        _buildStatItem(
          context,
          icon: Icons.pending_outlined,
          label: l10n.queue_remainingTasks,
          value: queueState.count.toString(),
          color: theme.colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildPauseResumeItem(
    BuildContext context,
    WidgetRef ref,
    QueueExecutionState executionState,
  ) {
    final l10n = context.l10n;
    final isPaused = executionState.isPaused;
    final isRunningOrReady = executionState.isRunning || executionState.isReady;
    final canToggle = isPaused || isRunningOrReady;

    return ListTile(
      leading: Icon(
        isPaused ? Icons.play_arrow : Icons.pause,
      ),
      title: Text(
        isPaused ? l10n.queue_resumeExecution : l10n.queue_pauseExecution,
      ),
      enabled: canToggle,
      onTap: () {
        if (isPaused) {
          ref.read(queueExecutionNotifierProvider.notifier).resume();
        } else {
          ref.read(queueExecutionNotifierProvider.notifier).pause();
        }
        Navigator.pop(context);
      },
    );
  }

  Widget _buildAutoExecuteSwitch(
    BuildContext context,
    WidgetRef ref,
    QueueExecutionState executionState,
  ) {
    final l10n = context.l10n;
    return SwitchListTile(
      secondary: const Icon(Icons.auto_mode),
      title: Text(l10n.queue_autoExecute),
      subtitle: Text(
        executionState.autoExecuteEnabled
            ? l10n.queue_autoExecuteOn
            : l10n.queue_autoExecuteOff,
      ),
      value: executionState.autoExecuteEnabled,
      onChanged: (value) {
        ref.read(queueExecutionNotifierProvider.notifier).setAutoExecute(value);
      },
    );
  }

  Future<void> _confirmClearQueue(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.queue_confirmClear),
        content: Text(l10n.queue_clearQueueConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.common_confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(replicationQueueNotifierProvider.notifier).clear();
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }
}
