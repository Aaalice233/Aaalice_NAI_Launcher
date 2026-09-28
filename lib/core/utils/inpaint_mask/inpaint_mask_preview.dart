import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../isolate_pool.dart';

/// Renders a mask over its source so a caller can visually verify placement.
abstract final class InpaintMaskPreview {
  static const int defaultMaxDimension = 768;
  static const int defaultOverlayAlpha = 140;

  // 与编辑器蒙版同色，避免同一张蒙版在两处看起来是两回事。
  static const int _overlayRed = 96;
  static const int _overlayGreen = 170;
  static const int _overlayBlue = 255;

  static Uint8List? render({
    required Uint8List sourceImage,
    required Uint8List maskBinary,
    required int width,
    required int height,
    int maxDimension = defaultMaxDimension,
    int overlayAlpha = defaultOverlayAlpha,
  }) {
    if (maskBinary.length != width * height || maxDimension <= 0) return null;

    final img.Image? decoded;
    try {
      decoded = img.decodeImage(sourceImage);
    } catch (_) {
      return null;
    }
    if (decoded == null || decoded.width != width || decoded.height != height) {
      return null;
    }

    final composed = decoded.convert(format: img.Format.uint8, numChannels: 3);
    final alpha = overlayAlpha.clamp(0, 255) / 255;
    final inverse = 1 - alpha;
    var index = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (maskBinary[index++] == 1) {
          final pixel = composed.getPixel(x, y);
          composed.setPixelRgb(
            x,
            y,
            (pixel.r * inverse + _overlayRed * alpha).round(),
            (pixel.g * inverse + _overlayGreen * alpha).round(),
            (pixel.b * inverse + _overlayBlue * alpha).round(),
          );
        }
      }
    }

    final longest = width > height ? width : height;
    final scaled = longest <= maxDimension
        ? composed
        : img.copyResize(
            composed,
            width: (width * maxDimension / longest).round().clamp(1, width),
            height: (height * maxDimension / longest).round().clamp(1, height),
            interpolation: img.Interpolation.average,
          );
    return Uint8List.fromList(img.encodeJpg(scaled, quality: 85));
  }

  static Future<Uint8List?> renderAsync({
    required Uint8List sourceImage,
    required Uint8List maskBinary,
    required int width,
    required int height,
    int maxDimension = defaultMaxDimension,
    int overlayAlpha = defaultOverlayAlpha,
  }) => ComputeGate().runIsolate(
    () => render(
      sourceImage: sourceImage,
      maskBinary: maskBinary,
      width: width,
      height: height,
      maxDimension: maxDimension,
      overlayAlpha: overlayAlpha,
    ),
  );
}
