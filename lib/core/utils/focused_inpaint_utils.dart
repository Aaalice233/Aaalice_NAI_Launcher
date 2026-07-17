import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import '../models/image_generation_artifact.dart';
import 'inpaint_mask_utils.dart';
import 'isolate_pool.dart';
import 'pica_lanczos_resizer.dart';

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

  int get area => width * height;

  Rect get rect => Rect.fromLTWH(
    x.toDouble(),
    y.toDouble(),
    width.toDouble(),
    height.toDouble(),
  );
}

class FocusedInpaintFrame {
  const FocusedInpaintFrame({
    required this.focusBounds,
    required this.contextCrop,
  });

  final FocusedInpaintCrop focusBounds;
  final FocusedInpaintCrop contextCrop;
}

enum FocusedInpaintRequestMode { upscaleToTarget, preserveCrop }

class FocusedInpaintGeometry extends FocusedInpaintFrame {
  const FocusedInpaintGeometry({
    required super.focusBounds,
    required super.contextCrop,
    required this.requestWidth,
    required this.requestHeight,
    required this.requestMode,
    required this.wasDynamicallyConstrained,
  });

  final int requestWidth;
  final int requestHeight;
  final FocusedInpaintRequestMode requestMode;
  final bool wasDynamicallyConstrained;

  int get requestArea => requestWidth * requestHeight;

  bool get isUpscaled =>
      requestMode == FocusedInpaintRequestMode.upscaleToTarget;
}

class FocusedInpaintRequest {
  /// [originalSource] ownership is transferred to this request.
  FocusedInpaintRequest({
    required this.requestSourceImage,
    required this.requestMaskImage,
    required this.targetWidth,
    required this.targetHeight,
    required this.crop,
    required this.geometry,
    required img.Image originalSource,
  }) : _originalSource = originalSource;

  final Uint8List requestSourceImage;
  final Uint8List requestMaskImage;
  final int targetWidth;
  final int targetHeight;
  final FocusedInpaintCrop crop;
  final FocusedInpaintGeometry geometry;
  final img.Image _originalSource;

  int get originalSourceWidth => _originalSource.width;

  int get originalSourceHeight => _originalSource.height;

  Future<ImageGenerationArtifact> composeGeneratedImageArtifactAsync(
    Uint8List generatedBytes,
    NovelAiInpaintMaskArtifacts maskArtifacts,
  ) {
    return ComputeGate().runIsolate(
      () => composeGeneratedImageArtifact(generatedBytes, maskArtifacts),
    );
  }

  ImageGenerationArtifact composeGeneratedImageArtifact(
    Uint8List generatedBytes,
    NovelAiInpaintMaskArtifacts maskArtifacts,
  ) {
    final generated = img.decodeImage(generatedBytes);
    final compositeMask = img.decodeImage(maskArtifacts.compositeMaskBytes);
    if (generated == null || compositeMask == null) {
      return ImageGenerationArtifact(displayImageBytes: generatedBytes);
    }

    final requestGenerated =
        generated.width == targetWidth && generated.height == targetHeight
        ? generated
        : PicaLanczosResizer.resizeImage(
            generated,
            width: targetWidth,
            height: targetHeight,
          );
    if (compositeMask.width != targetWidth ||
        compositeMask.height != targetHeight) {
      return ImageGenerationArtifact(displayImageBytes: generatedBytes);
    }

    final requestPatch = InpaintMaskUtils.applyCompositeMaskToGeneratedImage(
      requestGenerated,
      compositeMask,
    );
    final cropPatch = PicaLanczosResizer.resizeImage(
      requestPatch,
      width: crop.width,
      height: crop.height,
    );
    final fullPatch = img.Image(
      width: _originalSource.width,
      height: _originalSource.height,
      numChannels: 4,
    );
    img.fill(fullPatch, color: img.ColorRgba8(0, 0, 0, 0));
    img.compositeImage(
      fullPatch,
      cropPatch,
      dstX: crop.x,
      dstY: crop.y,
      blend: img.BlendMode.direct,
    );

    final display = img.Image.from(_originalSource, noAnimation: true);
    img.compositeImage(
      display,
      cropPatch,
      dstX: crop.x,
      dstY: crop.y,
      blend: img.BlendMode.alpha,
    );
    return ImageGenerationArtifact(
      displayImageBytes: Uint8List.fromList(img.encodePng(display, level: 1)),
      transparentPatchBytes: Uint8List.fromList(
        img.encodePng(fullPatch, level: 1),
      ),
    );
  }

  /// Compatibility wrapper for callers that do not already own artifacts.
  Future<Uint8List> compositeGeneratedImageAsync(Uint8List generatedBytes) {
    return ComputeGate().runIsolate(
      () => compositeGeneratedImage(generatedBytes),
    );
  }

  Uint8List compositeGeneratedImage(Uint8List generatedBytes) {
    final artifacts = InpaintMaskUtils.prepareNovelAiInpaintMaskArtifacts(
      requestMaskImage,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    return composeGeneratedImageArtifact(
      generatedBytes,
      artifacts,
    ).displayImageBytes;
  }
}

class FocusedInpaintUtils {
  FocusedInpaintUtils._();

  // NovelAI web build ae6a6aa-production, verified 2026-07-16.
  static const int dimensionStep = 64;
  static const int focusedTargetAreaPixels = 1048576;
  static const int maxRequestAreaPixels = 3145728;

  static FocusedInpaintGeometry? resolveGeometryForSelection({
    required int sourceWidth,
    required int sourceHeight,
    required Rect selectionRect,
    required double minContextMegaPixels,
    Offset? fixedAnchor,
  }) {
    if (sourceWidth <= 0 || sourceHeight <= 0) {
      return null;
    }

    final originalBounds = _resolveSelectionBounds(
      selectionRect,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    );
    if (originalBounds == null) {
      return null;
    }

    final originalCrop = _resolveCrop(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      bounds: originalBounds,
      minContextMegaPixels: minContextMegaPixels,
    );
    final mustConstrain = originalCrop.area > maxRequestAreaPixels;
    final constrainedRect = mustConstrain
        ? _constrainSelectionRectToMaxArea(
            selectionRect,
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            minContextMegaPixels: minContextMegaPixels,
            fixedAnchor: fixedAnchor,
          )
        : selectionRect;
    final focusBounds = _resolveSelectionBounds(
      constrainedRect,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    );
    if (focusBounds == null) {
      return null;
    }

    return _resolveGeometryFromBounds(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      focusBounds: focusBounds,
      minContextMegaPixels: minContextMegaPixels,
      wasDynamicallyConstrained: mustConstrain,
    );
  }

  static Rect? constrainSelectionRect({
    required int sourceWidth,
    required int sourceHeight,
    required Rect selectionRect,
    required double minContextMegaPixels,
    Offset? fixedAnchor,
  }) {
    return resolveGeometryForSelection(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      selectionRect: selectionRect,
      minContextMegaPixels: minContextMegaPixels,
      fixedAnchor: fixedAnchor,
    )?.focusBounds.rect;
  }

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

    final maskBounds = _resolveMaskBounds(maskImage);
    final focusRect = focusedSelectionRect ?? maskBounds?.rect;
    if (focusRect == null) {
      return null;
    }

    return resolveGeometryForSelection(
      sourceWidth: decodedSource.width,
      sourceHeight: decodedSource.height,
      selectionRect: focusRect,
      minContextMegaPixels: minContextMegaPixels,
    );
  }

  static FocusedInpaintCrop? resolveContextCropForSelection({
    required int sourceWidth,
    required int sourceHeight,
    required Rect selectionRect,
    required double minContextMegaPixels,
  }) {
    return resolveGeometryForSelection(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      selectionRect: selectionRect,
      minContextMegaPixels: minContextMegaPixels,
    )?.contextCrop;
  }

  static FocusedInpaintFrame? resolvePreviewFrameForSelection({
    required int sourceWidth,
    required int sourceHeight,
    required Rect selectionRect,
    required double minContextMegaPixels,
  }) {
    return resolveGeometryForSelection(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      selectionRect: selectionRect,
      minContextMegaPixels: minContextMegaPixels,
    );
  }

  static (int, int)? resolveRequestSizeForSelection({
    required int sourceWidth,
    required int sourceHeight,
    required Rect selectionRect,
    required double minContextMegaPixels,
  }) {
    final geometry = resolveGeometryForSelection(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      selectionRect: selectionRect,
      minContextMegaPixels: minContextMegaPixels,
    );
    if (geometry == null) {
      return null;
    }

    return (geometry.requestWidth, geometry.requestHeight);
  }

  /// 仅根据蒙版字节计算聚焦重绘请求尺寸的轻量路径。
  ///
  /// 目标尺寸只由蒙版外接矩形决定，与蒙版内部形状无关，因此这里
  /// 不做 [prepareRequest] 中的裁剪、缩放和 PNG 编码，结果与其
  /// targetWidth/targetHeight 一致。蒙版默认与源图同尺寸（重绘
  /// 流程的既有约定），外接矩形按蒙版自身宽高收敛。
  static FocusedInpaintGeometry? resolveGeometryForMask({
    required Uint8List maskImage,
    required double minContextMegaPixels,
  }) {
    final binaryMask = InpaintMaskUtils.decodeBinaryMask(maskImage);
    if (binaryMask == null) {
      return null;
    }

    final bounds = _findBinaryMaskBounds(
      binaryMask.mask,
      binaryMask.width,
      binaryMask.height,
    );
    if (bounds == null) {
      return null;
    }

    return resolveGeometryForSelection(
      sourceWidth: binaryMask.width,
      sourceHeight: binaryMask.height,
      selectionRect: bounds.rect,
      minContextMegaPixels: minContextMegaPixels,
    );
  }

  static (int, int)? resolveRequestSizeForMask({
    required Uint8List maskImage,
    required double minContextMegaPixels,
  }) {
    final geometry = resolveGeometryForMask(
      maskImage: maskImage,
      minContextMegaPixels: minContextMegaPixels,
    );
    if (geometry == null) {
      return null;
    }

    return (geometry.requestWidth, geometry.requestHeight);
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

    final croppedSource = img.copyCrop(
      context.source,
      x: context.geometry.contextCrop.x,
      y: context.geometry.contextCrop.y,
      width: context.geometry.contextCrop.width,
      height: context.geometry.contextCrop.height,
    );
    final croppedMask = img.copyCrop(
      context.mask,
      x: context.geometry.contextCrop.x,
      y: context.geometry.contextCrop.y,
      width: context.geometry.contextCrop.width,
      height: context.geometry.contextCrop.height,
    );

    final resizedSource = PicaLanczosResizer.resizeImage(
      croppedSource,
      width: context.geometry.requestWidth,
      height: context.geometry.requestHeight,
    );

    return FocusedInpaintRequest(
      // 仅作为请求载体、不落盘：用最快压缩等级换编码时间（像素无损）。
      requestSourceImage: Uint8List.fromList(
        img.encodePng(resizedSource, level: 1),
      ),
      requestMaskImage: Uint8List.fromList(
        img.encodePng(croppedMask, level: 1),
      ),
      targetWidth: context.geometry.requestWidth,
      targetHeight: context.geometry.requestHeight,
      crop: context.geometry.contextCrop,
      geometry: context.geometry,
      originalSource: context.source,
    );
  }

  /// [prepareRequest] 的后台 isolate 版本。
  ///
  /// 完整流程包含源图/蒙版解码、逐像素扫描、裁剪缩放与两次 PNG 编码，
  /// 大图下同步执行会阻塞 UI isolate 数秒；与源图归一化一样统一走
  /// [ComputeGate] 限制并发。
  static Future<FocusedInpaintRequest?> prepareRequestAsync({
    required Uint8List sourceImage,
    required Uint8List maskImage,
    Rect? focusedSelectionRect,
    required double minContextMegaPixels,
  }) {
    return ComputeGate().runIsolate(
      () => prepareRequest(
        sourceImage: sourceImage,
        maskImage: maskImage,
        focusedSelectionRect: focusedSelectionRect,
        minContextMegaPixels: minContextMegaPixels,
      ),
    );
  }

  static ({img.Image source, img.Image mask, FocusedInpaintGeometry geometry})?
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

    final binaryMask = InpaintMaskUtils.decodeBinaryMask(maskImage);
    if (binaryMask == null) {
      return null;
    }

    final maskBounds = _findBinaryMaskBounds(
      binaryMask.mask,
      binaryMask.width,
      binaryMask.height,
    );
    if (maskBounds == null) {
      // 与旧的 hasMaskedPixels 检查等价：空蒙版直接禁用聚焦重绘。
      return null;
    }

    final decodedMask = img.decodeImage(maskImage);
    if (decodedMask == null ||
        decodedMask.width != decodedSource.width ||
        decodedMask.height != decodedSource.height) {
      return null;
    }
    final focusRect = focusedSelectionRect ?? maskBounds.rect;
    final geometry = resolveGeometryForSelection(
      sourceWidth: decodedSource.width,
      sourceHeight: decodedSource.height,
      selectionRect: focusRect,
      minContextMegaPixels: minContextMegaPixels,
    );
    if (geometry == null) {
      return null;
    }

    return (source: decodedSource, mask: decodedMask, geometry: geometry);
  }

  static FocusedInpaintCrop? _findBinaryMaskBounds(
    Uint8List mask,
    int width,
    int height,
  ) {
    var minX = width;
    var minY = height;
    var maxX = -1;
    var maxY = -1;

    var index = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (mask[index++] == 0) {
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

    final binaryMask = InpaintMaskUtils.decodeBinaryMask(maskImage);
    if (binaryMask == null) {
      return null;
    }

    return _findBinaryMaskBounds(
      binaryMask.mask,
      binaryMask.width,
      binaryMask.height,
    );
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
    if (width <= 0 || height <= 0) {
      return null;
    }

    return FocusedInpaintCrop(
      x: left.floor(),
      y: top.floor(),
      width: width,
      height: height,
    );
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

  static FocusedInpaintGeometry _resolveGeometryFromBounds({
    required int sourceWidth,
    required int sourceHeight,
    required FocusedInpaintCrop focusBounds,
    required double minContextMegaPixels,
    required bool wasDynamicallyConstrained,
  }) {
    final contextCrop = _resolveCrop(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      bounds: focusBounds,
      minContextMegaPixels: minContextMegaPixels,
    );
    final target = _resolveTargetSize(
      cropWidth: contextCrop.width,
      cropHeight: contextCrop.height,
    );

    return FocusedInpaintGeometry(
      focusBounds: focusBounds,
      contextCrop: contextCrop,
      requestWidth: target.width,
      requestHeight: target.height,
      requestMode: target.mode,
      wasDynamicallyConstrained: wasDynamicallyConstrained,
    );
  }

  static Rect _constrainSelectionRectToMaxArea(
    Rect selectionRect, {
    required int sourceWidth,
    required int sourceHeight,
    required double minContextMegaPixels,
    Offset? fixedAnchor,
  }) {
    final canvasRect = Rect.fromLTWH(
      0,
      0,
      sourceWidth.toDouble(),
      sourceHeight.toDouble(),
    );
    final rect = selectionRect.intersect(canvasRect);
    final center = rect.center;
    final anchor = fixedAnchor == null
        ? null
        : Offset(
            fixedAnchor.dx.clamp(0.0, sourceWidth.toDouble()),
            fixedAnchor.dy.clamp(0.0, sourceHeight.toDouble()),
          );
    final movingCorner = anchor == null
        ? null
        : Offset(
            (anchor.dx - rect.left).abs() <= (anchor.dx - rect.right).abs()
                ? rect.right
                : rect.left,
            (anchor.dy - rect.top).abs() <= (anchor.dy - rect.bottom).abs()
                ? rect.bottom
                : rect.top,
          );

    Rect candidateAt(double scale) {
      if (anchor != null && movingCorner != null) {
        final moving = Offset(
          anchor.dx + (movingCorner.dx - anchor.dx) * scale,
          anchor.dy + (movingCorner.dy - anchor.dy) * scale,
        );
        return Rect.fromPoints(anchor, moving).intersect(canvasRect);
      }
      return Rect.fromCenter(
        center: center,
        width: rect.width * scale,
        height: rect.height * scale,
      ).intersect(canvasRect);
    }

    var low = 0.0;
    var high = 1.0;
    var best = _minimumSelectionRect(
      center: center,
      anchor: anchor,
      movingCorner: movingCorner,
      canvasRect: canvasRect,
    );
    for (var iteration = 0; iteration < 48; iteration++) {
      final scale = (low + high) / 2;
      final candidate = candidateAt(scale);
      final bounds = _resolveSelectionBounds(
        candidate,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
      );
      if (bounds == null) {
        low = scale;
        continue;
      }
      final crop = _resolveCrop(
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        bounds: bounds,
        minContextMegaPixels: minContextMegaPixels,
      );
      if (crop.area <= maxRequestAreaPixels) {
        low = scale;
        best = candidate;
      } else {
        high = scale;
      }
    }
    return best;
  }

  static Rect _minimumSelectionRect({
    required Offset center,
    required Offset? anchor,
    required Offset? movingCorner,
    required Rect canvasRect,
  }) {
    if (anchor != null && movingCorner != null) {
      final xDirection = movingCorner.dx >= anchor.dx ? 1.0 : -1.0;
      final yDirection = movingCorner.dy >= anchor.dy ? 1.0 : -1.0;
      return Rect.fromPoints(
        anchor,
        Offset(anchor.dx + 3 * xDirection, anchor.dy + 3 * yDirection),
      ).intersect(canvasRect);
    }
    return Rect.fromCenter(
      center: center,
      width: 3,
      height: 3,
    ).intersect(canvasRect);
  }

  static ({int width, int height, FocusedInpaintRequestMode mode})
  _resolveTargetSize({required int cropWidth, required int cropHeight}) {
    final cropArea = cropWidth * cropHeight;
    final mode = cropArea <= focusedTargetAreaPixels
        ? FocusedInpaintRequestMode.upscaleToTarget
        : FocusedInpaintRequestMode.preserveCrop;
    final scale = mode == FocusedInpaintRequestMode.upscaleToTarget
        ? math.sqrt(focusedTargetAreaPixels / cropArea)
        : 1.0;
    var width = _floorToGrid((cropWidth * scale).floor());
    var height = _floorToGrid((cropHeight * scale).floor());
    final areaLimit = mode == FocusedInpaintRequestMode.upscaleToTarget
        ? focusedTargetAreaPixels
        : maxRequestAreaPixels;

    if (width * height > areaLimit) {
      if (width >= height) {
        width = _largestGridDimensionForArea(areaLimit, height);
      } else {
        height = _largestGridDimensionForArea(areaLimit, width);
      }
    }

    return (width: width, height: height, mode: mode);
  }

  static int _floorToGrid(int value) {
    return math.max(dimensionStep, (value ~/ dimensionStep) * dimensionStep);
  }

  static int _largestGridDimensionForArea(int areaLimit, int otherDimension) {
    final gridUnits = areaLimit ~/ otherDimension ~/ dimensionStep;
    return math.max(dimensionStep, gridUnits * dimensionStep);
  }
}
