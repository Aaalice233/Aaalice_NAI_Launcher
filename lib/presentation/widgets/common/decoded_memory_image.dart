import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

        final memoryImage = MemoryImage(bytes);
        final ImageProvider<Object> imageProvider;
        if (cacheWidth == null && cacheHeight == null) {
          imageProvider = memoryImage;
        } else {
          imageProvider = ResizeImage(
            memoryImage,
            width: cacheWidth,
            height: cacheHeight,
            policy: ResizeImagePolicy.fit,
          );
        }

        return Image(
          image: imageProvider,
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
        .round()
        .clamp(1, 4096);
    return physicalSize;
  }
}
