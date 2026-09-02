import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../data/models/queue/replication_task.dart';
import '../../adaptive/interaction_policy.dart';
import '../../../data/models/queue/replication_task_status.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';
import 'queue_task_thumbnail.dart';

enum _TaskItemAction { select, edit, delete }

/// 任务列表项 - 紧凑美观的现代设计
class TaskListItem extends ConsumerStatefulWidget {
  final ReplicationTask task;
  final int index;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TaskListItem({
    super.key,
    required this.task,
    required this.index,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  ConsumerState<TaskListItem> createState() => _TaskListItemState();
}

class _TaskListItemState extends ConsumerState<TaskListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  bool _isHovered = false;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _updateAnimation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_disableAnimations == disableAnimations) return;
    _disableAnimations = disableAnimations;
    _updateAnimation();
  }

  @override
  void didUpdateWidget(TaskListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.status != widget.task.status) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.task.status == ReplicationTaskStatus.running &&
        !_disableAnimations) {
      _shimmerController.repeat();
    } else {
      _shimmerController.stop();
      _shimmerController.reset();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isRunning = widget.task.status == ReplicationTaskStatus.running;
    final interactionPolicy = context.interactionPolicy;

    // 获取当前执行任务ID和生成进度
    final (currentTaskId, generationProgress) = _getExecutionProgress();

    // currentTaskId 从 ready 阶段起即锁定任务，避免生成提交前的短暂窗口仍可编辑或删除。
    final isExecutionLocked = currentTaskId == widget.task.id;
    final isCurrentRunningTask = isRunning && isExecutionLocked;
    final canSelect =
        widget.task.status == ReplicationTaskStatus.pending &&
        !isExecutionLocked;
    final canEdit = canSelect && widget.onEdit != null;
    final canDelete = !isExecutionLocked && widget.onDelete != null;

    return ReorderableDragStartListener(
      index: widget.index,
      enabled:
          interactionPolicy.precisePointerAvailable &&
          !widget.isSelectionMode &&
          canSelect,
      child: MouseRegion(
        cursor: widget.isSelectionMode
            ? SystemMouseCursors.click
            : SystemMouseCursors.grab,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: _TaskTooltipWrapper(
          task: widget.task,
          enabled:
              !widget.isSelectionMode &&
              interactionPolicy.precisePointerAvailable,
          child: Dismissible(
            key: Key(widget.task.id),
            direction: widget.isSelectionMode || !canDelete
                ? DismissDirection.none
                : DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.delete_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            confirmDismiss: (_) async {
              return await _confirmDelete(context, l10n);
            },
            onDismissed: (_) => widget.onDelete?.call(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.isSelectionMode
                      ? canSelect
                            ? () => ref
                                  .read(
                                    replicationQueueNotifierProvider.notifier,
                                  )
                                  .toggleTaskSelection(widget.task.id)
                            : null
                      : widget.onTap,
                  onLongPress: widget.isSelectionMode || !canSelect
                      ? null
                      : _enterSelectionModeForTask,
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: widget.isSelected
                              ? Border.all(color: theme.colorScheme.primary)
                              : null,
                          // 如果是当前正在执行的任务，显示实心进度条；否则显示普通背景
                          color: widget.isSelected
                              ? theme.colorScheme.primaryContainer.withValues(
                                  alpha: 0.4,
                                )
                              : Color.alphaBlend(
                                  theme.colorScheme.onSurface.withValues(
                                    alpha: _isHovered ? 0.1 : 0.055,
                                  ),
                                  theme.colorScheme.surface,
                                ),
                        ),
                        child: Stack(
                          children: [
                            // 进度条背景（动态条纹 + 垂直切割末端）
                            if (isCurrentRunningTask)
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: generationProgress.clamp(
                                      0.0,
                                      1.0,
                                    ),
                                    child: _AnimatedStripeProgress(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            // 内容
                            child!,
                          ],
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        // 选择框/缩略图
                        if (widget.isSelectionMode && canSelect)
                          _buildCheckbox(theme, ref)
                        else
                          _buildThumbnail(context),

                        const SizedBox(width: 10),

                        // 任务信息
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 状态行
                              _buildStatusRow(theme, l10n),
                              const SizedBox(height: 4),
                              // 提示词
                              Text(
                                widget.task.prompt,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  height: 1.35,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                              ),
                              // 错误信息
                              if (widget.task.errorMessage != null) ...[
                                const SizedBox(height: 4),
                                _buildErrorMessage(theme),
                              ],
                            ],
                          ),
                        ),

                        // 操作按钮
                        if (!widget.isSelectionMode)
                          _buildActionButtons(
                            theme,
                            l10n,
                            canSelect: canSelect,
                            canEdit: canEdit,
                            canDelete: canDelete,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建复选框
  Widget _buildCheckbox(ThemeData theme, WidgetRef ref) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: Transform.scale(
          scale: 0.95,
          child: Checkbox(
            value: widget.isSelected,
            onChanged: (_) => ref
                .read(replicationQueueNotifierProvider.notifier)
                .toggleTaskSelection(widget.task.id),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建缩略图
  Widget _buildThumbnail(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.task.thumbnailUrl != null &&
        widget.task.thumbnailUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: QueueTaskThumbnail(
          source: widget.task.thumbnailUrl!,
          width: 44,
          height: 44,
        ),
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          theme.colorScheme.onSurface.withValues(alpha: 0.08),
          theme.colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.image_rounded,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
      ),
    );
  }

  /// 构建状态行
  Widget _buildStatusRow(ThemeData theme, AppLocalizations l10n) {
    final (icon, color) = _getStatusIconAndColor(theme);
    final isRunning = widget.task.status == ReplicationTaskStatus.running;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: isRunning
              ? _buildRotatingIcon(icon, color)
              : Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          '#${widget.index + 1}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
            fontWeight: FontWeight.w600,
          ),
        ),
        if (widget.task.retryCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              l10n.queue_retryCount(widget.task.retryCount, 10),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.orange,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 构建旋转图标
  Widget _buildRotatingIcon(IconData icon, Color color) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _shimmerController.value * 2 * 3.14159,
          child: child,
        );
      },
      child: Icon(icon, size: 12, color: color),
    );
  }

  /// 获取状态图标和颜色
  (IconData, Color) _getStatusIconAndColor(ThemeData theme) {
    switch (widget.task.status) {
      case ReplicationTaskStatus.pending:
        return (Icons.schedule_rounded, theme.colorScheme.onSurfaceVariant);
      case ReplicationTaskStatus.running:
        return (Icons.sync_rounded, Colors.blue);
      case ReplicationTaskStatus.completed:
        return (Icons.check_circle_rounded, Colors.green);
      case ReplicationTaskStatus.failed:
        return (Icons.error_rounded, Colors.red);
      case ReplicationTaskStatus.skipped:
        return (Icons.skip_next_rounded, Colors.orange);
    }
  }

  /// 构建错误消息
  Widget _buildErrorMessage(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 12, color: Colors.red),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              widget.task.errorMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建操作按钮组。触屏设备始终显示明确的排序和操作入口，
  /// 不要求用户猜测悬浮、整卡拖动或滑动手势。
  Widget _buildActionButtons(
    ThemeData theme,
    AppLocalizations l10n, {
    required bool canSelect,
    required bool canEdit,
    required bool canDelete,
  }) {
    if (!canSelect && !canEdit && !canDelete) {
      return const SizedBox.shrink();
    }

    if (context.interactionPolicy.touchAvailable) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canSelect)
            ReorderableDragStartListener(
              index: widget.index,
              child: Tooltip(
                message: l10n.queue_reorderTask,
                child: Semantics(
                  button: true,
                  label: l10n.queue_reorderTask,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.82,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          PopupMenuButton<_TaskItemAction>(
            tooltip: l10n.queue_moreTaskActions,
            constraints: const BoxConstraints(minWidth: 180),
            onSelected: (action) async {
              switch (action) {
                case _TaskItemAction.select:
                  _enterSelectionModeForTask();
                case _TaskItemAction.edit:
                  widget.onEdit?.call();
                case _TaskItemAction.delete:
                  await _handleDelete(l10n);
              }
            },
            itemBuilder: (context) => [
              if (canSelect)
                PopupMenuItem(
                  value: _TaskItemAction.select,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle_outline_rounded),
                    title: Text(l10n.queue_selectTask),
                  ),
                ),
              if (canEdit)
                PopupMenuItem(
                  value: _TaskItemAction.edit,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit_rounded),
                    title: Text(l10n.queue_edit),
                  ),
                ),
              if (canDelete)
                PopupMenuItem(
                  value: _TaskItemAction.delete,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(l10n.common_delete),
                  ),
                ),
            ],
            icon: Icon(
              Icons.more_vert_rounded,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
            ),
          ),
        ],
      );
    }

    return AnimatedOpacity(
      opacity: _isHovered ? 1.0 : 0.0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 150),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canEdit)
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                icon: Icon(
                  Icons.edit_rounded,
                  size: 18,
                  color: theme.colorScheme.outline,
                ),
                onPressed: widget.onEdit,
                tooltip: l10n.queue_edit,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (canEdit && canDelete) const SizedBox(width: 4),
          if (canDelete)
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.outline,
                ),
                onPressed: () => _handleDelete(l10n),
                tooltip: l10n.common_delete,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  void _enterSelectionModeForTask() {
    final notifier = ref.read(replicationQueueNotifierProvider.notifier);
    notifier.toggleSelectionMode();
    notifier.toggleTaskSelection(widget.task.id);
  }

  /// 处理删除操作
  Future<void> _handleDelete(AppLocalizations l10n) async {
    if (widget.onDelete == null) return;
    final confirmed = await _confirmDelete(context, l10n);
    if (confirmed) widget.onDelete!.call();
  }

  /// 获取当前执行进度
  (String?, double) _getExecutionProgress() {
    try {
      final executionState = ref.watch(queueExecutionNotifierProvider);
      final currentTaskId = executionState.currentTaskId;
      if (currentTaskId == widget.task.id && executionState.isRunning) {
        final genState = ref.watch(imageGenerationNotifierProvider);
        return (currentTaskId, genState.progress);
      }
      return (currentTaskId, 0.0);
    } catch (e) {
      return (null, 0.0);
    }
  }

  /// 确认删除对话框
  Future<bool> _confirmDelete(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.common_confirmDelete),
            content: Text(l10n.queue_confirmDeleteSelected(1)),
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
        ) ??
        false;
  }
}

/// 任务悬浮提示包装器 - 显示大图和完整提示词
class _TaskTooltipWrapper extends StatefulWidget {
  final ReplicationTask task;
  final bool enabled;
  final Widget child;

  const _TaskTooltipWrapper({
    required this.task,
    required this.enabled,
    required this.child,
  });

  @override
  State<_TaskTooltipWrapper> createState() => _TaskTooltipWrapperState();
}

class _TaskTooltipWrapperState extends State<_TaskTooltipWrapper>
    with WidgetsBindingObserver {
  OverlayEntry? _overlayEntry;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(_TaskTooltipWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _hideTooltip();
    } else if (oldWidget.task != widget.task) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  @override
  void didChangeMetrics() {
    _isHovering = false;
    _hideTooltip();
  }

  void _showTooltip() {
    if (!widget.enabled || _overlayEntry != null) return;

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideTooltip() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final overlayBox =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final itemOffset = renderBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final itemSize = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned.fill(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final safePadding = MediaQuery.paddingOf(context);
            final viewportSize = constraints.biggest;
            const preferredWidth = 420.0;
            const preferredMaxHeight = 560.0;
            const gap = 12.0;
            const edgePadding = 12.0;

            final safeLeft = safePadding.left + edgePadding;
            final safeTop = safePadding.top + edgePadding;
            final safeRight =
                viewportSize.width - safePadding.right - edgePadding;
            final safeBottom =
                viewportSize.height - safePadding.bottom - edgePadding;
            final availableWidth = math.max(0.0, safeRight - safeLeft);
            final availableHeight = math.max(0.0, safeBottom - safeTop);
            final tooltipWidth = math.min(preferredWidth, availableWidth);
            final tooltipHeight = math.min(preferredMaxHeight, availableHeight);

            final rightCandidate = itemOffset.dx + itemSize.width + gap;
            final leftCandidate = itemOffset.dx - tooltipWidth - gap;
            final rightSpace = safeRight - rightCandidate;
            final leftSpace = itemOffset.dx - gap - safeLeft;
            final preferredLeft = rightSpace >= tooltipWidth
                ? rightCandidate
                : leftSpace >= tooltipWidth
                ? leftCandidate
                : rightSpace >= leftSpace
                ? rightCandidate
                : leftCandidate;
            final left = preferredLeft
                .clamp(safeLeft, math.max(safeLeft, safeRight - tooltipWidth))
                .toDouble();
            final top = itemOffset.dy
                .clamp(safeTop, math.max(safeTop, safeBottom - tooltipHeight))
                .toDouble();

            return Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  width: tooltipWidth,
                  height: tooltipHeight,
                  child: QueueTaskDetailView(task: widget.task),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTooltip();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        _isHovering = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_isHovering && mounted) {
            _showTooltip();
          }
        });
      },
      onExit: (_) {
        _isHovering = false;
        _hideTooltip();
      },
      child: widget.child,
    );
  }
}

/// 队列任务详情。桌面悬浮预览与触屏详情面板共享同一份完整内容。
class QueueTaskDetailView extends StatelessWidget {
  const QueueTaskDetailView({
    super.key,
    required this.task,
    this.scrollController,
    this.framed = true,
  });

  final ReplicationTask task;
  final ScrollController? scrollController;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final parameters = <(String, String)>[
      if (task.model?.trim().isNotEmpty == true)
        (l10n.queue_model, task.model!.trim()),
      if (task.seed != null) (l10n.queue_seed, '${task.seed}'),
      if (task.sampler?.trim().isNotEmpty == true)
        (l10n.queue_sampler, task.sampler!.trim()),
      if (task.steps != null) (l10n.queue_steps, '${task.steps}'),
      if (task.cfgScale != null) (l10n.queue_cfg, '${task.cfgScale}'),
      if (task.width != null && task.height != null)
        (l10n.queue_size, '${task.width} × ${task.height}'),
    ];

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: framed
            ? const BoxConstraints(maxWidth: 420, maxHeight: 560)
            : null,
        decoration: framed
            ? BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              )
            : null,
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            if (task.thumbnailUrl?.trim().isNotEmpty == true) ...[
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: QueueTaskThumbnail(
                    source: task.thumbnailUrl!,
                    width: 220,
                    height: 220,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _QueuePromptSection(
              title: l10n.prompt_positivePrompt,
              text: task.prompt,
              color: theme.colorScheme.primary,
            ),
            if (task.negativePrompt.isNotEmpty) ...[
              const SizedBox(height: 14),
              _QueuePromptSection(
                title: l10n.prompt_negativePrompt,
                text: task.negativePrompt,
                color: Colors.orange,
              ),
            ],
            if (!task.applyNegativePrompt) ...[
              const SizedBox(height: 10),
              Text(
                l10n.queue_negativePromptFromMain,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (task.characterPrompts case final characters?) ...[
              if (characters.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  l10n.prompt_characterPrompts,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (var index = 0; index < characters.length; index++) ...[
                  _QueueCharacterPromptCard(
                    index: index,
                    character: characters[index],
                  ),
                  if (index + 1 < characters.length) const SizedBox(height: 8),
                ],
              ],
            ],
            if (parameters.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                l10n.queue_parametersPreview,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final parameter in parameters)
                    _QueueParameterChip(
                      label: parameter.$1,
                      value: parameter.$2,
                    ),
                ],
              ),
            ],
            if (task.errorMessage?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 18),
              _QueuePromptSection(
                title: l10n.common_error,
                text: task.errorMessage!.trim(),
                color: theme.colorScheme.error,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QueuePromptSection extends StatelessWidget {
  const _QueuePromptSection({
    required this.title,
    required this.text,
    required this.color,
  });

  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        SelectableText(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            height: 1.45,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

class _QueueCharacterPromptCard extends StatelessWidget {
  const _QueueCharacterPromptCard({
    required this.index,
    required this.character,
  });

  final int index;
  final ReplicationCharacterPromptSnapshot character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l10n.prompt_characterPrompts} ${index + 1}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!character.enabled)
                Text(
                  l10n.common_disabled,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (character.prompt.isNotEmpty) ...[
            const SizedBox(height: 6),
            SelectableText(character.prompt, style: theme.textTheme.bodySmall),
          ],
          if (character.negativePrompt.isNotEmpty) ...[
            const SizedBox(height: 6),
            SelectableText(
              character.negativePrompt,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QueueParameterChip extends StatelessWidget {
  const _QueueParameterChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label · $value',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 失败任务列表项 - 精致紧凑设计
class FailedTaskListItem extends ConsumerWidget {
  final ReplicationTask task;
  final VoidCallback? onRetry;
  final VoidCallback? onRequeue;

  const FailedTaskListItem({
    super.key,
    required this.task,
    this.onRetry,
    this.onRequeue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 提示词
              Text(
                task.prompt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),

              // 错误信息
              if (task.errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 14,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.red,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // 操作按钮行
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    _buildCompactButton(
                      context,
                      icon: Icons.delete_outline_rounded,
                      label: l10n.queue_delete,
                      onPressed: () => ref
                          .read(replicationQueueNotifierProvider.notifier)
                          .removeFailedTask(task.id),
                      color: Colors.grey,
                    ),
                    _buildCompactButton(
                      context,
                      icon: Icons.queue_rounded,
                      label: l10n.queue_requeue,
                      onPressed:
                          onRequeue ??
                          () => ref
                              .read(replicationQueueNotifierProvider.notifier)
                              .requeueFailedTask(task.id),
                      color: theme.colorScheme.primary,
                    ),
                    FilledButton.icon(
                      onPressed:
                          onRetry ??
                          () => ref
                              .read(replicationQueueNotifierProvider.notifier)
                              .retryFailedTask(task.id),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(l10n.queue_retry),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size(
                          0,
                          context.interactionPolicy.minimumControlExtent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建紧凑按钮
  Widget _buildCompactButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: Size(0, context.interactionPolicy.minimumControlExtent),
        foregroundColor: color,
      ),
    );
  }
}

/// 动态条纹进度条背景
///
/// 半透明斜条纹流动效果，末端垂直切割（无三角形斜角）
class _AnimatedStripeProgress extends StatefulWidget {
  final Color color;

  const _AnimatedStripeProgress({required this.color});

  @override
  State<_AnimatedStripeProgress> createState() =>
      _AnimatedStripeProgressState();
}

class _AnimatedStripeProgressState extends State<_AnimatedStripeProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool? _disableAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_disableAnimations == disableAnimations) return;
    _disableAnimations = disableAnimations;
    if (disableAnimations) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _StripeProgressPainter(
            color: widget.color,
            animationValue: _controller.value,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

/// 条纹绘制器（垂直切割末端）
class _StripeProgressPainter extends CustomPainter {
  final Color color;
  final double animationValue;

  _StripeProgressPainter({required this.color, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    // 背景填充
    final bgPaint = Paint()..color = color.withValues(alpha: 0.18);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 裁剪区域，确保条纹不超出边界（关键：末端垂直切割）
    canvas.clipRect(Offset.zero & size);

    // 斜条纹
    final stripePaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    const stripeWidth = 10.0;
    const stripeGap = 14.0;
    const stripeSpacing = stripeWidth + stripeGap;

    // 动画偏移
    final offset = animationValue * stripeSpacing;

    // 绘制斜条纹（45度）
    final path = Path();
    for (
      double x = -stripeSpacing * 2 + offset;
      x < size.width + size.height + stripeSpacing;
      x += stripeSpacing
    ) {
      path.moveTo(x, size.height);
      path.lineTo(x + stripeWidth, size.height);
      path.lineTo(x + size.height + stripeWidth, 0);
      path.lineTo(x + size.height, 0);
      path.close();
    }

    canvas.drawPath(path, stripePaint);
  }

  @override
  bool shouldRepaint(_StripeProgressPainter oldDelegate) =>
      animationValue != oldDelegate.animationValue ||
      color != oldDelegate.color;
}
