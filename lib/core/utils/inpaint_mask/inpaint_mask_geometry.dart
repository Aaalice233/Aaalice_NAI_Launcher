import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import '../isolate_pool.dart';
import 'inpaint_mask_operations.dart';

enum InpaintMaskShape { rect, ellipse, polygon }

enum InpaintMaskRegionMode { add, subtract }

/// One shape in normalized (0..1) image space.
class InpaintMaskRegion {
  const InpaintMaskRegion.rect(
    this.bounds, {
    this.mode = InpaintMaskRegionMode.add,
  }) : shape = InpaintMaskShape.rect,
       points = const [];

  const InpaintMaskRegion.ellipse(
    this.bounds, {
    this.mode = InpaintMaskRegionMode.add,
  }) : shape = InpaintMaskShape.ellipse,
       points = const [];

  const InpaintMaskRegion.polygon(
    this.points, {
    this.mode = InpaintMaskRegionMode.add,
  }) : shape = InpaintMaskShape.polygon,
       bounds = null;

  final InpaintMaskShape shape;
  final InpaintMaskRegionMode mode;
  final Rect? bounds;
  final List<Offset> points;
}

class InpaintMaskGeometryException implements Exception {
  const InpaintMaskGeometryException(this.message);

  final String message;

  @override
  String toString() => 'Invalid inpaint mask geometry: $message';
}

/// Rasterizes normalized shape descriptions into inpaint masks.
abstract final class InpaintMaskGeometry {
  /// Composes [regions] into a row-major 0/1 mask, then grows it by
  /// [expandRatio] of the shorter side.
  static Uint8List rasterizeBinary({
    required List<InpaintMaskRegion> regions,
    required int width,
    required int height,
    double expandRatio = 0,
  }) {
    if (width <= 0 || height <= 0) {
      throw const InpaintMaskGeometryException(
        'mask dimensions must be positive',
      );
    }
    if (regions.isEmpty) {
      throw const InpaintMaskGeometryException(
        'at least one region is required',
      );
    }
    if (!expandRatio.isFinite || expandRatio < 0) {
      throw const InpaintMaskGeometryException(
        'expand_ratio must be zero or a positive finite number',
      );
    }

    final mask = Uint8List(width * height);
    for (final region in regions) {
      final value = region.mode == InpaintMaskRegionMode.add ? 1 : 0;
      switch (region.shape) {
        case InpaintMaskShape.rect:
          _fillRect(mask, width, height, _requireBounds(region), value);
        case InpaintMaskShape.ellipse:
          _fillEllipse(mask, width, height, _requireBounds(region), value);
        case InpaintMaskShape.polygon:
          _fillPolygon(mask, width, height, region.points, value);
      }
    }

    final radius = (expandRatio * math.min(width, height)).round();
    if (radius <= 0) return mask;
    return expandBinary(mask, width: width, height: height, radius: radius);
  }

  static Uint8List rasterizeToPng({
    required List<InpaintMaskRegion> regions,
    required int width,
    required int height,
    double expandRatio = 0,
  }) => InpaintMaskUtils.encodeBinaryMask(
    rasterizeBinary(
      regions: regions,
      width: width,
      height: height,
      expandRatio: expandRatio,
    ),
    width,
    height,
  );

  static Future<Uint8List> rasterizeToPngAsync({
    required List<InpaintMaskRegion> regions,
    required int width,
    required int height,
    double expandRatio = 0,
  }) => ComputeGate().runIsolate(
    () => rasterizeToPng(
      regions: regions,
      width: width,
      height: height,
      expandRatio: expandRatio,
    ),
  );

  /// Chebyshev dilation via a two-pass chamfer transform: cost is independent
  /// of [radius], unlike iterating a 3x3 structuring element per pixel.
  static Uint8List expandBinary(
    Uint8List mask, {
    required int width,
    required int height,
    required int radius,
  }) {
    if (mask.length != width * height) {
      throw const InpaintMaskGeometryException(
        'binary mask length does not match dimensions',
      );
    }
    if (radius <= 0) return Uint8List.fromList(mask);

    const unreachable = 1 << 29;
    final distance = Int32List(width * height);
    for (var index = 0; index < mask.length; index++) {
      distance[index] = mask[index] == 1 ? 0 : unreachable;
    }

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = y * width + x;
        var best = distance[index];
        if (best == 0) continue;
        if (y > 0) {
          final above = (y - 1) * width;
          for (
            var nx = math.max(0, x - 1);
            nx <= math.min(width - 1, x + 1);
            nx++
          ) {
            best = math.min(best, distance[above + nx] + 1);
          }
        }
        if (x > 0) best = math.min(best, distance[index - 1] + 1);
        distance[index] = best;
      }
    }

    final result = Uint8List(width * height);
    for (var y = height - 1; y >= 0; y--) {
      for (var x = width - 1; x >= 0; x--) {
        final index = y * width + x;
        var best = distance[index];
        if (best != 0) {
          if (y + 1 < height) {
            final below = (y + 1) * width;
            for (
              var nx = math.max(0, x - 1);
              nx <= math.min(width - 1, x + 1);
              nx++
            ) {
              best = math.min(best, distance[below + nx] + 1);
            }
          }
          if (x + 1 < width) best = math.min(best, distance[index + 1] + 1);
          distance[index] = best;
        }
        result[index] = best <= radius ? 1 : 0;
      }
    }
    return result;
  }

  static Rect _requireBounds(InpaintMaskRegion region) {
    final bounds = region.bounds;
    if (bounds == null) {
      throw const InpaintMaskGeometryException('shape requires bounds');
    }
    if (!bounds.left.isFinite ||
        !bounds.top.isFinite ||
        !bounds.right.isFinite ||
        !bounds.bottom.isFinite) {
      throw const InpaintMaskGeometryException('bounds must be finite');
    }
    if (bounds.right <= bounds.left || bounds.bottom <= bounds.top) {
      throw const InpaintMaskGeometryException(
        'bounds must have positive extent',
      );
    }
    return bounds;
  }

  // 向外取整与 InpaintMaskUtils.createRectMaskBytes 保持一致，避免同一个矩形
  // 经两个入口得到不同边缘像素。
  static ({int left, int top, int right, int bottom}) _pixelBounds(
    Rect normalized,
    int width,
    int height,
  ) => (
    left: (normalized.left * width).floor().clamp(0, width),
    top: (normalized.top * height).floor().clamp(0, height),
    right: (normalized.right * width).ceil().clamp(0, width),
    bottom: (normalized.bottom * height).ceil().clamp(0, height),
  );

  static void _fillRect(
    Uint8List mask,
    int width,
    int height,
    Rect normalized,
    int value,
  ) {
    final box = _pixelBounds(normalized, width, height);
    for (var y = box.top; y < box.bottom; y++) {
      mask.fillRange(y * width + box.left, y * width + box.right, value);
    }
  }

  static void _fillEllipse(
    Uint8List mask,
    int width,
    int height,
    Rect normalized,
    int value,
  ) {
    final box = _pixelBounds(normalized, width, height);
    final centerX = (box.left + box.right) / 2;
    final centerY = (box.top + box.bottom) / 2;
    final radiusX = (box.right - box.left) / 2;
    final radiusY = (box.bottom - box.top) / 2;
    if (radiusX <= 0 || radiusY <= 0) return;

    for (var y = box.top; y < box.bottom; y++) {
      final offsetY = (y + 0.5 - centerY) / radiusY;
      final span = 1 - offsetY * offsetY;
      if (span < 0) continue;
      final halfWidth = radiusX * math.sqrt(span);
      final left = (centerX - halfWidth).floor().clamp(box.left, box.right);
      final right = (centerX + halfWidth).ceil().clamp(box.left, box.right);
      if (right > left) {
        mask.fillRange(y * width + left, y * width + right, value);
      }
    }
  }

  static void _fillPolygon(
    Uint8List mask,
    int width,
    int height,
    List<Offset> normalized,
    int value,
  ) {
    if (normalized.length < 3) {
      throw const InpaintMaskGeometryException(
        'polygon requires at least three points',
      );
    }
    final points = <Offset>[];
    for (final point in normalized) {
      if (!point.dx.isFinite || !point.dy.isFinite) {
        throw const InpaintMaskGeometryException(
          'polygon points must be finite',
        );
      }
      points.add(Offset(point.dx * width, point.dy * height));
    }

    var minY = points.first.dy;
    var maxY = points.first.dy;
    for (final point in points) {
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }

    final crossings = <double>[];
    final firstRow = minY.floor().clamp(0, height);
    final lastRow = maxY.ceil().clamp(0, height);
    for (var y = firstRow; y < lastRow; y++) {
      final scanY = y + 0.5;
      crossings.clear();
      for (var i = 0; i < points.length; i++) {
        final start = points[i];
        final end = points[(i + 1) % points.length];
        // 半开区间判定，避免共享顶点被两条边各算一次。
        if ((start.dy <= scanY && end.dy > scanY) ||
            (end.dy <= scanY && start.dy > scanY)) {
          final t = (scanY - start.dy) / (end.dy - start.dy);
          crossings.add(start.dx + t * (end.dx - start.dx));
        }
      }
      if (crossings.length < 2) continue;
      crossings.sort();
      for (var i = 0; i + 1 < crossings.length; i += 2) {
        final left = crossings[i].floor().clamp(0, width);
        final right = crossings[i + 1].ceil().clamp(0, width);
        if (right > left) {
          mask.fillRange(y * width + left, y * width + right, value);
        }
      }
    }
  }
}
