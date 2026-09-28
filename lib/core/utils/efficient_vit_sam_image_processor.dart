import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

import 'contiguous_region_selector.dart';
import 'isolate_pool.dart';

class EfficientVitSamPreparedImage {
  const EfficientVitSamPreparedImage({
    required this.tensor,
    required this.resizedWidth,
    required this.resizedHeight,
  });

  final Float32List tensor;
  final int resizedWidth;
  final int resizedHeight;
}

class EfficientVitSamLowResolutionMask {
  const EfficientVitSamLowResolutionMask({
    required this.logits,
    required this.width,
    required this.height,
  });

  final Float32List logits;
  final int width;
  final int height;
}

class EfficientVitSamImageProcessor {
  const EfficientVitSamImageProcessor._();

  static const int encoderSize = 512;
  static const int decoderCoordinateSize = 1024;
  static const List<double> _pixelMean = <double>[0.485, 0.456, 0.406];
  static const List<double> _pixelStd = <double>[0.229, 0.224, 0.225];

  static Future<String> hashRgbaAsync(Uint8List rgba) {
    return ComputeGate.singleTask().runIsolate(
      () => sha256.convert(rgba).toString(),
    );
  }

  static Future<EfficientVitSamPreparedImage> preprocessRgbaAsync({
    required Uint8List rgba,
    required int width,
    required int height,
  }) {
    return ComputeGate.singleTask().runIsolate(
      () => preprocessRgba(rgba: rgba, width: width, height: height),
    );
  }

  static EfficientVitSamPreparedImage preprocessRgba({
    required Uint8List rgba,
    required int width,
    required int height,
  }) {
    _validateRgba(rgba, width, height);
    final resizedSize = resizeLongestSide(
      width: width,
      height: height,
      targetLongestSide: encoderSize,
    );
    final source = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      bytesOffset: rgba.offsetInBytes,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    final resized = img.copyResize(
      source,
      width: resizedSize.width,
      height: resizedSize.height,
      interpolation: img.Interpolation.linear,
    );

    const planeSize = encoderSize * encoderSize;
    final tensor = Float32List(planeSize * 3);
    for (var y = 0; y < resized.height; y++) {
      final rowOffset = y * encoderSize;
      for (var x = 0; x < resized.width; x++) {
        final pixel = resized.getPixel(x, y);
        final index = rowOffset + x;
        tensor[index] = (pixel.r / 255.0 - _pixelMean[0]) / _pixelStd[0];
        tensor[planeSize + index] =
            (pixel.g / 255.0 - _pixelMean[1]) / _pixelStd[1];
        tensor[planeSize * 2 + index] =
            (pixel.b / 255.0 - _pixelMean[2]) / _pixelStd[2];
      }
    }

    return EfficientVitSamPreparedImage(
      tensor: tensor,
      resizedWidth: resized.width,
      resizedHeight: resized.height,
    );
  }

  static EfficientVitSamImageSize resizeLongestSide({
    required int width,
    required int height,
    required int targetLongestSide,
  }) {
    if (width <= 0 || height <= 0 || targetLongestSide <= 0) {
      throw ArgumentError('Image dimensions and target size must be positive.');
    }
    final scale = targetLongestSide / math.max(width, height);
    return EfficientVitSamImageSize(
      width: math.max(1, (width * scale).round()),
      height: math.max(1, (height * scale).round()),
    );
  }

  static Float32List scalePoint({
    required double x,
    required double y,
    required int width,
    required int height,
  }) {
    final resizedSize = resizeLongestSide(
      width: width,
      height: height,
      targetLongestSide: decoderCoordinateSize,
    );
    return Float32List.fromList(<double>[
      x * resizedSize.width / width,
      y * resizedSize.height / height,
    ]);
  }

  static EfficientVitSamLowResolutionMask parseLowResolutionMask(
    Object? value,
  ) {
    Object? current = value;
    while (current is List && current.length == 1 && current.first is List) {
      current = current.first;
    }
    if (current is! List || current.isEmpty) {
      throw StateError('EfficientViT-SAM returned an empty mask tensor.');
    }

    final firstRow = current.first;
    if (firstRow is! List || firstRow.isEmpty) {
      throw StateError('EfficientViT-SAM returned an invalid mask tensor.');
    }
    final width = firstRow.length;
    final height = current.length;
    final logits = Float32List(width * height);
    var outputIndex = 0;
    for (final row in current) {
      if (row is! List || row.length != width) {
        throw StateError(
          'EfficientViT-SAM returned an inconsistent mask tensor.',
        );
      }
      for (final value in row) {
        if (value is! num) {
          throw StateError(
            'EfficientViT-SAM returned a non-numeric mask tensor.',
          );
        }
        logits[outputIndex++] = value.toDouble();
      }
    }
    return EfficientVitSamLowResolutionMask(
      logits: logits,
      width: width,
      height: height,
    );
  }

  static Future<ContiguousRegionSelection> postprocessMaskAsync({
    required EfficientVitSamLowResolutionMask lowResolutionMask,
    required int outputWidth,
    required int outputHeight,
    bool invert = false,
  }) {
    return ComputeGate.singleTask().runIsolate(
      () => postprocessMask(
        lowResolutionMask: lowResolutionMask,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
        invert: invert,
      ),
    );
  }

  static ContiguousRegionSelection postprocessMask({
    required EfficientVitSamLowResolutionMask lowResolutionMask,
    required int outputWidth,
    required int outputHeight,
    bool invert = false,
  }) {
    if (outputWidth <= 0 || outputHeight <= 0) {
      throw ArgumentError('Output dimensions must be positive.');
    }
    if (lowResolutionMask.width <= 0 ||
        lowResolutionMask.height <= 0 ||
        lowResolutionMask.logits.length !=
            lowResolutionMask.width * lowResolutionMask.height) {
      throw ArgumentError('Low-resolution mask dimensions are invalid.');
    }

    final squareLogits = _resizeBilinear(
      source: lowResolutionMask.logits,
      sourceWidth: lowResolutionMask.width,
      sourceHeight: lowResolutionMask.height,
      sourceStride: lowResolutionMask.width,
      targetWidth: decoderCoordinateSize,
      targetHeight: decoderCoordinateSize,
    );
    final prepaddedSize = resizeLongestSide(
      width: outputWidth,
      height: outputHeight,
      targetLongestSide: decoderCoordinateSize,
    );
    final outputLogits = _resizeBilinear(
      source: squareLogits,
      sourceWidth: prepaddedSize.width,
      sourceHeight: prepaddedSize.height,
      sourceStride: decoderCoordinateSize,
      targetWidth: outputWidth,
      targetHeight: outputHeight,
    );

    final mask = Uint8List(outputWidth * outputHeight);
    var selectedPixelCount = 0;
    for (var index = 0; index < outputLogits.length; index++) {
      final selected = outputLogits[index] > 0;
      final value = invert ? !selected : selected;
      if (value) {
        mask[index] = 1;
        selectedPixelCount++;
      }
    }
    return ContiguousRegionSelection(
      mask: mask,
      width: outputWidth,
      height: outputHeight,
      selectedPixelCount: selectedPixelCount,
    );
  }

  static Float32List _resizeBilinear({
    required Float32List source,
    required int sourceWidth,
    required int sourceHeight,
    required int sourceStride,
    required int targetWidth,
    required int targetHeight,
  }) {
    final output = Float32List(targetWidth * targetHeight);
    final scaleX = sourceWidth / targetWidth;
    final scaleY = sourceHeight / targetHeight;

    for (var targetY = 0; targetY < targetHeight; targetY++) {
      final sourceY = (targetY + 0.5) * scaleY - 0.5;
      final rawTopY = sourceY.floor();
      final topY = rawTopY.clamp(0, sourceHeight - 1);
      final bottomY = (rawTopY + 1).clamp(0, sourceHeight - 1);
      final yWeight = (sourceY - sourceY.floor()).clamp(0.0, 1.0);
      final topOffset = topY * sourceStride;
      final bottomOffset = bottomY * sourceStride;
      final outputOffset = targetY * targetWidth;

      for (var targetX = 0; targetX < targetWidth; targetX++) {
        final sourceX = (targetX + 0.5) * scaleX - 0.5;
        final rawLeftX = sourceX.floor();
        final leftX = rawLeftX.clamp(0, sourceWidth - 1);
        final rightX = (rawLeftX + 1).clamp(0, sourceWidth - 1);
        final xWeight = (sourceX - sourceX.floor()).clamp(0.0, 1.0);
        final top = _lerp(
          source[topOffset + leftX],
          source[topOffset + rightX],
          xWeight,
        );
        final bottom = _lerp(
          source[bottomOffset + leftX],
          source[bottomOffset + rightX],
          xWeight,
        );
        output[outputOffset + targetX] = _lerp(top, bottom, yWeight);
      }
    }
    return output;
  }

  static double _lerp(double start, double end, double amount) {
    return start + (end - start) * amount;
  }

  static void _validateRgba(Uint8List rgba, int width, int height) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Image dimensions must be positive.');
    }
    if (rgba.lengthInBytes < width * height * 4) {
      throw ArgumentError('RGBA buffer is smaller than the image dimensions.');
    }
  }
}

class EfficientVitSamImageSize {
  const EfficientVitSamImageSize({required this.width, required this.height});

  final int width;
  final int height;
}
