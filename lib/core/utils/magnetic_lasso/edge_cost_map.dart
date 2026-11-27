import 'dart:math' as math;
import 'dart:typed_data';

import '../isolate_pool.dart';

/// Per-pixel edge features calculated from a non-premultiplied RGBA image.
class EdgeCostMap {
  const EdgeCostMap._(
    this.width,
    this.height,
    this.strength,
    this.zeroCrossing,
  );

  final int width;
  final int height;

  /// Normalized edge strength in 0..1, indexed by `y * width + x`.
  final Float32List strength;

  /// Laplacian zero-crossing flag (0 or 1), indexed by `y * width + x`.
  final Uint8List zeroCrossing;

  static EdgeCostMap build(Uint8List rgba, int width, int height) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Image dimensions must be positive.');
    }
    final pixelCount = rgba.lengthInBytes ~/ 4;
    if (rgba.lengthInBytes % 4 != 0 ||
        pixelCount % width != 0 ||
        pixelCount ~/ width != height) {
      throw ArgumentError('RGBA buffer must match the image dimensions.');
    }

    final rgb = _premultiply(rgba, pixelCount);
    return EdgeCostMap._(
      width,
      height,
      _sobelStrength(rgb, width, height),
      _zeroCrossings(rgb, width, height),
    );
  }

  /// Calculates the same features as [build] on a background isolate.
  static Future<EdgeCostMap> buildAsync(Uint8List rgba, int width, int height) {
    return ComputeGate.singleTask().runIsolate(
      () => build(rgba, width, height),
    );
  }
}

Uint16List _premultiply(Uint8List rgba, int pixelCount) {
  final rgb = Uint16List(pixelCount * 3);
  // Keep the numerator of channel * alpha / 255. The common divisor cancels
  // in both the Sobel normalization and the Laplacian comparisons.
  for (var src = 0, dst = 0; dst < rgb.length; src += 4, dst += 3) {
    final alpha = rgba[src + 3];
    rgb[dst] = rgba[src] * alpha;
    rgb[dst + 1] = rgba[src + 1] * alpha;
    rgb[dst + 2] = rgba[src + 2] * alpha;
  }
  return rgb;
}

Float32List _sobelStrength(Uint16List rgb, int width, int height) {
  final squared = _sobelSquared(rgb, width, height);
  final p99Squared = _percentile99(squared);
  final strength = Float32List(squared.length);
  if (p99Squared == 0) return strength;

  final p99 = math.sqrt(p99Squared);
  for (var i = 0; i < squared.length; i++) {
    final gradient = squared[i];
    strength[i] = gradient >= p99Squared ? 1.0 : math.sqrt(gradient) / p99;
  }
  return strength;
}

Uint64List _sobelSquared(Uint16List rgb, int width, int height) {
  final squared = Uint64List(width * height);
  for (var y = 0; y < height; y++) {
    final row = y * width;
    final middle = row * 3;
    final top = math.max(y - 1, 0) * width * 3;
    final bottom = math.min(y + 1, height - 1) * width * 3;
    for (var x = 0; x < width; x++) {
      final left = math.max(x - 1, 0) * 3;
      final center = x * 3;
      final right = math.min(x + 1, width - 1) * 3;
      var maxSquared = 0;
      for (var channel = 0; channel < 3; channel++) {
        final tl = rgb[top + left + channel];
        final tr = rgb[top + right + channel];
        final bl = rgb[bottom + left + channel];
        final br = rgb[bottom + right + channel];
        final gx =
            tr -
            tl +
            2 * (rgb[middle + right + channel] - rgb[middle + left + channel]) +
            br -
            bl;
        final gy =
            bl -
            tl +
            2 * (rgb[bottom + center + channel] - rgb[top + center + channel]) +
            br -
            tr;
        maxSquared = math.max(maxSquared, gx * gx + gy * gy);
      }
      squared[row + x] = maxSquared;
    }
  }
  return squared;
}

int _percentile99(Uint64List squared) {
  // Squaring preserves the rank of the nonnegative gradient magnitudes.
  // Sobel's squared values fit in 37 bits: at most 2 * (4 * 255 * 255)^2.
  // Refine the nearest-rank percentile in successive 10-bit histograms to
  // keep the bins small without quantizing weak gradients down to zero.
  const binBits = 10;
  const binCount = 1 << binBits;
  final histogram = Uint32List(binCount);
  var rank = (squared.length * 99 + 99) ~/ 100;
  var selected = 0;
  for (var shift = 30; shift >= 0; shift -= binBits) {
    final first = selected >> shift;
    histogram.fillRange(0, binCount, 0);
    for (var i = 0; i < squared.length; i++) {
      final bin = (squared[i] >> shift) - first;
      if (bin >= 0 && bin < binCount) histogram[bin]++;
    }
    var bin = 0;
    while (rank > histogram[bin]) {
      rank -= histogram[bin];
      bin++;
    }
    selected = (first + bin) << shift;
  }
  return selected;
}

Uint8List _zeroCrossings(Uint16List rgb, int width, int height) {
  final laplacian = _laplacian(
    _blurLuminance(rgb, width, height),
    width,
    height,
  );
  final flags = Uint8List(laplacian.length);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final p = y * width + x;
      // Visit each four-connected pair once. A clamped neighbor outside the
      // image would be p itself, so it cannot add any crossing.
      if (x + 1 < width) _markCrossing(laplacian, flags, p, p + 1);
      if (y + 1 < height) _markCrossing(laplacian, flags, p, p + width);
    }
  }
  return flags;
}

Int32List _blurLuminance(Uint16List rgb, int width, int height) {
  final luminance = Int32List(width * height);
  for (var i = 0, offset = 0; i < luminance.length; i++, offset += 3) {
    luminance[i] =
        299 * rgb[offset] + 587 * rgb[offset + 1] + 114 * rgb[offset + 2];
  }

  // Omit the common luminance (1000) and Gaussian (16) denominators to
  // preserve exact zeroes and equal magnitudes in the Laplacian.
  final blurred = Int32List(luminance.length);
  for (var y = 0; y < height; y++) {
    final middle = y * width;
    final top = math.max(y - 1, 0) * width;
    final bottom = math.min(y + 1, height - 1) * width;
    for (var x = 0; x < width; x++) {
      final left = math.max(x - 1, 0);
      final right = math.min(x + 1, width - 1);
      blurred[middle + x] =
          luminance[top + left] +
          2 * luminance[top + x] +
          luminance[top + right] +
          2 *
              (luminance[middle + left] +
                  2 * luminance[middle + x] +
                  luminance[middle + right]) +
          luminance[bottom + left] +
          2 * luminance[bottom + x] +
          luminance[bottom + right];
    }
  }
  return blurred;
}

Int32List _laplacian(Int32List blurred, int width, int height) {
  final laplacian = Int32List(blurred.length);
  for (var y = 0; y < height; y++) {
    final row = y * width;
    final top = math.max(y - 1, 0) * width;
    final bottom = math.min(y + 1, height - 1) * width;
    for (var x = 0; x < width; x++) {
      final p = row + x;
      // Adjacent Gaussian sums share at least half their kernel weights;
      // four differences therefore fit in 32 signed bits (32 * 65025000).
      laplacian[p] =
          blurred[top + x] +
          blurred[bottom + x] +
          blurred[row + math.max(x - 1, 0)] +
          blurred[row + math.min(x + 1, width - 1)] -
          4 * blurred[p];
    }
  }
  return laplacian;
}

void _markCrossing(Int32List laplacian, Uint8List flags, int p, int q) {
  final a = laplacian[p];
  final b = laplacian[q];
  if (!(a < 0 && b > 0 || a > 0 && b < 0)) return;
  final magnitudeA = a.abs();
  final magnitudeB = b.abs();
  if (magnitudeA <= magnitudeB) flags[p] = 1;
  if (magnitudeB <= magnitudeA) flags[q] = 1;
}
