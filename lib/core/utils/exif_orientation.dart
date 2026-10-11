import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'color_channel_normalizer.dart';
import 'exif_container.dart';
import 'isolate_pool.dart';

/// JPEG 与 WebP 的 EXIF 方向：Flutter 引擎显示时会把它转进像素，PNG 的 eXIf 不处理。
abstract final class ExifOrientation {
  /// 只读 JPEG 首个 EXIF APP1 段或 WebP 首个 EXIF 块；其它格式、没有方向标签或 EXIF 损坏时返回 null。
  ///
  /// WebP 块带 `Exif\0\0` 前缀时 Flutter 不识别方向，这里同样不剥前缀。
  static int? read(Uint8List bytes) {
    try {
      final tiff = ExifContainer.isJpeg(bytes)
          ? ExifContainer.jpegExifPayloads(bytes).firstOrNull
          : ExifContainer.webpExifChunks(bytes).firstOrNull;
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

  /// 解码出与 Flutter 显示一致的像素：JPEG 解码器已按方向转正，WebP 在这里补转，
  /// 并规范成像素 getter 可靠的颜色布局。
  static img.Image? decodeUpright(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final color = ColorChannelNormalizer.normalize(decoded);
    if (!ExifContainer.isWebp(bytes)) return color;
    final orientation = read(bytes);
    if (orientation == null || orientation < 2 || orientation > 8) {
      return color;
    }
    color.exif.imageIfd.orientation = orientation;
    return img.bakeOrientation(color);
  }

  /// `img.decodeImage` 结果转正后的宽高，只需尺寸时省去 [decodeUpright] 的整图旋转。
  static (int, int) uprightSize(Uint8List bytes, img.Image decoded) =>
      ExifContainer.isWebp(bytes) && swapsAxes(bytes)
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
}
