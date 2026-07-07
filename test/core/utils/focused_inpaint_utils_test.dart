import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/focused_inpaint_utils.dart';

void main() {
  group('FocusedInpaintUtils', () {
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

        final merged = request.compositeGeneratedImage(
          Uint8List.fromList(img.encodePng(generated)),
        );
        final decoded = img.decodeImage(merged)!;

        expect(decoded.width, equals(400));
        expect(decoded.height, equals(300));
        expect(decoded.getPixel(170, 140).r.toInt(), equals(255));
        expect(decoded.getPixel(110, 80).r.toInt(), equals(16));
        expect(decoded.getPixel(110, 80).g.toInt(), equals(32));
        expect(decoded.getPixel(110, 80).b.toInt(), equals(64));
      },
    );

    test(
      'compositeGeneratedImage should preserve pixels outside the original mask boundary',
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

        expect(decoded.getPixel(150, 140).r.toInt(), equals(255));
        expect(decoded.getPixel(149, 140).r.toInt(), equals(16));
        expect(decoded.getPixel(149, 140).g.toInt(), equals(32));
        expect(decoded.getPixel(149, 140).b.toInt(), equals(64));
        expect(decoded.getPixel(190, 140).r.toInt(), equals(16));
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
  });
}
