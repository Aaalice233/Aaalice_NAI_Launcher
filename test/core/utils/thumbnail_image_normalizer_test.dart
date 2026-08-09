import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/thumbnail_image_normalizer.dart';

void main() {
  group('normalizeThumbnailImageToPng', () {
    test('将 BMP 图像转换为 PNG', () {
      final source = img.Image(width: 2, height: 1)
        ..setPixelRgba(0, 0, 255, 0, 0, 255)
        ..setPixelRgba(1, 0, 0, 255, 0, 255);
      final bmpBytes = Uint8List.fromList(img.encodeBmp(source));

      final normalized = normalizeThumbnailImageToPng(bmpBytes);
      final decoded = img.decodePng(normalized);

      expect(decoded, isNotNull);
      expect(decoded!.width, 2);
      expect(decoded.height, 1);
      expect(decoded.getPixel(0, 0).r, 255);
      expect(decoded.getPixel(1, 0).g, 255);
    });

    test('将 WebP 图像转换为 PNG', () {
      final webpBytes = base64Decode(
        'UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA==',
      );

      final normalized = normalizeThumbnailImageToPng(webpBytes);
      final decoded = img.decodePng(normalized);

      expect(decoded, isNotNull);
      expect(decoded!.width, 1);
      expect(decoded.height, 1);
    });

    test('拒绝无法解码的数据', () {
      expect(
        () => normalizeThumbnailImageToPng(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    });
  });

  test('文件选择器包含扩展格式', () {
    expect(
      supportedThumbnailImageExtensions,
      containsAll(<String>[
        'jpe',
        'jfif',
        'webp',
        'gif',
        'bmp',
        'tif',
        'tiff',
        'tga',
        'ico',
      ]),
    );
  });
}
