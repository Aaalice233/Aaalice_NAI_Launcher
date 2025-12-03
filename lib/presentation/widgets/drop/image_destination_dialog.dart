import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';

/// 图片目标类型
enum ImageDestination {
  /// 图生图
  img2img,

  /// Vibe Transfer
  vibeTransfer,

  /// 角色参考
  characterReference,
}

/// 图片目标选择对话框
///
/// 当用户拖拽图片到界面时弹出，让用户选择图片的用途
class ImageDestinationDialog extends StatelessWidget {
  /// 图片数据
  final Uint8List imageBytes;

  /// 文件名
  final String fileName;

  const ImageDestinationDialog({
    super.key,
    required this.imageBytes,
    required this.fileName,
  });

  /// 显示对话框
  static Future<ImageDestination?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    required String fileName,
  }) {
    return showDialog<ImageDestination>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => ImageDestinationDialog(
        imageBytes: imageBytes,
        fileName: fileName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
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
                    onTap: () =>
                        Navigator.of(context).pop(ImageDestination.vibeTransfer),
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
  final VoidCallback onTap;

  const _DestinationButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
