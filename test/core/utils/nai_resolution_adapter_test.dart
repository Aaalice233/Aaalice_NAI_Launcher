import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/nai_resolution_adapter.dart';

void main() {
  group('NaiResolutionAdapter official import sizing', () {
    test('reads encoded image dimensions from the image header', () {
      final source = img.Image(width: 640, height: 960);
      final bytes = Uint8List.fromList(img.encodePng(source));

      expect(NaiResolutionAdapter.readImageSize(bytes), equals((640, 960)));
    });

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

    test(
      'returns original bytes untouched when png size already matches',
      () async {
        final bytes = _png(width: 832, height: 1216);

        final normalized = NaiResolutionAdapter.normalizeImageForRequest(
          bytes,
          targetWidth: 832,
          targetHeight: 1216,
        );
        final normalizedAsync =
            await NaiResolutionAdapter.normalizeImageForRequestAsync(
              bytes,
              targetWidth: 832,
              targetHeight: 1216,
            );

        expect(identical(normalized, bytes), isTrue);
        expect(identical(normalizedAsync, bytes), isTrue);
      },
    );

    test('keeps exact-size jpeg bytes across import, request, and editor', () {
      final bytes = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 1024, height: 1024)),
      );

      final imported = NaiResolutionAdapter.adaptImageForImport(
        bytes,
        currentWidth: 832,
        currentHeight: 1216,
      )!;
      final normalized = NaiResolutionAdapter.normalizeImageForRequest(
        bytes,
        targetWidth: 1024,
        targetHeight: 1024,
      );
      final working = NaiResolutionAdapter.prepareImageForEditor(
        bytes,
        alignForInpaint: true,
      )!;

      expect(identical(imported.bytes, bytes), isTrue);
      expect(imported.wasResized, isFalse);
      expect(identical(normalized, bytes), isTrue);
      expect(identical(working.bytes, bytes), isTrue);
      expect(working.resizeMode, NaiEditorResizeMode.passthrough);
    });

    test('still resizes when png header size differs from target', () {
      final normalized = NaiResolutionAdapter.normalizeImageForRequest(
        _png(width: 512, height: 512),
        targetWidth: 832,
        targetHeight: 1216,
      );

      final decoded = img.decodeImage(normalized!)!;
      expect((decoded.width, decoded.height), equals((832, 1216)));
    });

    test('limits the editor working image longest side to 2560', () {
      final source = _png(width: 2600, height: 100);
      final working = NaiResolutionAdapter.prepareImageForEditor(
        source,
        alignForInpaint: false,
      )!;
      final decoded = img.decodeImage(working.bytes)!;

      expect((working.width, working.height), (2560, 98));
      expect((decoded.width, decoded.height), (2560, 98));
      expect(working.wasNormalized, isTrue);
      expect(working.resizeMode, NaiEditorResizeMode.picaLanczos3);
    });

    test('aligns Inpaint working dimensions upward to the 64 grid', () {
      final source = _png(width: 1001, height: 129);
      final working = NaiResolutionAdapter.prepareImageForEditor(
        source,
        alignForInpaint: true,
      )!;

      expect((working.width, working.height), (1024, 192));
      expect(working.wasNormalized, isTrue);
      expect(working.resizeMode, NaiEditorResizeMode.medium);
      expect(identical(working.bytes, source), isTrue);
    });

    test('applies max-side scaling before Inpaint grid alignment', () {
      final working = NaiResolutionAdapter.prepareImageForEditor(
        _png(width: 2600, height: 100),
        alignForInpaint: true,
      )!;

      expect((working.width, working.height), (2560, 128));
      expect(working.resizeMode, NaiEditorResizeMode.picaLanczos3);
    });

    test('ordinary Edit does not align an otherwise small source', () {
      final source = _png(width: 1001, height: 129);
      final working = NaiResolutionAdapter.prepareImageForEditor(
        source,
        alignForInpaint: false,
      )!;

      expect((working.width, working.height), (1001, 129));
      expect(working.wasNormalized, isFalse);
      expect(identical(working.bytes, source), isTrue);
      expect(working.resizeMode, NaiEditorResizeMode.passthrough);
    });
  });
}

Uint8List _png({required int width, required int height}) {
  return Uint8List.fromList(
    img.encodePng(img.Image(width: width, height: height)),
  );
}
