import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/exif_orientation.dart';
import 'package:nai_launcher/core/utils/isolate_pool.dart';

import '../../helpers/exif_orientation_fixture.dart';
import '../../helpers/shared_compute_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const orientations = [1, 2, 3, 4, 5, 6, 7, 8];

  group('ExifOrientation.read', () {
    test('reads every orientation from jpeg and webp headers', () {
      for (final orientation in orientations) {
        final sources = {
          'jpeg': orientedCameraJpeg(orientation: orientation),
          'webp': orientedCameraWebp(orientation: orientation),
        };

        for (final MapEntry(key: name, value: bytes) in sources.entries) {
          final reason = '$name $orientation';
          expect(ExifOrientation.read(bytes), orientation, reason: reason);
          expect(
            ExifOrientation.transformsPixels(bytes),
            orientation != 1,
            reason: reason,
          );
          expect(
            ExifOrientation.swapsAxes(bytes),
            orientation >= 5,
            reason: reason,
          );
        }
      }
    });

    test('ignores formats flutter does not rotate and missing exif', () {
      final truncatedWebp = orientedCameraWebp(orientation: 6);
      for (final bytes in [
        _png(6, 4),
        _pngWithExif(orientation: 6),
        plainWebp,
        orientedCameraWebp(orientation: 6, exifPrefix: true),
        truncatedWebp.sublist(0, truncatedWebp.length - 4),
        Uint8List.fromList(img.encodeJpg(_image(6, 4))),
        orientedCameraJpeg(orientation: 6).sublist(0, 24),
        Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x01, 0xFF, 0xD9]),
        Uint8List(0),
        Uint8List.fromList([0xFF, 0xD8, 0xFF]),
      ]) {
        expect(ExifOrientation.read(bytes), isNull);
        expect(ExifOrientation.transformsPixels(bytes), isFalse);
        expect(ExifOrientation.swapsAxes(bytes), isFalse);
      }
    });
  });

  test('ignores jpeg exif after the scan like flutter', () async {
    final jpeg = Uint8List.fromList(img.encodeJpg(_image(6, 4)));
    final exif = jpegExifPayload(orientedCameraJpeg(orientation: 6));
    final app1 = [
      0xFF,
      0xE1,
      ...[(exif.length + 8) >> 8, (exif.length + 8) & 0xFF],
      ...'Exif\u0000\u0000'.codeUnits,
      ...exif,
    ];
    final exifAfterScan = Uint8List.fromList([
      ...jpeg.sublist(0, jpeg.length - 2),
      ...app1,
      0xFF,
      0xD9,
    ]);

    expect(ExifOrientation.read(exifAfterScan), isNull);
    final shown = await _flutterDecode(exifAfterScan);
    expect((shown.width, shown.height), (6, 4));
  });

  group('ExifOrientation.decodeUpright', () {
    test('matches the webp pixels flutter displays', () async {
      for (final orientation in orientations) {
        for (final exifPrefix in [false, true]) {
          final webp = orientedCameraWebp(
            orientation: orientation,
            exifPrefix: exifPrefix,
          );

          _expectSamePixels(
            ExifOrientation.decodeUpright(webp)!,
            await _flutterDecode(webp),
            reason: 'orientation $orientation, Exif prefix $exifPrefix',
          );
        }
      }
    });

    test('matches the jpeg size flutter displays', () async {
      for (final orientation in orientations) {
        final jpeg = orientedCameraJpeg(orientation: orientation);
        final upright = ExifOrientation.decodeUpright(jpeg)!;
        final shown = await _flutterDecode(jpeg);

        expect(
          (upright.width, upright.height),
          (shown.width, shown.height),
          reason: 'orientation $orientation',
        );
      }
    });

    test('keeps png eXIf unapplied like flutter', () async {
      final png = _pngWithExif(orientation: 6);

      _expectSamePixels(
        ExifOrientation.decodeUpright(png)!,
        await _flutterDecode(png),
        reason: 'png',
      );
    });

    test('matches the gray and 16-bit png colors flutter displays', () async {
      const rgb8 = (img.Format.uint8, 3);
      const rgba8 = (img.Format.uint8, 4);
      const rgba16 = (img.Format.uint16, 4);
      for (final (name, png, layout) in [
        ('gray1', _grayPng(img.Format.uint1), rgb8),
        ('gray2', _grayPng(img.Format.uint2), rgb8),
        ('gray4', _grayPng(img.Format.uint4), rgb8),
        ('gray8', _grayPng(img.Format.uint8), rgb8),
        ('gray16', _grayPng(img.Format.uint16), rgba16),
        ('grayAlpha8', _rawPng(img.Format.uint8, 2), rgba8),
        ('grayAlpha16', _rawPng(img.Format.uint16, 2), rgba16),
        ('rgb16', _rawPng(img.Format.uint16, 3), rgba16),
      ]) {
        final upright = ExifOrientation.decodeUpright(png)!;
        final shown = await _flutterDecode(png);

        expect((upright.format, upright.numChannels), layout, reason: name);
        for (final pixel in shown) {
          final other = upright.getPixel(pixel.x, pixel.y);
          expect(
            [
              other.rNormalized,
              other.gNormalized,
              other.bNormalized,
              other.aNormalized,
            ].map((channel) => (channel * 255).round()),
            pairwiseCompare(
              [pixel.r, pixel.g, pixel.b, pixel.a],
              (num actual, num expected) => (actual - expected).abs() <= 1,
              'within 1 of',
            ),
            reason: '$name at ${pixel.x},${pixel.y}',
          );
        }
      }
    });

    test('uprightSize answers the decodeUpright size without rotating', () {
      for (final orientation in orientations) {
        for (final bytes in [
          orientedCameraJpeg(orientation: orientation),
          orientedCameraWebp(orientation: orientation),
        ]) {
          final upright = ExifOrientation.decodeUpright(bytes)!;
          final stored = img.decodeImage(bytes)!;

          expect(ExifOrientation.uprightSize(bytes, stored), (
            upright.width,
            upright.height,
          ), reason: 'orientation $orientation');
        }
      }
      final png = _pngWithExif(orientation: 6);
      expect(ExifOrientation.uprightSize(png, img.decodeImage(png)!), (6, 4));
    });
  });

  group('ExifOrientation.bakeToPng', () {
    test('encodes oriented jpeg and webp as the png they decode to', () async {
      final sources = {
        'jpeg 6': orientedCameraJpeg(orientation: 6),
        for (final orientation in orientations.skip(1))
          'webp $orientation': orientedCameraWebp(orientation: orientation),
      };

      for (final MapEntry(key: name, value: bytes) in sources.entries) {
        final upright = ExifOrientation.decodeUpright(bytes)!;
        final results = [
          ExifOrientation.bakeToPng(bytes),
          await ExifOrientation.bakeToPngAsync(bytes),
        ];

        for (final baked in results) {
          expect(ExifOrientation.read(baked), isNull, reason: name);
          _expectSamePixels(img.decodePng(baked)!, upright, reason: name);
        }
      }
    });

    test('returns other bytes untouched without leaving the caller', () async {
      final gate = ComputeGate.forTesting(maxConcurrentTasks: 1);

      for (final bytes in [
        Uint8List.fromList(img.encodeJpg(_image(6, 4))),
        orientedCameraJpeg(orientation: 1),
        orientedCameraWebp(orientation: 1),
        _png(6, 4),
        _pngWithExif(orientation: 6),
        plainWebp,
        Uint8List.fromList(utf8.encode('not an image')),
      ]) {
        expect(identical(ExifOrientation.bakeToPng(bytes), bytes), isTrue);
        final baked = await expectRunsWithoutComputeGate(
          gate,
          () => ExifOrientation.bakeToPngAsync(bytes, gate: gate),
        );
        expect(identical(baked, bytes), isTrue);
      }
    });

    test('bakes on the compute gate', () async {
      for (final bytes in [
        orientedCameraJpeg(orientation: 6),
        orientedCameraWebp(orientation: 6),
      ]) {
        final gate = ComputeGate.forTesting(maxConcurrentTasks: 1);

        final baked = await expectQueuedBehindComputeGate(
          gate,
          () => ExifOrientation.bakeToPngAsync(bytes, gate: gate),
        );

        final png = img.decodePng(baked)!;
        expect(png.width < png.height, isTrue);
      }
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

Uint8List _png(int width, int height) =>
    Uint8List.fromList(img.encodePng(_image(width, height)));

Uint8List _grayPng(img.Format format) {
  final image = img.Image(width: 6, height: 4, format: format, numChannels: 1);
  final maxValue = image.maxChannelValue.toInt();
  final step = 37 * (maxValue ~/ 255 + 1);
  for (final pixel in image) {
    pixel.r = (pixel.x + pixel.y * image.width) * step % (maxValue + 1);
  }
  return Uint8List.fromList(img.encodePng(image));
}

// 这些布局的 getter/setter 本身有误，只能按原始通道写入；透明度保持较高，
// 避免 Flutter 预乘后反算的取整误差盖过被测差异
Uint8List _rawPng(img.Format format, int channels) {
  const width = 6;
  const height = 4;
  final maxValue = format == img.Format.uint16 ? 65535 : 255;
  final samples = List<int>.generate(width * height * channels, (index) {
    final pixel = index ~/ channels;
    final channel = index % channels;
    final isAlpha = channels == 2 && channel == 1;
    return isAlpha
        ? maxValue - pixel * maxValue ~/ 48
        : (pixel * 37 + channel * 91) * (maxValue ~/ 255) % (maxValue + 1);
  });
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: format == img.Format.uint16
        ? Uint16List.fromList(samples).buffer
        : Uint8List.fromList(samples).buffer,
    format: format,
    numChannels: channels,
  );
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _pngWithExif({required int orientation}) => withPngExif(
  _png(6, 4),
  jpegExifPayload(orientedCameraJpeg(orientation: orientation)),
);

Future<img.Image> _flutterDecode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    try {
      final rgba = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      return img.Image.fromBytes(
        width: frame.image.width,
        height: frame.image.height,
        bytes: rgba!.buffer,
        numChannels: 4,
      );
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

void _expectSamePixels(
  img.Image actual,
  img.Image expected, {
  required String reason,
}) {
  expect(
    (actual.width, actual.height),
    (expected.width, expected.height),
    reason: reason,
  );
  for (final pixel in expected) {
    final other = actual.getPixel(pixel.x, pixel.y);
    expect(
      (other.r, other.g, other.b),
      (pixel.r, pixel.g, pixel.b),
      reason: '$reason at ${pixel.x},${pixel.y}',
    );
  }
}

