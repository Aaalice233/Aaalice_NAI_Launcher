import 'package:image/image.dart' as img;

// package:image 的像素 getter 只在多通道下可靠：单通道 g/b 恒为 0，灰度+透明合成时
// 忽略 alpha，除 8 位与 float32 外缺 alpha 时读出 0（全透明）
abstract final class ColorChannelNormalizer {
  static img.Image normalize(img.Image image) {
    if (image.hasPalette) return image;
    final channels = image.numChannels;
    if (channels == 1 && _isSubByte(image.format)) {
      return _expandSubByteGray(image);
    }
    if (_readsOpaqueWithoutAlpha(image.format)) {
      return switch (channels) {
        1 => image.convert(numChannels: 3),
        2 => image.convert(numChannels: 4),
        _ => image,
      };
    }
    // 补 alpha 而不降位深：DLSS 以浮点传输源图，16 位精度要保留到 GPU
    return channels < 4 ? image.convert(numChannels: 4) : image;
  }

  static bool _readsOpaqueWithoutAlpha(img.Format format) =>
      format == img.Format.uint8 || format == img.Format.float32;

  static bool _isSubByte(img.Format format) =>
      format == img.Format.uint1 ||
      format == img.Format.uint2 ||
      format == img.Format.uint4;

  // package:image 把 2 位灰度满值换算成 225，低位深按满量程自行映射到 0..255
  static img.Image _expandSubByteGray(img.Image image) {
    final maxValue = image.maxChannelValue.toInt();
    final levels = List<int>.generate(
      maxValue + 1,
      (value) => (value * 255 / maxValue).round(),
      growable: false,
    );
    final rgb = image.convert(format: img.Format.uint8, numChannels: 3);
    for (var index = 0; index < image.numFrames; index++) {
      final source = image.frames[index];
      img.Pixel? sourcePixel;
      for (final pixel in rgb.frames[index]) {
        sourcePixel = source.getPixel(pixel.x, pixel.y, sourcePixel);
        final level = levels[sourcePixel.r.toInt()];
        pixel
          ..r = level
          ..g = level
          ..b = level;
      }
    }
    return rgb;
  }
}
