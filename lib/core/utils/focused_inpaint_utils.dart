import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import 'inpaint_mask_utils.dart';

class FocusedInpaintCrop {
  const FocusedInpaintCrop({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int x;
  final int y;
  final int width;
  final int height;
}

class FocusedInpaintFrame {
  const FocusedInpaintFrame({
    required this.focusBounds,
    required this.contextCrop,
  });

  final FocusedInpaintCrop focusBounds;
  final FocusedInpaintCrop contextCrop;
}

class FocusedInpaintRequest {
  FocusedInpaintRequest({
    required this.requestSourceImage,
    required this.requestMaskImage,
    required this.targetWidth,
    required this.targetHeight,
    required this.crop,
    required img.Image originalSource,
    required img.Image compositeMaskAtCrop,
  }) : _originalSource = img.Image.from(originalSource, noAnimation: true),
       _compositeMaskAtCrop = img.Image.from(
         compositeMaskAtCrop,
         noAnimation: true,
       );

  final Uint8List requestSourceImage;
  final Uint8List requestMaskImage;
  final int targetWidth;
  final int targetHeight;
  final FocusedInpaintCrop crop;
  final img.Image _originalSource;
  final img.Image _compositeMaskAtCrop;

  int get originalSourceWidth => _originalSource.width;

  int get originalSourceHeight => _originalSource.height;

  Uint8List compositeGeneratedImage(Uint8List generatedBytes) {
    final generated = img.decodeImage(generatedBytes);
    if (generated == null) {
      return generatedBytes;
    }
    final resizedGenerated = img.copyResize(
      generated,
      width: crop.width,
      height: crop.height,
      interpolation: img.Interpolation.cubic,
    );
    final composed = img.Image.from(_originalSource, noAnimation: true);
    img.compositeImage(
      composed,
      resizedGenerated,
      dstX: crop.x,
      dstY: crop.y,
      dstW: crop.width,
      dstH: crop.height,
      mask: _compositeMaskAtCrop,
      blend: img.BlendMode.direct,
    );

    return Uint8List.fromList(img.encodePng(composed));
  }
}

class FocusedInpaintUtils {
  FocusedInpaintUtils._();

  static const int _dimensionStep = 64;
  static const int _maxDimension = 1216;
  static const int _focusedTargetAreaPixels = 832 * 1216;

  static FocusedInpaintCrop? resolvePreviewCrop({
    required Uint8List sourceImage,
    Uint8List? maskImage,
    Rect? focusedSelectionRect,
    required double minContextMegaPixels,
  }) {
    return resolvePreviewFrame(
      sourceImage: sourceImage,
      maskImage: maskImage,
      focusedSelectionRect: focusedSelectionRect,
      minContextMegaPixels: minContextMegaPixels,
    )?.contextCrop;
  }

  static FocusedInpaintFrame? resolvePreviewFrame({
    required Uint8List sourceImage,
    Uint8List? maskImage,
    Rect? focusedSelectionRect,
    required double minContextMegaPixels,
  }) {
    final decodedSource = img.decodeImage(sourceImage);
    if (decodedSource == null) {
      return null;
    }

    final selectionBounds = focusedSelectionRect == null
        ? null
        : _resolveSelectionBounds(
            focusedSelectionRect,
            sourceWidth: decodedSource.width,
            sourceHeight: decodedSource.height,
          );
    final maskBounds = _resolveMaskBounds(maskImage);
    final focusBounds = _resolveFocusBounds(
      selectionBounds: selectionBounds,
      maskBounds: maskBounds,
    );
    if (focusBounds == null) {
      return null;
    }

    return FocusedInpaintFrame(
      focusBounds: focusBounds,
      contextCrop: _resolveCrop(
        sourceWidth: decodedSource.width,
        sourceHeight: decodedSource.height,
        bounds: focusBounds,
        minContextMegaPixels: minContextMegaPixels,
      ),
    );
  }

  static FocusedInpaintCrop? resolveContextCropForSelection({
    required int sourceWidth,
    required int sourceHeight,
    required Rect selectionRect,
    required double minContextMegaPixels,
  }) {
    final selectionBounds = _resolveSelectionBounds(
      selectionRect,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    );
    if (selectionBounds == null) {
      return null;
    }

    return _resolveCrop(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      bounds: selectionBounds,
      minContextMegaPixels: minContextMegaPixels,
    );
  }

  static FocusedInpaintFrame? resolvePreviewFrameForSelection({
    required int sourceWidth,
    required int sourceHeight,
    required Rect selectionRect,
    required double minContextMegaPixels,
  }) {
    final selectionBounds = _resolveSelectionBounds(
      selectionRect,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    );
    if (selectionBounds == null) {
      return null;
    }

    return FocusedInpaintFrame(
      focusBounds: selectionBounds,
      contextCrop: _resolveCrop(
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        bounds: selectionBounds,
        minContextMegaPixels: minContextMegaPixels,
      ),
    );
  }

  static (int, int)? resolveRequestSizeForSelection({
    required int sourceWidth,
    required int sourceHeight,
    required Rect selectionRect,
    required double minContextMegaPixels,
  }) {
    final crop = resolveContextCropForSelection(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      selectionRect: selectionRect,
      minContextMegaPixels: minContextMegaPixels,
    );
    if (crop == null) {
      return null;
    }

    return _resolveTargetSize(
      cropWidth: crop.width,
      cropHeight: crop.height,
      minContextMegaPixels: minContextMegaPixels,
    );
  }

  static FocusedInpaintRequest? prepareRequest({
    required Uint8List sourceImage,
    required Uint8List maskImage,
    Rect? focusedSelectionRect,
    required double minContextMegaPixels,
  }) {
    final context = _resolveFocusedContext(
      sourceImage: sourceImage,
      maskImage: maskImage,
      focusedSelectionRect: focusedSelectionRect,
      minContextMegaPixels: minContextMegaPixels,
    );
    if (context == null) {
      return null;
    }

    final targetSize = _resolveTargetSize(
      cropWidth: context.crop.width,
      cropHeight: context.crop.height,
      minContextMegaPixels: minContextMegaPixels,
    );

    final croppedSource = img.copyCrop(
      context.source,
      x: context.crop.x,
      y: context.crop.y,
      width: context.crop.width,
      height: context.crop.height,
    );
    final croppedMask = img.copyCrop(
      context.mask,
      x: context.crop.x,
      y: context.crop.y,
      width: context.crop.width,
      height: context.crop.height,
    );

    final resizedSource = img.copyResize(
      croppedSource,
      width: targetSize.$1,
      height: targetSize.$2,
      interpolation: img.Interpolation.cubic,
    );
    final resizedMask = img.copyResize(
      croppedMask,
      width: targetSize.$1,
      height: targetSize.$2,
      interpolation: img.Interpolation.nearest,
    );

    return FocusedInpaintRequest(
      requestSourceImage: Uint8List.fromList(img.encodePng(resizedSource)),
      requestMaskImage: Uint8List.fromList(img.encodePng(resizedMask)),
      targetWidth: targetSize.$1,
      targetHeight: targetSize.$2,
      crop: context.crop,
      originalSource: context.source,
      compositeMaskAtCrop: context.compositeMaskAtCrop,
    );
  }

  static ({
    img.Image source,
    img.Image mask,
    img.Image compositeMaskAtCrop,
    FocusedInpaintCrop crop,
  })?
  _resolveFocusedContext({
    required Uint8List sourceImage,
    required Uint8List maskImage,
    Rect? focusedSelectionRect,
    required double minContextMegaPixels,
  }) {
    final decodedSource = img.decodeImage(sourceImage);
    if (decodedSource == null) {
      return null;
    }

    final normalizedMaskBytes = InpaintMaskUtils.normalizeMaskBytes(maskImage);
    if (!InpaintMaskUtils.hasMaskedPixels(normalizedMaskBytes)) {
      return null;
    }

    final decodedMask = img.decodeImage(normalizedMaskBytes);
    if (decodedMask == null) {
      return null;
    }

    final maskBounds = _findMaskBounds(decodedMask);
    final selectionBounds = focusedSelectionRect == null
        ? null
        : _resolveSelectionBounds(
            focusedSelectionRect,
            sourceWidth: decodedSource.width,
            sourceHeight: decodedSource.height,
          );
    final focusBounds = _resolveFocusBounds(
      selectionBounds: selectionBounds,
      maskBounds: maskBounds,
    );
    if (focusBounds == null) {
      return null;
    }

    final crop = _resolveCrop(
      sourceWidth: decodedSource.width,
      sourceHeight: decodedSource.height,
      bounds: focusBounds,
      minContextMegaPixels: minContextMegaPixels,
    );

    return (
      source: decodedSource,
      mask: decodedMask,
      compositeMaskAtCrop: img.copyCrop(
        decodedMask,
        x: crop.x,
        y: crop.y,
        width: crop.width,
        height: crop.height,
      ),
      crop: crop,
    );
  }

  static FocusedInpaintCrop? _findMaskBounds(img.Image mask) {
    var minX = mask.width;
    var minY = mask.height;
    var maxX = -1;
    var maxY = -1;

    for (var y = 0; y < mask.height; y++) {
      for (var x = 0; x < mask.width; x++) {
        final pixel = mask.getPixel(x, y);
        if (pixel.r.toInt() < 128) {
          continue;
        }

        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }

    if (maxX < minX || maxY < minY) {
      return null;
    }

    return FocusedInpaintCrop(
      x: minX,
      y: minY,
      width: maxX - minX + 1,
      height: maxY - minY + 1,
    );
  }

  static FocusedInpaintCrop? _resolveMaskBounds(Uint8List? maskImage) {
    if (maskImage == null) {
      return null;
    }

    final normalizedMaskBytes = InpaintMaskUtils.normalizeMaskBytes(maskImage);
    if (!InpaintMaskUtils.hasMaskedPixels(normalizedMaskBytes)) {
      return null;
    }

    final decodedMask = img.decodeImage(normalizedMaskBytes);
    if (decodedMask == null) {
      return null;
    }

    return _findMaskBounds(decodedMask);
  }

  static FocusedInpaintCrop? _resolveSelectionBounds(
    Rect rect, {
    required int sourceWidth,
    required int sourceHeight,
  }) {
    final left = rect.left.clamp(0.0, sourceWidth.toDouble());
    final top = rect.top.clamp(0.0, sourceHeight.toDouble());
    final right = rect.right.clamp(left, sourceWidth.toDouble());
    final bottom = rect.bottom.clamp(top, sourceHeight.toDouble());

    final width = (right - left).round();
    final height = (bottom - top).round();
    if (width <= 2 || height <= 2) {
      return null;
    }

    return FocusedInpaintCrop(
      x: left.floor(),
      y: top.floor(),
      width: width,
      height: height,
    );
  }

  static FocusedInpaintCrop? _resolveFocusBounds({
    FocusedInpaintCrop? selectionBounds,
    FocusedInpaintCrop? maskBounds,
  }) {
    return selectionBounds ?? maskBounds;
  }

  static FocusedInpaintCrop _resolveCrop({
    required int sourceWidth,
    required int sourceHeight,
    required FocusedInpaintCrop bounds,
    required double minContextMegaPixels,
  }) {
    final padding = minContextMegaPixels.round().clamp(16, 192);

    return _expandAndClamp(
      centerX: bounds.x + bounds.width / 2,
      centerY: bounds.y + bounds.height / 2,
      width: bounds.width + padding * 2,
      height: bounds.height + padding * 2,
      maxWidth: sourceWidth,
      maxHeight: sourceHeight,
    );
  }

  static FocusedInpaintCrop _expandAndClamp({
    required double centerX,
    required double centerY,
    required int width,
    required int height,
    required int maxWidth,
    required int maxHeight,
  }) {
    final resolvedWidth = width.clamp(1, maxWidth);
    final resolvedHeight = height.clamp(1, maxHeight);

    var x = (centerX - resolvedWidth / 2).floor();
    var y = (centerY - resolvedHeight / 2).floor();

    x = x.clamp(0, maxWidth - resolvedWidth);
    y = y.clamp(0, maxHeight - resolvedHeight);

    return FocusedInpaintCrop(
      x: x,
      y: y,
      width: resolvedWidth,
      height: resolvedHeight,
    );
  }

  static (int, int) _resolveTargetSize({
    required int cropWidth,
    required int cropHeight,
    required double minContextMegaPixels,
  }) {
    final cropArea = cropWidth * cropHeight;
    final scale = math.sqrt(math.max(_focusedTargetAreaPixels / cropArea, 1.0));

    var scaledWidth = (cropWidth * scale).ceil();
    var scaledHeight = (cropHeight * scale).ceil();

    if (scaledWidth > _maxDimension || scaledHeight > _maxDimension) {
      final dimensionScale = math.min(
        _maxDimension / scaledWidth,
        _maxDimension / scaledHeight,
      );
      scaledWidth = math.max(1, (scaledWidth * dimensionScale).floor());
      scaledHeight = math.max(1, (scaledHeight * dimensionScale).floor());
    }

    return (
      _normalizeDimension(scaledWidth),
      _normalizeDimension(scaledHeight),
    );
  }

  static int _normalizeDimension(int value) {
    final normalized =
        ((value + (_dimensionStep ~/ 2)) ~/ _dimensionStep) * _dimensionStep;
    return normalized.clamp(_dimensionStep, _maxDimension);
  }
}
