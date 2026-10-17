import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 16×16 基线 JPEG，段顺序与 libjpeg 系工具（ImageMagick、Pillow）从官网 WebP 转出的文件一致：
/// SOI、APP0 JFIF、每个 [exifTiffs] 各一个 APP1 `Exif\0\0`、DQT、SOF0、DHT、SOS。
Uint8List novelAiLayoutJpeg({List<List<int>> exifTiffs = const []}) {
  final plain = Uint8List.fromList(
    img.encodeJpg(img.Image(width: 16, height: 16)),
  );
  final afterApp0 = 4 + ((plain[4] << 8) | plain[5]);
  return Uint8List.fromList([
    ...plain.sublist(0, afterApp0),
    for (final tiff in exifTiffs) ...jpegExifSegment(tiff),
    ...plain.sublist(afterApp0),
  ]);
}

/// 载荷为 `Exif\0\0` 加 [tiff] 的 APP1 段，含标记与段长。
List<int> jpegExifSegment(List<int> tiff) {
  final length = 2 + 6 + tiff.length;
  return [
    0xFF,
    0xE1,
    length >> 8,
    length & 0xFF,
    ...ascii.encode('Exif\u0000\u0000'),
    ...tiff,
  ];
}
