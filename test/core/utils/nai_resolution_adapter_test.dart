import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/nai_resolution_adapter.dart';

void main() {
  group('NaiResolutionAdapter official import sizing', () {
    test('matches current NovelAI Web buckets for oversized NAI images', () {
      final cases = [
        (source: (8000, 6000), expected: (1216, 896)),
        (source: (5000, 3000), expected: (1472, 896)),
        (source: (4096, 4096), expected: (896, 896)),
      ];

      for (final testCase in cases) {
        final result = NaiResolutionAdapter.findOfficialImportResolution(
          testCase.source.$1,
          testCase.source.$2,
          currentWidth: 832,
          currentHeight: 1216,
        );

        expect(
          (result.width, result.height),
          equals(testCase.expected),
          reason: '${testCase.source.$1}x${testCase.source.$2}',
        );
      }
    });

    test('uses the Stable Diffusion web bucket when requested', () {
      final result = NaiResolutionAdapter.findOfficialImportResolution(
        4096,
        4096,
        currentWidth: 512,
        currentHeight: 768,
        isStableDiffusionFamily: true,
      );

      expect((result.width, result.height), equals((512, 512)));
    });

    test(
      'keeps compatible source dimensions when web would use them directly',
      () {
        final result = NaiResolutionAdapter.findOfficialImportResolution(
          1024,
          1024,
          currentWidth: 832,
          currentHeight: 1216,
        );

        expect((result.width, result.height), equals((1024, 1024)));
      },
    );

    test(
      'keeps the current parameter size for a smaller same-aspect source',
      () {
        final result = NaiResolutionAdapter.findOfficialImportResolution(
          512,
          768,
          currentWidth: 1024,
          currentHeight: 1536,
        );

        expect((result.width, result.height), equals((1024, 1536)));
      },
    );

    test(
      'resizes imported source bytes to the official request dimensions',
      () {
        final adapted = NaiResolutionAdapter.adaptImageForImport(
          _png(width: 1500, height: 900),
          currentWidth: 832,
          currentHeight: 1216,
        );

        expect(adapted, isNotNull);
        final decoded = img.decodeImage(adapted!.bytes);

        expect((adapted.width, adapted.height), equals((1472, 896)));
        expect((decoded!.width, decoded.height), equals((1472, 896)));
        expect(adapted.wasResized, isTrue);
      },
    );

    test(
      'describes import dimensions without resizing imported source bytes',
      () {
        final source = _png(width: 1500, height: 900);
        final info = NaiResolutionAdapter.describeImageForImport(
          source,
          currentWidth: 832,
          currentHeight: 1216,
        );
        final decoded = img.decodeImage(source);

        expect(info, isNotNull);
        expect((info!.width, info.height), equals((1472, 896)));
        expect((info.originalWidth, info.originalHeight), equals((1500, 900)));
        expect((decoded!.width, decoded.height), equals((1500, 900)));
        expect(info.sizeChanged, isTrue);
      },
    );

    test(
      'normalizes request source bytes to the active request dimensions',
      () {
        final normalized = NaiResolutionAdapter.normalizeImageForRequest(
          _png(width: 1500, height: 900),
          targetWidth: 1472,
          targetHeight: 896,
        );

        expect(normalized, isNotNull);
        final decoded = img.decodeImage(normalized!);

        expect(decoded, isNotNull);
        expect((decoded!.width, decoded.height), equals((1472, 896)));
      },
    );

    test('uses Lanczos3 resampling instead of package cubic resizing', () {
      final source = img.Image(width: 7, height: 5);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          source.setPixelRgba(
            x,
            y,
            (x * 37 + y * 19) % 256,
            (x * 17 + y * 53) % 256,
            (x * 71 + y * 11) % 256,
            255,
          );
        }
      }

      final lanczos = img.decodeImage(
        NaiResolutionAdapter.normalizeImageForRequest(
          Uint8List.fromList(img.encodePng(source)),
          targetWidth: 4,
          targetHeight: 3,
        )!,
      )!;
      final cubic = img.copyResize(
        source,
        width: 4,
        height: 3,
        interpolation: img.Interpolation.cubic,
      );

      var differingPixels = 0;
      for (var y = 0; y < lanczos.height; y++) {
        for (var x = 0; x < lanczos.width; x++) {
          final lanczosPixel = lanczos.getPixel(x, y);
          final cubicPixel = cubic.getPixel(x, y);
          if (lanczosPixel.r != cubicPixel.r ||
              lanczosPixel.g != cubicPixel.g ||
              lanczosPixel.b != cubicPixel.b) {
            differingPixels++;
          }
        }
      }

      expect(differingPixels, greaterThan(0));
    });
  });
}

Uint8List _png({required int width, required int height}) {
  return Uint8List.fromList(
    img.encodePng(img.Image(width: width, height: height)),
  );
}
