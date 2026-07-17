import 'dart:collection';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:image/image.dart' as img;

import '../models/image_generation_artifact.dart';
import 'isolate_pool.dart';
import 'pica_lanczos_resizer.dart';

enum MaskFillRegionStatus {
  emptyMask,
  outOfBounds,
  clickedMaskedPixel,
  openRegion,
  filled,
}

class MaskFillRegionResult {
  const MaskFillRegionResult({
    required this.status,
    this.filledMaskBytes,
    this.overlayBytes,
  });

  final MaskFillRegionStatus status;
  final Uint8List? filledMaskBytes;
  final Uint8List? overlayBytes;
}

class NovelAiInpaintMaskArtifacts {
  const NovelAiInpaintMaskArtifacts({
    required this.requestMaskBytes,
    required this.latentMaskBytes,
    required this.compositeMaskBytes,
    required this.requestWidth,
    required this.requestHeight,
    required this.latentWidth,
    required this.latentHeight,
  });

  final Uint8List requestMaskBytes;
  final Uint8List latentMaskBytes;
  final Uint8List compositeMaskBytes;
  final int requestWidth;
  final int requestHeight;
  final int latentWidth;
  final int latentHeight;
}

/// Inpaint 蒙版处理工具
class InpaintMaskUtils {
  InpaintMaskUtils._();

  static const int _alphaThreshold = 8;
  static const int _colorThreshold = 32;

  /// 将任意输入蒙版归一化为 NovelAI 更稳定的黑白二值蒙版。
  static Uint8List normalizeMaskBytes(Uint8List bytes) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return bytes;
    }
    if (decoded == null) {
      return bytes;
    }

    final binaryMask = _createBinaryMask(decoded);
    return _encodeBinaryMask(binaryMask, decoded.width, decoded.height);
  }

  /// 将蒙版按最近邻重采样到编辑器工作画布，保持硬边和二值语义。
  static Uint8List resizeMaskBytes(
    Uint8List bytes, {
    required int targetWidth,
    required int targetHeight,
  }) {
    final decoded = decodeBinaryMask(bytes);
    if (decoded == null || targetWidth <= 0 || targetHeight <= 0) {
      return bytes;
    }
    if (decoded.width == targetWidth && decoded.height == targetHeight) {
      return _encodeBinaryMask(decoded.mask, decoded.width, decoded.height);
    }

    final source = _binaryMaskToImage(
      decoded.mask,
      decoded.width,
      decoded.height,
    );
    final resized = _resizeNearestCanvasLike(
      source,
      width: targetWidth,
      height: targetHeight,
    );
    return _encodeBinaryMask(
      _createBinaryMask(resized),
      targetWidth,
      targetHeight,
    );
  }

  static Future<Uint8List> resizeMaskBytesAsync(
    Uint8List bytes, {
    required int targetWidth,
    required int targetHeight,
  }) {
    return ComputeGate().runIsolate(
      () => resizeMaskBytes(
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      ),
    );
  }

  static Uint8List resizeBinaryMask(
    Uint8List source, {
    required int sourceWidth,
    required int sourceHeight,
    required int targetWidth,
    required int targetHeight,
  }) {
    if (sourceWidth <= 0 ||
        sourceHeight <= 0 ||
        targetWidth <= 0 ||
        targetHeight <= 0 ||
        source.length != sourceWidth * sourceHeight) {
      throw ArgumentError('Invalid binary mask dimensions.');
    }
    if (sourceWidth == targetWidth && sourceHeight == targetHeight) {
      return Uint8List.fromList(source);
    }

    final target = Uint8List(targetWidth * targetHeight);
    var targetIndex = 0;
    for (var y = 0; y < targetHeight; y++) {
      final sourceY = (((y + 0.5) * sourceHeight) / targetHeight).floor().clamp(
        0,
        sourceHeight - 1,
      );
      for (var x = 0; x < targetWidth; x++) {
        final sourceX = (((x + 0.5) * sourceWidth) / targetWidth).floor().clamp(
          0,
          sourceWidth - 1,
        );
        target[targetIndex++] = source[sourceY * sourceWidth + sourceX];
      }
    }
    return target;
  }

  static Future<Uint8List> resizeBinaryMaskToPngAsync(
    Uint8List source, {
    required int sourceWidth,
    required int sourceHeight,
    required int targetWidth,
    required int targetHeight,
  }) {
    return ComputeGate().runIsolate(() {
      final resized = resizeBinaryMask(
        source,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      return encodeBinaryMask(resized, targetWidth, targetHeight);
    });
  }

  static Future<Uint8List> createRectMaskBytesAsync({
    required int width,
    required int height,
    required Rect rect,
  }) {
    return ComputeGate().runIsolate(
      () => createRectMaskBytes(width: width, height: height, rect: rect),
    );
  }

  static Uint8List createRectMaskBytes({
    required int width,
    required int height,
    required Rect rect,
  }) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Mask dimensions must be positive.');
    }
    final binaryMask = Uint8List(width * height);
    final left = rect.left.floor().clamp(0, width);
    final top = rect.top.floor().clamp(0, height);
    final right = rect.right.ceil().clamp(0, width);
    final bottom = rect.bottom.ceil().clamp(0, height);
    for (var y = top; y < bottom; y++) {
      binaryMask.fillRange(y * width + left, y * width + right, 1);
    }
    return encodeBinaryMask(binaryMask, width, height);
  }

  static Uint8List encodeBinaryMask(
    Uint8List binaryMask,
    int width,
    int height,
  ) {
    if (binaryMask.length != width * height) {
      throw ArgumentError('Binary mask length does not match dimensions.');
    }
    return _encodeBinaryMask(binaryMask, width, height);
  }

  static bool hasMaskedPixels(Uint8List bytes) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return false;
    }
    if (decoded == null) {
      return false;
    }

    final binaryMask = _createBinaryMask(decoded);
    return binaryMask.any((value) => value == 1);
  }

  /// 单次解码得到 0/1 二值蒙版数组及尺寸；解码失败返回 null。
  ///
  /// 供需要同时做"归一化 + 空蒙版检查 + 像素扫描"的调用方使用，
  /// 避免 normalizeMaskBytes/hasMaskedPixels/decodeImage 三连的重复解码。
  static ({Uint8List mask, int width, int height})? decodeBinaryMask(
    Uint8List bytes,
  ) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
    if (decoded == null) {
      return null;
    }

    return (
      mask: _createBinaryMask(decoded),
      width: decoded.width,
      height: decoded.height,
    );
  }

  /// 将 0/1 二值蒙版渲染为黑白 RGBA 图像（白=蒙版区域），不做 PNG 编码。
  static img.Image binaryMaskToImage(
    Uint8List binaryMask,
    int width,
    int height,
  ) {
    return _binaryMaskToImage(binaryMask, width, height);
  }

  /// 将封闭轮廓内部的透明空洞补成白色蒙版。
  ///
  /// 仅填充与画布边界不连通的透明区域，保持开放轮廓不变。
  static Uint8List fillClosedMaskRegions(Uint8List bytes) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return bytes;
    }
    if (decoded == null) {
      return bytes;
    }

    final width = decoded.width;
    final height = decoded.height;
    final binaryMask = _createBinaryMask(decoded);
    final outside = Uint8List(width * height);
    final queue = Queue<int>();

    void enqueueIfTransparent(int x, int y) {
      final index = y * width + x;
      if (binaryMask[index] == 0 && outside[index] == 0) {
        outside[index] = 1;
        queue.add(index);
      }
    }

    for (var x = 0; x < width; x++) {
      enqueueIfTransparent(x, 0);
      enqueueIfTransparent(x, height - 1);
    }
    for (var y = 1; y < height - 1; y++) {
      enqueueIfTransparent(0, y);
      enqueueIfTransparent(width - 1, y);
    }

    while (queue.isNotEmpty) {
      final index = queue.removeFirst();
      final x = index % width;
      final y = index ~/ width;

      if (x > 0) enqueueIfTransparent(x - 1, y);
      if (x + 1 < width) enqueueIfTransparent(x + 1, y);
      if (y > 0) enqueueIfTransparent(x, y - 1);
      if (y + 1 < height) enqueueIfTransparent(x, y + 1);
    }

    final filledMask = Uint8List.fromList(binaryMask);
    for (var index = 0; index < filledMask.length; index++) {
      if (filledMask[index] == 0 && outside[index] == 0) {
        filledMask[index] = 1;
      }
    }

    return _encodeBinaryMask(filledMask, width, height);
  }

  /// 模拟油漆桶：仅填充用户点击到的封闭透明区域。
  ///
  /// 如果点击位置超出范围、落在已有蒙版上，或该区域与边界连通，则保持原样。
  static Uint8List fillMaskRegionAtPoint(
    Uint8List bytes, {
    required int x,
    required int y,
  }) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return bytes;
    }
    if (decoded == null) {
      return bytes;
    }

    final width = decoded.width;
    final height = decoded.height;
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return bytes;
    }

    final binaryMask = _createBinaryMask(decoded);
    final startIndex = y * width + x;
    if (binaryMask[startIndex] == 1) {
      return _encodeBinaryMask(binaryMask, width, height);
    }

    final visited = Uint8List(width * height);
    final queue = Queue<int>()..add(startIndex);
    final region = <int>[];
    visited[startIndex] = 1;
    var touchesBorder = false;

    while (queue.isNotEmpty) {
      final index = queue.removeFirst();
      region.add(index);
      final currentX = index % width;
      final currentY = index ~/ width;

      if (currentX == 0 ||
          currentX == width - 1 ||
          currentY == 0 ||
          currentY == height - 1) {
        touchesBorder = true;
      }

      void visit(int nextX, int nextY) {
        final nextIndex = nextY * width + nextX;
        if (visited[nextIndex] == 1 || binaryMask[nextIndex] == 1) {
          return;
        }
        visited[nextIndex] = 1;
        queue.add(nextIndex);
      }

      if (currentX > 0) visit(currentX - 1, currentY);
      if (currentX + 1 < width) visit(currentX + 1, currentY);
      if (currentY > 0) visit(currentX, currentY - 1);
      if (currentY + 1 < height) visit(currentX, currentY + 1);
    }

    if (touchesBorder) {
      return _encodeBinaryMask(binaryMask, width, height);
    }

    for (final index in region) {
      binaryMask[index] = 1;
    }
    return _encodeBinaryMask(binaryMask, width, height);
  }

  static Future<MaskFillRegionResult> fillEditorMaskRegionAtPointAsync(
    Uint8List bytes, {
    required int x,
    required int y,
    int overlayAlpha = 140,
  }) {
    return Isolate.run(
      () => fillEditorMaskRegionAtPoint(
        bytes,
        x: x,
        y: y,
        overlayAlpha: overlayAlpha,
      ),
    );
  }

  /// 编辑器点击填充专用路径：一次解码内完成校验、封闭区域填充与 overlay 生成。
  static MaskFillRegionResult fillEditorMaskRegionAtPoint(
    Uint8List bytes, {
    required int x,
    required int y,
    int overlayAlpha = 140,
  }) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return const MaskFillRegionResult(status: MaskFillRegionStatus.emptyMask);
    }
    if (decoded == null) {
      return const MaskFillRegionResult(status: MaskFillRegionStatus.emptyMask);
    }

    final width = decoded.width;
    final height = decoded.height;
    final binaryMask = _createBinaryMask(decoded);
    if (!binaryMask.any((value) => value == 1)) {
      return const MaskFillRegionResult(status: MaskFillRegionStatus.emptyMask);
    }
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return const MaskFillRegionResult(
        status: MaskFillRegionStatus.outOfBounds,
      );
    }

    final startIndex = y * width + x;
    if (binaryMask[startIndex] == 1) {
      return const MaskFillRegionResult(
        status: MaskFillRegionStatus.clickedMaskedPixel,
      );
    }

    final visited = Uint8List(width * height);
    final queue = Queue<int>()..add(startIndex);
    final region = <int>[];
    visited[startIndex] = 1;

    while (queue.isNotEmpty) {
      final index = queue.removeFirst();
      final currentX = index % width;
      final currentY = index ~/ width;

      if (currentX == 0 ||
          currentX == width - 1 ||
          currentY == 0 ||
          currentY == height - 1) {
        return const MaskFillRegionResult(
          status: MaskFillRegionStatus.openRegion,
        );
      }

      region.add(index);

      void visit(int nextX, int nextY) {
        final nextIndex = nextY * width + nextX;
        if (visited[nextIndex] == 1 || binaryMask[nextIndex] == 1) {
          return;
        }
        visited[nextIndex] = 1;
        queue.add(nextIndex);
      }

      visit(currentX - 1, currentY);
      visit(currentX + 1, currentY);
      visit(currentX, currentY - 1);
      visit(currentX, currentY + 1);
    }

    for (final index in region) {
      binaryMask[index] = 1;
    }

    return MaskFillRegionResult(
      status: MaskFillRegionStatus.filled,
      filledMaskBytes: _encodeBinaryMask(binaryMask, width, height),
      overlayBytes: _encodeEditorOverlay(
        binaryMask,
        width,
        height,
        overlayAlpha,
      ),
    );
  }

  /// 提取填充操作新补出的区域，避免把原有蒙版重复叠进新图层。
  static Uint8List extractFilledMaskDelta(
    Uint8List originalBytes,
    Uint8List filledBytes,
  ) {
    img.Image? original;
    img.Image? filled;
    try {
      original = img.decodeImage(originalBytes);
      filled = img.decodeImage(filledBytes);
    } catch (_) {
      return filledBytes;
    }
    if (original == null ||
        filled == null ||
        original.width != filled.width ||
        original.height != filled.height) {
      return filledBytes;
    }

    final originalMask = _createBinaryMask(original);
    final filledMask = _createBinaryMask(filled);
    final deltaMask = Uint8List(original.width * original.height);
    for (var index = 0; index < deltaMask.length; index++) {
      if (filledMask[index] == 1 && originalMask[index] == 0) {
        deltaMask[index] = 1;
      }
    }

    return _encodeBinaryMask(deltaMask, original.width, original.height);
  }

  /// 将 inpaint 返回图按蒙版合成回原图。
  ///
  /// NovelAI inpaint 返回的是整张图；Krita 写回时只应替换蒙版区域，
  /// 否则未选区域的轻微色偏也会覆盖原图。
  static Uint8List compositeGeneratedImage({
    required Uint8List sourceImage,
    required Uint8List maskImage,
    required Uint8List generatedImage,
    bool normalizeMask = true,
  }) {
    img.Image? source;
    img.Image? mask;
    img.Image? generated;
    try {
      source = img.decodeImage(sourceImage);
      mask = img.decodeImage(
        normalizeMask ? normalizeMaskBytes(maskImage) : maskImage,
      );
      generated = img.decodeImage(generatedImage);
    } catch (_) {
      return generatedImage;
    }

    if (source == null || mask == null || generated == null) {
      return generatedImage;
    }
    if (source.width != mask.width || source.height != mask.height) {
      return generatedImage;
    }

    final generatedCanvas =
        generated.width == source.width && generated.height == source.height
        ? generated
        : PicaLanczosResizer.resizeImage(
            generated,
            width: source.width,
            height: source.height,
          );

    final composed = img.Image.from(source, noAnimation: true);
    img.compositeImage(
      composed,
      generatedCanvas,
      dstX: 0,
      dstY: 0,
      dstW: source.width,
      dstH: source.height,
      mask: mask,
      blend: img.BlendMode.direct,
    );

    return Uint8List.fromList(img.encodePng(composed));
  }

  /// Creates both the full display image and the transparent inpaint patch.
  ///
  /// [compositeMaskImage] must be the request-size soft mask derived from the
  /// same latent mask as the HTTP payload. Patch RGB remains unassociated; only
  /// alpha is multiplied so later compositing does not darken edges.
  static ImageGenerationArtifact composeGeneratedImageArtifact({
    required Uint8List normalizedSourceImage,
    required Uint8List compositeMaskImage,
    required Uint8List generatedImage,
  }) {
    img.Image? source;
    img.Image? mask;
    img.Image? generated;
    try {
      source = img.decodeImage(normalizedSourceImage);
      mask = img.decodeImage(compositeMaskImage);
      generated = img.decodeImage(generatedImage);
    } catch (_) {
      return ImageGenerationArtifact(displayImageBytes: generatedImage);
    }
    if (source == null || mask == null || generated == null) {
      return ImageGenerationArtifact(displayImageBytes: generatedImage);
    }
    if (source.width != mask.width || source.height != mask.height) {
      return ImageGenerationArtifact(displayImageBytes: generatedImage);
    }

    final generatedCanvas =
        generated.width == source.width && generated.height == source.height
        ? generated
        : PicaLanczosResizer.resizeImage(
            generated,
            width: source.width,
            height: source.height,
          );
    final patch = applyCompositeMaskToGeneratedImage(generatedCanvas, mask);
    final display = img.Image.from(source, noAnimation: true);
    img.compositeImage(display, patch, blend: img.BlendMode.alpha);

    return ImageGenerationArtifact(
      displayImageBytes: Uint8List.fromList(img.encodePng(display, level: 1)),
      transparentPatchBytes: Uint8List.fromList(img.encodePng(patch, level: 1)),
    );
  }

  /// 构建用于 final inpaint 写回的客户端合成蒙版。
  ///
  /// 官网当前流程会关闭服务端 `add_original_image`，再用膨胀、放大、
  /// 柔化后的 mask 在客户端把生成图贴回原图。这样未选区域不会吃到
  /// 服务端整图 VAE 往返，同时蒙版边缘比硬二值贴回更不容易出接缝。
  static Uint8List prepareGeneratedImageCompositeMaskBytes(
    Uint8List bytes, {
    required int targetWidth,
    required int targetHeight,
    int closingIterations = 0,
    int expansionIterations = 0,
    int latentGridSize = 8,
    int latentDilationIterations = 4,
    int blurRadius = 20,
    int blurIterations = 2,
  }) {
    return prepareNovelAiInpaintMaskArtifacts(
      bytes,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
      closingIterations: closingIterations,
      expansionIterations: expansionIterations,
      latentGridSize: latentGridSize,
      latentDilationIterations: latentDilationIterations,
      blurRadius: blurRadius,
      blurIterations: blurIterations,
    ).compositeMaskBytes;
  }

  /// Builds the final HTTP payload and client-composite mask from one latent
  /// mask.
  ///
  /// NovelAI web build ae6a6aa-production first converts arbitrary mask input
  /// to coverage alpha, downsamples directly to the latent grid with nearest
  /// sampling, then applies a strict alpha > 155 threshold. Its common request
  /// layer then draws that latent mask over opaque black at the full request
  /// size with smoothing disabled. Local Closing and Expansion remain an
  /// opt-in pre-pass in source coordinates.
  static NovelAiInpaintMaskArtifacts prepareNovelAiInpaintMaskArtifacts(
    Uint8List bytes, {
    required int targetWidth,
    required int targetHeight,
    int closingIterations = 0,
    int expansionIterations = 0,
    int latentGridSize = 8,
    int latentDilationIterations = 4,
    int blurRadius = 20,
    int blurIterations = 2,
  }) {
    if (targetWidth <= 0 || targetHeight <= 0 || latentGridSize <= 0) {
      throw ArgumentError('Target dimensions and latent grid must be positive');
    }

    final latentWidth = math.max(1, targetWidth ~/ latentGridSize);
    final latentHeight = math.max(1, targetHeight ~/ latentGridSize);
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      decoded = null;
    }
    if (decoded == null) {
      return NovelAiInpaintMaskArtifacts(
        requestMaskBytes: bytes,
        latentMaskBytes: bytes,
        compositeMaskBytes: bytes,
        requestWidth: targetWidth,
        requestHeight: targetHeight,
        latentWidth: latentWidth,
        latentHeight: latentHeight,
      );
    }

    final img.Image coverageMask;
    if (closingIterations == 0 && expansionIterations == 0) {
      coverageMask = _normalizeMaskToCoverageImage(decoded);
    } else {
      var binaryMask = _createBinaryMask(decoded);
      if (closingIterations > 0) {
        binaryMask = _closeMask(
          binaryMask,
          decoded.width,
          decoded.height,
          closingIterations,
        );
      }
      if (expansionIterations > 0) {
        binaryMask = _dilateMask(
          binaryMask,
          decoded.width,
          decoded.height,
          expansionIterations,
        );
      }
      coverageMask = _binaryMaskToCoverageImage(
        binaryMask,
        decoded.width,
        decoded.height,
      );
    }

    final sampledCoverage = _resizeNearestCanvasLike(
      coverageMask,
      width: latentWidth,
      height: latentHeight,
    );
    final latentBinaryMask = _thresholdCoverageAlpha(sampledCoverage);
    final latentMask = _binaryMaskToCoverageImage(
      latentBinaryMask,
      latentWidth,
      latentHeight,
    );
    final latentMaskBytes = Uint8List.fromList(
      img.encodePng(latentMask, level: 1),
    );
    var requestMask = _binaryMaskToImage(
      latentBinaryMask,
      latentWidth,
      latentHeight,
    );
    if (latentGridSize > 1) {
      requestMask = _scaleImageByInteger(requestMask, latentGridSize);
    }
    if (requestMask.width != targetWidth ||
        requestMask.height != targetHeight) {
      requestMask = _resizeNearestCanvasLike(
        requestMask,
        width: targetWidth,
        height: targetHeight,
      );
    }
    final requestMaskBytes = Uint8List.fromList(
      img.encodePng(requestMask, level: 1),
    );

    var compositeBinaryMask = latentBinaryMask;
    if (latentDilationIterations > 0) {
      compositeBinaryMask = _dilateMask(
        compositeBinaryMask,
        latentWidth,
        latentHeight,
        latentDilationIterations,
      );
    }
    // Transparent latent pixels are explicitly filled black before dilation
    // and blur, matching the browser worker's canvas operations.
    var compositeMask = _binaryMaskToImage(
      compositeBinaryMask,
      latentWidth,
      latentHeight,
    );
    if (latentGridSize > 1) {
      compositeMask = _scaleImageByInteger(compositeMask, latentGridSize);
    }
    if (compositeMask.width != targetWidth ||
        compositeMask.height != targetHeight) {
      compositeMask = _resizeNearestCanvasLike(
        compositeMask,
        width: targetWidth,
        height: targetHeight,
      );
    }
    if (blurRadius > 0 && blurIterations > 0) {
      compositeMask = _officialWorkerBlur(
        compositeMask,
        radius: blurRadius,
        iterations: blurIterations,
      );
    }
    compositeMask = _alphaMatchRed(compositeMask);

    return NovelAiInpaintMaskArtifacts(
      requestMaskBytes: requestMaskBytes,
      latentMaskBytes: latentMaskBytes,
      compositeMaskBytes: Uint8List.fromList(img.encodePng(compositeMask)),
      requestWidth: targetWidth,
      requestHeight: targetHeight,
      latentWidth: latentWidth,
      latentHeight: latentHeight,
    );
  }

  static Future<NovelAiInpaintMaskArtifacts>
  prepareNovelAiInpaintMaskArtifactsAsync(
    Uint8List bytes, {
    required int targetWidth,
    required int targetHeight,
    int closingIterations = 0,
    int expansionIterations = 0,
    int latentGridSize = 8,
    int latentDilationIterations = 4,
    int blurRadius = 20,
    int blurIterations = 2,
  }) {
    return ComputeGate().runIsolate(
      () => prepareNovelAiInpaintMaskArtifacts(
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
        closingIterations: closingIterations,
        expansionIterations: expansionIterations,
        latentGridSize: latentGridSize,
        latentDilationIterations: latentDilationIterations,
        blurRadius: blurRadius,
        blurIterations: blurIterations,
      ),
    );
  }

  /// 从 inpaint 返回图中提取透明补丁层。
  ///
  /// Krita 写回时使用透明补丁层叠在原图上，蒙版外 alpha=0，
  /// 可以避免整张不透明图层覆盖原图造成色彩漂移。
  static Uint8List extractGeneratedPatch({
    required Uint8List maskImage,
    required Uint8List generatedImage,
  }) {
    img.Image? mask;
    img.Image? generated;
    try {
      mask = img.decodeImage(normalizeMaskBytes(maskImage));
      generated = img.decodeImage(generatedImage);
    } catch (_) {
      return generatedImage;
    }

    if (mask == null || generated == null) {
      return generatedImage;
    }

    final generatedCanvas =
        generated.width == mask.width && generated.height == mask.height
        ? generated
        : PicaLanczosResizer.resizeImage(
            generated,
            width: mask.width,
            height: mask.height,
          );

    final patch = img.Image(
      width: mask.width,
      height: mask.height,
      numChannels: 4,
    );
    img.fill(patch, color: img.ColorRgba8(0, 0, 0, 0));
    img.compositeImage(
      patch,
      generatedCanvas,
      dstX: 0,
      dstY: 0,
      dstW: mask.width,
      dstH: mask.height,
      mask: mask,
      blend: img.BlendMode.direct,
    );

    return Uint8List.fromList(img.encodePng(patch));
  }

  /// 将蒙版处理为更适合 NovelAI Inpaint 的版本：
  /// 默认仅做二值化；按需启用闭运算或扩边，避免平白放大蒙版边界。
  static Uint8List prepareInpaintMaskBytes(
    Uint8List bytes, {
    int closingIterations = 0,
    int expansionIterations = 0,
  }) {
    return prepareRequestMaskBytes(
      bytes,
      closingIterations: closingIterations,
      expansionIterations: expansionIterations,
    );
  }

  /// 构建真正发送给 NovelAI 的请求蒙版。
  ///
  /// `alignToLatentGrid` 会把 V4/V4.5 的 mask 对齐到 8px latent 网格，
  /// 避免 UI 里的软边/亚像素边界直接泄漏到请求层。
  static Uint8List prepareRequestMaskBytes(
    Uint8List bytes, {
    int closingIterations = 0,
    int expansionIterations = 0,
    bool alignToLatentGrid = false,
    int latentGridSize = 8,
  }) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return bytes;
    }
    if (decoded == null) {
      return bytes;
    }

    var binaryMask = _createBinaryMask(decoded);
    if (closingIterations > 0) {
      binaryMask = _closeMask(
        binaryMask,
        decoded.width,
        decoded.height,
        closingIterations,
      );
    }
    if (expansionIterations > 0) {
      binaryMask = _dilateMask(
        binaryMask,
        decoded.width,
        decoded.height,
        expansionIterations,
      );
    }
    if (alignToLatentGrid) {
      binaryMask = _alignMaskToLatentGrid(
        binaryMask,
        decoded.width,
        decoded.height,
        latentGridSize,
      );
    }

    return _encodeBinaryMask(binaryMask, decoded.width, decoded.height);
  }

  /// 构建 NovelAI 官网式 infill 请求蒙版。
  ///
  /// 官网先生成 `requestWidth / 8 × requestHeight / 8` latent mask，公共请求
  /// 层再以黑色不透明背景和 nearest-neighbor 放大到完整请求尺寸后提交。
  static Uint8List prepareNovelAiRequestMaskBytes(
    Uint8List bytes, {
    required int targetWidth,
    required int targetHeight,
    int closingIterations = 0,
    int expansionIterations = 0,
    int latentGridSize = 8,
  }) {
    return prepareNovelAiInpaintMaskArtifacts(
      bytes,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
      closingIterations: closingIterations,
      expansionIterations: expansionIterations,
      latentGridSize: latentGridSize,
    ).requestMaskBytes;
  }

  /// [prepareNovelAiRequestMaskBytes] 的后台 isolate 版本。
  ///
  /// 该流程包含多轮全图扫描与 PNG 编码，直接在 UI isolate 同步执行
  /// 会在点击生成后造成可感知的卡顿。
  static Future<Uint8List> prepareNovelAiRequestMaskBytesAsync(
    Uint8List bytes, {
    required int targetWidth,
    required int targetHeight,
    int closingIterations = 0,
    int expansionIterations = 0,
    int latentGridSize = 8,
  }) {
    return ComputeGate().runIsolate(
      () => prepareNovelAiInpaintMaskArtifacts(
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
        closingIterations: closingIterations,
        expansionIterations: expansionIterations,
        latentGridSize: latentGridSize,
      ).requestMaskBytes,
    );
  }

  /// 构建 NovelAI 官网 infill 流程中的 latent 网格中间蒙版。
  static Uint8List prepareNovelAiLatentMaskBytes(
    Uint8List bytes, {
    required int targetWidth,
    required int targetHeight,
    int closingIterations = 0,
    int expansionIterations = 0,
    int latentGridSize = 8,
  }) {
    return prepareNovelAiInpaintMaskArtifacts(
      bytes,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
      closingIterations: closingIterations,
      expansionIterations: expansionIterations,
      latentGridSize: latentGridSize,
    ).latentMaskBytes;
  }

  /// 将已保存的黑白蒙版转换为编辑器可见的透明覆盖层。
  static Uint8List maskToEditorOverlay(
    Uint8List bytes, {
    int overlayAlpha = 140,
  }) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return bytes;
    }
    if (decoded == null) {
      return bytes;
    }

    final overlay = img.Image(
      width: decoded.width,
      height: decoded.height,
      numChannels: 4,
    );

    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final pixel = decoded.getPixel(x, y);
        if (_isMaskedPixel(pixel)) {
          overlay.setPixelRgba(x, y, 96, 170, 255, overlayAlpha);
        } else {
          overlay.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }

    return Uint8List.fromList(img.encodePng(overlay));
  }

  static Future<Uint8List> maskToEditorOverlayAsync(
    Uint8List bytes, {
    int overlayAlpha = 140,
  }) {
    return Isolate.run(
      () => maskToEditorOverlay(bytes, overlayAlpha: overlayAlpha),
    );
  }

  static img.Image applyCompositeMaskToGeneratedImage(
    img.Image generated,
    img.Image compositeMask,
  ) {
    if (generated.width != compositeMask.width ||
        generated.height != compositeMask.height) {
      throw ArgumentError('Generated image and composite mask must match');
    }
    final patch = img.Image(
      width: generated.width,
      height: generated.height,
      numChannels: 4,
    );
    for (var y = 0; y < generated.height; y++) {
      for (var x = 0; x < generated.width; x++) {
        final generatedPixel = generated.getPixel(x, y);
        final maskAlpha = compositeMask.getPixel(x, y).a.toInt();
        final alpha = (generatedPixel.a.toInt() * maskAlpha + 127) ~/ 255;
        patch.setPixelRgba(
          x,
          y,
          generatedPixel.r.toInt(),
          generatedPixel.g.toInt(),
          generatedPixel.b.toInt(),
          alpha,
        );
      }
    }
    return patch;
  }

  static bool _isMaskedPixel(img.Pixel pixel) {
    final alpha = pixel.a.toInt();
    if (alpha <= _alphaThreshold) {
      return false;
    }

    final brightest = [
      pixel.r.toInt(),
      pixel.g.toInt(),
      pixel.b.toInt(),
    ].reduce((a, b) => a > b ? a : b);

    return brightest >= _colorThreshold;
  }

  static img.Image _normalizeMaskToCoverageImage(img.Image source) {
    final coverage = img.Image(
      width: source.width,
      height: source.height,
      numChannels: 4,
    );
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        final brightest = math.max(
          pixel.r.toInt(),
          math.max(pixel.g.toInt(), pixel.b.toInt()),
        );
        final alpha = pixel.a.toInt();
        final value = (brightest * alpha + 127) ~/ 255;
        coverage.setPixelRgba(x, y, 255, 255, 255, value);
      }
    }
    return coverage;
  }

  static Uint8List _thresholdCoverageAlpha(
    img.Image coverage, {
    int threshold = 155,
  }) {
    final binaryMask = Uint8List(coverage.width * coverage.height);
    var index = 0;
    for (var y = 0; y < coverage.height; y++) {
      for (var x = 0; x < coverage.width; x++) {
        binaryMask[index++] = coverage.getPixel(x, y).a.toInt() > threshold
            ? 1
            : 0;
      }
    }
    return binaryMask;
  }

  static Uint8List _createBinaryMask(img.Image decoded) {
    final mask = Uint8List(decoded.width * decoded.height);
    var index = 0;
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final pixel = decoded.getPixel(x, y);
        mask[index++] = _isMaskedPixel(pixel) ? 1 : 0;
      }
    }
    return mask;
  }

  static img.Image _binaryMaskToImage(
    Uint8List binaryMask,
    int width,
    int height,
  ) {
    final normalized = img.Image(width: width, height: height, numChannels: 4);

    var index = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final value = binaryMask[index++] == 1 ? 255 : 0;
        normalized.setPixelRgba(x, y, value, value, value, 255);
      }
    }
    return normalized;
  }

  static img.Image _binaryMaskToCoverageImage(
    Uint8List binaryMask,
    int width,
    int height,
  ) {
    final normalized = img.Image(width: width, height: height, numChannels: 4);
    var index = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final alpha = binaryMask[index++] == 1 ? 255 : 0;
        normalized.setPixelRgba(x, y, 255, 255, 255, alpha);
      }
    }
    return normalized;
  }

  static Uint8List _encodeBinaryMask(
    Uint8List binaryMask,
    int width,
    int height,
  ) {
    final normalized = _binaryMaskToImage(binaryMask, width, height);
    return Uint8List.fromList(img.encodePng(normalized));
  }

  static img.Image _resizeNearestCanvasLike(
    img.Image source, {
    required int width,
    required int height,
  }) {
    final resized = img.Image(width: width, height: height, numChannels: 4);

    for (var y = 0; y < height; y++) {
      var sourceY = (((y + 0.5) * source.height) / height).floor();
      sourceY = _clampInt(sourceY, 0, source.height - 1);
      for (var x = 0; x < width; x++) {
        var sourceX = (((x + 0.5) * source.width) / width).floor();
        sourceX = _clampInt(sourceX, 0, source.width - 1);
        final pixel = source.getPixel(sourceX, sourceY);
        resized.setPixelRgba(
          x,
          y,
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
          pixel.a.toInt(),
        );
      }
    }
    return resized;
  }

  static img.Image _scaleImageByInteger(img.Image source, int scale) {
    if (scale <= 1) {
      return img.Image.from(source, noAnimation: true);
    }

    final scaled = img.Image(
      width: source.width * scale,
      height: source.height * scale,
      numChannels: 4,
    );
    for (var y = 0; y < scaled.height; y++) {
      final sourceY = y ~/ scale;
      for (var x = 0; x < scaled.width; x++) {
        final sourceX = x ~/ scale;
        final pixel = source.getPixel(sourceX, sourceY);
        scaled.setPixelRgba(
          x,
          y,
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
          pixel.a.toInt(),
        );
      }
    }
    return scaled;
  }

  static img.Image _officialWorkerBlur(
    img.Image source, {
    required int radius,
    required int iterations,
  }) {
    if (radius < 1) {
      return img.Image.from(source, noAnimation: true);
    }

    final constants = _officialStackBlurConstants(radius);
    if (constants == null) {
      return img.gaussianBlur(source, radius: radius);
    }

    final width = source.width;
    final height = source.height;
    final right = width - 1;
    final bottom = height - 1;
    final rowBytes = width << 2;
    final radiusPlusOne = radius + 1;
    final iterationCount = _clampInt(iterations, 1, 3);
    final red = Int16List(width * height);
    final green = Int16List(width * height);
    final blue = Int16List(width * height);
    final minX = Uint16List(width);
    final maxX = Uint16List(width);
    final minY = Uint16List(height);
    final maxY = Uint16List(height);
    final capX = math.min(right, radius);
    final data = Uint8List(width * height * 4);

    var dataIndex = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = source.getPixel(x, y);
        data[dataIndex++] = pixel.r.toInt();
        data[dataIndex++] = pixel.g.toInt();
        data[dataIndex++] = pixel.b.toInt();
        data[dataIndex++] = pixel.a.toInt();
      }
    }

    for (var x = 0; x < width; x++) {
      minX[x] = math.min(x + radiusPlusOne, right) << 2;
      maxX[x] = math.max(x - radius, 0) << 2;
    }
    for (var y = 0; y < height; y++) {
      minY[y] = math.min(y + radiusPlusOne, bottom);
      maxY[y] = math.max(y - radius, 0);
    }

    for (var iteration = iterationCount; -1 != --iteration;) {
      var flatIndex = 0;
      for (var y = 0, rowOffset = 0; y < height; y++, rowOffset += rowBytes) {
        var r = data[rowOffset] * radiusPlusOne;
        var g = data[rowOffset + 1] * radiusPlusOne;
        var b = data[rowOffset + 2] * radiusPlusOne;
        for (var x = 1; x <= capX; x++) {
          final index = rowOffset + (x << 2);
          r += data[index];
          g += data[index + 1];
          b += data[index + 2];
        }
        if (radius > right) {
          r += data[rowOffset + rowBytes - 4] * (radius - right);
          g += data[rowOffset + rowBytes - 3] * (radius - right);
          b += data[rowOffset + rowBytes - 2] * (radius - right);
        }

        for (var x = 0; x < width; x++, flatIndex++) {
          red[flatIndex] = r;
          green[flatIndex] = g;
          blue[flatIndex] = b;
          final add = rowOffset + minX[x];
          final sub = rowOffset + maxX[x];
          if (_hasAnyRgb(data, add) || _hasAnyRgb(data, sub)) {
            r += data[add] - data[sub];
            g += data[add + 1] - data[sub + 1];
            b += data[add + 2] - data[sub + 2];
          }
        }
      }

      for (var x = 0; x < width; x++) {
        var flatBase = x;
        var r = red[flatBase] * radiusPlusOne;
        var g = green[flatBase] * radiusPlusOne;
        var b = blue[flatBase] * radiusPlusOne;
        for (var y = 1; y <= radius; y++) {
          if (y <= bottom) {
            flatBase += width;
          }
          r += red[flatBase];
          g += green[flatBase];
          b += blue[flatBase];
        }

        for (var y = 0, offset = x; y < height; y++, offset += width) {
          final pixelIndex = offset << 2;
          if ((b | g | r) == 0) {
            data[pixelIndex] = 0;
            data[pixelIndex + 1] = 0;
            data[pixelIndex + 2] = 0;
          } else {
            data[pixelIndex] = _clampByte((r * constants.mul) >> constants.shg);
            data[pixelIndex + 1] = _clampByte(
              (g * constants.mul) >> constants.shg,
            );
            data[pixelIndex + 2] = _clampByte(
              (b * constants.mul) >> constants.shg,
            );
          }

          final add = x + minY[y] * width;
          final sub = x + maxY[y] * width;
          r += red[add] - red[sub];
          g += green[add] - green[sub];
          b += blue[add] - blue[sub];
        }
      }
    }

    final blurred = img.Image(width: width, height: height, numChannels: 4);
    dataIndex = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        blurred.setPixelRgba(
          x,
          y,
          data[dataIndex],
          data[dataIndex + 1],
          data[dataIndex + 2],
          data[dataIndex + 3],
        );
        dataIndex += 4;
      }
    }
    return blurred;
  }

  static ({int mul, int shg})? _officialStackBlurConstants(int radius) {
    // NovelAI's current infill worker calls blur with radius 20.
    if (radius == 20) {
      return (mul: 39, shg: 16);
    }
    return null;
  }

  static bool _hasAnyRgb(Uint8List data, int index) {
    return data[index] != 0 || data[index + 1] != 0 || data[index + 2] != 0;
  }

  static int _clampByte(int value) => _clampInt(value, 0, 255);

  static int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static img.Image _alphaMatchRed(img.Image source) {
    final matched = img.Image.from(source, noAnimation: true);
    for (var y = 0; y < matched.height; y++) {
      for (var x = 0; x < matched.width; x++) {
        final pixel = matched.getPixel(x, y);
        final red = pixel.r.toInt();
        matched.setPixelRgba(x, y, red, pixel.g.toInt(), pixel.b.toInt(), red);
      }
    }
    return matched;
  }

  static Uint8List _encodeEditorOverlay(
    Uint8List binaryMask,
    int width,
    int height,
    int overlayAlpha,
  ) {
    final overlay = img.Image(width: width, height: height, numChannels: 4);

    var index = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (binaryMask[index++] == 1) {
          overlay.setPixelRgba(x, y, 96, 170, 255, overlayAlpha);
        } else {
          overlay.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }

    return Uint8List.fromList(img.encodePng(overlay));
  }

  static Uint8List _closeMask(
    Uint8List source,
    int width,
    int height,
    int iterations,
  ) {
    final expanded = _dilateMask(source, width, height, iterations);
    return _erodeMask(expanded, width, height, iterations);
  }

  static Uint8List _dilateMask(
    Uint8List source,
    int width,
    int height,
    int iterations,
  ) {
    var current = Uint8List.fromList(source);
    for (var i = 0; i < iterations; i++) {
      final next = Uint8List(width * height);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          var masked = false;
          for (var dy = -1; dy <= 1 && !masked; dy++) {
            final ny = y + dy;
            if (ny < 0 || ny >= height) {
              continue;
            }
            for (var dx = -1; dx <= 1; dx++) {
              final nx = x + dx;
              if (nx < 0 || nx >= width) {
                continue;
              }
              if (current[ny * width + nx] == 1) {
                masked = true;
                break;
              }
            }
          }
          next[y * width + x] = masked ? 1 : 0;
        }
      }
      current = next;
    }
    return current;
  }

  static Uint8List _erodeMask(
    Uint8List source,
    int width,
    int height,
    int iterations,
  ) {
    var current = Uint8List.fromList(source);
    for (var i = 0; i < iterations; i++) {
      final next = Uint8List(width * height);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          var masked = true;
          for (var dy = -1; dy <= 1 && masked; dy++) {
            final ny = y + dy;
            if (ny < 0 || ny >= height) {
              masked = false;
              break;
            }
            for (var dx = -1; dx <= 1; dx++) {
              final nx = x + dx;
              if (nx < 0 || nx >= width || current[ny * width + nx] == 0) {
                masked = false;
                break;
              }
            }
          }
          next[y * width + x] = masked ? 1 : 0;
        }
      }
      current = next;
    }
    return current;
  }

  static Uint8List _alignMaskToLatentGrid(
    Uint8List source,
    int width,
    int height,
    int latentGridSize,
  ) {
    const minBlockCoverage = 0.25;
    final aligned = Uint8List(width * height);

    for (var blockY = 0; blockY < height; blockY += latentGridSize) {
      final blockBottom = (blockY + latentGridSize).clamp(0, height);
      for (var blockX = 0; blockX < width; blockX += latentGridSize) {
        final blockRight = (blockX + latentGridSize).clamp(0, width);
        final blockWidth = blockRight - blockX;
        final blockHeight = blockBottom - blockY;
        final blockArea = blockWidth * blockHeight;

        var maskedPixels = 0;
        for (var y = blockY; y < blockBottom; y++) {
          for (var x = blockX; x < blockRight; x++) {
            if (source[y * width + x] == 1) {
              maskedPixels++;
            }
          }
        }

        if (maskedPixels / blockArea < minBlockCoverage) {
          continue;
        }

        for (var y = blockY; y < blockBottom; y++) {
          for (var x = blockX; x < blockRight; x++) {
            aligned[y * width + x] = 1;
          }
        }
      }
    }

    return aligned;
  }
}
