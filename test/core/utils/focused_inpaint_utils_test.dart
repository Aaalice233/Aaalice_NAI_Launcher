import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/focused_inpaint_utils.dart';
import 'package:nai_launcher/core/utils/inpaint_mask_utils.dart';

void main() {
  group('FocusedInpaintUtils', () {
    group('geometry', () {
      FocusedInpaintGeometry resolve({
        required int sourceWidth,
        required int sourceHeight,
        required Rect selection,
        double context = 16,
        Offset? anchor,
      }) {
        return FocusedInpaintUtils.resolveGeometryForSelection(
          sourceWidth: sourceWidth,
          sourceHeight: sourceHeight,
          selectionRect: selection,
          minContextMegaPixels: context,
          fixedAnchor: anchor,
        )!;
      }

      test('upscales a 512x512 crop to the one megapixel target', () {
        final geometry = resolve(
          sourceWidth: 512,
          sourceHeight: 512,
          selection: const Rect.fromLTWH(0, 0, 512, 512),
        );

        expect(geometry.contextCrop.area, 512 * 512);
        expect(geometry.requestMode, FocusedInpaintRequestMode.upscaleToTarget);
        expect((geometry.requestWidth, geometry.requestHeight), (1024, 1024));
      });

      test('uses the upscale branch at exactly 1,048,576 pixels', () {
        final geometry = resolve(
          sourceWidth: 1024,
          sourceHeight: 1024,
          selection: const Rect.fromLTWH(0, 0, 1024, 1024),
        );

        expect(geometry.contextCrop.area, 1048576);
        expect(geometry.requestMode, FocusedInpaintRequestMode.upscaleToTarget);
        expect((geometry.requestWidth, geometry.requestHeight), (1024, 1024));
      });

      test('preserves scale immediately above the one megapixel threshold', () {
        final geometry = resolve(
          sourceWidth: 1025,
          sourceHeight: 1024,
          selection: const Rect.fromLTWH(0, 0, 1025, 1024),
        );

        expect(geometry.contextCrop.area, 1025 * 1024);
        expect(geometry.requestMode, FocusedInpaintRequestMode.preserveCrop);
        expect((geometry.requestWidth, geometry.requestHeight), (1024, 1024));
      });

      test('keeps a 1280x1024 paid crop and floors it to the 64 grid', () {
        final geometry = resolve(
          sourceWidth: 1280,
          sourceHeight: 1024,
          selection: const Rect.fromLTWH(0, 0, 1280, 1024),
        );

        expect(geometry.requestMode, FocusedInpaintRequestMode.preserveCrop);
        expect((geometry.requestWidth, geometry.requestHeight), (1280, 1024));
      });

      test('accepts the exact 2048x1536 total-area boundary', () {
        final geometry = resolve(
          sourceWidth: 2048,
          sourceHeight: 1536,
          selection: const Rect.fromLTWH(0, 0, 2048, 1536),
        );

        expect(geometry.contextCrop.area, 3145728);
        expect(geometry.wasDynamicallyConstrained, isFalse);
        expect((geometry.requestWidth, geometry.requestHeight), (2048, 1536));
      });

      test('dynamically shrinks an outer crop above the total-area limit', () {
        final geometry = resolve(
          sourceWidth: 2048,
          sourceHeight: 1537,
          selection: const Rect.fromLTWH(0, 0, 2048, 1537),
        );

        expect(geometry.wasDynamicallyConstrained, isTrue);
        expect(
          geometry.contextCrop.area,
          lessThanOrEqualTo(FocusedInpaintUtils.maxRequestAreaPixels),
        );
        expect(
          geometry.requestArea,
          lessThanOrEqualTo(FocusedInpaintUtils.maxRequestAreaPixels),
        );
      });

      test('does not impose a 2048 per-side limit', () {
        final geometry = resolve(
          sourceWidth: 3072,
          sourceHeight: 1024,
          selection: const Rect.fromLTWH(0, 0, 3072, 1024),
        );

        expect(geometry.wasDynamicallyConstrained, isFalse);
        expect((geometry.requestWidth, geometry.requestHeight), (3072, 1024));
      });

      test('supports horizontal and vertical legal strips', () {
        final horizontal = resolve(
          sourceWidth: 3000,
          sourceHeight: 500,
          selection: const Rect.fromLTWH(0, 0, 3000, 500),
        );
        final vertical = resolve(
          sourceWidth: 500,
          sourceHeight: 3000,
          selection: const Rect.fromLTWH(0, 0, 500, 3000),
        );

        expect(
          (horizontal.requestWidth, horizontal.requestHeight),
          (2944, 448),
        );
        expect((vertical.requestWidth, vertical.requestHeight), (448, 2944));
      });

      test('floors non-grid paid crops without crossing the area limit', () {
        final geometry = resolve(
          sourceWidth: 1300,
          sourceHeight: 1000,
          selection: const Rect.fromLTWH(0, 0, 1300, 1000),
        );

        expect((geometry.requestWidth, geometry.requestHeight), (1280, 960));
        expect(geometry.requestWidth % 64, 0);
        expect(geometry.requestHeight % 64, 0);
      });

      test('clamps context crops at canvas edges', () {
        final geometry = resolve(
          sourceWidth: 1000,
          sourceHeight: 800,
          selection: const Rect.fromLTWH(0, 0, 120, 96),
          context: 88,
        );

        expect(geometry.contextCrop.x, 0);
        expect(geometry.contextCrop.y, 0);
        expect(
          (geometry.contextCrop.width, geometry.contextCrop.height),
          (296, 272),
        );
      });

      test('accepts a one-pixel focus region and applies the 64 grid', () {
        final geometry = resolve(
          sourceWidth: 32,
          sourceHeight: 32,
          selection: const Rect.fromLTWH(15, 15, 1, 1),
        );

        expect(
          (geometry.focusBounds.width, geometry.focusBounds.height),
          (1, 1),
        );
        expect((geometry.requestWidth, geometry.requestHeight), (1024, 1024));
        expect(geometry.requestWidth % 64, 0);
        expect(geometry.requestHeight % 64, 0);
      });

      test(
        'larger Minimum Context immediately reduces an oversized selection',
        () {
          const selection = Rect.fromLTWH(100, 100, 1900, 1500);
          final smallContext = resolve(
            sourceWidth: 2200,
            sourceHeight: 1800,
            selection: selection,
            context: 16,
          );
          final largeContext = resolve(
            sourceWidth: 2200,
            sourceHeight: 1800,
            selection: selection,
            context: 192,
          );

          expect(largeContext.wasDynamicallyConstrained, isTrue);
          expect(
            largeContext.focusBounds.area,
            lessThan(smallContext.focusBounds.area),
          );
          expect(
            largeContext.contextCrop.area,
            lessThanOrEqualTo(FocusedInpaintUtils.maxRequestAreaPixels),
          );
        },
      );

      test('fixed-corner constraint keeps the pointer-down corner', () {
        final geometry = resolve(
          sourceWidth: 4096,
          sourceHeight: 4096,
          selection: const Rect.fromLTWH(128, 256, 3600, 3200),
          context: 88,
          anchor: const Offset(128, 256),
        );

        expect(geometry.wasDynamicallyConstrained, isTrue);
        expect(geometry.focusBounds.x, 128);
        expect(geometry.focusBounds.y, 256);
        expect(
          geometry.contextCrop.area,
          lessThanOrEqualTo(FocusedInpaintUtils.maxRequestAreaPixels),
        );
      });
    });

    test(
      'prepareRequest should crop around mask and upscale focused region to about 1MP',
      () {
        final source = img.Image(width: 1200, height: 800);
        img.fill(source, color: img.ColorRgb8(0, 0, 0));

        final mask = img.Image(width: 1200, height: 800);
        img.fill(mask, color: img.ColorRgb8(0, 0, 0));
        for (var y = 260; y < 340; y++) {
          for (var x = 520; x < 600; x++) {
            mask.setPixelRgb(x, y, 255, 255, 255);
          }
        }

        final request = FocusedInpaintUtils.prepareRequest(
          sourceImage: Uint8List.fromList(img.encodePng(source)),
          maskImage: Uint8List.fromList(img.encodePng(mask)),
          minContextMegaPixels: 88,
        );

        expect(request, isNotNull);
        expect(request!.targetWidth % 64, equals(0));
        expect(request.targetHeight % 64, equals(0));
        expect(
          request.targetWidth * request.targetHeight,
          greaterThanOrEqualTo(800000),
        );
        expect(request.crop.width, lessThan(source.width));
        expect(request.crop.height, lessThan(source.height));
      },
    );

    test(
      'compositeGeneratedImage should merge focused result back into original canvas',
      () {
        final source = img.Image(width: 400, height: 300);
        img.fill(source, color: img.ColorRgb8(16, 32, 64));

        final mask = img.Image(width: 400, height: 300);
        img.fill(mask, color: img.ColorRgb8(0, 0, 0));
        for (var y = 120; y < 160; y++) {
          for (var x = 150; x < 190; x++) {
            mask.setPixelRgb(x, y, 255, 255, 255);
          }
        }

        final request = FocusedInpaintUtils.prepareRequest(
          sourceImage: Uint8List.fromList(img.encodePng(source)),
          maskImage: Uint8List.fromList(img.encodePng(mask)),
          minContextMegaPixels: 40,
        )!;

        final generated = img.Image(
          width: request.targetWidth,
          height: request.targetHeight,
        );
        img.fill(generated, color: img.ColorRgb8(255, 255, 255));
        final generatedBytes = Uint8List.fromList(img.encodePng(generated));

        final merged = request.compositeGeneratedImage(generatedBytes);
        final decoded = img.decodeImage(merged)!;

        expect(decoded.width, equals(400));
        expect(decoded.height, equals(300));
        expect(decoded.getPixel(170, 140).r.toInt(), equals(255));
        expect(decoded.getPixel(110, 80).r.toInt(), equals(16));
        expect(decoded.getPixel(110, 80).g.toInt(), equals(32));
        expect(decoded.getPixel(110, 80).b.toInt(), equals(64));

        final maskArtifacts =
            InpaintMaskUtils.prepareNovelAiInpaintMaskArtifacts(
              request.requestMaskImage,
              targetWidth: request.targetWidth,
              targetHeight: request.targetHeight,
            );
        final artifact = request.composeGeneratedImageArtifact(
          generatedBytes,
          maskArtifacts,
        );
        final patch = img.decodeImage(artifact.transparentPatchBytes!)!;
        final display = img.decodeImage(artifact.displayImageBytes)!;
        final reconstructed = img.Image.from(source, noAnimation: true);
        img.compositeImage(reconstructed, patch, blend: img.BlendMode.alpha);

        expect((patch.width, patch.height), equals((400, 300)));
        expect(patch.getPixel(0, 0).a.toInt(), equals(0));
        expect(patch.getPixel(170, 140).a.toInt(), greaterThan(245));
        _expectImagesMatch(reconstructed, display);
      },
    );

    test(
      'compositeGeneratedImage should use a soft edge and preserve distant pixels',
      () {
        final source = img.Image(width: 400, height: 300);
        img.fill(source, color: img.ColorRgb8(16, 32, 64));

        final mask = img.Image(width: 400, height: 300);
        img.fill(mask, color: img.ColorRgb8(0, 0, 0));
        for (var y = 120; y < 160; y++) {
          for (var x = 150; x < 190; x++) {
            mask.setPixelRgb(x, y, 255, 255, 255);
          }
        }

        final request = FocusedInpaintUtils.prepareRequest(
          sourceImage: Uint8List.fromList(img.encodePng(source)),
          maskImage: Uint8List.fromList(img.encodePng(mask)),
          minContextMegaPixels: 40,
        )!;

        final generated = img.Image(
          width: request.targetWidth,
          height: request.targetHeight,
        );
        img.fill(generated, color: img.ColorRgb8(255, 255, 255));

        final merged = request.compositeGeneratedImage(
          Uint8List.fromList(img.encodePng(generated)),
        );
        final decoded = img.decodeImage(merged)!;

        expect(decoded.getPixel(150, 140).r.toInt(), greaterThan(245));
        expect(decoded.getPixel(149, 140).r.toInt(), inInclusiveRange(17, 254));
        expect(decoded.getPixel(190, 140).r.toInt(), inInclusiveRange(17, 254));
        expect(decoded.getPixel(110, 80).r.toInt(), equals(16));
        expect(decoded.getPixel(110, 80).g.toInt(), equals(32));
        expect(decoded.getPixel(110, 80).b.toInt(), equals(64));
      },
    );

    test(
      'resolvePreviewCrop should prefer explicit focused selection rect',
      () {
        final source = img.Image(width: 1000, height: 1000);
        img.fill(source, color: img.ColorRgb8(0, 0, 0));

        final mask = img.Image(width: 1000, height: 1000);
        img.fill(mask, color: img.ColorRgb8(0, 0, 0));
        for (var y = 620; y < 700; y++) {
          for (var x = 700; x < 780; x++) {
            mask.setPixelRgb(x, y, 255, 255, 255);
          }
        }

        final maskDrivenCrop = FocusedInpaintUtils.resolvePreviewCrop(
          sourceImage: Uint8List.fromList(img.encodePng(source)),
          maskImage: Uint8List.fromList(img.encodePng(mask)),
          minContextMegaPixels: 32,
        )!;
        final focusedCrop = FocusedInpaintUtils.resolvePreviewCrop(
          sourceImage: Uint8List.fromList(img.encodePng(source)),
          maskImage: Uint8List.fromList(img.encodePng(mask)),
          focusedSelectionRect: const Rect.fromLTWH(120, 160, 240, 280),
          minContextMegaPixels: 48,
        )!;

        expect(maskDrivenCrop.x, greaterThan(400));
        expect(maskDrivenCrop.y, greaterThan(300));
        expect(focusedCrop.x, lessThan(400));
        expect(focusedCrop.y, lessThan(400));
      },
    );

    test(
      'resolveContextCropForSelection should expand selection by the requested context band',
      () {
        final crop = FocusedInpaintUtils.resolveContextCropForSelection(
          sourceWidth: 1200,
          sourceHeight: 800,
          selectionRect: const Rect.fromLTWH(420, 180, 120, 96),
          minContextMegaPixels: 88,
        )!;

        expect(crop.x, equals(332));
        expect(crop.y, equals(92));
        expect(crop.width, equals(296));
        expect(crop.height, equals(272));
      },
    );

    test(
      'resolveContextCropForSelection should enforce minimum context band',
      () {
        final crop = FocusedInpaintUtils.resolveContextCropForSelection(
          sourceWidth: 1200,
          sourceHeight: 800,
          selectionRect: const Rect.fromLTWH(420, 180, 120, 96),
          minContextMegaPixels: 0,
        )!;

        expect(crop.x, equals(404));
        expect(crop.y, equals(164));
        expect(crop.width, equals(152));
        expect(crop.height, equals(128));
      },
    );

    test(
      'resolveRequestSizeForSelection should match focused request target size without decoding images',
      () {
        const selectionRect = Rect.fromLTWH(420, 180, 120, 96);
        final requestSize = FocusedInpaintUtils.resolveRequestSizeForSelection(
          sourceWidth: 1200,
          sourceHeight: 800,
          selectionRect: selectionRect,
          minContextMegaPixels: 88,
        );

        final source = img.Image(width: 1200, height: 800);
        img.fill(source, color: img.ColorRgb8(0, 0, 0));
        final mask = img.Image(width: 1200, height: 800);
        img.fill(mask, color: img.ColorRgb8(0, 0, 0));
        for (
          var y = selectionRect.top.toInt();
          y < selectionRect.bottom.toInt();
          y++
        ) {
          for (
            var x = selectionRect.left.toInt();
            x < selectionRect.right.toInt();
            x++
          ) {
            mask.setPixelRgb(x, y, 255, 255, 255);
          }
        }

        final request = FocusedInpaintUtils.prepareRequest(
          sourceImage: Uint8List.fromList(img.encodePng(source)),
          maskImage: Uint8List.fromList(img.encodePng(mask)),
          focusedSelectionRect: selectionRect,
          minContextMegaPixels: 88,
        );

        expect(requestSize, isNotNull);
        expect(request, isNotNull);
        expect(requestSize!.$1, equals(request!.targetWidth));
        expect(requestSize.$2, equals(request.targetHeight));
      },
    );

    test(
      'resolveRequestSizeForMask should match prepareRequest for irregular masks',
      () {
        final source = img.Image(width: 1024, height: 768);
        img.fill(source, color: img.ColorRgb8(0, 0, 0));
        final mask = _buildIrregularMask(width: 1024, height: 768);
        final sourceBytes = Uint8List.fromList(img.encodePng(source));
        final maskBytes = Uint8List.fromList(img.encodePng(mask));

        final lightweightSize = FocusedInpaintUtils.resolveRequestSizeForMask(
          maskImage: maskBytes,
          minContextMegaPixels: 88,
        );
        final request = FocusedInpaintUtils.prepareRequest(
          sourceImage: sourceBytes,
          maskImage: maskBytes,
          minContextMegaPixels: 88,
        );

        expect(lightweightSize, isNotNull);
        expect(request, isNotNull);
        expect(lightweightSize!.$1, equals(request!.targetWidth));
        expect(lightweightSize.$2, equals(request.targetHeight));
      },
    );

    test('resolveRequestSizeForMask should return null for empty masks', () {
      final mask = img.Image(width: 320, height: 240);
      img.fill(mask, color: img.ColorRgb8(0, 0, 0));

      final size = FocusedInpaintUtils.resolveRequestSizeForMask(
        maskImage: Uint8List.fromList(img.encodePng(mask)),
        minContextMegaPixels: 88,
      );

      expect(size, isNull);
    });

    test(
      'prepareRequestAsync should match the sync path across the isolate boundary',
      () async {
        final source = img.Image(width: 640, height: 480);
        img.fill(source, color: img.ColorRgb8(16, 32, 64));
        final mask = _buildIrregularMask(width: 640, height: 480);
        final sourceBytes = Uint8List.fromList(img.encodePng(source));
        final maskBytes = Uint8List.fromList(img.encodePng(mask));

        final syncRequest = FocusedInpaintUtils.prepareRequest(
          sourceImage: sourceBytes,
          maskImage: maskBytes,
          minContextMegaPixels: 40,
        )!;
        final asyncRequest = await FocusedInpaintUtils.prepareRequestAsync(
          sourceImage: sourceBytes,
          maskImage: maskBytes,
          minContextMegaPixels: 40,
        );

        expect(asyncRequest, isNotNull);
        expect(asyncRequest!.targetWidth, equals(syncRequest.targetWidth));
        expect(asyncRequest.targetHeight, equals(syncRequest.targetHeight));
        expect(asyncRequest.crop.x, equals(syncRequest.crop.x));
        expect(asyncRequest.crop.y, equals(syncRequest.crop.y));
        expect(asyncRequest.crop.width, equals(syncRequest.crop.width));
        expect(asyncRequest.crop.height, equals(syncRequest.crop.height));
        expect(
          asyncRequest.requestSourceImage,
          equals(syncRequest.requestSourceImage),
        );
        expect(
          asyncRequest.requestMaskImage,
          equals(syncRequest.requestMaskImage),
        );

        final generated = img.Image(
          width: asyncRequest.targetWidth,
          height: asyncRequest.targetHeight,
        );
        img.fill(generated, color: img.ColorRgb8(255, 255, 255));
        final generatedBytes = Uint8List.fromList(img.encodePng(generated));

        final syncComposite = syncRequest.compositeGeneratedImage(
          generatedBytes,
        );
        expect(
          asyncRequest.compositeGeneratedImage(generatedBytes),
          equals(syncComposite),
        );
        expect(
          await asyncRequest.compositeGeneratedImageAsync(generatedBytes),
          equals(syncComposite),
        );
      },
    );
  });
}

/// 构造带斜向笔画、分离色块与孔洞的不规则蒙版。
img.Image _buildIrregularMask({required int width, required int height}) {
  final mask = img.Image(width: width, height: height);
  img.fill(mask, color: img.ColorRgb8(0, 0, 0));

  for (var y = height ~/ 4; y < height ~/ 4 + 60; y++) {
    for (var x = width ~/ 3; x < width ~/ 3 + 90; x++) {
      final onDiagonal = (x - y).abs() % 7 != 0;
      final inHole =
          x > width ~/ 3 + 30 &&
          x < width ~/ 3 + 50 &&
          y > height ~/ 4 + 20 &&
          y < height ~/ 4 + 40;
      if (onDiagonal && !inHole) {
        mask.setPixelRgb(x, y, 255, 255, 255);
      }
    }
  }
  for (var y = height ~/ 2; y < height ~/ 2 + 24; y++) {
    for (var x = width ~/ 2; x < width ~/ 2 + 36; x++) {
      mask.setPixelRgb(x, y, 255, 255, 255);
    }
  }

  return mask;
}

void _expectImagesMatch(img.Image actual, img.Image expected) {
  expect((actual.width, actual.height), (expected.width, expected.height));
  for (var y = 0; y < actual.height; y++) {
    for (var x = 0; x < actual.width; x++) {
      final actualPixel = actual.getPixel(x, y);
      final expectedPixel = expected.getPixel(x, y);
      expect(
        (
          actualPixel.r.toInt(),
          actualPixel.g.toInt(),
          actualPixel.b.toInt(),
          actualPixel.a.toInt(),
        ),
        (
          expectedPixel.r.toInt(),
          expectedPixel.g.toInt(),
          expectedPixel.b.toInt(),
          expectedPixel.a.toInt(),
        ),
        reason: 'Pixel mismatch at $x,$y',
      );
    }
  }
}
