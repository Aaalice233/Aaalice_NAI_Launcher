import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/exif_orientation.dart';
import 'package:nai_launcher/core/utils/isolate_pool.dart';
import 'package:nai_launcher/data/services/metadata/image_metadata_container_codec.dart';

import '../../helpers/exif_orientation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const orientations = [1, 2, 3, 4, 5, 6, 7, 8];

  group('ExifOrientation.read', () {
    test('reads every orientation from jpeg and webp headers', () {
      for (final orientation in orientations) {
        final sources = {
          'jpeg': _orientedJpeg(orientation),
          'webp': orientedCameraWebp(orientation: orientation),
          'webp with Exif prefix': orientedCameraWebp(
            orientation: orientation,
            exifPrefix: true,
          ),
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
        _webpLossless,
        truncatedWebp.sublist(0, truncatedWebp.length - 4),
        Uint8List.fromList(img.encodeJpg(_image(6, 4))),
        Uint8List(0),
        Uint8List.fromList([0xFF, 0xD8, 0xFF]),
      ]) {
        expect(ExifOrientation.read(bytes), isNull);
        expect(ExifOrientation.transformsPixels(bytes), isFalse);
        expect(ExifOrientation.swapsAxes(bytes), isFalse);
      }
    });
  });

  group('ExifOrientation.decodeUpright', () {
    test('matches the webp pixels flutter displays', () async {
      for (final orientation in orientations) {
        final webp = orientedCameraWebp(orientation: orientation);

        _expectSamePixels(
          ExifOrientation.decodeUpright(webp)!,
          await _flutterDecode(webp),
          reason: 'orientation $orientation',
        );
      }
    });

    test('matches the jpeg size flutter displays', () async {
      for (final orientation in orientations) {
        final jpeg = _orientedJpeg(orientation);
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

    test('uprightSize answers the decodeUpright size without rotating', () {
      for (final orientation in orientations) {
        for (final bytes in [
          _orientedJpeg(orientation),
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
        'jpeg 6': _orientedJpeg(6),
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
      final release = Completer<void>();
      final occupied = gate.run(() => release.future);

      for (final bytes in [
        Uint8List.fromList(img.encodeJpg(_image(6, 4))),
        _orientedJpeg(1),
        orientedCameraWebp(orientation: 1),
        _png(6, 4),
        _pngWithExif(orientation: 6),
        _webpLossless,
        Uint8List.fromList(utf8.encode('not an image')),
      ]) {
        expect(identical(ExifOrientation.bakeToPng(bytes), bytes), isTrue);
        expect(
          identical(
            await ExifOrientation.bakeToPngAsync(bytes, gate: gate),
            bytes,
          ),
          isTrue,
        );
      }

      release.complete();
      await occupied;
    });

    test('bakes on the compute gate', () async {
      for (final bytes in [
        _orientedJpeg(6),
        orientedCameraWebp(orientation: 6),
      ]) {
        final gate = ComputeGate.forTesting(maxConcurrentTasks: 1);
        final release = Completer<void>();
        final occupied = gate.run(() => release.future);
        var resolved = false;

        final baked = ExifOrientation.bakeToPngAsync(
          bytes,
          gate: gate,
        ).whenComplete(() => resolved = true);
        await Future<void>.delayed(Duration.zero);
        expect(resolved, isFalse);

        release.complete();
        await occupied;
        final png = img.decodePng(await baked)!;
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

Uint8List _orientedJpeg(int orientation) {
  final image = _image(6, 4)..exif.imageIfd.orientation = orientation;
  return Uint8List.fromList(img.encodeJpg(image, quality: 100));
}

Uint8List _png(int width, int height) =>
    Uint8List.fromList(img.encodePng(_image(width, height)));

Uint8List _pngWithExif({required int orientation}) =>
    ImageMetadataContainerCodec.copySupportedMetadata(
      source: orientedCameraJpeg(orientation: orientation),
      targetPng: _png(6, 4),
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

final _webpLossless = base64Decode(
  'UklGRqAAAABXRUJQVlA4TJQAAAAvE0ADALkyRPQ/FgrSNmC6419vpZhp28b8Ebfdjuh//CUC'
  'gEEjSYrqSQH617p0EhS3bePGmFx79WMUSZLi+Ebk8Yvxdx6YJFxMAOGaVt4jYOUS3RKsMPhm'
  'JIIJEyqwAwNK8ECyAPfQYkXeIGEBAIVto8UCABfAbebs4ATAXzkF+FEcULLiAwANBxB2ALwg'
  '1Xr3AwAS',
);
