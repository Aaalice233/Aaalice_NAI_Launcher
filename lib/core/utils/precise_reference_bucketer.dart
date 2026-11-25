import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'app_logger.dart';
import 'exif_container.dart';
import 'exif_orientation.dart';
import 'isolate_pool.dart';
import 'pica_lanczos_resizer.dart';

abstract final class PreciseReferenceBucketer {
  static final _byOriginal = Expando<Future<Uint8List>>();

  static Future<Uint8List> prepare(Uint8List original) =>
      _byOriginal[original] ??= _prepareInBackground(original);

  static Future<Uint8List> _prepareInBackground(Uint8List original) async {
    try {
      final resized = await ComputeGate().runCompute<Uint8List, Uint8List?>(
        _resizeToBucket,
        original,
      );
      return resized ?? original;
    } catch (_) {
      _byOriginal[original] = null;
      rethrow;
    }
  }

  static ({
    int width,
    int height,
    int resizeWidth,
    int resizeHeight,
    int left,
    int top,
    bool unchanged,
  })
  layout(int width, int height) {
    final aspect = math.log(math.max(width, 1) / math.max(height, 1));
    var best = _buckets.first;
    var bestDistance = (aspect - math.log(best.$1 / best.$2)).abs();
    for (final bucket in _buckets) {
      final distance = (aspect - math.log(bucket.$1 / bucket.$2)).abs();
      if (distance < bestDistance) {
        best = bucket;
        bestDistance = distance;
      }
    }

    final (bucketWidth, bucketHeight) = best;
    final scale = math.max(bucketWidth / width, bucketHeight / height);
    final resizeWidth = math.max((width * scale + .5).floor(), bucketWidth);
    final resizeHeight = math.max((height * scale + .5).floor(), bucketHeight);
    return (
      width: bucketWidth,
      height: bucketHeight,
      resizeWidth: resizeWidth,
      resizeHeight: resizeHeight,
      left: (resizeWidth - bucketWidth) ~/ 2,
      top: (resizeHeight - bucketHeight) ~/ 2,
      unchanged: width == bucketWidth && height == bucketHeight,
    );
  }

  static Uint8List? _resizeToBucket(Uint8List original) {
    final img.Image? image;
    try {
      image = ExifOrientation.decodeUpright(original);
    } catch (error, stackTrace) {
      AppLogger.e('精准参考图片解码失败，发送原图', error, stackTrace, 'ImgGen');
      return null;
    }
    if (image == null) return null;

    final bucket = layout(image.width, image.height);
    if (bucket.unchanged) {
      return img.PngDecoder().isValidFile(original) ||
              ExifContainer.isJpeg(original) ||
              ExifContainer.isWebp(original)
          ? null
          : ExifOrientation.encodeUpload(image);
    }

    final rgba = image.format == img.Format.uint8 && !image.hasPalette
        ? image
        : image.convert(format: img.Format.uint8, numChannels: 4);
    final pixels = PicaLanczosResizer.resizeBuffer(
      rgba.getBytes(order: img.ChannelOrder.rgba),
      sourceWidth: image.width,
      sourceHeight: image.height,
      targetWidth: bucket.resizeWidth,
      targetHeight: bucket.resizeHeight,
    );
    final resized = img.Image.fromBytes(
      width: bucket.resizeWidth,
      height: bucket.resizeHeight,
      bytes: pixels.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    final cropped = img.copyCrop(
      resized,
      x: bucket.left,
      y: bucket.top,
      width: bucket.width,
      height: bucket.height,
    );
    return ExifOrientation.encodeUpload(cropped);
  }

  // 官网按此顺序扫描，距离相同时保留前一个桶。
  static const _buckets = [
    (256, 4096),
    (256, 4032),
    (256, 3968),
    (256, 3904),
    (256, 3840),
    (256, 3776),
    (256, 3712),
    (256, 3648),
    (256, 3584),
    (256, 3520),
    (256, 3456),
    (256, 3392),
    (256, 3328),
    (320, 3264),
    (320, 3200),
    (320, 3136),
    (320, 3072),
    (320, 3008),
    (320, 2944),
    (320, 2880),
    (320, 2816),
    (320, 2752),
    (384, 2688),
    (384, 2624),
    (384, 2560),
    (384, 2496),
    (384, 2432),
    (384, 2368),
    (448, 2304),
    (448, 2240),
    (448, 2176),
    (448, 2112),
    (512, 2048),
    (512, 1984),
    (512, 1920),
    (512, 1856),
    (576, 1792),
    (576, 1728),
    (576, 1664),
    (640, 1600),
    (640, 1536),
    (704, 1472),
    (704, 1408),
    (768, 1344),
    (768, 1280),
    (832, 1216),
    (896, 1152),
    (960, 1088),
    (1024, 1024),
    (1088, 960),
    (1152, 896),
    (1216, 832),
    (1280, 768),
    (1344, 768),
    (1408, 704),
    (1472, 704),
    (1536, 640),
    (1600, 640),
    (1664, 576),
    (1728, 576),
    (1792, 576),
    (1856, 512),
    (1920, 512),
    (1984, 512),
    (2048, 512),
    (2112, 448),
    (2176, 448),
    (2240, 448),
    (2304, 448),
    (2368, 384),
    (2432, 384),
    (2496, 384),
    (2560, 384),
    (2624, 384),
    (2688, 384),
    (2752, 320),
    (2816, 320),
    (2880, 320),
    (2944, 320),
    (3008, 320),
    (3072, 320),
    (3136, 320),
    (3200, 320),
    (3264, 320),
    (3328, 256),
    (3392, 256),
    (3456, 256),
    (3520, 256),
    (3584, 256),
    (3648, 256),
    (3712, 256),
    (3776, 256),
    (3840, 256),
    (3904, 256),
    (3968, 256),
    (4032, 256),
    (4096, 256),
  ];
}
