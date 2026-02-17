import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../data/services/vibe_bulk_operation_service.dart';

/// Vibe 批量操作进度对话框
///
/// 用于显示 Vibe 库批量操作的进度，包括：
/// - 显示进度条
/// - 显示当前操作项
/// - 支持取消操作
/// - 完成后显示结果
class VibeBulkOperationDialog extends ConsumerStatefulWidget {
  /// 操作类型
  final VibeBulkOperationType operationType;

  /// 要处理的条目 ID 列表
  final List<String> entryIds;

  /// 目标分类 ID（用于移动操作）
  final String? targetCategoryId;

  /// 标签列表（用于添加/移除标签操作）
  final List<String>? tags;

  /// 收藏状态（用于切换收藏操作）
  final bool? isFavorite;

  const VibeBulkOperationDialog({
    super.key,
    required this.operationType,
    required this.entryIds,
    this.targetCategoryId,
    this.tags,
    this.isFavorite,
  });

  /// 显示批量操作进度对话框
  ///
  /// 返回操作结果，如果用户取消则返回 null
  static Future<VibeBulkOperationResult?> show({
    required BuildContext context,
    required VibeBulkOperationType operationType,
    required List<String> entryIds,
    String? targetCategoryId,
    List<String>? tags,
    bool? isFavorite,
  }) {
    return showDialog<VibeBulkOperationResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VibeBulkOperationDialog(
        operationType: operationType,
        entryIds: entryIds,
        targetCategoryId: targetCategoryId,
        tags: tags,
        isFavorite: isFavorite,
      ),
    );
  }

  @override
  ConsumerState<VibeBulkOperationDialog> createState() =>
      _VibeBulkOperationDialogState();
}

class _VibeBulkOperationDialogState
    extends ConsumerState<VibeBulkOperationDialog> {
  /// 是否正在操作中
  bool _isProcessing = true;

  /// 是否已取消
  bool _isCancelled = false;

  /// 当前进度
  int _currentProgress = 0;

  /// 总数
  int _totalCount = 0;

  /// 当前处理项名称
  String _currentItem = '';

  /// 操作结果
  VibeBulkOperationResult? _result;

  /// 错误信息
  String? _error;

  static const String _tag = 'VibeBulkOperationDialog';

  @override
  void initState() {
    super.initState();
    _totalCount = widget.entryIds.length;
    _executeOperation();
  }

  /// 执行批量操作
  Future<void> _executeOperation() async {
    final service = ref.read(vibeBulkOperationServiceProvider);

    try {
      VibeBulkOperationResult result;

      switch (widget.operationType) {
        case VibeBulkOperationType.delete:
          result = await service.bulkDelete(
            widget.entryIds,
            onProgress: _handleProgress,
          );
        case VibeBulkOperationType.move:
          result = await service.bulkMoveToCategory(
            widget.entryIds,
            targetCategoryId: widget.targetCategoryId,
            onProgress: _handleProgress,
          );
        case VibeBulkOperationType.toggleFavorite:
          result = await service.bulkToggleFavorite(
            widget.entryIds,
            isFavorite: widget.isFavorite ?? true,
            onProgress: _handleProgress,
          );
        case VibeBulkOperationType.addTags:
          result = await service.bulkAddTags(
            widget.entryIds,
            tags: widget.tags ?? [],
            onProgress: _handleProgress,
          );
        case VibeBulkOperationType.removeTags:
          result = await service.bulkRemoveTags(
            widget.entryIds,
            tags: widget.tags ?? [],
            onProgress: _handleProgress,
          );
        case VibeBulkOperationType.export:
        case VibeBulkOperationType.import:
          throw UnsupportedError(
            '${widget.operationType} is not supported in this dialog',
          );
      }

      if (mounted) {
        setState(() {
          _result = result;
          _isProcessing = false;
          _currentProgress = widget.entryIds.length;
        });
      }

      AppLogger.i(
        'Bulk operation completed: ${result.successCount} succeeded, '
        '${result.failedCount} failed',
        _tag,
      );
    } catch (e, stack) {
      AppLogger.e('Bulk operation failed', e, stack, _tag);
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isProcessing = false;
        });
      }
    }
  }

  /// 处理进度回调
  void _handleProgress({
    required int current,
    required int total,
    required String currentItem,
    required VibeBulkOperationType operationType,
    required bool isComplete,
  }) {
    if (_isCancelled) return;

    if (mounted) {
      setState(() {
        _currentProgress = current;
        _totalCount = total;
        _currentItem = currentItem;
      });
    }
  }

  /// 取消操作
  void _cancel() {
    setState(() {
      _isCancelled = true;
    });
    Navigator.of(context).pop();
  }

  /// 关闭对话框
  void _close() {
    Navigator.of(context).pop(_result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              _buildHeader(theme),
              const SizedBox(height: 24),

              // 进度或结果内容
              _buildContent(theme),

              const SizedBox(height: 24),

              // 底部按钮
              _buildFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Icon(
          _getOperationIcon(),
          color: _getOperationColor(theme),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _getOperationTitle(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (!_isProcessing)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _close,
            tooltip: '关闭',
          ),
      ],
    );
  }

  /// 构建内容区域
  Widget _buildContent(ThemeData theme) {
    if (_error != null) {
      return _buildErrorContent(theme);
    }

    if (_isProcessing) {
      return _buildProgressContent(theme);
    }

    return _buildResultContent(theme);
  }

  /// 构建进度内容
  Widget _buildProgressContent(ThemeData theme) {
    final progress = _totalCount > 0 ? _currentProgress / _totalCount : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 进度文本
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '正在处理: $_currentProgress / $_totalCount',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_currentItem.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _currentItem,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // 百分比
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 进度条
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  /// 构建结果内容
  Widget _buildResultContent(ThemeData theme) {
    if (_result == null) return const SizedBox.shrink();

    final result = _result!;
    final isSuccess = result.failedCount == 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 完成状态
        Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.warning_amber,
              color: isSuccess ? theme.colorScheme.primary : Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isSuccess ? '操作完成' : '操作完成（部分失败）',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isSuccess ? theme.colorScheme.primary : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 统计信息
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 成功数
                  _buildStatItem(
                    theme,
                    icon: Icons.check_circle,
                    label: '成功',
                    value: '${result.successCount}',
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 24),
                  // 失败数
                  if (result.failedCount > 0)
                    _buildStatItem(
                      theme,
                      icon: Icons.error,
                      label: '失败',
                      value: '${result.failedCount}',
                      color: theme.colorScheme.error,
                    ),
                ],
              ),

              // 错误列表
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(color: theme.dividerColor.withOpacity(0.5)),
                const SizedBox(height: 8),
                Text(
                  '错误信息:',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                ...result.errors.take(3).map(
                  (error) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 14,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            error,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (result.errors.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '...还有 ${result.errors.length - 3} 个错误',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 构建统计项
  Widget _buildStatItem(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建错误内容
  Widget _buildErrorContent(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.error,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '操作失败',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _error ?? '未知错误',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建底部按钮
  Widget _buildFooter(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_isProcessing)
          TextButton(
            onPressed: _cancel,
            child: const Text('取消'),
          )
        else
          FilledButton(
            onPressed: _close,
            child: const Text('确定'),
          ),
      ],
    );
  }

  /// 获取操作标题
  String _getOperationTitle() {
    switch (widget.operationType) {
      case VibeBulkOperationType.delete:
        return '批量删除';
      case VibeBulkOperationType.move:
        return '批量移动';
      case VibeBulkOperationType.toggleFavorite:
        return '批量切换收藏';
      case VibeBulkOperationType.addTags:
        return '批量添加标签';
      case VibeBulkOperationType.removeTags:
        return '批量移除标签';
      case VibeBulkOperationType.export:
        return '批量导出';
      case VibeBulkOperationType.import:
        return '批量导入';
    }
  }

  /// 获取操作图标
  IconData _getOperationIcon() {
    switch (widget.operationType) {
      case VibeBulkOperationType.delete:
        return Icons.delete_outline;
      case VibeBulkOperationType.move:
        return Icons.drive_file_move_outline;
      case VibeBulkOperationType.toggleFavorite:
        return Icons.favorite_border;
      case VibeBulkOperationType.addTags:
      case VibeBulkOperationType.removeTags:
        return Icons.label_outline;
      case VibeBulkOperationType.export:
        return Icons.file_download_outlined;
      case VibeBulkOperationType.import:
        return Icons.file_upload_outlined;
    }
  }

  /// 获取操作颜色
  Color _getOperationColor(ThemeData theme) {
    switch (widget.operationType) {
      case VibeBulkOperationType.delete:
        return theme.colorScheme.error;
      case VibeBulkOperationType.move:
        return theme.colorScheme.primary;
      case VibeBulkOperationType.toggleFavorite:
        return Colors.pink;
      case VibeBulkOperationType.addTags:
      case VibeBulkOperationType.removeTags:
        return theme.colorScheme.secondary;
      case VibeBulkOperationType.export:
      case VibeBulkOperationType.import:
        return theme.colorScheme.tertiary;
    }
  }
}

/// 便捷方法：显示批量删除进度对话框
Future<VibeBulkOperationResult?> showVibeBulkDeleteDialog({
  required BuildContext context,
  required List<String> entryIds,
}) {
  return VibeBulkOperationDialog.show(
    context: context,
    operationType: VibeBulkOperationType.delete,
    entryIds: entryIds,
  );
}

/// 便捷方法：显示批量移动进度对话框
Future<VibeBulkOperationResult?> showVibeBulkMoveDialog({
  required BuildContext context,
  required List<String> entryIds,
  String? targetCategoryId,
}) {
  return VibeBulkOperationDialog.show(
    context: context,
    operationType: VibeBulkOperationType.move,
    entryIds: entryIds,
    targetCategoryId: targetCategoryId,
  );
}

/// 便捷方法：显示批量切换收藏进度对话框
Future<VibeBulkOperationResult?> showVibeBulkToggleFavoriteDialog({
  required BuildContext context,
  required List<String> entryIds,
  required bool isFavorite,
}) {
  return VibeBulkOperationDialog.show(
    context: context,
    operationType: VibeBulkOperationType.toggleFavorite,
    entryIds: entryIds,
    isFavorite: isFavorite,
  );
}

/// 便捷方法：显示批量添加标签进度对话框
Future<VibeBulkOperationResult?> showVibeBulkAddTagsDialog({
  required BuildContext context,
  required List<String> entryIds,
  required List<String> tags,
}) {
  return VibeBulkOperationDialog.show(
    context: context,
    operationType: VibeBulkOperationType.addTags,
    entryIds: entryIds,
    tags: tags,
  );
}

/// 便捷方法：显示批量移除标签进度对话框
Future<VibeBulkOperationResult?> showVibeBulkRemoveTagsDialog({
  required BuildContext context,
  required List<String> entryIds,
  required List<String> tags,
}) {
  return VibeBulkOperationDialog.show(
    context: context,
    operationType: VibeBulkOperationType.removeTags,
    entryIds: entryIds,
    tags: tags,
  );
}
