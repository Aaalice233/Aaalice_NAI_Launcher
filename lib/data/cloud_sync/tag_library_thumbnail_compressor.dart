import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../core/utils/exif_orientation.dart';
import '../../core/utils/isolate_pool.dart';
import '../../core/utils/pica_lanczos_resizer.dart';

class CompressedTagThumbnail {
  const CompressedTagThumbnail(this.bytes);

  final Uint8List bytes;
  String get extension => '.jpg';
  String get mediaType => 'image/jpeg';
}

class TagLibraryThumbnailCompressor {
  const TagLibraryThumbnailCompressor();

  static const int maximumEdge = 512;
  static const int targetBytes = 256 * 1024;

  /// 读完源图后在后台 isolate 解码、缩放并编码。
  Future<CompressedTagThumbnail> compress(Stream<List<int>> source) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in source) {
      builder.add(chunk);
    }
    return _compressInBackground(builder.takeBytes());
  }

  static Future<CompressedTagThumbnail> _compressInBackground(
    Uint8List bytes,
  ) => ComputeGate().runIsolate(() => compressBytes(bytes));

  /// 同步压缩，供后台 isolate 调用；源图无法解码时抛出 [FormatException]。
  static CompressedTagThumbnail compressBytes(Uint8List bytes) {
    final decoded = ExifOrientation.decodeUpright(bytes);
    if (decoded == null) {
      throw const FormatException('Tag thumbnail is not a supported image');
    }

    var targetWidth = decoded.width;
    var targetHeight = decoded.height;
    final longest = math.max(targetWidth, targetHeight);
    if (longest > maximumEdge) {
      final scale = maximumEdge / longest;
      targetWidth = math.max(1, (targetWidth * scale).round());
      targetHeight = math.max(1, (targetHeight * scale).round());
    }
    var image = targetWidth == decoded.width && targetHeight == decoded.height
        ? decoded
        : PicaLanczosResizer.resizeImage(
            decoded,
            width: targetWidth,
            height: targetHeight,
          );
    image = _flattenAlpha(image);

    while (true) {
      Uint8List? smallest;
      for (final quality in const [82, 74, 66, 58, 50]) {
        final encoded = Uint8List.fromList(
          img.encodeJpg(image, quality: quality),
        );
        smallest = encoded;
        if (encoded.length <= targetBytes) {
          return CompressedTagThumbnail(encoded);
        }
      }
      if (image.width <= 64 && image.height <= 64) {
        return CompressedTagThumbnail(smallest!);
      }
      final scale = math.min(
        0.85,
        math.sqrt(targetBytes / smallest!.length) * 0.92,
      );
      image = PicaLanczosResizer.resizeImage(
        image,
        width: math.max(1, (image.width * scale).round()),
        height: math.max(1, (image.height * scale).round()),
      );
    }
  }

  static img.Image _flattenAlpha(img.Image source) {
    if (!source.hasAlpha) return source;
    final background = img.Image(
      width: source.width,
      height: source.height,
      numChannels: 3,
    );
    img.fill(background, color: img.ColorRgb8(32, 32, 32));
    img.compositeImage(background, source);
    return background;
  }
}
