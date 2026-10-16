import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/nai_resolution_adapter.dart';

import '../../helpers/exif_orientation_fixture.dart';

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

  group('NaiResolutionAdapter EXIF-oriented sources', () {
    final formats = <String, _MarkedSource>{
      'jpeg': (width, height, orientation) => orientedMarkedJpeg(
        width: width,
        height: height,
        orientation: orientation,
      ),
      'webp': (width, height, orientation) => orientedMarkedWebp(
        width: width,
        height: height,
        orientation: orientation,
      ),
    };

    test('reads the upright size for every orientation', () {
      for (final MapEntry(key: format, value: source) in formats.entries) {
        for (final orientation in [1, 2, 3, 4, 5, 6, 7, 8]) {
          expect(
            NaiResolutionAdapter.readImageSize(source(20, 14, orientation)),
            uprightSizeOf(20, 14, orientation),
            reason: '$format $orientation',
          );
        }
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

    test('describes imports from the upright size, sync and async', () async {
      for (final MapEntry(key: format, value: source) in formats.entries) {
        final bytes = source(128, 64, 6);
        final infos = [
          NaiResolutionAdapter.describeImageForImport(bytes)!,
          (await NaiResolutionAdapter.describeImageForImportAsync(bytes))!,
        ];

        for (final info in infos) {
          expect(
            (info.originalWidth, info.originalHeight),
            (64, 128),
            reason: format,
          );
          expect((info.width, info.height), (64, 128), reason: format);
        }
      }
    });

    test('adapts imports on the upright axes', () {
      for (final MapEntry(key: format, value: source) in formats.entries) {
        final bytes = source(130, 64, 6);
        final adapted = NaiResolutionAdapter.adaptImageForImport(bytes)!;

        expect(
          (adapted.originalWidth, adapted.originalHeight),
          (64, 130),
          reason: format,
        );
        expect((adapted.width, adapted.height), (64, 128), reason: format);
        _expectUprightMarker(adapted.bytes, (64, 128), reason: format);
      }
    });

    test('scales large editor images on the upright axes', () async {
      for (final MapEntry(key: format, value: source) in formats.entries) {
        final bytes = source(2600, 40, 6);
        final results = [
          NaiResolutionAdapter.prepareImageForEditor(
            bytes,
            alignForInpaint: false,
          )!,
          (await NaiResolutionAdapter.prepareImageForEditorAsync(
            bytes,
            alignForInpaint: false,
          ))!,
        ];

        for (final working in results) {
          expect(
            (working.originalWidth, working.originalHeight),
            (40, 2600),
            reason: format,
          );
          expect(
            working.resizeMode,
            NaiEditorResizeMode.picaLanczos3,
            reason: format,
          );
          _expectUprightMarker(working.bytes, (39, 2560), reason: format);
        }
      }
    });

    test('keeps small editor images on the upright axes', () {
      for (final MapEntry(key: format, value: source) in formats.entries) {
        final bytes = source(96, 40, 6);
        final edit = NaiResolutionAdapter.prepareImageForEditor(
          bytes,
          alignForInpaint: false,
        )!;
        final inpaint = NaiResolutionAdapter.prepareImageForEditor(
          bytes,
          alignForInpaint: true,
        )!;

        expect((edit.width, edit.height), (40, 96), reason: format);
        expect(
          edit.resizeMode,
          NaiEditorResizeMode.passthrough,
          reason: format,
        );
        expect((inpaint.width, inpaint.height), (64, 128), reason: format);
        expect(inpaint.resizeMode, NaiEditorResizeMode.medium, reason: format);
      }
    });

    test('sends oriented request sources as upright png', () async {
      for (final MapEntry(key: format, value: source) in formats.entries) {
        final bytes = source(128, 64, 6);

        for (final (width, height) in [(64, 128), (128, 64)]) {
          final reason = '$format ${width}x$height';
          final results = [
            NaiResolutionAdapter.normalizeImageForRequest(
              bytes,
              targetWidth: width,
              targetHeight: height,
            ),
            await NaiResolutionAdapter.normalizeImageForRequestAsync(
              bytes,
              targetWidth: width,
              targetHeight: height,
            ),
          ];

          for (final normalized in results) {
            expect(img.decodePng(normalized!), isNotNull, reason: reason);
            expect(_decodedSize(normalized), (width, height), reason: reason);
          }
        }
        _expectUprightMarker(
          NaiResolutionAdapter.normalizeImageForRequest(
            bytes,
            targetWidth: 64,
            targetHeight: 128,
          )!,
          (64, 128),
          reason: format,
        );
      }
    });

    test('passes unrotated request sources through byte for byte', () async {
      final cases = <String, Uint8List>{
        for (final MapEntry(key: format, value: source) in formats.entries)
          '$format orientation 1': source(128, 64, 1),
        'jpeg without exif': Uint8List.fromList(
          img.encodeJpg(img.Image(width: 128, height: 64)),
        ),
        'png': _png(width: 128, height: 64),
        'webp without exif': plainWebp,
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

typedef _MarkedSource =
    Uint8List Function(int width, int height, int orientation);

/// 方向 6 显示时顺时针转 90°：存储在左上角的标记应出现在 [output] 的右上角。
void _expectUprightMarker(
  Uint8List output,
  (int, int) size, {
  required String reason,
}) {
  final decoded = img.decodeImage(output)!;
  expect((decoded.width, decoded.height), size, reason: reason);
  expect(markerCorners(decoded), [false, true, false, false], reason: reason);
}

Uint8List _png({required int width, required int height}) {
  return Uint8List.fromList(
    img.encodePng(img.Image(width: width, height: height)),
  );
}

(int, int)? _decodedSize(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  return decoded == null ? null : (decoded.width, decoded.height);
}
