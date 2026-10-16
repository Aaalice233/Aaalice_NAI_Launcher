import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/decoded_image_size.dart';
import 'package:nai_launcher/core/utils/exif_orientation.dart';
import 'package:nai_launcher/core/utils/isolate_pool.dart';

import '../../helpers/exif_orientation_fixture.dart';

void main() {
  group('DecodedImageSize.readHeader', () {
    test('matches decodeImage for png, jpeg and webp headers', () {
      final cases = <String, (Uint8List, (int, int))>{
        'png': (Uint8List.fromList(img.encodePng(_image(6, 4))), (6, 4)),
        'jpeg': (Uint8List.fromList(img.encodeJpg(_image(6, 4))), (6, 4)),
        'webp lossless': (_webpLossless, (20, 14)),
        'webp lossy': (_webpLossy, (6, 4)),
        'webp lossy alpha': (_webpLossyAlpha, (6, 4)),
        'webp animated': (_webpAnimated, (6, 4)),
      };

      for (final MapEntry(key: name, value: (bytes, size)) in cases.entries) {
        expect(_decodedSize(bytes), size, reason: name);
        expect(DecodedImageSize.readHeader(bytes), size, reason: name);
      }
    });

    test('reads webp headers even when the pixel decoder rejects them', () {
      expect(() => img.decodeImage(_webpPalette), throwsRangeError);
      expect(DecodedImageSize.readHeader(_webpPalette), (6, 4));
    });

    test('applies jpeg exif orientation like decodeImage', () {
      for (final orientation in [1, 2, 3, 4, 5, 6, 7, 8]) {
        final source = _image(6, 4)..exif.imageIfd.orientation = orientation;
        final jpeg = Uint8List.fromList(img.encodeJpg(source));
        final expected = orientation >= 5 ? (4, 6) : (6, 4);

        expect(_decodedSize(jpeg), expected, reason: '$orientation');
        expect(
          DecodedImageSize.readHeader(jpeg),
          expected,
          reason: '$orientation',
        );
      }
    });

    test('applies webp exif orientation like flutter', () {
      for (final orientation in [1, 2, 3, 4, 5, 6, 7, 8]) {
        final webp = orientedCameraWebp(orientation: orientation);
        final upright = ExifOrientation.decodeUpright(webp)!;
        final uprightSize = (upright.width, upright.height);

        expect(
          DecodedImageSize.readHeader(webp),
          orientation >= 5 ? (14, 20) : (20, 14),
          reason: '$orientation',
        );
        expect(
          DecodedImageSize.readHeader(webp),
          uprightSize,
          reason: '$orientation',
        );
      }
    });

    test('leaves other formats and broken bytes to a full decode', () {
      expect(
        DecodedImageSize.readHeader(
          Uint8List.fromList(img.encodeGif(_image(6, 4))),
        ),
        isNull,
      );
      expect(
        DecodedImageSize.readHeader(
          Uint8List.fromList(img.encodeBmp(_image(6, 4))),
        ),
        isNull,
      );
      expect(DecodedImageSize.readHeader(Uint8List(0)), isNull);
      expect(
        DecodedImageSize.readHeader(Uint8List.fromList([1, 2, 3])),
        isNull,
      );
    });
  });

  group('DecodedImageSize.read', () {
    test(
      'answers header formats without waiting for the compute gate',
      () async {
        final gate = ComputeGate.forTesting(maxConcurrentTasks: 1);
        final release = Completer<void>();
        final occupied = gate.run(() => release.future);

        final size = await DecodedImageSize.read(
          Uint8List.fromList(img.encodePng(_image(6, 4))),
          gate: gate,
        );

        expect(size, (6, 4));
        release.complete();
        await occupied;
      },
    );

    test('decodes other formats in the background like decodeImage', () async {
      final gate = ComputeGate.forTesting(maxConcurrentTasks: 1);
      final gif = Uint8List.fromList(img.encodeGif(_image(6, 4)));
      final bmp = Uint8List.fromList(img.encodeBmp(_image(5, 3)));

      final release = Completer<void>();
      final occupied = gate.run(() => release.future);
      var gifResolved = false;
      final gifSize = DecodedImageSize.read(
        gif,
        gate: gate,
      ).whenComplete(() => gifResolved = true);
      await Future<void>.delayed(Duration.zero);
      expect(gifResolved, isFalse);
      release.complete();
      await occupied;

      expect(await gifSize, _decodedSize(gif));
      expect(await DecodedImageSize.read(bmp, gate: gate), _decodedSize(bmp));
    });

    test('keeps decodeImage null and error outcomes', () async {
      final unknown = Uint8List.fromList(utf8.encode('not an image at all'));
      expect(_decodedSize(unknown), isNull);
      expect(await DecodedImageSize.read(unknown), isNull);

      final empty = Uint8List(0);
      expect(() => img.decodeImage(empty), throwsA(isA<RangeError>()));
      await expectLater(
        DecodedImageSize.read(empty),
        throwsA(isA<RangeError>()),
      );
    });
  });

  group('DecodedImageSize.tryRead', () {
    test('reports decode failures as null', () async {
      expect(await DecodedImageSize.tryRead(Uint8List(0)), isNull);
      expect(
        await DecodedImageSize.tryRead(
          Uint8List.fromList(utf8.encode('not an image at all')),
        ),
        isNull,
      );
    });

    test('returns the same size as read', () async {
      final source = _image(6, 4)..exif.imageIfd.orientation = 6;
      final jpeg = Uint8List.fromList(img.encodeJpg(source));
      final bmp = Uint8List.fromList(img.encodeBmp(_image(5, 3)));

      expect(await DecodedImageSize.tryRead(jpeg), (4, 6));
      expect(
        await DecodedImageSize.tryRead(orientedCameraWebp(orientation: 8)),
        (14, 20),
      );
      expect(await DecodedImageSize.tryRead(bmp), (5, 3));
    });
  });
}

img.Image _image(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 40, 90));
  return image;
}

(int, int)? _decodedSize(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  return decoded == null ? null : (decoded.width, decoded.height);
}

final _webpLossless = base64Decode(
  'UklGRqAAAABXRUJQVlA4TJQAAAAvE0ADALkyRPQ/FgrSNmC6419vpZhp28b8Ebfdjuh//CUC'
  'gEEjSYrqSQH617p0EhS3bePGmFx79WMUSZLi+Ebk8Yvxdx6YJFxMAOGaVt4jYOUS3RKsMPhm'
  'JIIJEyqwAwNK8ECyAPfQYkXeIGEBAIVto8UCABfAbebs4ATAXzkF+FEcULLiAwANBxB2ALwg'
  '1Xr3AwAS',
);

final _webpPalette = base64Decode(
  'UklGRh4AAABXRUJQVlA4TBEAAAAvBcAAAAdQlCJXq/+BiOh/AAA=',
);

final _webpLossy = base64Decode(
  'UklGRjQAAABXRUJQVlA4ICgAAABwAQCdASoGAAQAAUAmJaACdAFAAAD+77zxU/+4OP/7g4//'
  'uDj90wAA',
);

final _webpLossyAlpha = base64Decode(
  'UklGRlgAAABXRUJQVlA4WAoAAAAQAAAABQAAAwAAQUxQSAoAAAABB1DAiAhERP8DVlA4ICgA'
  'AABwAQCdASoGAAQAAUAmJaACdAFAAAD+77zxU/+4OP/7g4//uDj90wAA',
);

final _webpAnimated = base64Decode(
  'UklGRrQAAABXRUJQVlA4WAoAAAACAAAABQAAAwAAQU5JTQYAAAAAAAAAAABBTk1GOgAAAAAA'
  'AAAAAAUAAAMAAGQAAAJWUDggIgAAADABAJ0BKgYABAABQCYllAADcAD+/DeL22WiUD7k/RGA'
  'AABBTk1GRgAAAAAAAAAAAAUAAAMAAGQAAABWUDggLgAAADQBAJ0BKgYABAAAACYloAADcAD+'
  '899n/8W/aP723j//++gH/99AP/76Af18AAA=',
);
