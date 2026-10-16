import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'isolate_pool.dart';

/// JPEG 的 EXIF 方向：`img.decodeImage`、Flutter 引擎与浏览器解码时都会把它转进像素。
abstract final class JpegExifOrientation {
  /// 只读编码头；不是 JPEG、没有方向标签或 EXIF 损坏时返回 null。
  static int? read(Uint8List bytes) {
    if (bytes.length < 2 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
      return null;
    }
    try {
      final imageIfd = img.decodeJpgExif(bytes)?.imageIfd;
      return imageIfd != null && imageIfd.hasOrientation
          ? imageIfd.orientation
          : null;
    } catch (_) {
      return null;
    }
  }

  /// 方向 2–8 时解码出的像素与存储像素不同。
  static bool transformsPixels(Uint8List bytes) {
    final orientation = read(bytes);
    return orientation != null && orientation >= 2 && orientation <= 8;
  }

  /// 方向 5–8 时解码结果宽高互换。
  static bool swapsAxes(Uint8List bytes) {
    final orientation = read(bytes);
    return orientation != null && orientation >= 5 && orientation <= 8;
  }

  /// 转正后编码为 PNG，与官网经 canvas 上传的形态一致；不需要转正的字节原样返回。
  static Uint8List bakeToPng(Uint8List bytes) {
    if (!transformsPixels(bytes)) return bytes;
    final decoded = img.decodeImage(bytes);
    return decoded == null ? bytes : encodeUpload(decoded);
  }

  static Future<Uint8List> bakeToPngAsync(
    Uint8List bytes, {
    ComputeGate? gate,
  }) {
    if (!transformsPixels(bytes)) return Future.value(bytes);
    return (gate ?? ComputeGate()).runIsolate(() => bakeToPng(bytes));
  }

  /// 只作请求载体、不落盘：用最快压缩等级换编码时间（像素无损）。
  static Uint8List encodeUpload(img.Image image) =>
      Uint8List.fromList(img.encodePng(image, level: 1));
}
