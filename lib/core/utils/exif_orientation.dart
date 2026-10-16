import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'isolate_pool.dart';

/// JPEG 与 WebP 的 EXIF 方向：Flutter 引擎显示时会把它转进像素，PNG 的 eXIf 不处理。
abstract final class ExifOrientation {
  /// 只读 JPEG 的 APP1 或 WebP 的 EXIF 块；其它格式、没有方向标签或 EXIF 损坏时返回 null。
  static int? read(Uint8List bytes) {
    try {
      if (_isJpeg(bytes)) {
        return _orientationOf(img.decodeJpgExif(bytes));
      }
      final tiff = _webpExifPayload(bytes);
      return tiff == null
          ? null
          : _orientationOf(img.ExifData.fromInputBuffer(img.InputBuffer(tiff)));
    } catch (_) {
      return null;
    }
  }

  /// 方向 2–8 时显示出的像素与存储像素不同。
  static bool transformsPixels(Uint8List bytes) {
    final orientation = read(bytes);
    return orientation != null && orientation >= 2 && orientation <= 8;
  }

  /// 方向 5–8 时转正后宽高互换。
  static bool swapsAxes(Uint8List bytes) {
    final orientation = read(bytes);
    return orientation != null && orientation >= 5 && orientation <= 8;
  }

  /// 解码出与 Flutter 显示一致的像素：JPEG 解码器已按方向转正，WebP 在这里补转。
  static img.Image? decodeUpright(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null || !_isWebp(bytes)) return decoded;
    final orientation = read(bytes);
    if (orientation == null || orientation < 2 || orientation > 8) {
      return decoded;
    }
    decoded.exif.imageIfd.orientation = orientation;
    return img.bakeOrientation(decoded);
  }

  /// `img.decodeImage` 结果转正后的宽高，只需尺寸时省去 [decodeUpright] 的整图旋转。
  static (int, int) uprightSize(Uint8List bytes, img.Image decoded) =>
      _isWebp(bytes) && swapsAxes(bytes)
      ? (decoded.height, decoded.width)
      : (decoded.width, decoded.height);

  /// 转正后编码为 PNG，与官网经 canvas 上传的形态一致；不需要转正的字节原样返回。
  static Uint8List bakeToPng(Uint8List bytes) {
    if (!transformsPixels(bytes)) return bytes;
    final decoded = decodeUpright(bytes);
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

  static int? _orientationOf(img.ExifData? exif) {
    final imageIfd = exif?.imageIfd;
    return imageIfd != null && imageIfd.hasOrientation
        ? imageIfd.orientation
        : null;
  }

  static bool _isJpeg(Uint8List bytes) =>
      bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;

  static bool _isWebp(Uint8List bytes) =>
      bytes.length >= 12 &&
      _fourCc(bytes, 0) == 'RIFF' &&
      _fourCc(bytes, 8) == 'WEBP';

  /// 只遍历 RIFF 块头找 EXIF 块，不触碰图像数据。
  static Uint8List? _webpExifPayload(Uint8List bytes) {
    if (!_isWebp(bytes)) return null;
    final view = ByteData.sublistView(bytes);
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final length = view.getUint32(offset + 4, Endian.little);
      final start = offset + 8;
      final end = start + length;
      if (end > bytes.length) return null;
      if (_fourCc(bytes, offset) == 'EXIF') {
        final payload = Uint8List.sublistView(bytes, start, end);
        // 部分编码器在 TIFF 头前保留 JPEG APP1 的 `Exif\0\0` 前缀。
        return payload.length >= 6 && _fourCc(payload, 0) == 'Exif'
            ? Uint8List.sublistView(payload, 6)
            : payload;
      }
      offset = end + (length.isOdd ? 1 : 0);
    }
    return null;
  }

  static String _fourCc(Uint8List bytes, int offset) =>
      String.fromCharCodes(bytes, offset, offset + 4);
}
