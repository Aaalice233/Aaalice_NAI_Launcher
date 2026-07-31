import 'dart:typed_data';

import 'isolate_pool.dart';

class ContiguousRegionSelection {
  const ContiguousRegionSelection({
    required this.mask,
    required this.width,
    required this.height,
    required this.selectedPixelCount,
  });

  final Uint8List mask;
  final int width;
  final int height;
  final int selectedPixelCount;

  bool get isEmpty => selectedPixelCount == 0;
}

class ContiguousRegionSelector {
  const ContiguousRegionSelector._();

  static Future<ContiguousRegionSelection> selectRgbaAsync({
    required Uint8List rgba,
    required int width,
    required int height,
    required int startX,
    required int startY,
    required int tolerance,
    bool invert = false,
  }) {
    return ComputeGate.singleTask().runIsolate(
      () => selectRgba(
        rgba: rgba,
        width: width,
        height: height,
        startX: startX,
        startY: startY,
        tolerance: tolerance,
        invert: invert,
      ),
    );
  }

  static ContiguousRegionSelection selectRgba({
    required Uint8List rgba,
    required int width,
    required int height,
    required int startX,
    required int startY,
    required int tolerance,
    bool invert = false,
  }) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Image dimensions must be positive.');
    }

    final pixelCount = width * height;
    if (rgba.lengthInBytes < pixelCount * 4) {
      throw ArgumentError('RGBA buffer is smaller than the image dimensions.');
    }

    final mask = Uint8List(pixelCount);
    if (startX < 0 || startX >= width || startY < 0 || startY >= height) {
      return ContiguousRegionSelection(
        mask: mask,
        width: width,
        height: height,
        selectedPixelCount: 0,
      );
    }

    final clampedTolerance = tolerance.clamp(0, 255);
    final targetOffset = (startY * width + startX) * 4;
    final targetR = rgba[targetOffset];
    final targetG = rgba[targetOffset + 1];
    final targetB = rgba[targetOffset + 2];
    final targetA = rgba[targetOffset + 3];

    // 0 = unseen, 1 = selected, 2 = rejected.
    final pixelState = Uint8List(pixelCount);
    final pendingSeeds = <int>[startY * width + startX];
    var selectedPixelCount = 0;

    bool matches(int index) {
      final state = pixelState[index];
      if (state == 1) return true;
      if (state == 2) return false;

      final offset = index * 4;
      final alpha = rgba[offset + 3];
      final matchesTarget =
          targetA == 0 && alpha == 0 ||
          (rgba[offset] - targetR).abs() <= clampedTolerance &&
              (rgba[offset + 1] - targetG).abs() <= clampedTolerance &&
              (rgba[offset + 2] - targetB).abs() <= clampedTolerance &&
              (alpha - targetA).abs() <= clampedTolerance;
      if (!matchesTarget) {
        pixelState[index] = 2;
      }
      return matchesTarget;
    }

    while (pendingSeeds.isNotEmpty) {
      final seed = pendingSeeds.removeLast();
      if (pixelState[seed] == 1 || !matches(seed)) {
        continue;
      }

      final y = seed ~/ width;
      var left = seed % width;
      var right = left;

      while (left > 0) {
        final candidate = y * width + left - 1;
        if (pixelState[candidate] == 1 || !matches(candidate)) {
          break;
        }
        left--;
      }

      while (right + 1 < width) {
        final candidate = y * width + right + 1;
        if (pixelState[candidate] == 1 || !matches(candidate)) {
          break;
        }
        right++;
      }

      final rowStart = y * width;
      for (var x = left; x <= right; x++) {
        final index = rowStart + x;
        if (pixelState[index] == 1) {
          continue;
        }
        pixelState[index] = 1;
        mask[index] = 1;
        selectedPixelCount++;
      }

      void enqueueMatchingRuns(int adjacentY) {
        if (adjacentY < 0 || adjacentY >= height) {
          return;
        }

        final adjacentRowStart = adjacentY * width;
        var x = left;
        while (x <= right) {
          var index = adjacentRowStart + x;
          while (x <= right && (pixelState[index] == 1 || !matches(index))) {
            x++;
            index++;
          }
          if (x > right) {
            break;
          }

          pendingSeeds.add(index);
          x++;
          index++;
          while (x <= right && pixelState[index] != 1 && matches(index)) {
            x++;
            index++;
          }
        }
      }

      enqueueMatchingRuns(y - 1);
      enqueueMatchingRuns(y + 1);
    }

    if (invert) {
      for (var index = 0; index < mask.length; index++) {
        mask[index] = mask[index] == 0 ? 1 : 0;
      }
      selectedPixelCount = pixelCount - selectedPixelCount;
    }

    return ContiguousRegionSelection(
      mask: mask,
      width: width,
      height: height,
      selectedPixelCount: selectedPixelCount,
    );
  }
}
