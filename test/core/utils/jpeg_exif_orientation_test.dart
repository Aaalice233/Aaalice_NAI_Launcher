import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/isolate_pool.dart';
import 'package:nai_launcher/core/utils/jpeg_exif_orientation.dart';

void main() {
  group('JpegExifOrientation.read', () {
    test('reads every orientation from the jpeg header', () {
      for (final orientation in [1, 2, 3, 4, 5, 6, 7, 8]) {
        final jpeg = _orientedJpeg(orientation);

        expect(JpegExifOrientation.read(jpeg), orientation);
        expect(
          JpegExifOrientation.transformsPixels(jpeg),
          orientation != 1,
          reason: '$orientation',
        );
        expect(
          JpegExifOrientation.swapsAxes(jpeg),
          orientation >= 5,
          reason: '$orientation',
        );
      }
    });

    test('ignores other formats and jpeg without exif', () {
      for (final bytes in [
        _png(6, 4),
        _webpLossless,
        Uint8List.fromList(img.encodeJpg(_image(6, 4))),
        Uint8List(0),
        Uint8List.fromList([0xFF, 0xD8, 0xFF]),
      ]) {
        expect(JpegExifOrientation.read(bytes), isNull);
        expect(JpegExifOrientation.transformsPixels(bytes), isFalse);
      }
    });
  });

  group('JpegExifOrientation.bakeToPng', () {
    test('encodes an oriented jpeg as the png it decodes to', () async {
      final jpeg = _orientedJpeg(6);
      final decoded = img.decodeImage(jpeg)!;
      final results = [
        JpegExifOrientation.bakeToPng(jpeg),
        await JpegExifOrientation.bakeToPngAsync(jpeg),
      ];

      for (final baked in results) {
        final png = img.decodePng(baked)!;
        expect((png.width, png.height), (4, 6));
        expect(JpegExifOrientation.read(baked), isNull);
        for (final pixel in decoded) {
          final other = png.getPixel(pixel.x, pixel.y);
          expect(
            (other.r, other.g, other.b),
            (pixel.r, pixel.g, pixel.b),
            reason: '${pixel.x},${pixel.y}',
          );
        }
      }
    });

    test('returns other bytes untouched without leaving the caller', () async {
      final gate = ComputeGate.forTesting(maxConcurrentTasks: 1);
      final release = Completer<void>();
      final occupied = gate.run(() => release.future);

      for (final bytes in [
        Uint8List.fromList(img.encodeJpg(_image(6, 4))),
        _orientedJpeg(1),
        _png(6, 4),
        _webpLossless,
        Uint8List.fromList(utf8.encode('not an image')),
      ]) {
        expect(identical(JpegExifOrientation.bakeToPng(bytes), bytes), isTrue);
        expect(
          identical(
            await JpegExifOrientation.bakeToPngAsync(bytes, gate: gate),
            bytes,
          ),
          isTrue,
        );
      }

      release.complete();
      await occupied;
    });

    test('bakes on the compute gate', () async {
      final gate = ComputeGate.forTesting(maxConcurrentTasks: 1);
      final release = Completer<void>();
      final occupied = gate.run(() => release.future);
      var resolved = false;

      final baked = JpegExifOrientation.bakeToPngAsync(
        _orientedJpeg(6),
        gate: gate,
      ).whenComplete(() => resolved = true);
      await Future<void>.delayed(Duration.zero);
      expect(resolved, isFalse);

      release.complete();
      await occupied;
      expect(img.decodePng(await baked)!.width, 4);
    });
  });
}

img.Image _image(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (final pixel in image) {
    pixel.setRgb(pixel.x * 40, pixel.y * 60, 90);
  }
  return image;
}

Uint8List _orientedJpeg(int orientation) {
  final image = _image(6, 4)..exif.imageIfd.orientation = orientation;
  return Uint8List.fromList(img.encodeJpg(image, quality: 100));
}

Uint8List _png(int width, int height) =>
    Uint8List.fromList(img.encodePng(_image(width, height)));

final _webpLossless = base64Decode(
  'UklGRqAAAABXRUJQVlA4TJQAAAAvE0ADALkyRPQ/FgrSNmC6419vpZhp28b8Ebfdjuh//CUC'
  'gEEjSYrqSQH617p0EhS3bePGmFx79WMUSZLi+Ebk8Yvxdx6YJFxMAOGaVt4jYOUS3RKsMPhm'
  'JIIJEyqwAwNK8ECyAPfQYkXeIGEBAIVto8UCABfAbebs4ATAXzkF+FEcULLiAwANBxB2ALwg'
  '1Xr3AwAS',
);
