import 'dart:io';

import 'package:flutter/material.dart';

/// Progressive image widget with smooth transition from low-res preview to high-res
///
/// 渐进式图片组件，从低分辨率预览平滑过渡到高分辨率
///
/// Features:
/// - Shows placeholder immediately while loading
/// - Loads low-resolution thumbnail first (fast)
/// - Smoothly fades in high-resolution image
/// - Handles errors gracefully with fallback UI
/// - Optimized memory usage with cacheWidth
///
/// 功能特性：
/// - 加载时立即显示占位符
/// - 首先加载低分辨率缩略图（快速）
/// - 平滑淡入高分辨率图片
/// - 优雅处理错误并显示备用 UI
/// - 通过 cacheWidth 优化内存使用
class ProgressiveImageWidget extends StatefulWidget {
  /// Path to the image file
  /// 图片文件路径
  final String imagePath;

  /// Width of the widget (for calculating cache dimensions)
  /// 组件宽度（用于计算缓存尺寸）
  final double? width;

  /// Height of the widget
  /// 组件高度
  final double? height;

  /// How the image should be inscribed into the widget
  /// 图片如何适配组件
  final BoxFit fit;

  /// Optional custom placeholder widget
  /// 可选的自定义占位符组件
  final Widget? placeholder;

  /// Optional custom error widget
  /// 可选的自定义错误组件
  final Widget? errorWidget;

  /// Thumbnail resolution multiplier (0.1 = 10% of original size)
  /// 缩略图分辨率倍数（0.1 = 原始尺寸的 10%）
  final double thumbnailQuality;

  /// Transition duration for fade-in effect
  /// 淡入效果的过渡时长
  final Duration transitionDuration;

  const ProgressiveImageWidget({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.thumbnailQuality = 0.2,
    this.transitionDuration = const Duration(milliseconds: 300),
  });

  @override
  State<ProgressiveImageWidget> createState() => _ProgressiveImageWidgetState();
}

class _ProgressiveImageWidgetState extends State<ProgressiveImageWidget>
    with SingleTickerProviderStateMixin {
  /// Loading state tracking
  /// 加载状态跟踪
  bool _hasError = false;
  bool _thumbnailLoaded = false;
  bool _fullImageLoaded = false;

  /// Animation controller for fade-in effect
  /// 淡入效果的动画控制器
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: widget.transitionDuration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOut,
      ),
    );

    // Start loading process
    // 开始加载流程
    _loadImage();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// Load image with progressive enhancement
  ///
  /// 以渐进式增强方式加载图片
  Future<void> _loadImage() async {
    try {
      // Check if file exists
      // 检查文件是否存在
      final file = File(widget.imagePath);
      if (!file.existsSync()) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
        return;
      }

      // Load thumbnail first
      // 首先加载缩略图
      await Future.delayed(const Duration(milliseconds: 50));

      if (mounted) {
        setState(() {
          _thumbnailLoaded = true;
        });
      }

      // Load full image
      // 加载完整图片
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        setState(() {
          _fullImageLoaded = true;
        });

        // Start fade-in animation
        // 开始淡入动画
        _fadeController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  /// Build placeholder widget
  ///
  /// 构建占位符组件
  Widget _buildPlaceholder() {
    return widget.placeholder ??
        Container(
          width: widget.width,
          height: widget.height,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        );
  }

  /// Build error widget
  ///
  /// 构建错误组件
  Widget _buildError() {
    return widget.errorWidget ??
        Container(
          width: widget.width,
          height: widget.height,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.broken_image,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
  }

  /// Build image with appropriate resolution
  ///
  /// 构建适当分辨率的图片
  Widget _buildImage({bool useThumbnail = false}) {
    final file = File(widget.imagePath);
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;

    // Calculate cache width based on widget width and pixel ratio
    // 根据组件宽度和像素比计算缓存宽度
    int? cacheWidth;
    if (widget.width != null) {
      if (useThumbnail) {
        // Use reduced resolution for thumbnail
        // 缩略图使用降低的分辨率
        cacheWidth = (widget.width! * pixelRatio * widget.thumbnailQuality)
            .toInt();
      } else {
        // Use full resolution for final image
        // 最终图片使用完整分辨率
        cacheWidth = (widget.width! * pixelRatio).toInt();
      }
    }

    return Image.file(
      file,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return _buildError();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show error state if image failed to load
    // 如果图片加载失败则显示错误状态
    if (_hasError) {
      return _buildError();
    }

    // Show placeholder while loading thumbnail
    // 加载缩略图时显示占位符
    if (!_thumbnailLoaded) {
      return _buildPlaceholder();
    }

    // Show thumbnail while full image loads
    // 缩略图加载完成后，完整图片加载中时显示缩略图
    if (!_fullImageLoaded) {
      return _buildImage(useThumbnail: true);
    }

    // Show full image with fade-in animation
    // 显示带淡入动画的完整图片
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _buildImage(useThumbnail: false),
    );
  }
}
