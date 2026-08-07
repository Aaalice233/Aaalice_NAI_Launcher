import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 展示用缩略图压缩工具
///
/// 与 Vibe 库使用相同的压缩策略：最长边 256px、JPEG q78，
/// 超过 64KB 的原图在后台 Isolate 中压缩，避免阻塞 UI。
class DisplayThumbnailUtils {
  DisplayThumbnailUtils._();

  /// 缩略图最长边
  static const int maxDimension = 256;

  /// 小于该体积的图片直接内联，不做压缩
  static const int inlineLimitBytes = 64 * 1024;

  /// JPEG 压缩质量
  static const int jpegQuality = 78;

  /// 同步压缩（供 Isolate 内调用）
  ///
  /// 解码失败返回 null；已满足尺寸与体积要求的原样返回。
  static Uint8List? resizeSync(Uint8List sourceBytes) {
    final img.Image? source;
    try {
      source = img.decodeImage(sourceBytes);
    } catch (_) {
      return null;
    }
    if (source == null) {
      return null;
    }

    final longestSide = math.max(source.width, source.height);
    if (longestSide <= maxDimension && sourceBytes.length <= inlineLimitBytes) {
      return sourceBytes;
    }

    final scale = maxDimension / longestSide;
    final width = math.max(1, (source.width * scale).round());
    final height = math.max(1, (source.height * scale).round());
    final resized = img.copyResize(
      source,
      width: width,
      height: height,
      interpolation: img.Interpolation.average,
    );
    return Uint8List.fromList(img.encodeJpg(resized, quality: jpegQuality));
  }

  /// 规范化为展示缩略图
  ///
  /// 空数据或无法解码的图片返回 null；大图走后台 Isolate 压缩。
  static Future<Uint8List?> normalize(Uint8List sourceBytes) async {
    if (sourceBytes.isEmpty) {
      return null;
    }

    if (sourceBytes.length <= inlineLimitBytes) {
      return resizeSync(sourceBytes);
    }

    return Isolate.run(() => resizeSync(sourceBytes));
  }
}
