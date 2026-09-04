import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../decoded_memory_image.dart';

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
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheSize = DecodedMemoryImage.resolveCacheDimension(
      logicalSize: size,
      constrainedSize: null,
      pixelRatio: pixelRatio,
    );

    // 优先使用字节数据
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.memory(
          imageBytes!,
          width: size,
          height: size,
          cacheWidth: cacheSize,
          cacheHeight: cacheSize,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallback(theme),
        ),
      );
    }

    // 其次使用文件路径 - 异步检查避免阻塞UI
    if (imagePath != null && imagePath!.isNotEmpty) {
      return FutureBuilder<bool>(
        future: File(imagePath!).exists(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // 加载中显示占位符
            return _buildLoadingPlaceholder(context, theme);
          }

          if (snapshot.data == true) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.file(
                File(imagePath!),
                width: size,
                height: size,
                cacheWidth: cacheSize,
                cacheHeight: cacheSize,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildFallback(theme),
              ),
            );
          }

          return _buildFallback(theme);
        },
      );
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

  /// 构建加载中的占位符
  Widget _buildLoadingPlaceholder(BuildContext context, ThemeData theme) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: SizedBox.square(
          dimension: size * 0.3,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            value: MediaQuery.disableAnimationsOf(context) ? 0.72 : null,
          ),
        ),
      ),
    );
  }
}
