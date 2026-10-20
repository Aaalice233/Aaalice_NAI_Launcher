import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/cache/box_fit_resize_image.dart';

/// 根据布局尺寸限制内存图解码尺寸，避免列表里反复全尺寸解码大图。
class DecodedMemoryImage extends StatefulWidget {
  const DecodedMemoryImage({
    super.key,
    required this.bytes,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.gaplessPlayback = true,
    this.maxLogicalWidth,
    this.maxLogicalHeight,
    this.decodeScale = 1.0,
    this.errorBuilder,
    this.frameBuilder,
    this.evictOnDispose = false,
  });

  final Uint8List bytes;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final bool gaplessPlayback;
  final double? maxLogicalWidth;
  final double? maxLogicalHeight;
  final double decodeScale;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageFrameBuilder? frameBuilder;

  /// 卸载时驱逐本组件用过的缓存项：缓存键强引用原图字节，且预算只计解码尺寸，
  /// 每次读取新字节的临时预览不驱逐会让关闭后的原图常驻到被 LRU 挤出。
  final bool evictOnDispose;

  @override
  State<DecodedMemoryImage> createState() => _DecodedMemoryImageState();

  static int? resolveCacheDimension({
    required double? logicalSize,
    required double? constrainedSize,
    required double pixelRatio,
    double decodeScale = 1.0,
  }) {
    final effectiveLogicalSize = logicalSize ?? constrainedSize;
    if (effectiveLogicalSize == null || !effectiveLogicalSize.isFinite) {
      return null;
    }

    final physicalSize = (effectiveLogicalSize * pixelRatio * decodeScale)
        .ceil()
        .clamp(1, BoxFitResizeImage.maximumDecodedDimension);
    return _roundUpToSizeClass(physicalSize);
  }

  static const int _sizeClassBitsPerOctave = 2;

  // 每个二倍区间分 4 档向上取整：最多多解码 25%，换来窗口缩放时只在跨档处换缓存键
  static int _roundUpToSizeClass(int size) {
    final stepBits = size.bitLength - 1 - _sizeClassBitsPerOctave;
    if (stepBits <= 0) return size;
    final step = 1 << stepBits;
    return (size + step - 1) ~/ step * step;
  }
}

class _DecodedMemoryImageState extends State<DecodedMemoryImage> {
  final Set<ImageProvider<Object>> _usedProviders = {};

  @override
  void dispose() {
    if (widget.evictOnDispose) _evictUsedProviders();
    super.dispose();
  }

  // 子树先于本组件卸载，Image 已摘掉监听；includeLive: false 避免打断同键的其他显示
  void _evictUsedProviders() {
    final imageCache = PaintingBinding.instance.imageCache;
    for (final provider in _usedProviders) {
      provider
          .obtainKey(ImageConfiguration.empty)
          .then((key) => imageCache.evict(key, includeLive: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pixelRatio =
            MediaQuery.maybeDevicePixelRatioOf(context) ??
            View.of(context).devicePixelRatio;
        final cacheWidth = DecodedMemoryImage.resolveCacheDimension(
          logicalSize: widget.maxLogicalWidth,
          constrainedSize: constraints.hasBoundedWidth
              ? constraints.maxWidth
              : null,
          pixelRatio: pixelRatio,
          decodeScale: widget.decodeScale,
        );
        final cacheHeight = DecodedMemoryImage.resolveCacheDimension(
          logicalSize: widget.maxLogicalHeight,
          constrainedSize: constraints.hasBoundedHeight
              ? constraints.maxHeight
              : null,
          pixelRatio: pixelRatio,
          decodeScale: widget.decodeScale,
        );
        final provider = BoxFitResizeImage.resizeIfNeeded(
          MemoryImage(widget.bytes),
          fit: widget.fit,
          width: cacheWidth,
          height: cacheHeight,
        );
        if (widget.evictOnDispose) _usedProviders.add(provider);

        return Image(
          image: provider,
          fit: widget.fit,
          alignment: widget.alignment,
          filterQuality: widget.filterQuality,
          gaplessPlayback: widget.gaplessPlayback,
          errorBuilder: widget.errorBuilder,
          frameBuilder: widget.frameBuilder,
        );
      },
    );
  }
}
