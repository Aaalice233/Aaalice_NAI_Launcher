import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'isolate_pool.dart';

/// 读取与 `img.decodeImage` 结果一致的图像宽高，能从编码头确定时不解码像素。
abstract final class DecodedImageSize {
  static const Set<img.ImageFormat> _headerFormats = {
    img.ImageFormat.png,
    img.ImageFormat.jpg,
    img.ImageFormat.webp,
  };

  /// 只解析 PNG/JPEG/WebP 编码头；其它格式或头部异常返回 null。
  static (int, int)? readHeader(Uint8List bytes) {
    try {
      final decoder = img.findDecoderForData(bytes);
      if (decoder == null || !_headerFormats.contains(decoder.format)) {
        return null;
      }
      final info = decoder.startDecode(bytes);
      if (info == null || info.width <= 0 || info.height <= 0) {
        return null;
      }
      if (decoder.format == img.ImageFormat.jpg && _jpegSwapsAxes(bytes)) {
        return (info.height, info.width);
      }
      return (info.width, info.height);
    } catch (_) {
      return null;
    }
  }

  /// 编码头读不出时在后台 isolate 完整解码；解码异常与 `img.decodeImage` 一样原样抛出。
  static Future<(int, int)?> read(Uint8List bytes, {ComputeGate? gate}) async {
    final size = readHeader(bytes);
    if (size != null) {
      return size;
    }
    return (gate ?? ComputeGate()).runIsolate(() => _decodeSize(bytes));
  }

  static (int, int)? _decodeSize(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    return decoded == null ? null : (decoded.width, decoded.height);
  }

  // decodeImage 会把 EXIF 方向烘焙进像素，方向 5–8 输出宽高互换。
  static bool _jpegSwapsAxes(Uint8List bytes) {
    final imageIfd = img.decodeJpgExif(bytes)?.imageIfd;
    final orientation = imageIfd != null && imageIfd.hasOrientation
        ? imageIfd.orientation!
        : 0;
    return orientation >= 5 && orientation <= 8;
  }
}
