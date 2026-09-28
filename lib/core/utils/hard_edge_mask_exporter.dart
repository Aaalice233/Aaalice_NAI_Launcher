import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:image/image.dart' as img;

import 'inpaint_mask_utils.dart';

class HardEdgeMaskExportInput {
  const HardEdgeMaskExportInput({
    required this.width,
    required this.height,
    required this.strokes,
    required this.baseMasks,
    required this.additionalRects,
    this.orderedOperations = const [],
  });

  final int width;
  final int height;
  final List<HardEdgeMaskStroke> strokes;
  final List<HardEdgeMaskBaseImage> baseMasks;
  final List<Rect> additionalRects;
  final List<HardEdgeMaskOperation> orderedOperations;
}

class HardEdgeMaskRaster {
  const HardEdgeMaskRaster({
    required this.mask,
    required this.width,
    required this.height,
  });

  final Uint8List mask;
  final int width;
  final int height;
}

class HardEdgeMaskStroke {
  const HardEdgeMaskStroke({
    required this.points,
    required this.size,
    required this.isEraser,
  });

  final List<Offset> points;
  final double size;
  final bool isEraser;
}

class HardEdgeMaskBaseImage {
  const HardEdgeMaskBaseImage({
    required this.bytes,
    required this.offsetX,
    required this.offsetY,
  });

  final Uint8List bytes;
  final int offsetX;
  final int offsetY;
}

abstract class HardEdgeMaskOperation {
  const HardEdgeMaskOperation();
}

class HardEdgeMaskBaseImageOperation extends HardEdgeMaskOperation {
  const HardEdgeMaskBaseImageOperation({required this.baseMask});

  final HardEdgeMaskBaseImage baseMask;
}

class HardEdgeMaskStrokeOperation extends HardEdgeMaskOperation {
  const HardEdgeMaskStrokeOperation({required this.stroke});

  final HardEdgeMaskStroke stroke;
}

class HardEdgeMaskRectOperation extends HardEdgeMaskOperation {
  const HardEdgeMaskRectOperation({required this.rect});

  final Rect rect;
}

class HardEdgeMaskExporter {
  const HardEdgeMaskExporter._();

  static const int _transparentAlphaThreshold = 8;

  static Future<Uint8List> exportAsync(HardEdgeMaskExportInput input) {
    return Isolate.run(() => export(input));
  }

  static Future<HardEdgeMaskRaster> exportRasterAsync(
    HardEdgeMaskExportInput input,
  ) {
    return Isolate.run(() => exportRaster(input));
  }

  static Uint8List export(HardEdgeMaskExportInput input) {
    final raster = exportRaster(input);
    return InpaintMaskUtils.encodeBinaryMask(
      raster.mask,
      raster.width,
      raster.height,
    );
  }

  static HardEdgeMaskRaster exportRaster(HardEdgeMaskExportInput input) {
    if (input.width <= 0 || input.height <= 0) {
      throw ArgumentError('Mask dimensions must be positive.');
    }

    final mask = img.Image(
      width: input.width,
      height: input.height,
      numChannels: 4,
    );
    img.fill(mask, color: img.ColorRgba8(0, 0, 0, 255));

    if (input.orderedOperations.isNotEmpty) {
      for (final operation in input.orderedOperations) {
        _applyOperation(mask, operation);
      }
    } else {
      for (final baseMask in input.baseMasks) {
        _pasteBaseMask(mask, baseMask);
      }
      for (final stroke in input.strokes) {
        _drawStroke(mask, stroke);
      }
    }

    for (final rect in input.additionalRects) {
      _fillRect(mask, rect);
    }

    final binaryMask = Uint8List(input.width * input.height);
    var index = 0;
    for (var y = 0; y < input.height; y++) {
      for (var x = 0; x < input.width; x++) {
        binaryMask[index++] = mask.getPixel(x, y).r.toInt() > 0 ? 1 : 0;
      }
    }
    return HardEdgeMaskRaster(
      mask: binaryMask,
      width: input.width,
      height: input.height,
    );
  }

  static void _applyOperation(img.Image mask, HardEdgeMaskOperation operation) {
    if (operation is HardEdgeMaskBaseImageOperation) {
      _pasteBaseMask(mask, operation.baseMask);
      return;
    }
    if (operation is HardEdgeMaskStrokeOperation) {
      _drawStroke(mask, operation.stroke);
      return;
    }
    if (operation is HardEdgeMaskRectOperation) {
      _fillRect(mask, operation.rect);
      return;
    }

    throw ArgumentError('Unsupported hard-edge mask operation: $operation');
  }

  static void _pasteBaseMask(img.Image mask, HardEdgeMaskBaseImage baseMask) {
    final source = img.decodeImage(baseMask.bytes);
    if (source == null) {
      return;
    }

    final normalizedBytes = InpaintMaskUtils.normalizeMaskBytes(baseMask.bytes);
    final base = img.decodeImage(normalizedBytes);
    if (base == null) {
      return;
    }

    for (var y = 0; y < base.height; y++) {
      final targetY = y + baseMask.offsetY;
      if (targetY < 0 || targetY >= mask.height) {
        continue;
      }

      for (var x = 0; x < base.width; x++) {
        final targetX = x + baseMask.offsetX;
        if (targetX < 0 || targetX >= mask.width) {
          continue;
        }

        final sourcePixel = source.getPixel(x, y);
        if (sourcePixel.a.toInt() <= _transparentAlphaThreshold) {
          continue;
        }

        final pixel = base.getPixel(x, y);
        _setMaskPixel(mask, targetX, targetY, masked: pixel.r.toInt() > 0);
      }
    }
  }

  static void _fillRect(img.Image mask, Rect rect) {
    final left = rect.left.floor().clamp(0, mask.width).toInt();
    final top = rect.top.floor().clamp(0, mask.height).toInt();
    final right = rect.right.ceil().clamp(0, mask.width).toInt();
    final bottom = rect.bottom.ceil().clamp(0, mask.height).toInt();

    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        _setMaskPixel(mask, x, y, masked: true);
      }
    }
  }

  static void _drawStroke(img.Image mask, HardEdgeMaskStroke stroke) {
    if (stroke.points.isEmpty || stroke.size <= 0) {
      return;
    }

    if (stroke.points.length == 1) {
      _drawDisc(
        mask,
        stroke.points.first,
        stroke.size,
        masked: !stroke.isEraser,
      );
      return;
    }

    final masked = !stroke.isEraser;
    if (stroke.points.length == 2) {
      _drawSegment(
        mask,
        stroke.points.first,
        stroke.points.last,
        stroke.size,
        masked: masked,
      );
      return;
    }

    _drawSmoothPath(mask, stroke.points, stroke.size, masked: masked);
  }

  static void _drawSmoothPath(
    img.Image mask,
    List<Offset> points,
    double size, {
    required bool masked,
  }) {
    var current = points.first;

    for (var i = 1; i < points.length - 1; i++) {
      final control = points[i];
      final next = points[i + 1];
      final end = Offset(
        (control.dx + next.dx) / 2,
        (control.dy + next.dy) / 2,
      );

      _drawQuadraticSegment(mask, current, control, end, size, masked: masked);
      current = end;
    }

    _drawSegment(mask, current, points.last, size, masked: masked);
  }

  static void _drawSegment(
    img.Image mask,
    Offset start,
    Offset end,
    double size, {
    required bool masked,
  }) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final steps = math.max(dx.abs(), dy.abs()).ceil();
    if (steps == 0) {
      _drawDisc(mask, start, size, masked: masked);
      return;
    }

    for (var step = 0; step <= steps; step++) {
      final t = step / steps;
      _drawDisc(
        mask,
        Offset(start.dx + dx * t, start.dy + dy * t),
        size,
        masked: masked,
      );
    }
  }

  static void _drawQuadraticSegment(
    img.Image mask,
    Offset start,
    Offset control,
    Offset end,
    double size, {
    required bool masked,
  }) {
    final estimatedLength =
        (control - start).distance + (end - control).distance;
    final steps = math.max(estimatedLength.ceil(), 1);

    for (var step = 0; step <= steps; step++) {
      final t = step / steps;
      _drawDisc(
        mask,
        _quadraticPoint(start, control, end, t),
        size,
        masked: masked,
      );
    }
  }

  static Offset _quadraticPoint(
    Offset start,
    Offset control,
    Offset end,
    double t,
  ) {
    final inverseT = 1 - t;
    return Offset(
      inverseT * inverseT * start.dx +
          2 * inverseT * t * control.dx +
          t * t * end.dx,
      inverseT * inverseT * start.dy +
          2 * inverseT * t * control.dy +
          t * t * end.dy,
    );
  }

  static void _drawDisc(
    img.Image mask,
    Offset center,
    double size, {
    required bool masked,
  }) {
    final radius = size / 2;
    final radiusSquared = radius * radius;
    final left = (center.dx - radius).floor().clamp(0, mask.width - 1).toInt();
    final top = (center.dy - radius).floor().clamp(0, mask.height - 1).toInt();
    final right = (center.dx + radius).ceil().clamp(0, mask.width - 1).toInt();
    final bottom = (center.dy + radius)
        .ceil()
        .clamp(0, mask.height - 1)
        .toInt();

    for (var y = top; y <= bottom; y++) {
      for (var x = left; x <= right; x++) {
        final pixelCenterX = x + 0.5;
        final pixelCenterY = y + 0.5;
        final distanceX = pixelCenterX - center.dx;
        final distanceY = pixelCenterY - center.dy;
        if (distanceX * distanceX + distanceY * distanceY <= radiusSquared) {
          _setMaskPixel(mask, x, y, masked: masked);
        }
      }
    }
  }

  static void _setMaskPixel(
    img.Image mask,
    int x,
    int y, {
    required bool masked,
  }) {
    if (x < 0 || x >= mask.width || y < 0 || y >= mask.height) {
      return;
    }

    final value = masked ? 255 : 0;
    mask.setPixelRgba(x, y, value, value, value, 255);
  }
}
