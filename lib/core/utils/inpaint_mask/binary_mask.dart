import 'dart:typed_data';

/// Row-major binary coverage mask. Values are normalized to 0 or 1.
class BinaryMask {
  BinaryMask({
    required this.pixels,
    required this.width,
    required this.height,
  }) {
    if (width <= 0 || height <= 0 || pixels.length != width * height) {
      throw ArgumentError('Invalid binary mask dimensions.');
    }
  }

  final Uint8List pixels;
  final int width;
  final int height;

  int indexOf(int x, int y) => y * width + x;

  /// Places this mask at ([left], [top]) of an empty canvas; parts outside
  /// the canvas are dropped.
  BinaryMask placedIn({
    required int canvasWidth,
    required int canvasHeight,
    required int left,
    required int top,
  }) {
    final placed = Uint8List(canvasWidth * canvasHeight);
    final firstColumn = left < 0 ? -left : 0;
    final lastColumn = canvasWidth - left < width ? canvasWidth - left : width;
    if (firstColumn < lastColumn) {
      for (var y = 0; y < height; y++) {
        final canvasY = top + y;
        if (canvasY < 0 || canvasY >= canvasHeight) continue;
        placed.setRange(
          canvasY * canvasWidth + left + firstColumn,
          canvasY * canvasWidth + left + lastColumn,
          pixels,
          indexOf(firstColumn, y),
        );
      }
    }
    return BinaryMask(pixels: placed, width: canvasWidth, height: canvasHeight);
  }
}

enum MaskFillRegionStatus {
  emptyMask,
  outOfBounds,
  clickedMaskedPixel,
  openRegion,
  filled,
}

/// Editor overlay PNG cropped to the bounding box of its masked pixels.
/// [left] and [top] locate the crop inside the source mask.
class MaskOverlayPatch {
  const MaskOverlayPatch({
    required this.bytes,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int left;
  final int top;
  final int width;
  final int height;
}

class MaskFillRegionResult {
  const MaskFillRegionResult({required this.status, this.addedPatch});

  final MaskFillRegionStatus status;

  /// Only the newly enclosed pixels; the mask that formed the outline is not
  /// part of it.
  final MaskOverlayPatch? addedPatch;
}

/// NovelAI samples inpaint masks to a 1/8 latent grid for every model.
const novelAiLatentGridSize = 8;

class NovelAiInpaintMaskArtifacts {
  const NovelAiInpaintMaskArtifacts({
    required this.requestMaskBytes,
    required this.latentMaskBytes,
    required this.compositeMaskBytes,
    required this.requestWidth,
    required this.requestHeight,
    required this.latentWidth,
    required this.latentHeight,
    required this.isLatentMaskEmpty,
  });

  final Uint8List requestMaskBytes;
  final Uint8List latentMaskBytes;
  final Uint8List compositeMaskBytes;
  final int requestWidth;
  final int requestHeight;
  final int latentWidth;
  final int latentHeight;
  final bool isLatentMaskEmpty;
}
