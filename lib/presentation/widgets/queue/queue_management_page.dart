import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../router/app_router.dart';
import 'execution_stats_panel.dart';
import 'task_list_item.dart';
import 'task_edit_dialog.dart';

/// 队列管理页面 - 紧凑精致的现代化设计
class QueueManagementPage extends ConsumerStatefulWidget {
  const QueueManagementPage({super.key});

  @override
  ConsumerState<QueueManagementPage> createState() =>
      _QueueManagementPageState();
}

class _QueueManagementPageState extends ConsumerState<QueueManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 安全获取执行状态
  QueueExecutionState _watchExecutionState() {
    try {
      return ref.watch(queueExecutionNotifierProvider);
    } catch (e) {
      return const QueueExecutionState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final queueState = ref.watch(replicationQueueNotifierProvider);
    final executionState = _watchExecutionState();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.queue_management),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          // 暂停/继续按钮
          if (executionState.isRunning ||
              executionState.isReady ||
              executionState.isPaused)
            _buildActionButton(
              icon: executionState.isPaused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
              tooltip: executionState.isPaused
                  ? l10n.queue_resume
                  : l10n.queue_pause,
              onPressed: () {
                if (executionState.isPaused) {
                  ref.read(queueExecutionNotifierProvider.notifier).resume();
                } else {
                  ref.read(queueExecutionNotifierProvider.notifier).pause();
                }
              },
              isHighlighted: executionState.isPaused,
            ),
          // 清空按钮 / 关闭悬浮球按钮
          if (queueState.isEmpty && queueState.failedTasks.isEmpty)
            // 队列为空时显示“关闭悬浮球”按钮
            _buildActionButton(
              icon: Icons.close_rounded,
              tooltip: l10n.queue_closeFloatingButton,
              onPressed: () {
                ref.read(floatingButtonClosedProvider.notifier).state = true;
                ref.read(queueManagementVisibleProvider.notifier).state = false;
              },
            )
          else
            // 队列非空时显示“清空队列”按钮
            _buildActionButton(
              icon: Icons.delete_sweep_rounded,
              tooltip: l10n.queue_clearQueue,
              onPressed: () => _confirmClearQueue(context),
            ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildTabBar(theme, l10n, queueState),
        ),
      ),
      body: Column(
        children: [
          // 紧凑统计面板
          const ExecutionStatsPanel(),

          // 批量操作栏
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: queueState.isSelectionMode
                ? _buildBatchOperationBar(theme, l10n, queueState)
                : const SizedBox.shrink(),
          ),

          // Tab内容
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPendingTab(theme, l10n, queueState),
                _buildCompletedTab(theme, l10n, queueState),
                _buildFailedTab(theme, l10n, queueState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool isHighlighted = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        icon: Icon(
          icon,
          color: isHighlighted
              ? theme.colorScheme.primary
              : onPressed == null
                  ? theme.disabledColor
                  : null,
        ),
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: isHighlighted
              ? theme.colorScheme.primaryContainer.withOpacity(0.5)
              : null,
        ),
      ),
    );
  }

  /// 构建Tab栏
  Widget _buildTabBar(
    ThemeData theme,
    dynamic l10n,
    ReplicationQueueState queueState,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: TabBar(
        controller: _tabController,
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: [
          _buildTab(
            icon: Icons.queue_rounded,
            label: l10n.queue_pending,
            count: queueState.count,
            theme: theme,
          ),
          _buildTab(
            icon: Icons.check_circle_outline_rounded,
            label: l10n.queue_completed,
            count: queueState.completedCount,
            theme: theme,
            color: Colors.green,
          ),
          _buildTab(
            icon: Icons.error_outline_rounded,
            label: l10n.queue_failed,
            count: queueState.failedCount,
            theme: theme,
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  /// 构建Tab项
  Widget _buildTab({
    required IconData icon,
    required String label,
    required int count,
    required ThemeData theme,
    Color? color,
  }) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: (color ?? theme.colorScheme.primary).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color ?? theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建批量操作栏
  Widget _buildBatchOperationBar(
    ThemeData theme,
    dynamic l10n,
    ReplicationQueueState queueState,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              l10n.queue_selectedCount(queueState.selectedCount),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          const Spacer(),
          _buildCompactButton(
            label: l10n.queue_selectAll,
            onPressed: () =>
                ref.read(replicationQueueNotifierProvider.notifier).selectAll(),
          ),
          _buildCompactButton(
            label: l10n.queue_invertSelection,
            onPressed: () => ref
                .read(replicationQueueNotifierProvider.notifier)
                .invertSelection(),
          ),
          _buildCompactButton(
            label: l10n.queue_cancelSelection,
            onPressed: () => ref
                .read(replicationQueueNotifierProvider.notifier)
                .exitSelectionMode(),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: queueState.selectedCount == 0
                ? null
                : () => ref
                    .read(replicationQueueNotifierProvider.notifier)
                    .pinSelectedToTop(),
            icon: const Icon(Icons.vertical_align_top_rounded, size: 16),
            label: Text(l10n.queue_pinToTop),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(0, 32),
            ),
          ),
          const SizedBox(width: 6),
          FilledButton.tonalIcon(
            onPressed:
                queueState.selectedCount == 0 ? null : _confirmDeleteSelected,
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: Text(l10n.queue_delete),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(0, 32),
              backgroundColor: Colors.red.withOpacity(0.12),
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建紧凑按钮
  Widget _buildCompactButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 28),
      ),
      child: Text(label),
    );
  }

  /// 构建等待中Tab
  Widget _buildPendingTab(
    ThemeData theme,
    dynamic l10n,
    ReplicationQueueState queueState,
  ) {
    if (queueState.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inbox_rounded,
        message: l10n.queue_empty,
        hint: l10n.queue_emptyHint,
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: queueState.tasks.length,
      onReorder: (oldIndex, newIndex) {
        ref
            .read(replicationQueueNotifierProvider.notifier)
            .reorder(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final elevation =
                Tween<double>(begin: 0, end: 6).evaluate(animation);
            return Material(
              elevation: elevation,
              borderRadius: BorderRadius.circular(12),
              child: child,
            );
          },
        );
      },
      itemBuilder: (context, index) {
        final task = queueState.tasks[index];
        return TaskListItem(
          key: Key(task.id),
          task: task,
          index: index,
          isSelectionMode: queueState.isSelectionMode,
          isSelected: queueState.selectedTaskIds.contains(task.id),
          onTap: () => _showTaskDetails(task),
          onEdit: () => _editTask(task),
        );
      },
    );
  }

  /// 构建已完成Tab
  Widget _buildCompletedTab(
    ThemeData theme,
    dynamic l10n,
    ReplicationQueueState queueState,
  ) {
    if (queueState.completedTasks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline_rounded,
        message: l10n.queue_noCompletedTasks,
        color: Colors.green,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: queueState.completedTasks.length,
      itemBuilder: (context, index) {
        final task = queueState
            .completedTasks[queueState.completedTasks.length - 1 - index];
        return TaskListItem(
          task: task,
          index: index,
          onTap: () => _showTaskDetails(task),
        );
      },
    );
  }

  /// 构建失败Tab
  Widget _buildFailedTab(
    ThemeData theme,
    dynamic l10n,
    ReplicationQueueState queueState,
  ) {
    if (queueState.failedTasks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.sentiment_satisfied_rounded,
        message: l10n.queue_noFailedTasks,
        hint: null,
        color: Colors.green,
      );
    }

    return Column(
      children: [
        // 清空按钮
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => ref
                    .read(replicationQueueNotifierProvider.notifier)
                    .clearFailedTasks(),
                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                label: Text(l10n.queue_clearFailedTasks),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: queueState.failedTasks.length,
            itemBuilder: (context, index) {
              final task = queueState.failedTasks[index];
              return FailedTaskListItem(task: task);
            },
          ),
        ),
      ],
    );
  }

  /// 构建空状态
  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? hint,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final displayColor = color ?? theme.disabledColor;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: displayColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: displayColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showTaskDetails(task) {
    // 显示任务详情
  }

  void _editTask(task) {
    showDialog(
      context: context,
      builder: (context) => TaskEditDialog(task: task),
    );
  }

  Future<void> _confirmClearQueue(BuildContext context) async {
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
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(l10n.common_confirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(replicationQueueNotifierProvider.notifier).clear();
    }
  }

  Future<void> _confirmDeleteSelected() async {
    final l10n = context.l10n;
    final selectedCount =
        ref.read(replicationQueueNotifierProvider).selectedCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.common_confirmDelete),
        content: Text(l10n.queue_confirmDeleteSelected(selectedCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(l10n.common_confirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(replicationQueueNotifierProvider.notifier)
          .deleteSelected();
    }
  }
}
