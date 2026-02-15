import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../data/models/queue/replication_task.dart';
import '../../../data/models/queue/replication_task_status.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';

/// 任务列表项 - 紧凑美观的现代设计
class TaskListItem extends ConsumerStatefulWidget {
  final ReplicationTask task;
  final int index;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const TaskListItem({
    super.key,
    required this.task,
    required this.index,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onTap,
    this.onEdit,
  });

  @override
  ConsumerState<TaskListItem> createState() => _TaskListItemState();
}

class _TaskListItemState extends ConsumerState<TaskListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  bool _isHovered = false;

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
  void didUpdateWidget(TaskListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.status != widget.task.status) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.task.status == ReplicationTaskStatus.running) {
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

    // 获取当前执行任务ID和生成进度
    final (currentTaskId, generationProgress) = _getExecutionProgress();

    // 判断是否是当前正在执行的任务（有实际进度）
    final isCurrentRunningTask = isRunning && currentTaskId == widget.task.id;

    return ReorderableDragStartListener(
      index: widget.index,
      enabled: !widget.isSelectionMode && !isRunning,
      child: MouseRegion(
        cursor: widget.isSelectionMode
            ? SystemMouseCursors.click
            : SystemMouseCursors.grab,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: _TaskTooltipWrapper(
          task: widget.task,
          enabled: !widget.isSelectionMode,
          child: Dismissible(
            key: Key(widget.task.id),
            direction: widget.isSelectionMode
                ? DismissDirection.none
                : DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.9),
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
            onDismissed: (_) {
              ref
                  .read(replicationQueueNotifierProvider.notifier)
                  .remove(widget.task.id);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.isSelectionMode
                      ? () => ref
                          .read(replicationQueueNotifierProvider.notifier)
                          .toggleTaskSelection(widget.task.id)
                      : widget.onTap,
                  onLongPress: widget.isSelectionMode
                      ? null
                      : () => ref
                          .read(replicationQueueNotifierProvider.notifier)
                          .toggleSelectionMode(),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.isSelected
                                ? theme.colorScheme.primary.withOpacity(0.5)
                                : isRunning
                                    ? theme.colorScheme.primary.withOpacity(0.3)
                                    : theme.colorScheme.outline
                                        .withOpacity(0.1),
                            width: 1,
                          ),
                          // 如果是当前正在执行的任务，显示实心进度条；否则显示普通背景
                          color: widget.isSelected
                              ? theme.colorScheme.primaryContainer
                                  .withOpacity(0.4)
                              : theme.colorScheme.surfaceContainerHighest
                                  .withOpacity(0.4),
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
                                    widthFactor:
                                        generationProgress.clamp(0.0, 1.0),
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
                        if (widget.isSelectionMode)
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
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.85),
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
                          _buildActionButtons(theme, l10n),
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
        child: CachedNetworkImage(
          imageUrl: widget.task.thumbnailUrl!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.image_rounded,
              size: 20,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.broken_image_rounded,
              size: 20,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.image_rounded,
        size: 20,
        color: theme.colorScheme.outline.withOpacity(0.5),
      ),
    );
  }

  /// 构建状态行
  Widget _buildStatusRow(ThemeData theme, dynamic l10n) {
    final (icon, color) = _getStatusIconAndColor();
    final isRunning = widget.task.status == ReplicationTaskStatus.running;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
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
            color: theme.colorScheme.outline,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (widget.task.retryCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
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
  (IconData, Color) _getStatusIconAndColor() {
    switch (widget.task.status) {
      case ReplicationTaskStatus.pending:
        return (Icons.schedule_rounded, Colors.grey);
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
        color: Colors.red.withOpacity(0.08),
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
              style: const TextStyle(
                fontSize: 10,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建操作按钮组（悬浮时显示）
  Widget _buildActionButtons(ThemeData theme, dynamic l10n) {
    return AnimatedOpacity(
      opacity: _isHovered ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 150),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 编辑按钮
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
          const SizedBox(width: 4),
          // 删除按钮
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

  /// 处理删除操作
  Future<void> _handleDelete(dynamic l10n) async {
    final confirmed = await _confirmDelete(context, l10n);
    if (confirmed) {
      ref
          .read(replicationQueueNotifierProvider.notifier)
          .remove(widget.task.id);
    }
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
  Future<bool> _confirmDelete(BuildContext context, dynamic l10n) async {
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
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
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

class _TaskTooltipWrapperState extends State<_TaskTooltipWrapper> {
  OverlayEntry? _overlayEntry;
  bool _isHovering = false;

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
    final itemOffset = renderBox.localToGlobal(Offset.zero);
    final itemSize = renderBox.size;

    return OverlayEntry(
      builder: (context) {
        final screenSize = MediaQuery.of(context).size;
        const tooltipWidth = 350.0;
        const tooltipMaxHeight = 450.0;
        const gap = 12.0;

        // 计算水平位置：优先显示在右侧，空间不足则显示在左侧
        double left;
        final rightSpace =
            screenSize.width - (itemOffset.dx + itemSize.width + gap);
        if (rightSpace >= tooltipWidth) {
          // 右侧空间足够
          left = itemOffset.dx + itemSize.width + gap;
        } else {
          // 显示在左侧
          left = itemOffset.dx - tooltipWidth - gap;
          if (left < 0) left = gap; // 确保不超出屏幕左边界
        }

        // 计算垂直位置：确保不超出屏幕底部
        double top = itemOffset.dy;
        final bottomSpace = screenSize.height - top;
        if (bottomSpace < tooltipMaxHeight) {
          // 向上调整，确保底部不被截断
          top = screenSize.height - tooltipMaxHeight - 20;
          if (top < 20) top = 20; // 确保不超出屏幕顶部
        }

        return Positioned(
          left: left,
          top: top,
          child: _TaskTooltipContent(task: widget.task),
        );
      },
    );
  }

  @override
  void dispose() {
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

/// 悬浮提示内容 - 大图和完整提示词
class _TaskTooltipContent extends StatelessWidget {
  final ReplicationTask task;

  const _TaskTooltipContent({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 350, maxHeight: 450),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 大图预览
            if (task.thumbnailUrl != null && task.thumbnailUrl!.isNotEmpty)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: task.thumbnailUrl!,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 200,
                      height: 200,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 200,
                      height: 200,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.broken_image_rounded,
                        size: 48,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              ),

            if (task.thumbnailUrl != null && task.thumbnailUrl!.isNotEmpty)
              const SizedBox(height: 12),

            // 完整提示词
            Text(
              '正向提示词',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: SelectableText(
                  task.prompt,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.4,
                    color: theme.colorScheme.onSurface.withOpacity(0.9),
                  ),
                ),
              ),
            ),

            // 负向提示词
            if (task.negativePrompt.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '负向提示词',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 80),
                child: SingleChildScrollView(
                  child: SelectableText(
                    task.negativePrompt,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.4,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
            ],
          ],
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
            color: Colors.red.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.red.withOpacity(0.15),
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
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.4,
                ),
              ),

              // 错误信息
              if (task.errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildCompactButton(
                    icon: Icons.delete_outline_rounded,
                    label: l10n.queue_delete,
                    onPressed: () => ref
                        .read(replicationQueueNotifierProvider.notifier)
                        .removeFailedTask(task.id),
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  _buildCompactButton(
                    icon: Icons.queue_rounded,
                    label: l10n.queue_requeue,
                    onPressed: onRequeue ??
                        () => ref
                            .read(replicationQueueNotifierProvider.notifier)
                            .requeueFailedTask(task.id),
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: onRetry ??
                        () => ref
                            .read(replicationQueueNotifierProvider.notifier)
                            .retryFailedTask(task.id),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(l10n.queue_retry),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      minimumSize: const Size(0, 30),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建紧凑按钮
  Widget _buildCompactButton({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        minimumSize: const Size(0, 30),
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
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

  _StripeProgressPainter({
    required this.color,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 背景填充
    final bgPaint = Paint()..color = color.withOpacity(0.18);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 裁剪区域，确保条纹不超出边界（关键：末端垂直切割）
    canvas.clipRect(Offset.zero & size);

    // 斜条纹
    final stripePaint = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    const stripeWidth = 10.0;
    const stripeGap = 14.0;
    const stripeSpacing = stripeWidth + stripeGap;

    // 动画偏移
    final offset = animationValue * stripeSpacing;

    // 绘制斜条纹（45度）
    final path = Path();
    for (double x = -stripeSpacing * 2 + offset;
        x < size.width + size.height + stripeSpacing;
        x += stripeSpacing) {
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
