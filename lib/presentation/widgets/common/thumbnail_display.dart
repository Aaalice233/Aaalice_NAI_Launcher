import 'dart:io';

import 'package:flutter/material.dart';

import 'package:image/image.dart' as img;

import 'image_viewport_surface.dart';

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
  int _imageSizeRequestId = 0;

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

  Future<void> _loadImageSize() async {
    final requestId = ++_imageSizeRequestId;
    final imageSize = await _readImageSize(widget.imagePath);

    if (!mounted || requestId != _imageSizeRequestId) return;
    setState(() => _imageSize = imageSize);
  }

  Future<Size?> _readImageSize(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) return null;

    try {
      final bytes = await file.readAsBytes();
      final decoder = img.findDecoderForData(bytes);
      final info = decoder?.startDecode(bytes);
      if (info == null) return null;
      return Size(info.width.toDouble(), info.height.toDouble());
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _imageSizeRequestId++;
    super.dispose();
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
    final containerAspectRatio = containerWidth / containerHeight;

    // 按当前显示区域的实际比例铺满，避免组件用于非 200x80
    // 区域时出现未被图像覆盖的边带。
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
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

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
              cacheWidth: _decodeCacheExtent(virtualWidth, devicePixelRatio),
              cacheHeight: _decodeCacheExtent(virtualHeight, devicePixelRatio),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildError(),
            ),
          ),
        ),
      ),
    );

    image = ImageViewportSurface(child: image);

    if (widget.borderRadius != null) {
      image = ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }

    return image;
  }

  Widget _buildSimpleImage() {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    Widget image = ClipRect(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Image.file(
          File(widget.imagePath),
          cacheWidth: _decodeCacheExtent(widget.width, devicePixelRatio),
          cacheHeight: _decodeCacheExtent(widget.height, devicePixelRatio),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildError(),
        ),
      ),
    );

    image = ImageViewportSurface(child: image);

    if (widget.borderRadius != null) {
      image = ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }

    return image;
  }

  Widget _buildError() => Container(
    width: widget.width,
    height: widget.height,
    color: ImageViewportSurface.background,
    child: const Icon(Icons.broken_image_outlined, color: Colors.white38),
  );

  static int? _decodeCacheExtent(
    double logicalExtent,
    double devicePixelRatio,
  ) {
    if (!logicalExtent.isFinite ||
        !devicePixelRatio.isFinite ||
        logicalExtent <= 0 ||
        devicePixelRatio <= 0) {
      return null;
    }

    return (logicalExtent * devicePixelRatio).ceil().clamp(1, 1 << 30);
  }
}
