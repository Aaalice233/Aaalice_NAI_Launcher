import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/localization_extension.dart';
import '../../data/models/gallery/local_image_record.dart';

/// 图片对比屏幕
///
/// 支持并排对比2-4张图片，每张图片独立缩放
class ImageComparisonScreen extends ConsumerStatefulWidget {
  /// 图片列表（2-4张）
  final List<LocalImageRecord> images;

  const ImageComparisonScreen({
    super.key,
    required this.images,
  });

  @override
  ConsumerState<ImageComparisonScreen> createState() =>
      _ImageComparisonScreenState();
}

class _ImageComparisonScreenState extends ConsumerState<ImageComparisonScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    // 验证图片数量
    if (widget.images.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported,
                size: 64,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.comparison_noImages,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.images.length > 4) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.comparison_tooManyImages,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.comparison_maxImages,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 根据图片数量决定布局
    final imageCount = widget.images.length;
    final bool isHorizontal = imageCount == 2;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 主内容区 - 根据图片数量使用不同布局
          SafeArea(
            child: isHorizontal
                ? _buildHorizontalLayout(theme, l10n)
                : _buildGridLayout(theme, l10n),
          ),

          // 顶部关闭按钮
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.close,
                  color: theme.colorScheme.onSurface,
                ),
                tooltip: l10n.comparison_close,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // 底部提示
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.comparison_zoomHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建水平布局（2张图片）
  Widget _buildHorizontalLayout(ThemeData theme, dynamic l10n) {
    return Row(
      children: widget.images.asMap().entries.map((entry) {
        final index = entry.key;
        final image = entry.value;
        return Expanded(
          child: _buildImageContainer(
            theme,
            image,
            index,
            widget.images.length,
          ),
        );
      }).toList(),
    );
  }

  /// 构建网格布局（3-4张图片）
  Widget _buildGridLayout(ThemeData theme, dynamic l10n) {
    final imageCount = widget.images.length;
    final int crossAxisCount = imageCount == 3 ? 2 : 2;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: imageCount,
      itemBuilder: (context, index) {
        return _buildImageContainer(
          theme,
          widget.images[index],
          index,
          imageCount,
        );
      },
    );
  }

  /// 构建单个图片容器
  Widget _buildImageContainer(
    ThemeData theme,
    LocalImageRecord image,
    int index,
    int total,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 图片显示区域 - 支持独立缩放
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(
                File(image.path),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            context.l10n.comparison_loadError,
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // 图片编号标签
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                '${index + 1}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
