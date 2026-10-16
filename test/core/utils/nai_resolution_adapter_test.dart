import 'dart:convert';
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

    test('suggests a valid generation size for invalid edge inputs', () {
      final cases = [
        (source: (1080, 1920), expected: (1088, 1920)),
        (source: (0, 1920), expected: null),
        (source: (-100, 1920), expected: null),
        (source: (5000, 1920), expected: null),
        (source: (4096, 4096), expected: null),
      ];

      for (final testCase in cases) {
        final result = NaiResolutionAdapter.findClosestResolution(
          testCase.source.$1,
          testCase.source.$2,
        );

        expect(
          NaiResolutionAdapter.isGenerationCompatible(
            result.width,
            result.height,
          ),
          isTrue,
          reason: '${testCase.source.$1}x${testCase.source.$2}',
        );
        if (testCase.expected != null) {
          expect((result.width, result.height), testCase.expected);
        }
      }
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

    for (final channels in [3, 4]) {
      test('normalizes 16-bit $channels-channel PNG requests', () async {
        final source = img.Image(
          width: 9,
          height: 7,
          format: img.Format.uint16,
          numChannels: channels,
        )..setPixelRgba(4, 3, 0x1234, 0xabcd, 0xffff, 0x807f);
        final bytes = Uint8List.fromList(img.encodePng(source));
        final originalBytes = Uint8List.fromList(bytes);
        expect(img.decodePng(bytes)!.format, img.Format.uint16);
        final expected = NaiResolutionAdapter.normalizeImageForRequest(
          Uint8List.fromList(
            img.encodePng(
              source.convert(format: img.Format.uint8, numChannels: 4),
            ),
          ),
          targetWidth: 7,
          targetHeight: 5,
        );

        final normalized = NaiResolutionAdapter.normalizeImageForRequest(
          bytes,
          targetWidth: 7,
          targetHeight: 5,
        );
        final normalizedAsync =
            await NaiResolutionAdapter.normalizeImageForRequestAsync(
              bytes,
              targetWidth: 7,
              targetHeight: 5,
            );

        expect(normalized, expected);
        expect(normalizedAsync, expected);
        final decoded = img.decodePng(normalized!)!;
        expect((decoded.width, decoded.height), (7, 5));
        expect(decoded.format, img.Format.uint8);
        expect(decoded.numChannels, 4);
        expect(bytes, originalBytes);
      });
    }

    test('preserves exact-size 16-bit PNG request bytes', () async {
      final bytes = Uint8List.fromList(
        img.encodePng(
          img.Image(width: 9, height: 7, format: img.Format.uint16)
            ..setPixelRgb(4, 3, 0x1234, 0xabcd, 0xffff),
        ),
      );

      final normalized = NaiResolutionAdapter.normalizeImageForRequest(
        bytes,
        targetWidth: 9,
        targetHeight: 7,
      );
      final normalizedAsync =
          await NaiResolutionAdapter.normalizeImageForRequestAsync(
            bytes,
            targetWidth: 9,
            targetHeight: 7,
          );

      expect(identical(normalized, bytes), isTrue);
      expect(identical(normalizedAsync, bytes), isTrue);
      expect(img.decodePng(normalized!)!.format, img.Format.uint16);
    });

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

  group('NaiResolutionAdapter default import sizing', () {
    test('keeps in-budget sources at their own 64-grid size', () {
      final cases = [
        (source: (1472, 1984), expected: (1472, 1984)),
        (source: (1536, 2048), expected: (1536, 2048)),
        (source: (1920, 1080), expected: (1920, 1088)),
      ];

      for (final testCase in cases) {
        final result = NaiResolutionAdapter.findImportResolution(
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

    test('scales oversized sources down to the largest legal size', () {
      final cases = [
        (source: (2048, 2048), expected: (1728, 1728)),
        (source: (2000, 3000), expected: (1408, 2112)),
        (source: (1728, 2560), expected: (1408, 2112)),
      ];

      for (final testCase in cases) {
        final result = NaiResolutionAdapter.findImportResolution(
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
        expect(
          NaiResolutionAdapter.isGenerationCompatible(
            result.width,
            result.height,
          ),
          isTrue,
        );
        // 收敛后仍应贴着面积上限，而不是掉回官网的 1216/896 基准边。
        expect(result.width * result.height, greaterThan(2900000));
      }
    });

    test('keeps the official buckets for Stable Diffusion family models', () {
      final result = NaiResolutionAdapter.findImportResolution(
        4096,
        4096,
        currentWidth: 512,
        currentHeight: 768,
        isStableDiffusionFamily: true,
      );

      expect((result.width, result.height), equals((512, 512)));
    });

    test('keeps the current parameter size for a smaller same-aspect source', () {
      final result = NaiResolutionAdapter.findImportResolution(
        512,
        768,
        currentWidth: 1024,
        currentHeight: 1536,
      );

      expect((result.width, result.height), equals((1024, 1536)));
    });

    test('describeImageForImport follows the default sizing', () {
      final info = NaiResolutionAdapter.describeImageForImport(
        _png(width: 2048, height: 2048),
        currentWidth: 832,
        currentHeight: 1216,
      );

      expect(info, isNotNull);
      expect((info!.width, info.height), equals((1728, 1728)));
      expect((info.originalWidth, info.originalHeight), equals((2048, 2048)));
    });
  });

  group('NaiResolutionAdapter EXIF-oriented jpeg sources', () {
    const orientations = [1, 2, 3, 4, 5, 6, 7, 8];

    test('reads the decoded size for every orientation', () {
      for (final orientation in orientations) {
        final jpeg = _orientedJpeg(6, 4, orientation);

        expect(
          NaiResolutionAdapter.readImageSize(jpeg),
          _decodedSize(jpeg),
          reason: 'orientation $orientation',
        );
      }
    });

    test('keeps header sizes for other formats and plain jpeg', () {
      final cases = <String, (Uint8List, (int, int))>{
        'png': (_png(width: 6, height: 4), (6, 4)),
        'jpeg without exif': (
          Uint8List.fromList(img.encodeJpg(img.Image(width: 6, height: 4))),
          (6, 4),
        ),
        'gif': (
          Uint8List.fromList(img.encodeGif(img.Image(width: 6, height: 4))),
          (6, 4),
        ),
        'bmp': (
          Uint8List.fromList(img.encodeBmp(img.Image(width: 5, height: 3))),
          (5, 3),
        ),
      };

      for (final MapEntry(key: name, value: (bytes, size)) in cases.entries) {
        expect(NaiResolutionAdapter.readImageSize(bytes), size, reason: name);
      }
    });

    test('describes imports from the decoded size, sync and async', () async {
      for (final orientation in orientations) {
        final jpeg = _orientedJpeg(128, 64, orientation);
        final decoded = _decodedSize(jpeg);
        final infos = [
          NaiResolutionAdapter.describeImageForImport(jpeg)!,
          (await NaiResolutionAdapter.describeImageForImportAsync(jpeg))!,
        ];

        for (final info in infos) {
          expect(
            (info.originalWidth, info.originalHeight),
            decoded,
            reason: 'orientation $orientation',
          );
          expect(
            (info.width, info.height),
            decoded,
            reason: 'orientation $orientation',
          );
        }
      }
    });

    test('adapts imports without swapping the target size', () {
      for (final orientation in orientations) {
        final jpeg = _orientedJpeg(130, 64, orientation);
        final (decodedWidth, decodedHeight) = _decodedSize(jpeg)!;
        final adapted = NaiResolutionAdapter.adaptImageForImport(jpeg)!;

        expect(
          (adapted.originalWidth, adapted.originalHeight),
          (decodedWidth, decodedHeight),
          reason: 'orientation $orientation',
        );
        expect(
          (adapted.width, adapted.height),
          decodedWidth > decodedHeight ? (128, 64) : (64, 128),
          reason: 'orientation $orientation',
        );
        final adaptedSize = (adapted.width, adapted.height);
        expect(
          _decodedSize(adapted.bytes),
          adaptedSize,
          reason: 'orientation $orientation',
        );
      }
    });

    test('scales large editor images on the decoded axes', () async {
      for (final orientation in orientations) {
        final jpeg = _orientedJpeg(2600, 40, orientation);
        final (decodedWidth, decodedHeight) = _decodedSize(jpeg)!;
        final expected = decodedWidth > decodedHeight ? (2560, 39) : (39, 2560);
        final results = [
          NaiResolutionAdapter.prepareImageForEditor(
            jpeg,
            alignForInpaint: false,
          )!,
          (await NaiResolutionAdapter.prepareImageForEditorAsync(
            jpeg,
            alignForInpaint: false,
          ))!,
        ];

        for (final working in results) {
          final reason = 'orientation $orientation';
          expect(
            (working.originalWidth, working.originalHeight),
            (decodedWidth, decodedHeight),
            reason: reason,
          );
          expect((working.width, working.height), expected, reason: reason);
          expect(
            working.resizeMode,
            NaiEditorResizeMode.picaLanczos3,
            reason: reason,
          );
          expect(_decodedSize(working.bytes), expected, reason: reason);
        }
      }
    });

    test('keeps small editor images on the decoded axes', () {
      for (final orientation in orientations) {
        final jpeg = _orientedJpeg(96, 40, orientation);
        final decoded = _decodedSize(jpeg)!;
        final reason = 'orientation $orientation';
        final edit = NaiResolutionAdapter.prepareImageForEditor(
          jpeg,
          alignForInpaint: false,
        )!;
        final inpaint = NaiResolutionAdapter.prepareImageForEditor(
          jpeg,
          alignForInpaint: true,
        )!;

        expect((edit.width, edit.height), decoded, reason: reason);
        expect(
          edit.resizeMode,
          NaiEditorResizeMode.passthrough,
          reason: reason,
        );
        expect(
          (inpaint.width, inpaint.height),
          decoded.$1 > decoded.$2 ? (128, 64) : (64, 128),
          reason: reason,
        );
        expect(inpaint.resizeMode, NaiEditorResizeMode.medium, reason: reason);
      }
    });

    test('sends oriented request sources as png at the target size', () async {
      for (final orientation in orientations.skip(1)) {
        final jpeg = _orientedJpeg(128, 64, orientation);
        final decoded = _decodedSize(jpeg)!;
        final targets = [decoded, (decoded.$2, decoded.$1)];

        for (final (width, height) in targets) {
          final reason = 'orientation $orientation, ${width}x$height';
          final results = [
            NaiResolutionAdapter.normalizeImageForRequest(
              jpeg,
              targetWidth: width,
              targetHeight: height,
            ),
            await NaiResolutionAdapter.normalizeImageForRequestAsync(
              jpeg,
              targetWidth: width,
              targetHeight: height,
            ),
          ];

          for (final normalized in results) {
            expect(img.decodePng(normalized!), isNotNull, reason: reason);
            expect(_decodedSize(normalized), (width, height), reason: reason);
          }
        }
      }
    });

    test('passes unrotated request sources through byte for byte', () async {
      final cases = <String, Uint8List>{
        'jpeg orientation 1': _orientedJpeg(128, 64, 1),
        'jpeg without exif': Uint8List.fromList(
          img.encodeJpg(img.Image(width: 128, height: 64)),
        ),
        'png': _png(width: 128, height: 64),
        'webp': _webpLossless,
      };

      for (final MapEntry(key: name, value: bytes) in cases.entries) {
        final (width, height) = _decodedSize(bytes)!;
        final normalized = NaiResolutionAdapter.normalizeImageForRequest(
          bytes,
          targetWidth: width,
          targetHeight: height,
        );
        final normalizedAsync =
            await NaiResolutionAdapter.normalizeImageForRequestAsync(
              bytes,
              targetWidth: width,
              targetHeight: height,
            );

        expect(identical(normalized, bytes), isTrue, reason: name);
        expect(identical(normalizedAsync, bytes), isTrue, reason: name);
      }
    });
  });
}

final _webpLossless = base64Decode(
  'UklGRqAAAABXRUJQVlA4TJQAAAAvE0ADALkyRPQ/FgrSNmC6419vpZhp28b8Ebfdjuh//CUC'
  'gEEjSYrqSQH617p0EhS3bePGmFx79WMUSZLi+Ebk8Yvxdx6YJFxMAOGaVt4jYOUS3RKsMPhm'
  'JIIJEyqwAwNK8ECyAPfQYkXeIGEBAIVto8UCABfAbebs4ATAXzkF+FEcULLiAwANBxB2ALwg'
  '1Xr3AwAS',
);

Uint8List _png({required int width, required int height}) {
  return Uint8List.fromList(
    img.encodePng(img.Image(width: width, height: height)),
  );
}

Uint8List _orientedJpeg(int width, int height, int orientation) {
  final image = img.Image(width: width, height: height)
    ..exif.imageIfd.orientation = orientation;
  img.fill(image, color: img.ColorRgb8(200, 40, 90));
  return Uint8List.fromList(img.encodeJpg(image));
}

(int, int)? _decodedSize(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  return decoded == null ? null : (decoded.width, decoded.height);
}
