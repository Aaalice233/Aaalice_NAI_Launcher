import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../widgets/common/themed_divider.dart';

/// 图片目标类型
enum ImageDestination {
  /// 图生图
  img2img,

  /// Vibe Transfer
  vibeTransfer,

  /// 角色参考
  characterReference,

  /// 提取元数据并应用到生成参数
  extractMetadata,

  /// 提取提示词加入队列
  addToQueue,
}

/// 图片目标选择对话框
///
/// 当用户拖拽图片到界面时弹出，让用户选择图片的用途
class ImageDestinationDialog extends ConsumerWidget {
  /// 图片数据
  final Uint8List imageBytes;

  /// 文件名
  final String fileName;

  /// 是否显示提取元数据选项
  final bool showExtractMetadata;

  const ImageDestinationDialog({
    super.key,
    required this.imageBytes,
    required this.fileName,
    this.showExtractMetadata = true,
  });

  /// 显示对话框
  static Future<ImageDestination?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    required String fileName,
    bool showExtractMetadata = true,
  }) {
    return showDialog<ImageDestination>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => ImageDestinationDialog(
        imageBytes: imageBytes,
        fileName: fileName,
        showExtractMetadata: showExtractMetadata,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // 判断悬浮球是否可见（队列有任务或正在执行）
    final queueState = ref.watch(replicationQueueNotifierProvider);
    final queueExecutionState = ref.watch(queueExecutionNotifierProvider);
    final shouldShowAddToQueue = !(queueState.isEmpty &&
        queueState.failedTasks.isEmpty &&
        queueExecutionState.isIdle &&
        !queueExecutionState.hasFailedTasks);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.drop_dialogTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: context.l10n.common_close,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 图片预览
              Center(
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 200,
                    maxHeight: 200,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      imageBytes,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 200,
                          height: 200,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 64,
                            color: theme.colorScheme.outline,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 选项按钮（垂直排列）
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 提取元数据选项（置顶，用主题色高亮）
                  if (showExtractMetadata) ...[
                    _DestinationButton(
                      icon: Icons.data_object,
                      label: '提取元数据并应用',
                      subtitle: '读取图片中的 Prompt、Seed 等参数',
                      isPrimary: true,
                      onTap: () => Navigator.of(context)
                          .pop(ImageDestination.extractMetadata),
                    ),
                    const SizedBox(height: 12),
                    // 加入队列选项（仅在悬浮球可见且是PNG时显示）
                    if (shouldShowAddToQueue)
                      Tooltip(
                        message: '提取正面提示词加入队列',
                        child: _DestinationButton(
                          icon: Icons.playlist_add,
                          label: '加入队列',
                          subtitle: '提取正面提示词并加入生成队列',
                          onTap: () => Navigator.of(context)
                              .pop(ImageDestination.addToQueue),
                        ),
                      ),
                    if (shouldShowAddToQueue) const SizedBox(height: 16),
                    if (!shouldShowAddToQueue) const SizedBox(height: 4),
                    const ThemedDivider(height: 1),
                    const SizedBox(height: 16),
                  ],
                  _DestinationButton(
                    icon: Icons.image_outlined,
                    label: context.l10n.drop_img2img,
                    onTap: () =>
                        Navigator.of(context).pop(ImageDestination.img2img),
                  ),
                  const SizedBox(height: 12),
                  _DestinationButton(
                    icon: Icons.auto_awesome,
                    label: context.l10n.drop_vibeTransfer,
                    onTap: () => Navigator.of(context)
                        .pop(ImageDestination.vibeTransfer),
                  ),
                  const SizedBox(height: 12),
                  _DestinationButton(
                    icon: Icons.person_outline,
                    label: context.l10n.drop_characterReference,
                    onTap: () => Navigator.of(context)
                        .pop(ImageDestination.characterReference),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 目标选项按钮
class _DestinationButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isPrimary;

  const _DestinationButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isPrimary
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: isPrimary
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: isPrimary
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                        fontWeight: isPrimary ? FontWeight.bold : null,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isPrimary
                              ? theme.colorScheme.onPrimaryContainer
                                  .withOpacity(0.7)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: isPrimary
                    ? theme.colorScheme.onPrimaryContainer.withOpacity(0.5)
                    : theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
