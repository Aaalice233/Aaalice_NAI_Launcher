import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../core/utils/isolate_pool.dart';

class ReversePromptImageLimits {
  const ReversePromptImageLimits({
    this.maxBytes = 16 * 1024 * 1024,
    this.maxLongSide = 4096,
    this.maxPixels = 16 * 1024 * 1024,
    this.minJpegQuality = 60,
  }) : assert(maxBytes > 0),
       assert(maxLongSide > 0),
       assert(maxPixels > 0),
       assert(minJpegQuality >= 1 && minJpegQuality <= 100);

  final int maxBytes;
  final int maxLongSide;
  final int maxPixels;
  final int minJpegQuality;
}

class ReversePromptImageNormalizer {
  const ReversePromptImageNormalizer._();

  static Future<Uint8List> normalize(
    Uint8List bytes, {
    ReversePromptImageLimits limits = const ReversePromptImageLimits(),
  }) {
    final imageData = TransferableTypedData.fromList([bytes]);
    return ComputeGate.singleTask().runIsolate(
      () => _normalizeInCurrentIsolate(imageData, limits),
    );
  }

  static Uint8List _normalizeInCurrentIsolate(
    TransferableTypedData imageData,
    ReversePromptImageLimits limits,
  ) {
    final bytes = imageData.materialize().asUint8List();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return bytes;
    }

    final scale = _resolveResizeScale(decoded, limits);
    final needsResize = scale < 0.999;
    if (!needsResize && bytes.length <= limits.maxBytes) {
      return bytes;
    }

    final prepared = needsResize
        ? img.copyResize(
            decoded,
            width: math.max(1, (decoded.width * scale).round()),
            height: math.max(1, (decoded.height * scale).round()),
            interpolation: img.Interpolation.cubic,
          )
        : decoded;
    return _encodeJpegWithinLimit(prepared, limits);
  }

  static double _resolveResizeScale(
    img.Image image,
    ReversePromptImageLimits limits,
  ) {
    var scale = 1.0;
    final longSide = math.max(image.width, image.height);
    if (longSide > limits.maxLongSide) {
      scale = math.min(scale, limits.maxLongSide / longSide);
    }

    final pixels = image.width * image.height;
    if (pixels > limits.maxPixels) {
      scale = math.min(scale, math.sqrt(limits.maxPixels / pixels));
    }
    return scale;
  }

  static Uint8List _encodeJpegWithinLimit(
    img.Image source,
    ReversePromptImageLimits limits,
  ) {
    var current = _flattenOnWhite(source);
    Uint8List best = Uint8List.fromList(
      img.encodeJpg(current, quality: limits.minJpegQuality),
    );

    for (final quality in _qualitySteps(limits.minJpegQuality)) {
      final encoded = Uint8List.fromList(
        img.encodeJpg(current, quality: quality),
      );
      best = encoded.length < best.length ? encoded : best;
      if (encoded.length <= limits.maxBytes) {
        return encoded;
      }
    }

    while (best.length > limits.maxBytes &&
        (current.width > 1 || current.height > 1)) {
      final nextWidth = math.max(1, (current.width * 0.85).round());
      final nextHeight = math.max(1, (current.height * 0.85).round());
      if (nextWidth == current.width && nextHeight == current.height) {
        break;
      }
      current = img.copyResize(
        current,
        width: nextWidth,
        height: nextHeight,
        interpolation: img.Interpolation.cubic,
      );
      best = Uint8List.fromList(
        img.encodeJpg(current, quality: limits.minJpegQuality),
      );
    }

    return best;
  }

  static Iterable<int> _qualitySteps(int minJpegQuality) sync* {
    for (var quality = 90; quality > minJpegQuality; quality -= 8) {
      yield quality;
    }
    yield minJpegQuality;
  }

  static img.Image _flattenOnWhite(img.Image source) {
    final canvas = img.Image(width: source.width, height: source.height);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(canvas, source);
    return canvas;
  }
}
