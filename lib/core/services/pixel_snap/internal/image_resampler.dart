import 'dart:typed_data';

/// 最近邻降采样 RGB 平面。
Uint8List downscaleRgb(
  Uint8List source,
  int sourceWidth,
  int sourceHeight,
  int targetWidth,
  int targetHeight,
) {
  final Uint8List out = Uint8List(targetWidth * targetHeight * 3);
  for (int y = 0; y < targetHeight; y++) {
    final int sy = _map(y, sourceHeight, targetHeight);
    for (int x = 0; x < targetWidth; x++) {
      final int sx = _map(x, sourceWidth, targetWidth);
      final int src = (sy * sourceWidth + sx) * 3;
      final int dst = (y * targetWidth + x) * 3;
      out[dst] = source[src];
      out[dst + 1] = source[src + 1];
      out[dst + 2] = source[src + 2];
    }
  }
  return out;
}

/// 最近邻降采样 alpha 平面。
Uint8List downscaleAlpha(
  Uint8List source,
  int sourceWidth,
  int sourceHeight,
  int targetWidth,
  int targetHeight,
) {
  final Uint8List out = Uint8List(targetWidth * targetHeight);
  for (int y = 0; y < targetHeight; y++) {
    final int sy = _map(y, sourceHeight, targetHeight);
    for (int x = 0; x < targetWidth; x++) {
      out[y * targetWidth + x] =
          source[sy * sourceWidth + _map(x, sourceWidth, targetWidth)];
    }
  }
  return out;
}

int _map(int index, int sourceSize, int targetSize) {
  final int mapped = (index * sourceSize / targetSize).truncate();
  return mapped < sourceSize - 1 ? mapped : sourceSize - 1;
}

/// 整数倍最近邻放大 RGBA。
///
/// 像素画放大只能用最近邻，任何插值都会把刚 snap 出来的硬边缘重新糊掉。
Uint8List upscaleRgbaNearest(
  Uint8List rgba,
  int width,
  int height,
  int factor,
) {
  if (factor <= 1) return rgba;
  final int outWidth = width * factor;
  final int outHeight = height * factor;
  final Uint8List out = Uint8List(outWidth * outHeight * 4);
  for (int y = 0; y < outHeight; y++) {
    final int sy = y ~/ factor;
    final int rowBase = y * outWidth * 4;
    for (int x = 0; x < outWidth; x++) {
      final int src = (sy * width + x ~/ factor) * 4;
      final int dst = rowBase + x * 4;
      out[dst] = rgba[src];
      out[dst + 1] = rgba[src + 1];
      out[dst + 2] = rgba[src + 2];
      out[dst + 3] = rgba[src + 3];
    }
  }
  return out;
}
