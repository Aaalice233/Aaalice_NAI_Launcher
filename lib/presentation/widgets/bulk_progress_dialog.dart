import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../data/services/bulk_operation_service.dart';
import '../providers/bulk_operation_provider.dart';

/// Bulk operation progress dialog
///
/// Displays progress for long-running bulk operations with:
/// - Progress bar showing completion percentage
/// - Current item being processed
/// - Operation status and statistics
/// - Cancel button (when operation is cancellable)
///
/// 批量操作进度对话框
///
/// 显示长时间运行的批量操作的进度，包括：
/// - 显示完成百分比的进度条
/// - 当前正在处理的项目
/// - 操作状态和统计信息
/// - 取消按钮（当操作可取消时）
class BulkProgressDialog extends ConsumerStatefulWidget {
  /// Create bulk progress dialog
  const BulkProgressDialog({super.key});

  /// Show bulk progress dialog
  ///
  /// Returns true if operation completed successfully,
  /// false if cancelled or failed
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const BulkProgressDialog(),
    );
  }

  @override
  ConsumerState<BulkProgressDialog> createState() => _BulkProgressDialogState();
}

class _BulkProgressDialogState extends ConsumerState<BulkProgressDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    // Watch bulk operation state
    final operationState = ref.watch(bulkOperationNotifierProvider);
    final state = operationState;

    // Auto-close when operation completes successfully
    if (state.isCompleted && !state.isOperationInProgress) {
      // Close dialog after a short delay to show completion
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    }

    // Get operation type title
    final operationTitle = _getOperationTitle(state.currentOperation, l10n);

    // Get operation icon
    final operationIcon = _getOperationIcon(state.currentOperation);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            operationIcon,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              operationTitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Close button (only when not in progress)
          if (!state.isOperationInProgress)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(false),
              tooltip: l10n.common_close,
            ),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress text
            if (state.isOperationInProgress) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Progress label
                        Text(
                          state.totalItems > 0
                              ? l10n.bulkProgress_progress(
                                  state.currentProgress,
                                  state.totalItems,
                                )
                              : l10n.common_loading,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Current item (if available)
                        if (state.currentItem != null)
                          Text(
                            state.currentItem!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // Progress percentage
                  Text(
                    '${state.progressPercentage.toStringAsFixed(0)}%',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: state.totalItems > 0
                      ? state.currentProgress / state.totalItems
                      : null,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Completed status
            if (state.isCompleted && !state.isOperationInProgress) ...[
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getCompletionMessage(state, l10n),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Result statistics
              if (state.lastResult != null) ...[
                _buildResultStats(context, state.lastResult!),
              ],
            ],
            // Error message
            if (state.hasError) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error ?? l10n.common_error,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (state.isOperationInProgress)
          TextButton(
            onPressed: () => _handleCancel(context),
            child: Text(l10n.common_cancel),
          )
        else if (state.hasError || state.isCompleted)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(state.isCompleted),
            child: Text(l10n.common_close),
          ),
      ],
    );
  }

  /// Build result statistics widget
  Widget _buildResultStats(
    BuildContext context,
    BulkOperationResult result,
  ) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Success count
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.bulkProgress_success(result.success),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              // Failed count
              if (result.failed > 0) ...[
                Icon(
                  Icons.error,
                  color: theme.colorScheme.error,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.bulkProgress_failed(result.failed),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
          // Errors list (if any)
          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l10n.bulkProgress_errors,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 4),
            ...result.errors.take(3).map(
                  (error) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 2),
                    child: Text(
                      '• $error',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            if (result.errors.length > 3)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  l10n.bulkProgress_moreErrors(result.errors.length - 3),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Get operation type title
  String _getOperationTitle(
    BulkOperationType? operation,
    AppLocalizations l10n,
  ) {
    switch (operation) {
      case BulkOperationType.delete:
        return l10n.bulkProgress_title_delete;
      case BulkOperationType.export:
        return l10n.bulkProgress_title_export;
      case BulkOperationType.metadataEdit:
        return l10n.bulkProgress_title_metadataEdit;
      case BulkOperationType.addToCollection:
        return l10n.bulkProgress_title_addToCollection;
      case BulkOperationType.removeFromCollection:
        return l10n.bulkProgress_title_removeFromCollection;
      case BulkOperationType.toggleFavorite:
        return l10n.bulkProgress_title_toggleFavorite;
      case null:
        return l10n.bulkProgress_title_default;
    }
  }

  /// Get operation icon
  IconData _getOperationIcon(BulkOperationType? operation) {
    switch (operation) {
      case BulkOperationType.delete:
        return Icons.delete_outline;
      case BulkOperationType.export:
        return Icons.download_outlined;
      case BulkOperationType.metadataEdit:
        return Icons.edit_outlined;
      case BulkOperationType.addToCollection:
        return Icons.playlist_add_check;
      case BulkOperationType.removeFromCollection:
        return Icons.playlist_remove;
      case BulkOperationType.toggleFavorite:
        return Icons.favorite_border;
      case null:
        return Icons.settings_outlined;
    }
  }

  /// Get completion message
  String _getCompletionMessage(
    BulkOperationState state,
    AppLocalizations l10n,
  ) {
    if (state.lastResult != null) {
      final result = state.lastResult!;
      if (result.failed > 0) {
        return l10n.bulkProgress_completedWithErrors(
          result.success,
          result.failed,
        );
      } else {
        return l10n.bulkProgress_completed(result.success);
      }
    }
    return l10n.bulkProgress_completed(0);
  }

  /// Handle cancel operation
  void _handleCancel(BuildContext context) {
    Navigator.of(context).pop(false);
  }
}
