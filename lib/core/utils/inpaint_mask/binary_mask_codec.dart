import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'binary_mask.dart';

/// PNG/image codec for the row-major [BinaryMask] protocol.
abstract final class BinaryMaskCodec {
  static const int alphaThreshold = 8;
  static const int colorThreshold = 32;

  static BinaryMask? decode(Uint8List bytes) {
    img.Image? image;
    try {
      image = img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
    if (image == null) return null;
    final pixels = Uint8List(image.width * image.height);
    var index = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        pixels[index++] = isMaskedPixel(image.getPixel(x, y)) ? 1 : 0;
      }
    }
    return BinaryMask(pixels: pixels, width: image.width, height: image.height);
  }

  static Uint8List encode(BinaryMask mask) =>
      Uint8List.fromList(img.encodePng(toOpaqueImage(mask)));

  static img.Image toOpaqueImage(BinaryMask mask) {
    final image = img.Image(
      width: mask.width,
      height: mask.height,
      numChannels: 4,
    );
    var index = 0;
    for (var y = 0; y < mask.height; y++) {
      for (var x = 0; x < mask.width; x++) {
        final value = mask.pixels[index++] == 1 ? 255 : 0;
        image.setPixelRgba(x, y, value, value, value, 255);
      }
    }
    return image;
  }

  static bool isMaskedPixel(img.Pixel pixel) {
    if (pixel.a.toInt() <= alphaThreshold) return false;
    final brightest = [
      pixel.r.toInt(),
      pixel.g.toInt(),
      pixel.b.toInt(),
    ].reduce((a, b) => a > b ? a : b);
    return brightest >= colorThreshold;
  }
}
