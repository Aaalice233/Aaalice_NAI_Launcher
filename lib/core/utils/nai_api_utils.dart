import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;

import '../network/error_mappers/api_error_mapper.dart';
import 'app_logger.dart';

/// NAI API 工具类
/// 提供 NovelAI API 相关的共享静态方法
class NAIApiUtils {
  /// 将 double 转换为 JSON 数值（整数或浮点数）
  /// 如果是整数值（如 5.0），返回 int；否则返回 double
  static num toJsonNumber(double value) {
    return value == value.truncateToDouble() ? value.toInt() : value;
  }

  /// 将图片转换为 NovelAI Director Reference 要求的格式
  /// 根据 Reddit 帖子的正确实现：
  /// - 缩放到三种"大"分辨率之一：(1024,1536), (1536,1024), (1472,1472)
  /// - 选择最接近的目标尺寸（最小化未使用的填充）
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

    // =========================================================
    // 1. 目标尺寸（portrait, landscape, square）
    // 根据 Reddit 帖子，必须是这三种大分辨率之一
    // =========================================================
    final targets = [
      (1024, 1536), // portrait
      (1536, 1024), // landscape
      (1472, 1472), // square
    ];

    // 计算最佳适配（最小化未使用的填充面积）
    int fitScore(int tw, int th) {
      final scale = min(tw / width, th / height);
      final newW = (width * scale).toInt();
      final newH = (height * scale).toInt();
      final padW = tw - newW;
      final padH = th - newH;
      return padW * padH; // 填充面积越小越好
    }

    // 选择最佳目标尺寸
    var bestTarget = targets.first;
    var bestScore = fitScore(bestTarget.$1, bestTarget.$2);
    for (final target in targets.skip(1)) {
      final score = fitScore(target.$1, target.$2);
      if (score < bestScore) {
        bestScore = score;
        bestTarget = target;
      }
    }
    final targetW = bestTarget.$1;
    final targetH = bestTarget.$2;

    // =========================================================
    // 2. 按比例缩放图像
    // =========================================================
    final scale = min(targetW / width, targetH / height);
    final newW = (width * scale).toInt();
    final newH = (height * scale).toInt();
    final resized = img.copyResize(
      originalImage,
      width: newW,
      height: newH,
      interpolation: img.Interpolation.cubic,
    );

    // =========================================================
    // 3. 创建黑色背景并居中粘贴
    // =========================================================
    final newImg = img.Image(
      width: targetW,
      height: targetH,
      numChannels: 3,
      backgroundColor: img.ColorRgb8(0, 0, 0), // 黑色背景
    );

    // 填充黑色像素
    for (int y = 0; y < targetH; y++) {
      for (int x = 0; x < targetW; x++) {
        newImg.setPixelRgb(x, y, 0, 0, 0);
      }
    }

    // 居中粘贴
    final left = (targetW - newW) ~/ 2;
    final top = (targetH - newH) ~/ 2;
    img.compositeImage(newImg, resized, dstX: left, dstY: top);

    // =========================================================
    // 4. 转换为 PNG（Reddit 帖子说 PNG preferred）
    // =========================================================
    final pngBytes = Uint8List.fromList(img.encodePng(newImg));
    AppLogger.d(
      'Character reference processed: ${width}x$height -> ${targetW}x$targetH (centered on black), '
          '${imageBytes.length} bytes -> ${pngBytes.length} bytes',
      'Utils',
    );

    return pngBytes;
  }

  /// 格式化 DioException 为错误代码（供 UI 层本地化显示）
  /// 返回格式: "ERROR_CODE|详细信息"
  static String formatDioError(DioException e) {
    return ApiErrorMapper.formatDioError(e);
  }
}
