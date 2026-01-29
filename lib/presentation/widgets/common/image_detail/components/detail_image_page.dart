import 'package:flutter/material.dart';

import '../image_detail_data.dart';

/// 单张图像页面组件
///
/// 支持缩放、平移和双击缩放功能
class DetailImagePage extends StatefulWidget {
  final ImageDetailData data;
  final String? heroTag;

  const DetailImagePage({
    super.key,
    required this.data,
    this.heroTag,
  });

  @override
  State<DetailImagePage> createState() => _DetailImagePageState();
}

class _DetailImagePageState extends State<DetailImagePage>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformController =
      TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  static const double _minScale = 0.5;
  static const double _maxScale = 4.0;
  static const double _doubleTapScale = 2.5;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animationController.addListener(() {
      if (_animation != null) {
        _transformController.value = _animation!.value;
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformController.dispose();
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
        ..translate(x, y)
        ..scale(_doubleTapScale);
    }

    _animation = Matrix4Tween(
      begin: _transformController.value,
      end: endMatrix,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = Image(
      image: widget.data.getImageProvider(),
      fit: BoxFit.contain,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                '无法加载图片',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );

    if (widget.heroTag != null) {
      imageWidget = Hero(
        tag: widget.heroTag!,
        child: imageWidget,
      );
    }

    return GestureDetector(
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: _minScale,
        maxScale: _maxScale,
        child: Center(child: imageWidget),
      ),
    );
  }
}
