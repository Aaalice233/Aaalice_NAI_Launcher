import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;

import '../network/error_mappers/api_error_mapper.dart';
import 'app_logger.dart';

/// NAI API 工具类
/// 提供 NovelAI API 相关的共享静态方法
class NAIApiUtils {
  static final Expando<bool> _normalizedPreciseReferencePngCache =
      Expando<bool>('normalizedPreciseReferencePng');

  /// 标记该字节对象已经是 Director Reference 可直接提交的 PNG。
  static Uint8List markNormalizedPreciseReferencePng(Uint8List imageBytes) {
    _normalizedPreciseReferencePngCache[imageBytes] = true;
    return imageBytes;
  }

  /// 当前会话中是否已确认该字节对象是规范化后的 Director Reference PNG。
  static bool isKnownNormalizedPreciseReferencePng(Uint8List imageBytes) {
    return _normalizedPreciseReferencePngCache[imageBytes] == true;
  }

  /// 将 double 转换为 JSON 数值（整数或浮点数）
  /// 如果是整数值（如 5.0），返回 int；否则返回 double
  static num toJsonNumber(double value) {
    return value == value.truncateToDouble() ? value.toInt() : value;
  }

  /// 将图片转换为 NovelAI Director Reference 要求的格式
  /// 按官方 Web 客户端 Q6 路径处理：
  /// - 选择三种目标画布之一：(1024,1536), (1536,1024), (1472,1472)
  /// - 选择宽高比最接近原图的目标画布
  /// - 按比例缩放图像，黑色背景居中粘贴
  /// - 转换为 PNG 格式
  static Uint8List ensurePngFormat(Uint8List imageBytes) {
    // 解码图片
    final originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) {
      AppLogger.w('Failed to decode image, returning original bytes', 'Utils');
      return imageBytes;
    }

    final int width = originalImage.width;
    final int height = originalImage.height;

    AppLogger.d(
      'Processing character reference: ${width}x$height, channels: ${originalImage.numChannels}',
      'Utils',
    );

    final targets = [
      (1024, 1536), // portrait
      (1536, 1024), // landscape
      (1472, 1472), // square
    ];

    final imageAspectRatio = width / height;
    var bestTarget = targets.first;
    var bestAspectDelta = (bestTarget.$1 / bestTarget.$2 - imageAspectRatio)
        .abs();
    for (final target in targets.skip(1)) {
      final aspectDelta = (target.$1 / target.$2 - imageAspectRatio).abs();
      if (aspectDelta < bestAspectDelta) {
        bestAspectDelta = aspectDelta;
        bestTarget = target;
      }
    }
    final targetW = bestTarget.$1;
    final targetH = bestTarget.$2;

    final targetAspectRatio = targetW / targetH;
    final (newW, newH) = imageAspectRatio > targetAspectRatio
        ? (targetW, (targetW / imageAspectRatio).round())
        : ((targetH * imageAspectRatio).round(), targetH);
    final resized = img.copyResize(
      originalImage,
      width: newW,
      height: newH,
      interpolation: img.Interpolation.cubic,
    );

    final newImg = img.Image(
      width: targetW,
      height: targetH,
      numChannels: 3,
      backgroundColor: img.ColorRgb8(0, 0, 0), // 黑色背景
    );

    final left = (targetW - newW) ~/ 2;
    final top = (targetH - newH) ~/ 2;
    img.compositeImage(newImg, resized, dstX: left, dstY: top);

    final pngBytes = Uint8List.fromList(img.encodePng(newImg));
    AppLogger.d(
      'Character reference processed: ${width}x$height -> ${targetW}x$targetH (centered on black), '
          '${imageBytes.length} bytes -> ${pngBytes.length} bytes',
      'Utils',
    );

    return markNormalizedPreciseReferencePng(pngBytes);
  }

  /// 在后台 isolate 中执行 Director Reference 图片规范化，避免阻塞 UI isolate。
  static Future<Uint8List> ensurePngFormatAsync(Uint8List imageBytes) async {
    final normalizedBytes = await Isolate.run(
      () => ensurePngFormat(imageBytes),
    );
    return markNormalizedPreciseReferencePng(normalizedBytes);
  }

  /// 格式化 DioException 为错误代码（供 UI 层本地化显示）
  /// 返回格式: "ERROR_CODE|详细信息"
  static String formatDioError(DioException e) {
    return ApiErrorMapper.formatDioError(e);
  }
}
