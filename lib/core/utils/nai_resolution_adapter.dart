import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'isolate_pool.dart';
import 'pica_lanczos_resizer.dart';

/// NovelAI 分辨率适配器
///
/// 将任意尺寸图像缩放到 NovelAI Web 当前使用的导入分辨率。
class NaiResolutionAdapter {
  NaiResolutionAdapter._();

  // NovelAI web build ae6a6aa-production, verified 2026-07-16.
  /// 当前官网图像生成请求的最大像素面积。
  static const int officialMaxPixels = 3145728;

  /// 当前官网图像编辑器工作画布的最长边限制。
  static const int officialEditorMaxSide = 2560;

  /// 当前官网普通 NAI 模型导入基准边。
  static const int officialNaiTargetLongSide = 1216;
  static const int officialNaiTargetShortSide = 896;

  /// 当前官网 Stable Diffusion 族模型导入基准边。
  static const int officialStableDiffusionTargetLongSide = 768;
  static const int officialStableDiffusionTargetShortSide = 512;

  static const int _officialGridSize = 64;

  /// 检查尺寸是否已经兼容 NAI（宽高均为 64 的倍数）
  static bool isCompatible(int width, int height) {
    return width % 64 == 0 && height % 64 == 0 && width >= 64 && height >= 64;
  }

  /// 检查尺寸是否可被官网导入逻辑直接使用。
  static bool isOfficialImportCompatible(int width, int height) {
    return isCompatible(width, height) && width * height <= officialMaxPixels;
  }

  /// 按当前 NovelAI Web 的 Image2Image 导入逻辑计算目标分辨率。
  ///
  /// 官网逻辑会先把横图临时转为竖向计算，再在两个基准边
  /// (1216/896 或 768/512) 中选择宽高比误差更小的 64-grid 结果。
  /// 如果图片已经是 64-grid 且面积不超过上限，则直接使用原尺寸。
  static ({int width, int height, double scaleFactor})
  findOfficialImportResolution(
    int sourceWidth,
    int sourceHeight, {
    int? currentWidth,
    int? currentHeight,
    bool isStableDiffusionFamily = false,
  }) {
    final sourceAspect = sourceWidth / sourceHeight;
    final isLandscape = sourceAspect > 1;

    var orientedWidth = sourceWidth;
    var orientedHeight = sourceHeight;
    if (isLandscape) {
      final temp = orientedWidth;
      orientedWidth = orientedHeight;
      orientedHeight = temp;
    }

    final orientedAspect = orientedWidth / orientedHeight;
    final currentMatchesAspect =
        currentWidth != null &&
        currentHeight != null &&
        currentWidth / currentHeight == sourceAspect;
    final fitsCurrent =
        currentWidth != null &&
        currentHeight != null &&
        orientedWidth <= currentWidth &&
        orientedHeight <= currentHeight;

    if (currentMatchesAspect && fitsCurrent) {
      return (
        width: currentWidth,
        height: currentHeight,
        scaleFactor: _combinedScale(
          sourceWidth,
          sourceHeight,
          currentWidth,
          currentHeight,
        ),
      );
    }

    if (!isOfficialImportCompatible(orientedWidth, orientedHeight)) {
      final targetLongSide = isStableDiffusionFamily
          ? officialStableDiffusionTargetLongSide
          : officialNaiTargetLongSide;
      final targetShortSide = isStableDiffusionFamily
          ? officialStableDiffusionTargetShortSide
          : officialNaiTargetShortSide;

      final widthFromLongSide = _nearestOfficialGrid(
        targetLongSide * orientedAspect,
      );
      final heightFromShortSide = _nearestOfficialGrid(
        targetShortSide / orientedAspect,
      );

      final longSideAspectError =
          (widthFromLongSide / targetLongSide - orientedAspect).abs();
      final shortSideAspectError =
          (targetShortSide / heightFromShortSide - orientedAspect).abs();

      if (longSideAspectError < shortSideAspectError &&
          widthFromLongSide * targetLongSide <= officialMaxPixels) {
        orientedWidth = widthFromLongSide;
        orientedHeight = targetLongSide;
      } else if (targetShortSide * heightFromShortSide <= officialMaxPixels) {
        orientedWidth = targetShortSide;
        orientedHeight = heightFromShortSide;
      } else {
        orientedWidth = 512;
        orientedHeight = 512;
      }
    }

    var targetWidth = orientedWidth;
    var targetHeight = orientedHeight;
    if (isLandscape) {
      final temp = targetWidth;
      targetWidth = targetHeight;
      targetHeight = temp;
    }

    return (
      width: targetWidth,
      height: targetHeight,
      scaleFactor: _combinedScale(
        sourceWidth,
        sourceHeight,
        targetWidth,
        targetHeight,
      ),
    );
  }

  /// 找到最接近的 NAI 兼容分辨率
  ///
  /// 策略：
  ///   1. 先检查是否已经是 64 倍数 → 直接返回
  ///   2. 将宽高分别舍入到最近的 64 倍数
  ///   3. 在 4 种组合（floor/ceil × floor/ceil）中选面积变化和宽高比偏移最小的
  ///   4. 保证结果 >= 64 且 <= 4096
  static ({int width, int height, double scaleFactor}) findClosestResolution(
    int sourceWidth,
    int sourceHeight,
  ) {
    if (isCompatible(sourceWidth, sourceHeight)) {
      return (width: sourceWidth, height: sourceHeight, scaleFactor: 1.0);
    }

    // 对宽高分别做 floor/ceil 到 64 倍数，取最优组合
    final wFloor = _floorTo64(sourceWidth);
    final wCeil = _ceilTo64(sourceWidth);
    final hFloor = _floorTo64(sourceHeight);
    final hCeil = _ceilTo64(sourceHeight);

    final candidates = [
      (wFloor, hFloor),
      (wFloor, hCeil),
      (wCeil, hFloor),
      (wCeil, hCeil),
    ];

    var bestW = wFloor;
    var bestH = hFloor;
    var bestScore = double.infinity;

    for (final (cw, ch) in candidates) {
      if (cw < 64 || ch < 64 || cw > 4096 || ch > 4096) continue;

      // 评分 = 面积变化比 + 宽高比偏移（加权）
      final areaRatio = (cw * ch) / (sourceWidth * sourceHeight);
      final arSource = sourceWidth / sourceHeight;
      final arCandidate = cw / ch;
      final arDiff = (arSource - arCandidate).abs() / arSource;
      final score = (areaRatio - 1.0).abs() + arDiff * 2.0;

      if (score < bestScore) {
        bestScore = score;
        bestW = cw;
        bestH = ch;
      }
    }

    final scale = _combinedScale(sourceWidth, sourceHeight, bestW, bestH);
    return (width: bestW, height: bestH, scaleFactor: scale);
  }

  /// 将图像字节数据适配到最近的 NAI 兼容分辨率
  ///
  /// 如果图像已经兼容，直接返回原数据，不做任何处理。
  /// 使用 Lanczos3 插值以贴近 NovelAI Web 的请求归一化行为。
  ///
  /// 返回 null 表示解码失败。
  static NaiAdaptedImage? adaptImage(Uint8List imageBytes) {
    return adaptImageForImport(imageBytes);
  }

  /// 将图像字节数据适配到当前 NovelAI Web 的 Image2Image 导入尺寸。
  ///
  /// [currentWidth]/[currentHeight] 对应官网导入时当前参数面板里的尺寸。
  /// 当原图宽高比与当前尺寸相同且不大于当前尺寸时，官网会保留当前参数
  /// 尺寸，并在请求发送前把源图 resize 到这个尺寸。
  static NaiAdaptedImage? adaptImageForImport(
    Uint8List imageBytes, {
    int? currentWidth,
    int? currentHeight,
    bool isStableDiffusionFamily = false,
  }) {
    img.Image? decoded;
    final imageSize = readImageSize(imageBytes);
    if (imageSize == null) {
      decoded = img.decodeImage(imageBytes);
      if (decoded == null) return null;
    }

    final srcW = imageSize?.$1 ?? decoded!.width;
    final srcH = imageSize?.$2 ?? decoded!.height;
    final target = findOfficialImportResolution(
      srcW,
      srcH,
      currentWidth: currentWidth,
      currentHeight: currentHeight,
      isStableDiffusionFamily: isStableDiffusionFamily,
    );

    if (srcW == target.width && srcH == target.height) {
      return NaiAdaptedImage(
        bytes: imageBytes,
        width: srcW,
        height: srcH,
        wasResized: false,
        originalWidth: srcW,
        originalHeight: srcH,
      );
    }

    decoded ??= img.decodeImage(imageBytes);
    if (decoded == null) return null;
    final resized = PicaLanczosResizer.resizeImage(
      decoded,
      width: target.width,
      height: target.height,
    );

    final encoded = img.encodePng(resized);

    return NaiAdaptedImage(
      bytes: Uint8List.fromList(encoded),
      width: target.width,
      height: target.height,
      wasResized: true,
      originalWidth: srcW,
      originalHeight: srcH,
    );
  }

  /// 只解析图生图导入后的目标尺寸，不在导入阶段重采样或重编码图片字节。
  ///
  /// NovelAI Web 会在导入时更新请求尺寸；实际 source image bytes 会在请求
  /// 发送前按当前 width/height 归一化。
  static NaiImportImageInfo? describeImageForImport(
    Uint8List imageBytes, {
    int? currentWidth,
    int? currentHeight,
    bool isStableDiffusionFamily = false,
  }) {
    final imageSize = readImageSize(imageBytes);
    if (imageSize == null) return null;

    final srcW = imageSize.$1;
    final srcH = imageSize.$2;
    final target = findOfficialImportResolution(
      srcW,
      srcH,
      currentWidth: currentWidth,
      currentHeight: currentHeight,
      isStableDiffusionFamily: isStableDiffusionFamily,
    );

    return NaiImportImageInfo(
      width: target.width,
      height: target.height,
      originalWidth: srcW,
      originalHeight: srcH,
    );
  }

  /// 将源图归一化到当前请求尺寸。
  ///
  /// NovelAI Web 在发送 img2img/infill 请求前会确保 image 字节宽高等于
  /// 请求参数中的 width/height；这可以覆盖导入后用户又手动改尺寸的场景。
  static Uint8List? normalizeImageForRequest(
    Uint8List imageBytes, {
    required int targetWidth,
    required int targetHeight,
  }) {
    // 先读元数据：尺寸已匹配时不解码、不重采样也不重新编码。
    if (_imageSizeMatches(imageBytes, targetWidth, targetHeight)) {
      return imageBytes;
    }

    final img.Image? decoded;
    try {
      decoded = img.decodeImage(imageBytes);
    } catch (_) {
      return null;
    }
    if (decoded == null) return null;

    if (decoded.width == targetWidth && decoded.height == targetHeight) {
      return imageBytes;
    }

    final resized = PicaLanczosResizer.resizeImage(
      decoded,
      width: targetWidth,
      height: targetHeight,
    );

    // 仅作为请求载体、不落盘：用最快压缩等级换编码时间（像素无损）。
    return Uint8List.fromList(img.encodePng(resized, level: 1));
  }

  /// 异步版本，适合大图在 isolate 中处理
  static Future<NaiAdaptedImage?> adaptImageAsync(
    Uint8List imageBytes, {
    int? currentWidth,
    int? currentHeight,
    bool isStableDiffusionFamily = false,
  }) {
    return ComputeGate().runIsolate(
      () => adaptImageForImport(
        imageBytes,
        currentWidth: currentWidth,
        currentHeight: currentHeight,
        isStableDiffusionFamily: isStableDiffusionFamily,
      ),
    );
  }

  /// 异步解析导入尺寸，避免大图解码阻塞 UI isolate。
  static Future<NaiImportImageInfo?> describeImageForImportAsync(
    Uint8List imageBytes, {
    int? currentWidth,
    int? currentHeight,
    bool isStableDiffusionFamily = false,
  }) {
    return ComputeGate().runIsolate(
      () => describeImageForImport(
        imageBytes,
        currentWidth: currentWidth,
        currentHeight: currentHeight,
        isStableDiffusionFamily: isStableDiffusionFamily,
      ),
    );
  }

  /// 构造官网编辑器语义下的独立工作图。
  ///
  /// 最长边超过 2560 时先等比缩小；Inpaint/Mask 编辑随后把宽高
  /// 分别向上对齐到 64，并将图像绘制到完整工作画布。
  static NaiEditorImage? prepareImageForEditor(
    Uint8List imageBytes, {
    required bool alignForInpaint,
  }) {
    img.Image? decoded;
    final imageSize = readImageSize(imageBytes);
    if (imageSize == null) {
      decoded = img.decodeImage(imageBytes);
      if (decoded == null) return null;
    }

    final originalWidth = imageSize?.$1 ?? decoded!.width;
    final originalHeight = imageSize?.$2 ?? decoded!.height;
    var width = originalWidth;
    var height = originalHeight;
    final longestSide = math.max(width, height);
    if (longestSide > officialEditorMaxSide) {
      final scale = officialEditorMaxSide / longestSide;
      width = math.max(1, (width * scale).round());
      height = math.max(1, (height * scale).round());
    }
    if (alignForInpaint) {
      width = _ceilToGrid(width);
      height = _ceilToGrid(height);
    }

    final wasNormalized = width != originalWidth || height != originalHeight;
    if (!wasNormalized) {
      return NaiEditorImage(
        bytes: imageBytes,
        width: width,
        height: height,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
        wasNormalized: false,
        resizeMode: NaiEditorResizeMode.passthrough,
      );
    }

    // Small Inpaint sources only need ceil64. The editor materializes this
    // branch once with Canvas FilterQuality.medium on the UI isolate.
    if (longestSide <= officialEditorMaxSide) {
      return NaiEditorImage(
        bytes: imageBytes,
        width: width,
        height: height,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
        wasNormalized: true,
        resizeMode: NaiEditorResizeMode.medium,
      );
    }

    decoded ??= img.decodeImage(imageBytes);
    if (decoded == null) return null;
    final resized = PicaLanczosResizer.resizeImage(
      decoded,
      width: width,
      height: height,
    );
    return NaiEditorImage(
      bytes: Uint8List.fromList(img.encodePng(resized, level: 1)),
      width: width,
      height: height,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      wasNormalized: true,
      resizeMode: NaiEditorResizeMode.picaLanczos3,
    );
  }

  static Future<NaiEditorImage?> prepareImageForEditorAsync(
    Uint8List imageBytes, {
    required bool alignForInpaint,
  }) {
    return ComputeGate().runIsolate(
      () => prepareImageForEditor(imageBytes, alignForInpaint: alignForInpaint),
    );
  }

  /// 异步请求归一化版本，避免大图 Lanczos3 resize 阻塞 UI isolate。
  static Future<Uint8List?> normalizeImageForRequestAsync(
    Uint8List imageBytes, {
    required int targetWidth,
    required int targetHeight,
  }) {
    // 尺寸已匹配时直接短路，连 isolate 往返都省掉。
    if (_imageSizeMatches(imageBytes, targetWidth, targetHeight)) {
      return Future.value(imageBytes);
    }
    return ComputeGate().runIsolate(
      () => normalizeImageForRequest(
        imageBytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      ),
    );
  }

  // ==================== 内部方法 ====================

  static int _floorTo64(int value) {
    final result = (value ~/ 64) * 64;
    return result.clamp(64, 4096);
  }

  static int _ceilTo64(int value) {
    final result = ((value + 63) ~/ 64) * 64;
    return result.clamp(64, 4096);
  }

  static int _ceilToGrid(int value) {
    return math.max(
      _officialGridSize,
      ((value + _officialGridSize - 1) ~/ _officialGridSize) *
          _officialGridSize,
    );
  }

  static int _nearestOfficialGrid(double value) {
    if (value.isNaN) return 0;
    final floor = (value / _officialGridSize).floor() * _officialGridSize;
    final ceil = (value / _officialGridSize).ceil() * _officialGridSize;
    final nearest = value - floor < ceil - value ? floor : ceil;
    return nearest <= 0 ? _officialGridSize : nearest;
  }

  static bool _isPng(Uint8List bytes) {
    return bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
  }

  static bool _imageSizeMatches(Uint8List bytes, int width, int height) {
    final size = readImageSize(bytes);
    return size != null && size.$1 == width && size.$2 == height;
  }

  /// 只解析编码头获取画布尺寸，不解码任何像素帧。
  static (int, int)? readImageSize(Uint8List bytes) {
    final pngSize = _tryReadPngSize(bytes);
    if (pngSize != null) {
      return pngSize;
    }
    try {
      final decoder = img.findDecoderForData(bytes);
      final info = decoder?.startDecode(bytes);
      if (info == null || info.width <= 0 || info.height <= 0) {
        return null;
      }
      return (info.width, info.height);
    } catch (_) {
      return null;
    }
  }

  /// 从 PNG IHDR 直接读取宽高（签名 8 字节 + 长度 4 字节 + 'IHDR' + w/h）。
  /// 非 PNG 或头部异常时返回 null，由调用方回退到完整解码。
  static (int, int)? _tryReadPngSize(Uint8List bytes) {
    if (bytes.length < 24 || !_isPng(bytes)) {
      return null;
    }
    if (bytes[12] != 0x49 ||
        bytes[13] != 0x48 ||
        bytes[14] != 0x44 ||
        bytes[15] != 0x52) {
      return null;
    }
    final width =
        (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
    final height =
        (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
    if (width <= 0 || height <= 0) {
      return null;
    }
    return (width, height);
  }

  static double _combinedScale(int srcW, int srcH, int dstW, int dstH) {
    final scaleW = dstW / srcW;
    final scaleH = dstH / srcH;
    return (scaleW + scaleH) / 2.0;
  }
}

/// 适配后的图像数据
class NaiAdaptedImage {
  final Uint8List bytes;
  final int width;
  final int height;

  /// 是否经过了缩放
  final bool wasResized;

  /// 原始宽度
  final int originalWidth;

  /// 原始高度
  final int originalHeight;

  const NaiAdaptedImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.wasResized,
    required this.originalWidth,
    required this.originalHeight,
  });

  String get resizeDescription {
    if (!wasResized) return '无需调整';
    return '$originalWidth×$originalHeight → $width×$height';
  }
}

/// 图生图导入后应使用的请求尺寸信息。
class NaiImportImageInfo {
  final int width;
  final int height;

  /// 原始宽度
  final int originalWidth;

  /// 原始高度
  final int originalHeight;

  const NaiImportImageInfo({
    required this.width,
    required this.height,
    required this.originalWidth,
    required this.originalHeight,
  });

  bool get sizeChanged => originalWidth != width || originalHeight != height;

  String get resizeDescription {
    if (!sizeChanged) return '无需调整';
    return '$originalWidth×$originalHeight → $width×$height';
  }
}

enum NaiEditorResizeMode { passthrough, medium, picaLanczos3 }

class NaiEditorImage {
  const NaiEditorImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.originalWidth,
    required this.originalHeight,
    required this.wasNormalized,
    required this.resizeMode,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int originalWidth;
  final int originalHeight;
  final bool wasNormalized;
  final NaiEditorResizeMode resizeMode;
}
