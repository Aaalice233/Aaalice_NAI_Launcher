import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/inpaint_mask_utils.dart';

void main() {
  group('InpaintMaskUtils', () {
    test('normalizeMaskBytes should output an opaque black white mask', () {
      final source = img.Image(width: 2, height: 1);
      source.setPixelRgba(0, 0, 0, 0, 0, 255);
      source.setPixelRgba(1, 0, 80, 180, 255, 96);

      final result = InpaintMaskUtils.normalizeMaskBytes(
        Uint8List.fromList(img.encodePng(source)),
      );
      final decoded = img.decodeImage(result)!;

      expect(decoded.getPixel(0, 0).r.toInt(), equals(0));
      expect(decoded.getPixel(0, 0).g.toInt(), equals(0));
      expect(decoded.getPixel(0, 0).b.toInt(), equals(0));
      expect(decoded.getPixel(0, 0).a.toInt(), equals(255));

      expect(decoded.getPixel(1, 0).r.toInt(), equals(255));
      expect(decoded.getPixel(1, 0).g.toInt(), equals(255));
      expect(decoded.getPixel(1, 0).b.toInt(), equals(255));
      expect(decoded.getPixel(1, 0).a.toInt(), equals(255));
    });

    test(
      'maskToEditorOverlay should remove black background and keep mask visible',
      () {
        final source = img.Image(width: 2, height: 1);
        source.setPixelRgba(0, 0, 0, 0, 0, 255);
        source.setPixelRgba(1, 0, 255, 255, 255, 255);

        final result = InpaintMaskUtils.maskToEditorOverlay(
          Uint8List.fromList(img.encodePng(source)),
        );
        final decoded = img.decodeImage(result)!;

        expect(decoded.getPixel(0, 0).a.toInt(), equals(0));
        expect(decoded.getPixel(1, 0).a.toInt(), greaterThan(0));
      },
    );

    test('maskToEditorOverlayAsync should match sync overlay output', () async {
      final source = img.Image(width: 4, height: 4);
      img.fill(source, color: img.ColorRgba8(0, 0, 0, 255));
      source.setPixelRgba(2, 1, 255, 255, 255, 255);

      final bytes = Uint8List.fromList(img.encodePng(source));
      final syncResult = InpaintMaskUtils.maskToEditorOverlay(
        bytes,
        overlayAlpha: 160,
      );
      final asyncResult = await InpaintMaskUtils.maskToEditorOverlayAsync(
        bytes,
        overlayAlpha: 160,
      );

      expect(asyncResult, syncResult);
    });

    test(
      'prepareInpaintMaskBytes should close pinholes and expand mask edges',
      () {
        final source = img.Image(width: 7, height: 7);
        for (var y = 2; y <= 4; y++) {
          for (var x = 2; x <= 4; x++) {
            source.setPixelRgba(x, y, 255, 255, 255, 255);
          }
        }
        source.setPixelRgba(3, 3, 0, 0, 0, 255);

        final result = InpaintMaskUtils.prepareInpaintMaskBytes(
          Uint8List.fromList(img.encodePng(source)),
          closingIterations: 1,
          expansionIterations: 1,
        );
        final decoded = img.decodeImage(result)!;

        expect(decoded.getPixel(3, 3).r.toInt(), equals(255));
        expect(decoded.getPixel(1, 3).r.toInt(), equals(255));
        expect(decoded.getPixel(0, 0).r.toInt(), equals(0));
      },
    );

    test(
      'prepareRequestMaskBytes should align v4 inpaint masks to the latent 8px grid',
      () {
        final source = img.Image(width: 16, height: 16);
        img.fill(source, color: img.ColorRgba8(0, 0, 0, 255));
        for (var y = 10; y <= 13; y++) {
          for (var x = 10; x <= 13; x++) {
            source.setPixelRgba(x, y, 255, 255, 255, 255);
          }
        }

        final result = InpaintMaskUtils.prepareRequestMaskBytes(
          Uint8List.fromList(img.encodePng(source)),
          alignToLatentGrid: true,
        );
        final decoded = img.decodeImage(result)!;

        expect(decoded.getPixel(8, 8).r.toInt(), equals(255));
        expect(decoded.getPixel(15, 15).r.toInt(), equals(255));
        expect(decoded.getPixel(7, 9).r.toInt(), equals(0));
        expect(decoded.getPixel(9, 7).r.toInt(), equals(0));
      },
    );

    test(
      'prepareNovelAiRequestMaskBytes should expand latent mask to the full HTTP payload',
      () {
        final source = img.Image(width: 16, height: 16, numChannels: 4);
        img.fill(source, color: img.ColorRgba8(0, 0, 0, 255));
        source.setPixelRgba(4, 4, 255, 255, 255, 255);
        source.setPixelRgba(12, 12, 255, 255, 255, 255);

        final result = InpaintMaskUtils.prepareNovelAiRequestMaskBytes(
          Uint8List.fromList(img.encodePng(source)),
          targetWidth: 16,
          targetHeight: 16,
        );
        final decoded = img.decodeImage(result)!;

        expect((decoded.width, decoded.height), equals((16, 16)));
        expect(decoded.getPixel(0, 0).r.toInt(), equals(255));
        expect(decoded.getPixel(7, 7).r.toInt(), equals(255));
        expect(decoded.getPixel(8, 0).r.toInt(), equals(0));
        expect(decoded.getPixel(0, 8).r.toInt(), equals(0));
        expect(decoded.getPixel(15, 15).r.toInt(), equals(255));
        expect(decoded.every((pixel) => pixel.a.toInt() == 255), isTrue);
      },
    );

    test(
      'prepareNovelAiInpaintMaskArtifacts normalizes coverage and uses strict alpha threshold',
      () {
        final source = img.Image(width: 8, height: 1, numChannels: 4);
        source.setPixelRgba(0, 0, 255, 255, 255, 255);
        source.setPixelRgba(1, 0, 155, 155, 155, 255);
        source.setPixelRgba(2, 0, 156, 156, 156, 255);
        source.setPixelRgba(3, 0, 255, 255, 255, 0);
        source.setPixelRgba(4, 0, 50, 200, 100, 200);
        source.setPixelRgba(5, 0, 0, 0, 0, 255);
        source.setPixelRgba(6, 0, 255, 255, 255, 156);
        source.setPixelRgba(7, 0, 255, 255, 255, 155);

        final artifacts = InpaintMaskUtils.prepareNovelAiInpaintMaskArtifacts(
          Uint8List.fromList(img.encodePng(source)),
          targetWidth: 64,
          targetHeight: 64,
          latentDilationIterations: 0,
          blurRadius: 0,
          blurIterations: 0,
        );
        final requestMask = img.decodeImage(artifacts.requestMaskBytes)!;
        final latentMask = img.decodeImage(artifacts.latentMaskBytes)!;

        expect((artifacts.latentWidth, artifacts.latentHeight), equals((8, 8)));
        expect((latentMask.width, latentMask.height), equals((8, 8)));
        expect((requestMask.width, requestMask.height), equals((64, 64)));
        expect([
          for (var x = 0; x < 8; x++) latentMask.getPixel(x, 0).a.toInt(),
        ], equals([255, 0, 255, 0, 255, 0, 255, 0]));
        expect([
          for (var x = 0; x < 8; x++) requestMask.getPixel(x * 8, 0).r.toInt(),
        ], equals([255, 0, 255, 0, 255, 0, 255, 0]));
        expect(requestMask.every((pixel) => pixel.a.toInt() == 255), isTrue);
      },
    );

    test(
      'prepareNovelAiRequestMaskBytesAsync should match the sync request mask',
      () async {
        final mask = _buildParityMask(width: 256, height: 192);
        final maskBytes = Uint8List.fromList(img.encodePng(mask));

        final syncResult = InpaintMaskUtils.prepareNovelAiRequestMaskBytes(
          maskBytes,
          targetWidth: 256,
          targetHeight: 192,
          closingIterations: 1,
          expansionIterations: 1,
        );
        final asyncResult =
            await InpaintMaskUtils.prepareNovelAiRequestMaskBytesAsync(
              maskBytes,
              targetWidth: 256,
              targetHeight: 192,
              closingIterations: 1,
              expansionIterations: 1,
            );

        expect(asyncResult, equals(syncResult));
      },
    );

    test(
      'prepareNovelAiInpaintMaskArtifactsAsync matches all sync artifacts',
      () async {
        final maskBytes = Uint8List.fromList(
          img.encodePng(_buildParityMask(width: 256, height: 192)),
        );
        final syncResult = InpaintMaskUtils.prepareNovelAiInpaintMaskArtifacts(
          maskBytes,
          targetWidth: 256,
          targetHeight: 192,
          closingIterations: 1,
          expansionIterations: 1,
        );
        final asyncResult =
            await InpaintMaskUtils.prepareNovelAiInpaintMaskArtifactsAsync(
              maskBytes,
              targetWidth: 256,
              targetHeight: 192,
              closingIterations: 1,
              expansionIterations: 1,
            );

        expect(
          asyncResult.requestMaskBytes,
          equals(syncResult.requestMaskBytes),
        );
        expect(asyncResult.latentMaskBytes, equals(syncResult.latentMaskBytes));
        expect(
          asyncResult.compositeMaskBytes,
          equals(syncResult.compositeMaskBytes),
        );
        expect(asyncResult.requestWidth, syncResult.requestWidth);
        expect(asyncResult.requestHeight, syncResult.requestHeight);
        expect(asyncResult.latentWidth, syncResult.latentWidth);
        expect(asyncResult.latentHeight, syncResult.latentHeight);
      },
    );

    test(
      'prepareGeneratedImageCompositeMaskBytes should match NovelAI worker mask samples',
      () {
        final mask = _buildParityMask(width: 256, height: 192);

        final result = InpaintMaskUtils.prepareGeneratedImageCompositeMaskBytes(
          Uint8List.fromList(img.encodePng(mask)),
          targetWidth: 256,
          targetHeight: 192,
        );
        final decoded = img.decodeImage(result)!;

        expect(_rgbaAt(decoded, 0, 0), equals((r: 62, g: 62, b: 62, a: 62)));
        expect(
          _rgbaAt(decoded, 20, 80),
          equals((r: 254, g: 254, b: 254, a: 254)),
        );
        expect(
          _rgbaAt(decoded, 32, 48),
          equals((r: 249, g: 249, b: 249, a: 249)),
        );
        expect(
          _rgbaAt(decoded, 80, 80),
          equals((r: 255, g: 255, b: 255, a: 255)),
        );
        expect(
          _rgbaAt(decoded, 126, 92),
          equals((r: 255, g: 255, b: 255, a: 255)),
        );
        expect(
          _rgbaAt(decoded, 180, 70),
          equals((r: 236, g: 236, b: 236, a: 236)),
        );
        expect(_rgbaAt(decoded, 244, 180), equals((r: 0, g: 0, b: 0, a: 0)));
      },
    );

    test('fillClosedMaskRegions should fill enclosed transparent holes', () {
      final source = img.Image(width: 24, height: 24);
      img.fill(source, color: img.ColorRgba8(0, 0, 0, 255));
      img.drawRect(
        source,
        x1: 4,
        y1: 4,
        x2: 19,
        y2: 19,
        color: img.ColorRgba8(255, 255, 255, 255),
      );

      final result = InpaintMaskUtils.fillClosedMaskRegions(
        Uint8List.fromList(img.encodePng(source)),
      );
      final decoded = img.decodeImage(result)!;

      expect(decoded.getPixel(12, 12).r.toInt(), equals(255));
      expect(decoded.getPixel(2, 2).r.toInt(), equals(0));
    });

    test('fillClosedMaskRegions should keep open contours unfilled', () {
      final source = img.Image(width: 24, height: 24);
      img.fill(source, color: img.ColorRgba8(0, 0, 0, 255));
      img.drawRect(
        source,
        x1: 4,
        y1: 4,
        x2: 19,
        y2: 19,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
      for (var y = 10; y <= 13; y++) {
        source.setPixelRgba(4, y, 0, 0, 0, 255);
      }

      final result = InpaintMaskUtils.fillClosedMaskRegions(
        Uint8List.fromList(img.encodePng(source)),
      );
      final decoded = img.decodeImage(result)!;

      expect(decoded.getPixel(12, 12).r.toInt(), equals(0));
    });

    test(
      'fillMaskRegionAtPoint should fill only the clicked closed region',
      () {
        final source = img.Image(width: 32, height: 24);
        img.fill(source, color: img.ColorRgba8(0, 0, 0, 255));
        img.drawRect(
          source,
          x1: 2,
          y1: 4,
          x2: 12,
          y2: 18,
          color: img.ColorRgba8(255, 255, 255, 255),
        );
        img.drawRect(
          source,
          x1: 18,
          y1: 4,
          x2: 28,
          y2: 18,
          color: img.ColorRgba8(255, 255, 255, 255),
        );

        final result = InpaintMaskUtils.fillMaskRegionAtPoint(
          Uint8List.fromList(img.encodePng(source)),
          x: 7,
          y: 11,
        );
        final decoded = img.decodeImage(result)!;

        expect(decoded.getPixel(7, 11).r.toInt(), equals(255));
        expect(decoded.getPixel(23, 11).r.toInt(), equals(0));
      },
    );

    test('fillMaskRegionAtPoint should keep open regions unchanged', () {
      final source = img.Image(width: 24, height: 24);
      img.fill(source, color: img.ColorRgba8(0, 0, 0, 255));
      img.drawRect(
        source,
        x1: 4,
        y1: 4,
        x2: 19,
        y2: 19,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
      for (var y = 10; y <= 13; y++) {
        source.setPixelRgba(4, y, 0, 0, 0, 255);
      }

      final result = InpaintMaskUtils.fillMaskRegionAtPoint(
        Uint8List.fromList(img.encodePng(source)),
        x: 12,
        y: 12,
      );
      final decoded = img.decodeImage(result)!;

      expect(decoded.getPixel(12, 12).r.toInt(), equals(0));
    });

    test(
      'fillEditorMaskRegionAtPointAsync should fill a closed region and produce editor overlay',
      () async {
        final source = img.Image(width: 32, height: 24);
        img.fill(source, color: img.ColorRgba8(0, 0, 0, 255));
        img.drawRect(
          source,
          x1: 2,
          y1: 4,
          x2: 12,
          y2: 18,
          color: img.ColorRgba8(255, 255, 255, 255),
        );
        img.drawRect(
          source,
          x1: 18,
          y1: 4,
          x2: 28,
          y2: 18,
          color: img.ColorRgba8(255, 255, 255, 255),
        );

        final originalBytes = Uint8List.fromList(img.encodePng(source));
        final expectedMask = InpaintMaskUtils.fillMaskRegionAtPoint(
          originalBytes,
          x: 7,
          y: 11,
        );
        final expectedOverlay = InpaintMaskUtils.maskToEditorOverlay(
          expectedMask,
          overlayAlpha: 160,
        );

        final result = await InpaintMaskUtils.fillEditorMaskRegionAtPointAsync(
          originalBytes,
          x: 7,
          y: 11,
          overlayAlpha: 160,
        );

        expect(result.status, MaskFillRegionStatus.filled);
        expect(result.filledMaskBytes, expectedMask);
        expect(result.overlayBytes, expectedOverlay);

        final decodedMask = img.decodeImage(result.filledMaskBytes!)!;
        final decodedOverlay = img.decodeImage(result.overlayBytes!)!;
        expect(decodedMask.getPixel(7, 11).r.toInt(), equals(255));
        expect(decodedMask.getPixel(23, 11).r.toInt(), equals(0));
        expect(decodedOverlay.getPixel(7, 11).a.toInt(), equals(160));
        expect(decodedOverlay.getPixel(0, 0).a.toInt(), equals(0));
      },
    );

    test(
      'fillEditorMaskRegionAtPointAsync should report open regions without producing overlay',
      () async {
        final source = img.Image(width: 24, height: 24);
        img.fill(source, color: img.ColorRgba8(0, 0, 0, 255));
        img.drawRect(
          source,
          x1: 4,
          y1: 4,
          x2: 19,
          y2: 19,
          color: img.ColorRgba8(255, 255, 255, 255),
        );
        for (var y = 10; y <= 13; y++) {
          source.setPixelRgba(4, y, 0, 0, 0, 255);
        }

        final result = await InpaintMaskUtils.fillEditorMaskRegionAtPointAsync(
          Uint8List.fromList(img.encodePng(source)),
          x: 12,
          y: 12,
        );

        expect(result.status, MaskFillRegionStatus.openRegion);
        expect(result.filledMaskBytes, isNull);
        expect(result.overlayBytes, isNull);
      },
    );

    test('extractFilledMaskDelta should only keep newly filled regions', () {
      final source = img.Image(width: 24, height: 24);
      img.fill(source, color: img.ColorRgba8(0, 0, 0, 255));
      img.drawRect(
        source,
        x1: 4,
        y1: 4,
        x2: 19,
        y2: 19,
        color: img.ColorRgba8(255, 255, 255, 255),
      );

      final originalBytes = Uint8List.fromList(img.encodePng(source));
      final filledBytes = InpaintMaskUtils.fillClosedMaskRegions(originalBytes);
      final deltaBytes = InpaintMaskUtils.extractFilledMaskDelta(
        originalBytes,
        filledBytes,
      );
      final decoded = img.decodeImage(deltaBytes)!;

      expect(decoded.getPixel(12, 12).r.toInt(), equals(255));
      expect(decoded.getPixel(4, 4).r.toInt(), equals(0));
      expect(decoded.getPixel(2, 2).r.toInt(), equals(0));
    });

    test('compositeGeneratedImage should preserve source outside mask', () {
      final source = img.Image(width: 4, height: 4);
      img.fill(source, color: img.ColorRgb8(10, 20, 30));

      final generated = img.Image(width: 4, height: 4);
      img.fill(generated, color: img.ColorRgb8(200, 210, 220));

      final mask = img.Image(width: 4, height: 4);
      img.fill(mask, color: img.ColorRgba8(0, 0, 0, 255));
      mask.setPixelRgba(1, 1, 255, 255, 255, 255);
      mask.setPixelRgba(2, 1, 255, 255, 255, 255);

      final result = InpaintMaskUtils.compositeGeneratedImage(
        sourceImage: Uint8List.fromList(img.encodePng(source)),
        maskImage: Uint8List.fromList(img.encodePng(mask)),
        generatedImage: Uint8List.fromList(img.encodePng(generated)),
      );
      final decoded = img.decodeImage(result)!;

      expect(decoded.getPixel(1, 1).r.toInt(), equals(200));
      expect(decoded.getPixel(2, 1).g.toInt(), equals(210));
      expect(decoded.getPixel(0, 0).r.toInt(), equals(10));
      expect(decoded.getPixel(0, 0).g.toInt(), equals(20));
      expect(decoded.getPixel(0, 0).b.toInt(), equals(30));
      expect(decoded.getPixel(3, 3).r.toInt(), equals(10));
    });

    test(
      'composeGeneratedImageArtifact patch reconstructs display without dark edges',
      () {
        final source = img.Image(width: 256, height: 256, numChannels: 4);
        img.fill(source, color: img.ColorRgba8(10, 20, 30, 255));
        final generated = img.Image(width: 256, height: 256, numChannels: 4);
        img.fill(generated, color: img.ColorRgba8(200, 210, 220, 255));
        final mask = img.Image(width: 256, height: 256, numChannels: 4);
        img.fill(mask, color: img.ColorRgba8(0, 0, 0, 255));
        img.fillRect(
          mask,
          x1: 112,
          y1: 112,
          x2: 143,
          y2: 143,
          color: img.ColorRgba8(255, 255, 255, 255),
        );
        final sourceBytes = Uint8List.fromList(img.encodePng(source));
        final generatedBytes = Uint8List.fromList(img.encodePng(generated));
        final artifacts = InpaintMaskUtils.prepareNovelAiInpaintMaskArtifacts(
          Uint8List.fromList(img.encodePng(mask)),
          targetWidth: 256,
          targetHeight: 256,
        );

        final result = InpaintMaskUtils.composeGeneratedImageArtifact(
          normalizedSourceImage: sourceBytes,
          compositeMaskImage: artifacts.compositeMaskBytes,
          generatedImage: generatedBytes,
        );
        final patch = img.decodeImage(result.transparentPatchBytes!)!;
        final display = img.decodeImage(result.displayImageBytes)!;
        final reconstructed = img.Image.from(source, noAnimation: true);
        img.compositeImage(reconstructed, patch, blend: img.BlendMode.alpha);

        img.Pixel? softPixel;
        for (final pixel in patch) {
          if (pixel.a.toInt() > 0 && pixel.a.toInt() < 255) {
            softPixel = pixel;
            break;
          }
        }
        expect(softPixel, isNotNull);
        expect(softPixel!.r.toInt(), equals(200));
        expect(softPixel.g.toInt(), equals(210));
        expect(softPixel.b.toInt(), equals(220));
        expect(patch.getPixel(0, 0).a.toInt(), equals(0));
        expect(patch.getPixel(128, 128).a.toInt(), equals(255));
        _expectSamePixels(reconstructed, display);
      },
    );

    test(
      'extractGeneratedPatch should make pixels outside mask transparent',
      () {
        final generated = img.Image(width: 4, height: 4);
        img.fill(generated, color: img.ColorRgba8(200, 210, 220, 255));

        final mask = img.Image(width: 4, height: 4);
        img.fill(mask, color: img.ColorRgba8(0, 0, 0, 255));
        mask.setPixelRgba(1, 1, 255, 255, 255, 255);

        final result = InpaintMaskUtils.extractGeneratedPatch(
          maskImage: Uint8List.fromList(img.encodePng(mask)),
          generatedImage: Uint8List.fromList(img.encodePng(generated)),
        );
        final decoded = img.decodeImage(result)!;

        expect(decoded.getPixel(1, 1).a.toInt(), equals(255));
        expect(decoded.getPixel(1, 1).r.toInt(), equals(200));
        expect(decoded.getPixel(0, 0).a.toInt(), equals(0));
        expect(decoded.getPixel(3, 3).a.toInt(), equals(0));
      },
    );
  });
}

({int r, int g, int b, int a}) _rgbaAt(img.Image image, int x, int y) {
  final pixel = image.getPixel(x, y);
  return (
    r: pixel.r.toInt(),
    g: pixel.g.toInt(),
    b: pixel.b.toInt(),
    a: pixel.a.toInt(),
  );
}

void _expectSamePixels(img.Image actual, img.Image expected) {
  expect((actual.width, actual.height), (expected.width, expected.height));
  for (var y = 0; y < actual.height; y++) {
    for (var x = 0; x < actual.width; x++) {
      expect(
        _rgbaAt(actual, x, y),
        _rgbaAt(expected, x, y),
        reason: 'Pixel mismatch at $x,$y',
      );
    }
  }
}

img.Image _buildParityMask({required int width, required int height}) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final masked = _isParityMasked(x, y);
      final value = masked ? 255 : 0;
      image.setPixelRgba(x, y, value, value, value, 255);
    }
  }
  return image;
}

bool _isParityMasked(int x, int y) {
  final wobble =
      1 +
      0.13 * math.sin(y / 6.0) +
      0.08 * math.cos(x / 8.0) +
      0.05 * math.sin((x + y) / 9.0);
  final dx = (x - 126) / 48;
  final dy = (y - 92) / 31;
  final blob = dx * dx + dy * dy < wobble;
  final leftPatch = x >= 34 && x <= 76 && y >= 48 && y <= 86;
  final thinStroke =
      (x - y).abs() <= 2 && x >= 148 && x <= 206 && y >= 40 && y <= 98;
  final lowerPatch = x >= 92 && x <= 146 && y >= 132 && y <= 154;
  return blob || leftPatch || thinStroke || lowerPatch;
}
