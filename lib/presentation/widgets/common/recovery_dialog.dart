import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/crash_recovery_service.dart';
import '../../themes/design_tokens.dart';
import 'glass_dialog.dart';

/// 恢复对话框结果
enum RecoveryDialogResult {
  /// 恢复会话
  recover,

  /// 放弃恢复
  discard,
}

/// 崩溃恢复对话框
///
/// 在应用启动时检测到可恢复的会话状态时显示，
/// 允许用户选择恢复上次会话或放弃恢复
class RecoveryDialog extends ConsumerWidget {
  /// 崩溃分析结果
  final CrashAnalysisResult analysisResult;

  const RecoveryDialog({
    super.key,
    required this.analysisResult,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recoveryPoint = analysisResult.recoveryPoint;
    final sessionState = recoveryPoint?.sessionState;

    // 格式化时间
    String? formattedTime;
    if (recoveryPoint != null) {
      final now = DateTime.now();
      final diff = now.difference(recoveryPoint.timestamp);
      if (diff.inMinutes < 1) {
        formattedTime = '刚刚';
      } else if (diff.inHours < 1) {
        formattedTime = '${diff.inMinutes} 分钟前';
      } else if (diff.inDays < 1) {
        formattedTime = '${diff.inHours} 小时前';
      } else {
        formattedTime = '${diff.inDays} 天前';
      }
    }

    // 任务进度信息
    final hasQueueTasks = sessionState?.hasActiveQueueExecution ?? false;
    final currentIndex = sessionState?.currentQueueIndex ?? 0;
    final totalTasks = sessionState?.totalQueueTasks ?? 0;
    final remainingTasks = totalTasks - currentIndex;

    return GlassDialog(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题区域
          Row(
            children: [
              Icon(
                Icons.restore_page_outlined,
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: DesignTokens.spacingSm),
              Text(
                '恢复会话',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingMd),

          // 说明文本
          Text(
            analysisResult.reason ?? '检测到上次会话异常退出',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: DesignTokens.spacingMd),

          // 恢复点信息卡片
          Container(
            padding: const EdgeInsets.all(DesignTokens.spacingMd),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: DesignTokens.borderRadiusMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 时间信息
                if (formattedTime != null)
                  _buildInfoRow(
                    context,
                    icon: Icons.access_time,
                    label: '最后活跃',
                    value: formattedTime,
                  ),

                // 队列任务信息
                if (hasQueueTasks && totalTasks > 0) ...[
                  const SizedBox(height: DesignTokens.spacingSm),
                  _buildInfoRow(
                    context,
                    icon: Icons.queue_outlined,
                    label: '队列进度',
                    value: '$currentIndex / $totalTasks 已完成',
                  ),
                  const SizedBox(height: DesignTokens.spacingSm),
                  _buildInfoRow(
                    context,
                    icon: Icons.pending_actions_outlined,
                    label: '待处理任务',
                    value: '$remainingTasks 个',
                  ),
                ],

                // 建议操作
                if (analysisResult.suggestedAction != null) ...[
                  const SizedBox(height: DesignTokens.spacingSm),
                  _buildInfoRow(
                    context,
                    icon: Icons.lightbulb_outline,
                    label: '建议操作',
                    value: _getSuggestedActionText(analysisResult.suggestedAction!),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.spacingLg),

          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 放弃按钮
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(RecoveryDialogResult.discard);
                },
                child: const Text('放弃恢复'),
              ),
              const SizedBox(width: DesignTokens.spacingSm),

              // 恢复按钮
              FilledButton.icon(
                onPressed: analysisResult.canRecover
                    ? () {
                        Navigator.of(context).pop(RecoveryDialogResult.recover);
                      }
                    : null,
                icon: const Icon(Icons.restore, size: 18),
                label: const Text('恢复会话'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: DesignTokens.spacingXs),
        Text(
          '$label：',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 获取建议操作文本
  String _getSuggestedActionText(CrashRecoveryAction action) {
    switch (action) {
      case CrashRecoveryAction.restoreSession:
        return '恢复上次会话状态';
      case CrashRecoveryAction.resumeQueue:
        return '继续未完成的队列任务';
      case CrashRecoveryAction.resetState:
        return '重置状态并重新开始';
    }
  }

  /// 显示恢复对话框
  ///
  /// 返回 [RecoveryDialogResult.recover] 表示用户选择恢复，
  /// [RecoveryDialogResult.discard] 表示用户选择放弃
  static Future<RecoveryDialogResult?> show({
    required BuildContext context,
    required CrashAnalysisResult analysisResult,
  }) {
    return showDialog<RecoveryDialogResult>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => RecoveryDialog(analysisResult: analysisResult),
    );
  }
}
