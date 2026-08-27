import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../adaptive/adaptive_presenter.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../common/app_toast.dart';
import 'execution_stats_panel.dart';
import 'task_list_item.dart';
import 'task_edit_dialog.dart';

/// 队列管理页面 - 紧凑精致的现代化设计
class QueueManagementPage extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  final VoidCallback? onQueueStarted;

  const QueueManagementPage({super.key, this.onClose, this.onQueueStarted});

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final queueState = ref.watch(replicationQueueNotifierProvider);
    final executionState = ref.watch(queueExecutionNotifierProvider);
    final currentPrompt = ref.watch(
      generationParamsNotifierProvider.select((params) => params.prompt),
    );

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
          if (!queueState.isEmpty || queueState.failedTasks.isNotEmpty)
            _buildActionButton(
              icon: Icons.delete_sweep_rounded,
              tooltip: l10n.queue_clearQueue,
              onPressed: () => _confirmClearQueue(context),
            ),
          _buildActionButton(
            icon: Icons.close_rounded,
            tooltip: l10n.common_close,
            onPressed: widget.onClose,
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
          ExecutionStatsPanel(
            onQueueStarted: widget.onQueueStarted,
            onAddCurrentTask: currentPrompt.trim().isEmpty || queueState.isFull
                ? null
                : _addCurrentTask,
          ),

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
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
              : null,
        ),
      ),
    );
  }

  /// 构建Tab栏
  Widget _buildTabBar(
    ThemeData theme,
    AppLocalizations l10n,
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
                color: (color ?? theme.colorScheme.primary).withValues(
                  alpha: 0.15,
                ),
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
    AppLocalizations l10n,
    ReplicationQueueState queueState,
  ) {
    final isTouch = PlatformCapabilities.current.hasTouchInput;
    final selectedChip = Container(
      constraints: BoxConstraints(minHeight: isTouch ? 48 : 0),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
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
    );
    final actions = <Widget>[
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
      FilledButton.icon(
        onPressed: queueState.selectedCount == 0
            ? null
            : () => ref
                  .read(replicationQueueNotifierProvider.notifier)
                  .pinSelectedToTop(),
        icon: const Icon(Icons.vertical_align_top_rounded, size: 16),
        label: Text(l10n.queue_pinToTop),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: Size(0, isTouch ? 48 : 32),
        ),
      ),
      FilledButton.tonalIcon(
        onPressed: queueState.selectedCount == 0
            ? null
            : _confirmDeleteSelected,
        icon: const Icon(Icons.delete_rounded, size: 16),
        label: Text(l10n.queue_delete),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: Size(0, isTouch ? 48 : 32),
          backgroundColor: Colors.red.withValues(alpha: 0.12),
          foregroundColor: Colors.red,
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: isTouch
          ? Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [selectedChip, ...actions],
            )
          : Row(children: [selectedChip, const Spacer(), ...actions]),
    );
  }

  /// 构建紧凑按钮
  Widget _buildCompactButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    final isTouch = PlatformCapabilities.current.hasTouchInput;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size(0, isTouch ? 48 : 28),
      ),
      child: Text(label),
    );
  }

  /// 构建等待中Tab
  Widget _buildPendingTab(
    ThemeData theme,
    AppLocalizations l10n,
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
      onReorderItem: (oldIndex, newIndex) {
        ref
            .read(replicationQueueNotifierProvider.notifier)
            .reorder(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final elevation = Tween<double>(
              begin: 0,
              end: 6,
            ).evaluate(animation);
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
          onDelete: () => ref
              .read(replicationQueueNotifierProvider.notifier)
              .remove(task.id),
        );
      },
    );
  }

  /// 构建已完成Tab
  Widget _buildCompletedTab(
    ThemeData theme,
    AppLocalizations l10n,
    ReplicationQueueState queueState,
  ) {
    if (queueState.completedTasks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline_rounded,
        message: l10n.queue_noCompletedTasks,
        color: Colors.green,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: _confirmClearCompletedTasks,
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: Text(l10n.queue_clearCompletedTasks),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: queueState.completedTasks.length,
            itemBuilder: (context, index) {
              final task = queueState
                  .completedTasks[queueState.completedTasks.length - 1 - index];
              return TaskListItem(
                key: Key(task.id),
                task: task,
                index: index,
                onTap: () => _showTaskDetails(task),
                onDelete: () => ref
                    .read(replicationQueueNotifierProvider.notifier)
                    .removeCompletedTask(task.id),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 构建失败Tab
  Widget _buildFailedTab(
    ThemeData theme,
    AppLocalizations l10n,
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
                style: TextButton.styleFrom(foregroundColor: Colors.red),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.hasBoundedHeight && constraints.maxHeight < 180;
        final verticalPadding = compact ? 4.0 : 12.0;
        final minimumContentHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - verticalPadding * 2)
                  .clamp(0.0, double.infinity)
                  .toDouble()
            : 0.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: verticalPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minimumContentHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(compact ? 12 : 20),
                  decoration: BoxDecoration(
                    color: displayColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: compact ? 32 : 48,
                    color: displayColor.withValues(alpha: 0.6),
                  ),
                ),
                SizedBox(height: compact ? 8 : 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (hint != null) ...[
                  SizedBox(height: compact ? 4 : 6),
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addCurrentTask() async {
    final prompt = ref.read(generationParamsNotifierProvider).prompt.trim();
    if (prompt.isEmpty) {
      AppToast.warning(context, context.l10n.generation_pleaseInputPrompt);
      return;
    }

    final added = await ref
        .read(replicationQueueNotifierProvider.notifier)
        .add(ReplicationTask.create(prompt: prompt));
    if (!mounted) return;
    if (!added) {
      AppToast.warning(context, context.l10n.onlineGallery_queueFullMax);
      return;
    }

    _tabController.animateTo(0);
    AppToast.success(context, context.l10n.queue_taskAdded);
  }

  void _showTaskDetails(ReplicationTask task) {
    AdaptivePresenter.showPanel<void>(
      context: context,
      title: context.l10n.queue_taskDetails,
      builder: (context, scrollController) => QueueTaskDetailView(
        task: task,
        scrollController: scrollController,
        framed: false,
      ),
    );
  }

  void _editTask(ReplicationTask task) {
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.common_confirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(queueExecutionNotifierProvider.notifier).clearQueue();
    }
  }

  Future<void> _confirmClearCompletedTasks() async {
    final queueState = ref.read(replicationQueueNotifierProvider);
    if (queueState.completedTasks.isEmpty) return;

    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.common_confirmClear),
        content: Text(
          l10n.common_clearAllItemsConfirm(
            queueState.completedTasks.length,
            l10n.queue_completedTasks,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.common_confirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(replicationQueueNotifierProvider.notifier).clearCompletedTasks();
    }
  }

  Future<void> _confirmDeleteSelected() async {
    final l10n = context.l10n;
    final selectedCount = ref
        .read(replicationQueueNotifierProvider)
        .selectedCount;
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
