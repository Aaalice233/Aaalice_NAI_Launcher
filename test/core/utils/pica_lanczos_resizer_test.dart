import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/pica_lanczos_resizer.dart';

void main() {
  group('PicaLanczosResizer', () {
    test('matches official Pica raw RGBA fixtures', () {
      for (final fixture in _fixtures) {
        final source = _buildSource(
          fixture.sourceWidth,
          fixture.sourceHeight,
          withAlpha: fixture.withAlpha,
        );
        final actual = PicaLanczosResizer.resizeRgba(
          source,
          sourceWidth: fixture.sourceWidth,
          sourceHeight: fixture.sourceHeight,
          targetWidth: fixture.targetWidth,
          targetHeight: fixture.targetHeight,
        );

        expect(
          actual,
          base64Decode(fixture.expectedBase64),
          reason: fixture.name,
        );
      }
    });

    test('premultiplies alpha and avoids colored transparent fringes', () {
      final source = Uint8List.fromList([
        255,
        0,
        0,
        0,
        0,
        255,
        0,
        255,
        0,
        0,
        255,
        0,
      ]);

      final actual = PicaLanczosResizer.resizeRgba(
        source,
        sourceWidth: 3,
        sourceHeight: 1,
        targetWidth: 9,
        targetHeight: 1,
      );

      expect(
        actual,
        base64Decode('AAAAAAAAAAAA/wBYAP8AxgD/AP8A/wDGAP8AWAAAAAAAAAAA'),
      );
      for (var index = 0; index < actual.length; index += 4) {
        if (actual[index + 3] == 0) {
          expect(actual.sublist(index, index + 3), [0, 0, 0]);
        }
      }
    });

    test('PNG codec round trip stays within one channel value', () {
      final fixture = _fixtures[1];
      final sourceBytes = _buildSource(
        fixture.sourceWidth,
        fixture.sourceHeight,
        withAlpha: fixture.withAlpha,
      );
      final source = img.Image.fromBytes(
        width: fixture.sourceWidth,
        height: fixture.sourceHeight,
        bytes: sourceBytes.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      final resized = PicaLanczosResizer.resizeImage(
        source,
        width: fixture.targetWidth,
        height: fixture.targetHeight,
      );
      final decoded = img.decodeImage(img.encodePng(resized))!;
      final actual = decoded.getBytes(order: img.ChannelOrder.rgba);
      final expected = base64Decode(fixture.expectedBase64);

      expect(actual.length, expected.length);
      for (var index = 0; index < actual.length; index++) {
        expect(
          (actual[index] - expected[index]).abs(),
          lessThanOrEqualTo(1),
          reason: 'Channel mismatch at byte $index',
        );
      }
    });

    test('returns an independent copy when dimensions already match', () {
      final source = _buildSource(2, 2, withAlpha: true);

      final actual = PicaLanczosResizer.resizeRgba(
        source,
        sourceWidth: 2,
        sourceHeight: 2,
        targetWidth: 2,
        targetHeight: 2,
      );

      expect(actual, source);
      expect(identical(actual, source), isFalse);
    });

    test('rejects buffers that do not match the declared dimensions', () {
      expect(
        () => PicaLanczosResizer.resizeRgba(
          Uint8List(3),
          sourceWidth: 1,
          sourceHeight: 1,
          targetWidth: 2,
          targetHeight: 2,
        ),
        throwsArgumentError,
      );
    });
  });
}

Uint8List _buildSource(int width, int height, {required bool withAlpha}) {
  final bytes = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final index = (y * width + x) * 4;
      bytes[index] = (x * 37 + y * 17 + 11) & 255;
      bytes[index + 1] = (x * 13 + y * 47 + 29) & 255;
      bytes[index + 2] = (x * 71 + y * 7 + 3) & 255;
      bytes[index + 3] = withAlpha ? (x * 53 + y * 29 + 19) & 255 : 255;
    }
  }
  return bytes;
}

// Generated offline with pica@10.0.2's raw Uint8 RGBA path used by NovelAI
// web build ae6a6aa-production, captured 2026-07-16. Keeping encoded image
// codecs outside these fixtures makes the core parity assertion byte-exact.
const _fixtures = <_PicaFixture>[
  _PicaFixture(
    name: 'opaque upscale',
    sourceWidth: 3,
    sourceHeight: 2,
    targetWidth: 5,
    targetHeight: 4,
    withAlpha: false,
    expectedBase64:
        'BRQA/xAYEv8tIkn/SiyA/1Uwlf8MJwH/FysV/zQ1TP9RP4P/XEOY/xVABP8gRBj/PU5P/1pYhv9lXJz/HFMF/ydXG/9EYVL/YWuJ/2xvn/8=',
  ),
  _PicaFixture(
    name: 'alpha upscale',
    sourceWidth: 4,
    sourceHeight: 3,
    targetWidth: 7,
    targetHeight: 5,
    withAlpha: true,
    expectedBase64:
        'AxUBDRcdHB0tJkZBOythYFg1mIBxPcike0HdtAolABUbKxwmMjNISkA5ZGldQ5uIdkzLrIBP370YSgMsJ1AfPD9YTWBPXmt/amefn4Nw0MOOdOXTJm8IQjNzI1NLfFF3XIJylneMpbWQldbZm5jp6it9C0s4giVbUYtUf2KQdJ98mqe+laPX4qCn7PI=',
  ),
  _PicaFixture(
    name: 'downscale',
    sourceWidth: 9,
    sourceHeight: 7,
    targetWidth: 4,
    targetHeight: 3,
    withAlpha: false,
    expectedBase64:
        'LENC/4Jsk//Lknj/QqyZ/1G4Uv+6nrD/iZx5/zxlSv+BUGX/v0CN/ztGh/9vaFv/',
  ),
  _PicaFixture(
    name: 'non-integer ratio',
    sourceWidth: 17,
    sourceHeight: 11,
    targetWidth: 13,
    targetHeight: 7,
    withAlpha: true,
    expectedBase64:
        'GC8TJEM9a2Z7Usm7k088gf9fcy1Yh/yBMJZbymCWkXCZ3C4+3uNKl8DguNMAwrpgcoJRVjBvG1BggneWjZfXx//1jSGw6KdgK79os0zQOrql//8htnBTedJNW95WXcClVBNWLnI3bZVE0Rt3geCN3KHFzVT2WBJBSJ2/kjY9OudwJwA/nEH4W9NIZLvzM0iGACrVLV5xUn2SkXzHbTE+xIxjfqH2bOIulyxCdyJFteBTTZyIk2MTPrWA35XrjXvIhOwxKjrjeld85CCsqNeMyIJNOtKmKaxM+mgOVCKGT7M9mbPEcsSNRp7WTmra0NTZ3uv2ZQNEgTVkZYuOmX825LRhgkyNnDOQ////M0zWQaMk10vDgIv/FYq0PlbDlHm/6DnDrUmNSChKK6l1h0GN2aY5FpP/V984qLFDKP9IzX1RZ0zEIdE5XYkh/z6lNWqY2j54ybc5olAjahdRb4OosJWQvsfZqA5KZ72+bA==',
  ),
  _PicaFixture(
    name: '1024 tile boundary',
    sourceWidth: 1030,
    sourceHeight: 5,
    targetWidth: 10,
    targetHeight: 4,
    withAlpha: true,
    expectedBase64:
        'fISCf4B+f4F/goR9f4KAgX99gX9+hIN/gH5+gX+ChH1/goCBgXyBfnx8gIGAgIB+gYKDgX58gH+ChIJ/fnyBgoCBgH6BgoOBfn2Af4OEg35/gn5+gIB+gIB7foB/g39+f3t9gn9/f36AgX6Af3t+gH+Df36BfH6BgX59gH59f4GBgn59f3t+gn+BgH6AfnyAfn1/gYGCfn2AfH+Bf4KAfg==',
  ),
  _PicaFixture(
    name: 'extreme staged downscale',
    sourceWidth: 10000,
    sourceHeight: 2,
    targetWidth: 20,
    targetHeight: 2,
    withAlpha: true,
    expectedBase64:
        'foGAgH+BgX9+gICAfoCAgH+BgX9/gYF/foCAgH+BgX9/gYF/f4GBf3+BgX9/gYF/f4GBf3+BgX9+gICAfoCAgH+BgX9+gICAfoCAgH6AgICAgIJ/f4CCgH9/goCAgIN/gICDf39/goB/f4KAf3+CgICAg3+AgIN/gICDf4CAg3+AgIN/f3+CgICAg3+AgYN/gICCgH9/goB/f4KAgYGDfw==',
  ),
];

class _PicaFixture {
  const _PicaFixture({
    required this.name,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.targetWidth,
    required this.targetHeight,
    required this.withAlpha,
    required this.expectedBase64,
  });

  final String name;
  final int sourceWidth;
  final int sourceHeight;
  final int targetWidth;
  final int targetHeight;
  final bool withAlpha;
  final String expectedBase64;
}
