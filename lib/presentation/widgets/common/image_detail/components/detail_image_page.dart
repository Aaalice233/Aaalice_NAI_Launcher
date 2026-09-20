import 'package:flutter/material.dart';

import '../../image_viewport_surface.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../image_detail_data.dart';

/// 单张图像页面组件
///
/// 支持缩放、平移和双击缩放功能
/// 包含加载状态指示器和渐进式加载优化
class DetailImagePage extends StatefulWidget {
  final ImageDetailData data;
  final String? heroTag;

  /// 外部传入的 TransformationController，用于快捷键控制缩放
  final TransformationController? transformationController;

  const DetailImagePage({
    super.key,
    required this.data,
    this.heroTag,
    this.transformationController,
  });

  @override
  State<DetailImagePage> createState() => _DetailImagePageState();
}

class _DetailImagePageState extends State<DetailImagePage>
    with SingleTickerProviderStateMixin {
  TransformationController get _transformController =>
      widget.transformationController ?? _internalTransformController;
  late TransformationController _internalTransformController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  Matrix4? _animationEnd;
  bool _disableAnimations = false;
  TapDownDetails? _doubleTapDetails;

  /// 加载状态
  bool _isLoading = true;

  /// 原图解码期间的低清占位图。
  ///
  /// 【偏离上游】上游只在 [_buildLoadingIndicator] 里显示一个转圈，
  /// 全尺寸 PNG 在移动端解码要好几百毫秒，期间整屏是纯色。
  ImageProvider? _placeholder;

  static const double _minScale = 0.5;
  static const double _maxScale = 4.0;
  static const double _doubleTapScale = 2.5;

  @override
  void initState() {
    super.initState();
    _internalTransformController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animationController.addListener(() {
      if (_animation != null) {
        _transformController.value = _animation!.value;
      }
    });
    // 占位是纯优化：原图已经解码完（_isLoading == false）就不再插入占位，
    // 失败也只是回退到上游原本的转圈。
    widget.data.getPlaceholderProvider().then((provider) {
      if (!mounted || provider == null || !_isLoading) return;
      setState(() => _placeholder = provider);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_disableAnimations == disableAnimations) return;
    _disableAnimations = disableAnimations;
    if (disableAnimations && _animationController.isAnimating) {
      _animationController.stop();
      final endMatrix = _animationEnd;
      if (endMatrix != null) _transformController.value = endMatrix;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _internalTransformController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition;
    if (position == null) return;

    final currentScale = _transformController.value.getMaxScaleOnAxis();

    Matrix4 endMatrix;
    if (currentScale > 1.0) {
      endMatrix = Matrix4.identity();
    } else {
      final x = -position.dx * (_doubleTapScale - 1);
      final y = -position.dy * (_doubleTapScale - 1);
      endMatrix = Matrix4.identity()
        ..translateByDouble(x, y, 0, 1)
        ..scaleByDouble(_doubleTapScale, _doubleTapScale, _doubleTapScale, 1);
    }

    _animationEnd = endMatrix;
    if (_disableAnimations) {
      _animationController.stop();
      _animation = null;
      _transformController.value = endMatrix;
      return;
    }

    _animation = Matrix4Tween(begin: _transformController.value, end: endMatrix)
        .animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward(from: 0);
  }

  /// 构建加载指示器
  Widget _buildLoadingIndicator(BuildContext context) {
    return Container(
      color: ImageViewportSurface.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: MediaQuery.disableAnimationsOf(context) ? 0.72 : null,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.detail_loadingImage,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建低清占位层（占位铺满 + 右下角小转圈）
  Widget _buildPlaceholderLayer(BuildContext context, ImageProvider provider) {
    return Container(
      color: ImageViewportSurface.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Image(
              image: provider,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              // 占位解码失败不能连带炸掉整屏，静默留纯色背景。
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: MediaQuery.disableAnimationsOf(context) ? 0.72 : null,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 标记加载完成
  void _markLoadingComplete() {
    if (_isLoading && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = Image(
      image: widget.data.getImageProvider(),
      fit: BoxFit.contain,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        // 同步加载完成（缓存命中）
        if (wasSynchronouslyLoaded) {
          _markLoadingComplete();
          return child;
        }

        // 异步加载完成
        if (frame != null) {
          _markLoadingComplete();
        }

        // 渐进式淡入动画
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        // 加载失败也要隐藏加载指示器
        _markLoadingComplete();
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                context.l10n.detail_imageLoadFailed,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );

    if (widget.heroTag != null) {
      imageWidget = Hero(tag: widget.heroTag!, child: imageWidget);
    }

    return Stack(
      children: [
        // 主图像区域
        GestureDetector(
          onDoubleTapDown: _handleDoubleTapDown,
          onDoubleTap: _handleDoubleTap,
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: _minScale,
            maxScale: _maxScale,
            child: Center(child: imageWidget),
          ),
        ),

        // 加载指示器：拿到低清占位图时先铺占位 + 角落小转圈，
        // 否则退回上游的全屏加载指示。
        if (_isLoading)
          Positioned.fill(
            child: _placeholder != null
                ? _buildPlaceholderLayer(context, _placeholder!)
                : _buildLoadingIndicator(context),
          ),
      ],
    );
  }
}
