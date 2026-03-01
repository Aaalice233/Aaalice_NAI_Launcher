import 'dart:io';

import 'package:flutter/material.dart';

/// 缩略图显示组件
///
/// 使用与裁剪对话框完全相同的坐标系统和计算逻辑。
/// - offsetX/Y: -1.0 到 1.0，表示选中区域在图像中的位置
/// - scale: 1.0 到 3.0，表示放大倍数
class ThumbnailDisplay extends StatefulWidget {
  final String imagePath;
  final double offsetX;
  final double offsetY;
  final double scale;

  /// 显示区域的宽度
  final double width;

  /// 显示区域的高度
  final double height;

  final BorderRadius? borderRadius;

  const ThumbnailDisplay({
    super.key,
    required this.imagePath,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.scale = 1.0,
    this.width = 200,
    this.height = 80,
    this.borderRadius,
  });

  @override
  State<ThumbnailDisplay> createState() => _ThumbnailDisplayState();
}

class _ThumbnailDisplayState extends State<ThumbnailDisplay> {
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  void didUpdateWidget(ThumbnailDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _loadImageSize();
    }
  }

  void _loadImageSize() {
    final file = File(widget.imagePath);
    if (!file.existsSync()) {
      setState(() => _imageSize = null);
      return;
    }

    final imageProvider = FileImage(file);
    imageProvider.resolve(const ImageConfiguration()).addListener(
          ImageStreamListener(
            (ImageInfo info, bool synchronousCall) {
              if (mounted) {
                setState(() {
                  _imageSize = Size(
                    info.image.width.toDouble(),
                    info.image.height.toDouble(),
                  );
                });
              }
            },
            onError: (exception, stackTrace) {
              if (mounted) {
                setState(() => _imageSize = null);
              }
            },
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    // 在图像尺寸加载前，使用简单的 BoxFit.cover 显示
    if (_imageSize == null) {
      return _buildSimpleImage();
    }

    final ox = widget.offsetX.clamp(-1.0, 1.0);
    final oy = widget.offsetY.clamp(-1.0, 1.0);
    final s = widget.scale.clamp(1.0, 3.0);

    // 容器尺寸
    final containerWidth = widget.width;
    final containerHeight = widget.height;
    const containerAspectRatio = 2.5; // 与 EntryCard 一致

    // 计算图像相对于容器的缩放（模拟 BoxFit.cover 或类似效果）
    final imageAspectRatio = _imageSize!.width / _imageSize!.height;

    // 使用与裁剪对话框相同的逻辑计算"虚拟图像"尺寸
    // 虚拟图像 = 在容器比例下显示的图像尺寸
    double virtualWidth, virtualHeight;

    if (imageAspectRatio > containerAspectRatio) {
      // 图像更宽，高度填满，宽度超出
      virtualHeight = containerHeight * s;
      virtualWidth = virtualHeight * imageAspectRatio;
    } else {
      // 图像更高，宽度填满，高度超出
      virtualWidth = containerWidth * s;
      virtualHeight = virtualWidth / imageAspectRatio;
    }

    // 计算裁剪区域尺寸（与裁剪对话框中的裁剪框对应）
    // 裁剪区域 = 容器尺寸（在虚拟图像上）
    final cropWidth = containerWidth;
    final cropHeight = containerHeight;

    // 计算可移动范围
    final maxOffsetX = (virtualWidth - cropWidth) / 2;
    final maxOffsetY = (virtualHeight - cropHeight) / 2;

    // 计算平移量
    final shiftX = ox * maxOffsetX;
    final shiftY = oy * maxOffsetY;

    Widget image = ClipRect(
      child: SizedBox(
        width: containerWidth,
        height: containerHeight,
        child: OverflowBox(
          alignment: Alignment.center,
          minWidth: virtualWidth,
          maxWidth: virtualWidth,
          minHeight: virtualHeight,
          maxHeight: virtualHeight,
          child: Transform.translate(
            offset: Offset(-shiftX, -shiftY),
            child: Image.file(
              File(widget.imagePath),
              width: virtualWidth,
              height: virtualHeight,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildError(),
            ),
          ),
        ),
      ),
    );

    if (widget.borderRadius != null) {
      image = ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }

    return image;
  }

  Widget _buildSimpleImage() {
    Widget image = ClipRect(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Image.file(
          File(widget.imagePath),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildError(),
        ),
      ),
    );

    if (widget.borderRadius != null) {
      image = ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }

    return image;
  }

  Widget _buildError() => Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey.shade800,
        child: const Icon(Icons.broken_image_outlined, color: Colors.white38),
      );
}
