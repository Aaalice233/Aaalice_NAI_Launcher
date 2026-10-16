import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/thumbnail_image_normalizer.dart';

import '../../helpers/exif_orientation_fixture.dart';
import '../../helpers/image_pixel_matchers.dart';
import '../../helpers/shared_compute_gate.dart';

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

    test('带方向的 WebP 按 Flutter 显示的方向输出', () {
      for (final exifPrefix in [false, true]) {
        final webp = orientedCameraWebp(orientation: 6, exifPrefix: exifPrefix);

        // 带前缀的 EXIF 块 Flutter 不识别，原样输出
        expectPixelsWithin(
          img.decodePng(normalizeThumbnailImageToPng(webp))!,
          exifPrefix ? img.decodeImage(webp)! : displayedWebp(webp, 6),
        );
      }
    });

    test('拒绝无法解码的数据', () {
      expect(
        () => normalizeThumbnailImageToPng(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    });

    test('后台转换经过共享计算闸门排队且结果一致', () async {
      final bmpBytes = Uint8List.fromList(
        img.encodeBmp(img.Image(width: 3, height: 2)),
      );

      final normalized = await expectQueuedBehindSharedComputeGate(
        () => normalizeThumbnailImageToPngInBackground(bmpBytes),
      );

      expect(normalized, orderedEquals(normalizeThumbnailImageToPng(bmpBytes)));
    });

    test('后台转换保留无法解码时的错误类型', () async {
      await expectLater(
        normalizeThumbnailImageToPngInBackground(Uint8List.fromList([1, 2, 3])),
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
