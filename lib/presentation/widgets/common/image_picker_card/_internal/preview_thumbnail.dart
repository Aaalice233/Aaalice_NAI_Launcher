import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 缩略图预览组件
///
/// 支持从 Uint8List 或文件路径显示图像
class PreviewThumbnail extends StatelessWidget {
  /// 图像字节数据
  final Uint8List? imageBytes;

  /// 图像文件路径
  final String? imagePath;

  /// 备用图标
  final IconData fallbackIcon;

  /// 尺寸
  final double size;

  /// 圆角半径
  final double borderRadius;

  const PreviewThumbnail({
    super.key,
    this.imageBytes,
    this.imagePath,
    this.fallbackIcon = Icons.image_outlined,
    this.size = 48,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 优先使用字节数据
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.memory(
          imageBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallback(theme),
        ),
      );
    }

    // 其次使用文件路径
    if (imagePath != null && imagePath!.isNotEmpty) {
      final file = File(imagePath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallback(theme),
          ),
        );
      }
    }

    // 默认显示图标
    return _buildFallback(theme);
  }

  Widget _buildFallback(ThemeData theme) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        fallbackIcon,
        size: size * 0.5,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
