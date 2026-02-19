import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../data/models/gallery/local_image_record.dart';

/// 图片发送目标类型
enum SendDestination {
  /// 发送到图生图
  img2img,

  /// 发送到Vibe Transfer
  vibeTransfer,
}

/// 图片发送目标选择对话框
///
/// 用于选择将图片发送到何处：
/// - 图生图 (img2img)
/// - Vibe Transfer
class ImageSendDestinationDialog extends StatelessWidget {
  /// 创建发送目标选择对话框
  const ImageSendDestinationDialog({
    super.key,
    required this.record,
  });

  /// 图片记录
  final LocalImageRecord record;

  /// 显示对话框并返回用户选择
  ///
  /// 返回 [SendDestination] 或 null（用户取消）
  static Future<SendDestination?> show(
    BuildContext context,
    LocalImageRecord record,
  ) async {
    return showDialog<SendDestination>(
      context: context,
      builder: (context) => ImageSendDestinationDialog(record: record),
    );
  }

  /// 检查图片是否有 vibe 数据
  bool get hasVibeData => record.vibeData != null || record.hasVibeMetadata;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.gallery_send_to),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 发送到图生图
            _buildOption(
              context,
              icon: Icons.image,
              title: '图生图',
              subtitle: '使用此图片进行图像生成',
              onTap: () => Navigator.of(context).pop(SendDestination.img2img),
            ),
            const SizedBox(height: 8),
            // 发送到 Vibe Transfer
            _buildOption(
              context,
              icon: Icons.style,
              title: 'Vibe Transfer',
              subtitle: hasVibeData ? '提取并应用图片的风格/角色' : '此图片不包含 Vibe 数据',
              enabled: hasVibeData,
              onTap: hasVibeData
                  ? () =>
                      Navigator.of(context).pop(SendDestination.vibeTransfer)
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: enabled
          ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.3)
          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: enabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.38),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: enabled
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withOpacity(0.38),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: enabled
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface.withOpacity(0.38),
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                )
              else
                Icon(
                  Icons.block,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.38),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
