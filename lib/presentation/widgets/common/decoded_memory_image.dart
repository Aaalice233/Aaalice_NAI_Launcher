import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/cache/box_fit_resize_image.dart';

/// 根据布局尺寸限制内存图解码尺寸，避免列表里反复全尺寸解码大图。
class DecodedMemoryImage extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pixelRatio =
            MediaQuery.maybeDevicePixelRatioOf(context) ??
            View.of(context).devicePixelRatio;
        final cacheWidth = resolveCacheDimension(
          logicalSize: maxLogicalWidth,
          constrainedSize: constraints.hasBoundedWidth
              ? constraints.maxWidth
              : null,
          pixelRatio: pixelRatio,
          decodeScale: decodeScale,
        );
        final cacheHeight = resolveCacheDimension(
          logicalSize: maxLogicalHeight,
          constrainedSize: constraints.hasBoundedHeight
              ? constraints.maxHeight
              : null,
          pixelRatio: pixelRatio,
          decodeScale: decodeScale,
        );

        return Image(
          image: BoxFitResizeImage.resizeIfNeeded(
            MemoryImage(bytes),
            fit: fit,
            width: cacheWidth,
            height: cacheHeight,
          ),
          fit: fit,
          alignment: alignment,
          filterQuality: filterQuality,
          gaplessPlayback: gaplessPlayback,
          errorBuilder: errorBuilder,
          frameBuilder: frameBuilder,
        );
      },
    );
  }

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
