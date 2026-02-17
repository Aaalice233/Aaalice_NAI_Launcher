import 'package:flutter/material.dart';

/// 批量移动进度对话框
///
/// 显示批量移动操作的进度，包括:
/// - 当前进度条和百分比
/// - 已处理/总数显示
/// - 当前正在处理的文件名
/// - 错误信息和重试选项
/// - 取消操作按钮
///
/// 使用示例:
/// ```dart
/// final result = await BatchMoveDialog.show(
///   context: context,
///   totalCount: 100,
///   sourceFolder: '源文件夹',
///   destinationFolder: '目标文件夹',
/// );
/// ```
class BatchMoveDialog extends StatefulWidget {
  /// 总文件数
  final int totalCount;

  /// 源文件夹名称
  final String sourceFolder;

  /// 目标文件夹名称
  final String destinationFolder;

  /// 取消操作回调
  final VoidCallback? onCancel;

  const BatchMoveDialog({
    super.key,
    required this.totalCount,
    required this.sourceFolder,
    required this.destinationFolder,
    this.onCancel,
  });

  /// 显示批量移动进度对话框
  ///
  /// 返回 `true` 表示操作完成，`false` 表示用户取消
  static Future<bool> show({
    required BuildContext context,
    required int totalCount,
    required String sourceFolder,
    required String destinationFolder,
    VoidCallback? onCancel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BatchMoveDialog(
        totalCount: totalCount,
        sourceFolder: sourceFolder,
        destinationFolder: destinationFolder,
        onCancel: onCancel,
      ),
    );
    return result ?? false;
  }

  @override
  State<BatchMoveDialog> createState() => BatchMoveDialogState();
}

/// 批量移动对话框状态
///
/// 通过 GlobalKey 访问以更新进度
class BatchMoveDialogState extends State<BatchMoveDialog> {
  /// 当前处理数量
  int _processedCount = 0;

  /// 当前处理的文件名
  String _currentFileName = '';

  /// 错误信息
  String? _errorMessage;

  /// 是否已取消
  bool _isCancelled = false;

  /// 是否已完成
  bool _isCompleted = false;

  /// 获取当前进度 (0.0 - 1.0)
  double get progress =>
      widget.totalCount > 0 ? _processedCount / widget.totalCount : 0;

  /// 获取已处理数量
  int get processedCount => _processedCount;

  /// 获取是否已取消
  bool get isCancelled => _isCancelled;

  /// 获取是否已完成
  bool get isCompleted => _isCompleted;

  /// 更新进度
  ///
  /// [count] - 当前已处理数量
  /// [currentFileName] - 当前正在处理的文件名（可选）
  void updateProgress(int count, {String? currentFileName}) {
    if (_isCancelled || _isCompleted) return;

    setState(() {
      _processedCount = count;
      if (currentFileName != null) {
        _currentFileName = currentFileName;
      }
    });
  }

  /// 标记为已完成
  void markCompleted() {
    if (_isCancelled) return;

    setState(() {
      _isCompleted = true;
      _processedCount = widget.totalCount;
    });
  }

  /// 设置错误信息
  void setError(String message) {
    setState(() {
      _errorMessage = message;
    });
  }

  /// 清除错误信息
  void clearError() {
    setState(() {
      _errorMessage = null;
    });
  }

  /// 取消操作
  void _cancel() {
    setState(() {
      _isCancelled = true;
    });
    widget.onCancel?.call();
  }

  /// 关闭对话框
  void _close() {
    Navigator.of(context).pop(_isCompleted && !_isCancelled);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      title: Row(
        children: [
          Icon(
            Icons.drive_file_move_outlined,
            color: theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getTitleText(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 文件夹信息
            _buildFolderInfo(theme),
            const SizedBox(height: 20),
            // 进度条
            _buildProgressBar(theme),
            const SizedBox(height: 12),
            // 进度文字
            _buildProgressText(theme),
            // 当前文件名
            if (_currentFileName.isNotEmpty && !_isCompleted && !_isCancelled)
              _buildCurrentFile(theme),
            // 错误信息
            if (_errorMessage != null) _buildErrorMessage(theme),
          ],
        ),
      ),
      actions: _buildActions(theme),
    );
  }

  /// 获取标题文字
  String _getTitleText() {
    if (_isCancelled) {
      return '已取消';
    }
    if (_errorMessage != null) {
      return '移动出错';
    }
    if (_isCompleted) {
      return '移动完成';
    }
    return '正在移动文件...';
  }

  /// 构建文件夹信息
  Widget _buildFolderInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '从: ${widget.sourceFolder}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.arrow_downward,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '到: ${widget.destinationFolder}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建进度条
  Widget _buildProgressBar(ThemeData theme) {
    final progressColor = _getProgressColor(theme);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: _isCompleted ? 1.0 : progress,
        backgroundColor: theme.colorScheme.surfaceContainerLowest,
        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
        minHeight: 8,
      ),
    );
  }

  /// 获取进度条颜色
  Color _getProgressColor(ThemeData theme) {
    if (_isCancelled) {
      return theme.colorScheme.error;
    }
    if (_errorMessage != null) {
      return theme.colorScheme.error;
    }
    if (_isCompleted) {
      return Colors.green;
    }
    return theme.colorScheme.primary;
  }

  /// 构建进度文字
  Widget _buildProgressText(ThemeData theme) {
    final String statusText;
    final Color statusColor;

    if (_isCancelled) {
      statusText = '已取消 ($_processedCount/${widget.totalCount})';
      statusColor = theme.colorScheme.error;
    } else if (_errorMessage != null) {
      statusText = '出错 ($_processedCount/${widget.totalCount})';
      statusColor = theme.colorScheme.error;
    } else if (_isCompleted) {
      statusText = '完成 (${widget.totalCount}/${widget.totalCount})';
      statusColor = Colors.green;
    } else {
      final percentage = (progress * 100).toStringAsFixed(0);
      statusText = '$percentage% ($_processedCount/${widget.totalCount})';
      statusColor = theme.colorScheme.onSurfaceVariant;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '进度',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          statusText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: statusColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 构建当前文件名显示
  Widget _buildCurrentFile(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _currentFileName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建错误信息
  Widget _buildErrorMessage(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建操作按钮
  List<Widget> _buildActions(ThemeData theme) {
    // 完成或出错状态：显示关闭按钮
    if (_isCompleted || _isCancelled || _errorMessage != null) {
      return [
        FilledButton(
          onPressed: _close,
          child: const Text('关闭'),
        ),
      ];
    }

    // 进行中状态：显示取消按钮
    return [
      TextButton(
        onPressed: _cancel,
        child: Text(
          '取消',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    ];
  }
}

/// 批量移动控制器
///
/// 用于控制批量移动对话框的进度更新
class BatchMoveController {
  final GlobalKey<BatchMoveDialogState> _dialogKey;

  BatchMoveController(this._dialogKey);

  /// 更新进度
  void updateProgress(int count, {String? currentFileName}) {
    _dialogKey.currentState?.updateProgress(count, currentFileName: currentFileName);
  }

  /// 标记为已完成
  void markCompleted() {
    _dialogKey.currentState?.markCompleted();
  }

  /// 设置错误信息
  void setError(String message) {
    _dialogKey.currentState?.setError(message);
  }

  /// 清除错误信息
  void clearError() {
    _dialogKey.currentState?.clearError();
  }

  /// 获取当前进度
  double get progress => _dialogKey.currentState?.progress ?? 0;

  /// 获取已处理数量
  int get processedCount => _dialogKey.currentState?.processedCount ?? 0;

  /// 获取是否已取消
  bool get isCancelled => _dialogKey.currentState?.isCancelled ?? false;

  /// 获取是否已完成
  bool get isCompleted => _dialogKey.currentState?.isCompleted ?? false;
}
