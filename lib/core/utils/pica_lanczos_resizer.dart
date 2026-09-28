import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Pure Dart port of Pica's Lanczos3 resize pipeline.
///
/// The filter generator and convolvers follow the Pica code bundled by
/// NovelAI web build ae6a6aa-production, verified 2026-07-16. Pica is
/// distributed under the MIT license; see THIRD_PARTY_NOTICES.md.
class PicaLanczosResizer {
  PicaLanczosResizer._();

  static const int sourceTileSize = 1024;
  static const int destinationTileBorder = 3;
  static const double _pixelEpsilon = 1e-5;
  static const int _fixedPointScale = (1 << 14) - 1;

  /// Resize an [img.Image] with the same high-level stages used by Pica.
  static img.Image resizeImage(
    img.Image source, {
    required int width,
    required int height,
  }) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Target dimensions must be positive.');
    }
    if (source.width == width && source.height == height) {
      return source.clone();
    }

    final sourceBytes = source.getBytes(order: img.ChannelOrder.rgba);
    final resizedBytes = resizeRgba(
      sourceBytes,
      sourceWidth: source.width,
      sourceHeight: source.height,
      targetWidth: width,
      targetHeight: height,
    );
    return img.Image.fromBytes(
      width: width,
      height: height,
      bytes: resizedBytes.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  }

  /// Resize a tightly packed RGBA buffer.
  ///
  /// This entry point is public so raw Pica fixtures can be compared without
  /// introducing PNG decoder or encoder differences.
  static Uint8List resizeRgba(
    Uint8List source, {
    required int sourceWidth,
    required int sourceHeight,
    required int targetWidth,
    required int targetHeight,
  }) {
    if (sourceWidth <= 0 ||
        sourceHeight <= 0 ||
        targetWidth <= 0 ||
        targetHeight <= 0) {
      throw ArgumentError('Source and target dimensions must be positive.');
    }
    final expectedLength = sourceWidth * sourceHeight * 4;
    if (source.length != expectedLength) {
      throw ArgumentError.value(
        source.length,
        'source',
        'Expected $expectedLength tightly packed RGBA bytes.',
      );
    }
    if (sourceWidth == targetWidth && sourceHeight == targetHeight) {
      return Uint8List.fromList(source);
    }

    var current = _PicaImageBuffer(
      bytes: source,
      width: sourceWidth,
      height: sourceHeight,
    );
    final stages = _createStages(
      sourceWidth,
      sourceHeight,
      targetWidth,
      targetHeight,
    );
    final scratch = _PicaResizeScratch();

    for (var index = 0; index < stages.length; index++) {
      final stage = stages[index];
      final isFinalStage = index == stages.length - 1;
      current = _resizeStage(
        current,
        targetWidth: stage.width,
        targetHeight: stage.height,
        filter: isFinalStage ? _PicaFilter.lanczos3 : _PicaFilter.hamming,
        scratch: scratch,
      );
    }

    return current.bytes;
  }

  static _PicaImageBuffer _resizeStage(
    _PicaImageBuffer source, {
    required int targetWidth,
    required int targetHeight,
    required _PicaFilter filter,
    required _PicaResizeScratch scratch,
  }) {
    final target = Uint8List(targetWidth * targetHeight * 4);
    final tiles = _createTiles(
      sourceWidth: source.width,
      sourceHeight: source.height,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );

    for (final tile in tiles) {
      final sourceTile = _cropRgba(source, tile, scratch);
      final targetTile = _resizeBuffer(
        sourceTile,
        sourceWidth: tile.width,
        sourceHeight: tile.height,
        targetWidth: tile.targetWidth,
        targetHeight: tile.targetHeight,
        scaleX: tile.scaleX,
        scaleY: tile.scaleY,
        offsetX: tile.offsetX,
        offsetY: tile.offsetY,
        filter: filter,
        scratch: scratch,
      );
      _copyInnerTile(
        targetTile,
        tile: tile,
        target: target,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
    }

    return _PicaImageBuffer(
      bytes: target,
      width: targetWidth,
      height: targetHeight,
    );
  }

  static Uint8List _resizeBuffer(
    Uint8List source, {
    required int sourceWidth,
    required int sourceHeight,
    required int targetWidth,
    required int targetHeight,
    required double scaleX,
    required double scaleY,
    required double offsetX,
    required double offsetY,
    required _PicaFilter filter,
    required _PicaResizeScratch scratch,
  }) {
    final filtersX = _createFilters(
      filter,
      sourceWidth,
      targetWidth,
      scaleX,
      offsetX,
    );
    final filtersY = _createFilters(
      filter,
      sourceHeight,
      targetHeight,
      scaleY,
      offsetY,
    );
    final intermediate = scratch.intermediate(targetWidth * sourceHeight * 4);
    final target = scratch.targetTile(targetWidth * targetHeight * 4);

    if (_hasAlpha(source)) {
      _convolveHorizontalPremultiplied(
        source,
        intermediate,
        sourceWidth,
        sourceHeight,
        targetWidth,
        filtersX,
      );
      _convolveVerticalPremultiplied(
        intermediate,
        target,
        sourceHeight,
        targetWidth,
        targetHeight,
        filtersY,
      );
    } else {
      _convolveHorizontal(
        source,
        intermediate,
        sourceWidth,
        sourceHeight,
        targetWidth,
        filtersX,
      );
      _convolveVertical(
        intermediate,
        target,
        sourceHeight,
        targetWidth,
        targetHeight,
        filtersY,
      );
      for (var pointer = 3; pointer < target.length; pointer += 4) {
        target[pointer] = 255;
      }
    }

    return target;
  }

  static Int16List _createFilters(
    _PicaFilter filter,
    int sourceSize,
    int targetSize,
    double scale,
    double offset,
  ) {
    final inverseScale = 1 / scale;
    final clampedScale = math.min(1.0, scale);
    final sourceWindow = filter.window / clampedScale;
    final maxFilterElementSize = ((sourceWindow + 1) * 2).floor();
    final packed = Int16List((maxFilterElementSize + 2) * targetSize);
    var packedPointer = 0;

    for (var targetPixel = 0; targetPixel < targetSize; targetPixel++) {
      final sourcePixel = (targetPixel + 0.5) * inverseScale + offset;
      final sourceFirst = math.max(0, (sourcePixel - sourceWindow).floor());
      final sourceLast = math.min(
        sourceSize - 1,
        (sourcePixel + sourceWindow).ceil(),
      );
      final filterElementSize = sourceLast - sourceFirst + 1;
      final floatingFilter = Float32List(filterElementSize);
      final fixedFilter = Int16List(filterElementSize);
      var total = 0.0;

      for (
        var sourceSample = sourceFirst, filterIndex = 0;
        sourceSample <= sourceLast;
        sourceSample++, filterIndex++
      ) {
        final value = filter.sample(
          ((sourceSample + 0.5) - sourcePixel) * clampedScale,
        );
        total += value;
        floatingFilter[filterIndex] = value;
      }

      var filterTotal = 0.0;
      for (var index = 0; index < floatingFilter.length; index++) {
        final normalized = floatingFilter[index] / total;
        filterTotal += normalized;
        fixedFilter[index] = _toInt16(_toFixedPoint(normalized));
      }

      // This index intentionally mirrors the Pica bundle. Out-of-range writes
      // to a JavaScript Int16Array are ignored.
      final compensationIndex = targetSize >> 1;
      if (compensationIndex < fixedFilter.length) {
        fixedFilter[compensationIndex] = _toInt16(
          fixedFilter[compensationIndex] + _toFixedPoint(1.0 - filterTotal),
        );
      }

      var leftNotEmpty = 0;
      while (leftNotEmpty < fixedFilter.length &&
          fixedFilter[leftNotEmpty] == 0) {
        leftNotEmpty++;
      }

      if (leftNotEmpty >= fixedFilter.length) {
        packed[packedPointer++] = 0;
        packed[packedPointer++] = 0;
        continue;
      }

      var rightNotEmpty = fixedFilter.length - 1;
      while (rightNotEmpty > 0 && fixedFilter[rightNotEmpty] == 0) {
        rightNotEmpty--;
      }
      final filterShift = sourceFirst + leftNotEmpty;
      final filterSize = rightNotEmpty - leftNotEmpty + 1;
      packed[packedPointer++] = filterShift;
      packed[packedPointer++] = filterSize;
      packed.setRange(
        packedPointer,
        packedPointer + filterSize,
        fixedFilter,
        leftNotEmpty,
      );
      packedPointer += filterSize;
    }

    return packed;
  }

  static void _convolveHorizontal(
    Uint8List source,
    Uint16List target,
    int sourceWidth,
    int sourceHeight,
    int targetWidth,
    Int16List filters,
  ) {
    var sourceOffset = 0;
    var targetOffset = 0;

    for (var sourceY = 0; sourceY < sourceHeight; sourceY++) {
      var filterPointer = 0;
      for (var targetX = 0; targetX < targetWidth; targetX++) {
        final filterShift = filters[filterPointer++];
        var filterSize = filters[filterPointer++];
        var sourcePointer = sourceOffset + filterShift * 4;
        var red = 0;
        var green = 0;
        var blue = 0;
        var alpha = 0;

        while (filterSize > 0) {
          final filterValue = filters[filterPointer++];
          alpha += filterValue * source[sourcePointer + 3];
          blue += filterValue * source[sourcePointer + 2];
          green += filterValue * source[sourcePointer + 1];
          red += filterValue * source[sourcePointer];
          sourcePointer += 4;
          filterSize--;
        }

        target[targetOffset + 3] = _toUint16(_clampNegative(alpha >> 7));
        target[targetOffset + 2] = _toUint16(_clampNegative(blue >> 7));
        target[targetOffset + 1] = _toUint16(_clampNegative(green >> 7));
        target[targetOffset] = _toUint16(_clampNegative(red >> 7));
        targetOffset += sourceHeight * 4;
      }

      targetOffset = (sourceY + 1) * 4;
      sourceOffset = (sourceY + 1) * sourceWidth * 4;
    }
  }

  static void _convolveVertical(
    Uint16List source,
    Uint8List target,
    int sourceWidth,
    int sourceHeight,
    int targetWidth,
    Int16List filters,
  ) {
    var sourceOffset = 0;
    var targetOffset = 0;

    for (var sourceY = 0; sourceY < sourceHeight; sourceY++) {
      var filterPointer = 0;
      for (var targetX = 0; targetX < targetWidth; targetX++) {
        final filterShift = filters[filterPointer++];
        var filterSize = filters[filterPointer++];
        var sourcePointer = sourceOffset + filterShift * 4;
        var red = 0;
        var green = 0;
        var blue = 0;
        var alpha = 0;

        while (filterSize > 0) {
          final filterValue = filters[filterPointer++];
          alpha += filterValue * source[sourcePointer + 3];
          blue += filterValue * source[sourcePointer + 2];
          green += filterValue * source[sourcePointer + 1];
          red += filterValue * source[sourcePointer];
          sourcePointer += 4;
          filterSize--;
        }

        red >>= 7;
        green >>= 7;
        blue >>= 7;
        alpha >>= 7;
        target[targetOffset + 3] = _clampToByte((alpha + (1 << 13)) >> 14);
        target[targetOffset + 2] = _clampToByte((blue + (1 << 13)) >> 14);
        target[targetOffset + 1] = _clampToByte((green + (1 << 13)) >> 14);
        target[targetOffset] = _clampToByte((red + (1 << 13)) >> 14);
        targetOffset += sourceHeight * 4;
      }

      targetOffset = (sourceY + 1) * 4;
      sourceOffset = (sourceY + 1) * sourceWidth * 4;
    }
  }

  static void _convolveHorizontalPremultiplied(
    Uint8List source,
    Uint16List target,
    int sourceWidth,
    int sourceHeight,
    int targetWidth,
    Int16List filters,
  ) {
    var sourceOffset = 0;
    var targetOffset = 0;

    for (var sourceY = 0; sourceY < sourceHeight; sourceY++) {
      var filterPointer = 0;
      for (var targetX = 0; targetX < targetWidth; targetX++) {
        final filterShift = filters[filterPointer++];
        var filterSize = filters[filterPointer++];
        var sourcePointer = sourceOffset + filterShift * 4;
        var red = 0;
        var green = 0;
        var blue = 0;
        var alpha = 0;

        while (filterSize > 0) {
          final filterValue = filters[filterPointer++];
          final sourceAlpha = source[sourcePointer + 3];
          alpha += filterValue * sourceAlpha;
          blue += filterValue * source[sourcePointer + 2] * sourceAlpha;
          green += filterValue * source[sourcePointer + 1] * sourceAlpha;
          red += filterValue * source[sourcePointer] * sourceAlpha;
          sourcePointer += 4;
          filterSize--;
        }

        blue ~/= 255;
        green ~/= 255;
        red ~/= 255;
        target[targetOffset + 3] = _toUint16(_clampNegative(alpha >> 7));
        target[targetOffset + 2] = _toUint16(_clampNegative(blue >> 7));
        target[targetOffset + 1] = _toUint16(_clampNegative(green >> 7));
        target[targetOffset] = _toUint16(_clampNegative(red >> 7));
        targetOffset += sourceHeight * 4;
      }

      targetOffset = (sourceY + 1) * 4;
      sourceOffset = (sourceY + 1) * sourceWidth * 4;
    }
  }

  static void _convolveVerticalPremultiplied(
    Uint16List source,
    Uint8List target,
    int sourceWidth,
    int sourceHeight,
    int targetWidth,
    Int16List filters,
  ) {
    var sourceOffset = 0;
    var targetOffset = 0;

    for (var sourceY = 0; sourceY < sourceHeight; sourceY++) {
      var filterPointer = 0;
      for (var targetX = 0; targetX < targetWidth; targetX++) {
        final filterShift = filters[filterPointer++];
        var filterSize = filters[filterPointer++];
        var sourcePointer = sourceOffset + filterShift * 4;
        var red = 0;
        var green = 0;
        var blue = 0;
        var alpha = 0;

        while (filterSize > 0) {
          final filterValue = filters[filterPointer++];
          alpha += filterValue * source[sourcePointer + 3];
          blue += filterValue * source[sourcePointer + 2];
          green += filterValue * source[sourcePointer + 1];
          red += filterValue * source[sourcePointer];
          sourcePointer += 4;
          filterSize--;
        }

        red >>= 7;
        green >>= 7;
        blue >>= 7;
        alpha >>= 7;
        final outputAlpha = _clampToByte((alpha + (1 << 13)) >> 14);
        if (outputAlpha > 0) {
          red = red * 255 ~/ outputAlpha;
          green = green * 255 ~/ outputAlpha;
          blue = blue * 255 ~/ outputAlpha;
        }

        target[targetOffset + 3] = outputAlpha;
        target[targetOffset + 2] = _clampToByte((blue + (1 << 13)) >> 14);
        target[targetOffset + 1] = _clampToByte((green + (1 << 13)) >> 14);
        target[targetOffset] = _clampToByte((red + (1 << 13)) >> 14);
        targetOffset += sourceHeight * 4;
      }

      targetOffset = (sourceY + 1) * 4;
      sourceOffset = (sourceY + 1) * sourceWidth * 4;
    }
  }

  static List<_PicaStage> _createStages(
    int sourceWidth,
    int sourceHeight,
    int targetWidth,
    int targetHeight,
  ) {
    final scaleX = targetWidth / sourceWidth;
    final scaleY = targetHeight / sourceHeight;
    const minimumInnerTileSize = 2;
    const minimumScale =
        (2 * destinationTileBorder + minimumInnerTileSize + 1) / sourceTileSize;
    if (minimumScale > 0.5) {
      return [_PicaStage(targetWidth, targetHeight)];
    }

    final stageCount =
        (math.log(math.min(scaleX, scaleY)) / math.log(minimumScale)).ceil();
    if (stageCount <= 1) {
      return [_PicaStage(targetWidth, targetHeight)];
    }

    return List.generate(stageCount, (index) {
      final width = math
          .pow(
            math.pow(sourceWidth, stageCount - index - 1) *
                math.pow(targetWidth, index + 1),
            1 / stageCount,
          )
          .round();
      final height = math
          .pow(
            math.pow(sourceHeight, stageCount - index - 1) *
                math.pow(targetHeight, index + 1),
            1 / stageCount,
          )
          .round();
      return _PicaStage(width, height);
    });
  }

  static List<_PicaTile> _createTiles({
    required int sourceWidth,
    required int sourceHeight,
    required int targetWidth,
    required int targetHeight,
  }) {
    final scaleX = targetWidth / sourceWidth;
    final scaleY = targetHeight / sourceHeight;
    final innerTileWidth =
        _pixelFloor(sourceTileSize * scaleX) - 2 * destinationTileBorder;
    final innerTileHeight =
        _pixelFloor(sourceTileSize * scaleY) - 2 * destinationTileBorder;
    if (innerTileWidth < 1 || innerTileHeight < 1) {
      throw StateError('Pica target tile width or height is too small.');
    }

    final tiles = <_PicaTile>[];
    for (var innerY = 0; innerY < targetHeight; innerY += innerTileHeight) {
      for (var innerX = 0; innerX < targetWidth; innerX += innerTileWidth) {
        var targetX = innerX - destinationTileBorder;
        if (targetX < 0) targetX = 0;
        var targetTileWidth =
            innerX + innerTileWidth + destinationTileBorder - targetX;
        if (targetX + targetTileWidth >= targetWidth) {
          targetTileWidth = targetWidth - targetX;
        }

        var targetY = innerY - destinationTileBorder;
        if (targetY < 0) targetY = 0;
        var targetTileHeight =
            innerY + innerTileHeight + destinationTileBorder - targetY;
        if (targetY + targetTileHeight >= targetHeight) {
          targetTileHeight = targetHeight - targetY;
        }

        final sourceX = _pixelFloor(targetX / scaleX);
        final sourceY = _pixelFloor(targetY / scaleY);
        final sourceTileWidth = _pixelCeil(targetTileWidth / scaleX);
        final sourceTileHeight = _pixelCeil(targetTileHeight / scaleY);
        tiles.add(
          _PicaTile(
            targetX: targetX,
            targetY: targetY,
            targetWidth: targetTileWidth,
            targetHeight: targetTileHeight,
            targetInnerX: innerX,
            targetInnerY: innerY,
            targetInnerWidth: innerTileWidth,
            targetInnerHeight: innerTileHeight,
            offsetX: targetX / scaleX - _pixelFloor(targetX / scaleX),
            offsetY: targetY / scaleY - _pixelFloor(targetY / scaleY),
            scaleX: scaleX,
            scaleY: scaleY,
            x: sourceX,
            y: sourceY,
            width: math.min(sourceTileWidth, sourceWidth - sourceX),
            height: math.min(sourceTileHeight, sourceHeight - sourceY),
          ),
        );
      }
    }
    return tiles;
  }

  static Uint8List _cropRgba(
    _PicaImageBuffer source,
    _PicaTile tile,
    _PicaResizeScratch scratch,
  ) {
    if (tile.x == 0 &&
        tile.y == 0 &&
        tile.width == source.width &&
        tile.height == source.height) {
      return source.bytes;
    }

    final cropped = scratch.sourceTile(tile.width * tile.height * 4);
    final rowLength = tile.width * 4;
    for (var row = 0; row < tile.height; row++) {
      final sourceStart = ((tile.y + row) * source.width + tile.x) * 4;
      cropped.setRange(
        row * rowLength,
        (row + 1) * rowLength,
        source.bytes,
        sourceStart,
      );
    }
    return cropped;
  }

  static void _copyInnerTile(
    Uint8List source, {
    required _PicaTile tile,
    required Uint8List target,
    required int targetWidth,
    required int targetHeight,
  }) {
    final sourceInnerX = tile.targetInnerX - tile.targetX;
    final sourceInnerY = tile.targetInnerY - tile.targetY;
    final copyWidth = math.min(
      tile.targetInnerWidth,
      targetWidth - tile.targetInnerX,
    );
    final copyHeight = math.min(
      tile.targetInnerHeight,
      targetHeight - tile.targetInnerY,
    );
    final copyLength = copyWidth * 4;

    for (var row = 0; row < copyHeight; row++) {
      final sourceStart =
          ((sourceInnerY + row) * tile.targetWidth + sourceInnerX) * 4;
      final targetStart =
          ((tile.targetInnerY + row) * targetWidth + tile.targetInnerX) * 4;
      target.setRange(
        targetStart,
        targetStart + copyLength,
        source,
        sourceStart,
      );
    }
  }

  static bool _hasAlpha(Uint8List source) {
    for (var pointer = 3; pointer < source.length; pointer += 4) {
      if (source[pointer] != 255) return true;
    }
    return false;
  }

  static int _pixelFloor(double value) {
    final nearest = value.round();
    if ((value - nearest).abs() < _pixelEpsilon) return nearest;
    return value.floor();
  }

  static int _pixelCeil(double value) {
    final nearest = value.round();
    if ((value - nearest).abs() < _pixelEpsilon) return nearest;
    return value.ceil();
  }

  static int _toFixedPoint(double value) {
    return _javaScriptRound(value * _fixedPointScale);
  }

  static int _javaScriptRound(double value) => (value + 0.5).floor();

  static int _toInt16(int value) => value.toSigned(16);

  static int _toUint16(int value) => value.toUnsigned(16);

  static int _clampNegative(int value) => value < 0 ? 0 : value;

  static int _clampToByte(int value) => value.clamp(0, 255);
}

enum _PicaFilter {
  hamming(1.0),
  lanczos3(3.0);

  const _PicaFilter(this.window);

  final double window;

  double sample(double value) {
    var distance = value;
    if (distance < 0) distance = -distance;
    return switch (this) {
      _PicaFilter.hamming => _hamming(distance),
      _PicaFilter.lanczos3 => _lanczos3(distance),
    };
  }

  static double _hamming(double value) {
    if (value >= 1.0) return 0.0;
    if (value < 1.19209290e-7) return 1.0;
    final radians = value * math.pi;
    return math.sin(radians) / radians * (0.54 + 0.46 * math.cos(radians));
  }

  static double _lanczos3(double value) {
    if (value >= 3.0) return 0.0;
    if (value < 1.19209290e-7) return 1.0;
    final radians = value * math.pi;
    return math.sin(radians) /
        radians *
        math.sin(radians / 3.0) /
        (radians / 3.0);
  }
}

class _PicaImageBuffer {
  const _PicaImageBuffer({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

class _PicaResizeScratch {
  Uint8List _sourceTile = Uint8List(0);
  Uint16List _intermediate = Uint16List(0);
  Uint8List _targetTile = Uint8List(0);

  Uint8List sourceTile(int length) {
    if (_sourceTile.length < length) {
      _sourceTile = Uint8List(length);
    }
    return _sourceTile.buffer.asUint8List(0, length);
  }

  Uint16List intermediate(int length) {
    if (_intermediate.length < length) {
      _intermediate = Uint16List(length);
    }
    return _intermediate.buffer.asUint16List(0, length);
  }

  Uint8List targetTile(int length) {
    if (_targetTile.length < length) {
      _targetTile = Uint8List(length);
    }
    return _targetTile.buffer.asUint8List(0, length);
  }
}

class _PicaStage {
  const _PicaStage(this.width, this.height);

  final int width;
  final int height;
}

class _PicaTile {
  const _PicaTile({
    required this.targetX,
    required this.targetY,
    required this.targetWidth,
    required this.targetHeight,
    required this.targetInnerX,
    required this.targetInnerY,
    required this.targetInnerWidth,
    required this.targetInnerHeight,
    required this.offsetX,
    required this.offsetY,
    required this.scaleX,
    required this.scaleY,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int targetX;
  final int targetY;
  final int targetWidth;
  final int targetHeight;
  final int targetInnerX;
  final int targetInnerY;
  final int targetInnerWidth;
  final int targetInnerHeight;
  final double offsetX;
  final double offsetY;
  final double scaleX;
  final double scaleY;
  final int x;
  final int y;
  final int width;
  final int height;
}
