import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/focused_inpaint_utils.dart';
import 'package:nai_launcher/core/utils/inpaint_mask_utils.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

import '../../helpers/exif_orientation_fixture.dart';
import '../../helpers/image_pixel_matchers.dart';

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

      group('fixed context crop', () {
        FocusedInpaintGeometry? resolveCrop(Rect crop, {int size = 2560}) {
          return FocusedInpaintUtils.resolveGeometryForCrop(
            sourceWidth: size,
            sourceHeight: size,
            crop: crop,
          );
        }

        test('uses the crop exactly and keeps a free-tier frame as is', () {
          final geometry = resolveCrop(
            const Rect.fromLTWH(384, 0, 832, 1216),
            size: 1216,
          )!;

          expect(
            geometry.contextCrop.rect,
            const Rect.fromLTWH(384, 0, 832, 1216),
          );
          expect(geometry.focusBounds.rect, geometry.contextCrop.rect);
          expect(geometry.wasDynamicallyConstrained, isFalse);
          expect((geometry.requestWidth, geometry.requestHeight), (832, 1216));
        });

        test('follows the focused sizing rules', () {
          final small = resolveCrop(const Rect.fromLTWH(0, 0, 512, 512))!;
          expect(small.requestMode, FocusedInpaintRequestMode.upscaleToTarget);
          expect((small.requestWidth, small.requestHeight), (1024, 1024));

          final paid = resolveCrop(const Rect.fromLTWH(0, 0, 1216, 1216))!;
          expect(paid.requestMode, FocusedInpaintRequestMode.preserveCrop);
          expect((paid.requestWidth, paid.requestHeight), (1216, 1216));
        });

        test('shrinks an oversized crop without changing its aspect', () {
          final geometry = resolveCrop(const Rect.fromLTWH(0, 0, 2048, 2048))!;

          expect((geometry.requestWidth, geometry.requestHeight), (1728, 1728));
          expect(
            geometry.requestArea,
            lessThanOrEqualTo(FocusedInpaintUtils.maxRequestAreaPixels),
          );
        });

        test('rejects crops that leave the source', () {
          expect(resolveCrop(const Rect.fromLTWH(-64, 0, 832, 1216)), isNull);
          expect(resolveCrop(const Rect.fromLTWH(2000, 0, 832, 1216)), isNull);
          expect(resolveCrop(const Rect.fromLTWH(10, 10, 0, 64)), isNull);
        });
      });

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
      'composeGeneratedImageArtifact should merge the focused result into the display image',
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
        expect(display.getPixel(170, 140).r.toInt(), equals(255));
        expect(display.getPixel(110, 80).r.toInt(), equals(16));
        expect(display.getPixel(110, 80).g.toInt(), equals(32));
        expect(display.getPixel(110, 80).b.toInt(), equals(64));
        expectPixelsWithin(
          reconstructed,
          display,
          tolerance: focusedInpaintResampleTolerance,
        );
      },
    );

    test(
      'composeGeneratedImageArtifact takes display metadata from the server result only',
      () {
        Map<String, String> naiText(
          String prompt,
          int seed, {
          required int width,
          required int height,
        }) => {
          'Comment': jsonEncode({
            'prompt': prompt,
            'width': width,
            'height': height,
            'seed': seed,
          }),
          'Description': prompt,
          'Software': 'NovelAI',
          'Source': 'NovelAI Diffusion V4.5',
        };
        final source = img.Image(width: 400, height: 300);
        img.fill(source, color: img.ColorRgb8(16, 32, 64));
        final mask = img.Image(width: 400, height: 300);
        img.fill(mask, color: img.ColorRgb8(0, 0, 0));
        img.fillRect(
          mask,
          x1: 150,
          y1: 120,
          x2: 189,
          y2: 159,
          color: img.ColorRgb8(255, 255, 255),
        );
        final request = FocusedInpaintUtils.prepareRequest(
          sourceImage: UnifiedMetadataParser.embedTextChunks(
            Uint8List.fromList(img.encodePng(source)),
            naiText('original prompt', 1, width: 400, height: 300),
          ),
          maskImage: Uint8List.fromList(img.encodePng(mask)),
          minContextMegaPixels: 40,
        )!;
        final generated = img.Image(
          width: request.targetWidth,
          height: request.targetHeight,
        );
        img.fill(generated, color: img.ColorRgb8(255, 255, 255));
        expect((request.targetWidth, request.targetHeight), isNot((400, 300)));
        final serverText = naiText(
          'focused prompt',
          4242,
          width: request.targetWidth,
          height: request.targetHeight,
        );
        final maskArtifacts =
            InpaintMaskUtils.prepareNovelAiInpaintMaskArtifacts(
              request.requestMaskImage,
              targetWidth: request.targetWidth,
              targetHeight: request.targetHeight,
            );

        final artifact = request.composeGeneratedImageArtifact(
          UnifiedMetadataParser.embedTextChunks(
            Uint8List.fromList(img.encodePng(generated)),
            serverText,
          ),
          maskArtifacts,
        );

        final displayText = UnifiedMetadataParser.extractPngTextData(
          artifact.displayImageBytes,
        );
        expect(
          jsonDecode(displayText['Comment']!),
          equals({
            'prompt': 'focused prompt',
            'width': 400,
            'height': 300,
            'seed': 4242,
          }),
        );
        expect(
          Map.of(displayText)..remove('Comment'),
          equals(Map.of(serverText)..remove('Comment')),
        );
      },
    );

    test(
      'composeGeneratedImageArtifact clears old pixels for transparent focused results',
      () {
        final source = img.Image(width: 400, height: 300);
        img.fill(source, color: img.ColorRgb8(16, 32, 64));
        final mask = img.Image(width: 400, height: 300);
        img.fill(mask, color: img.ColorRgb8(0, 0, 0));
        img.fillRect(
          mask,
          x1: 150,
          y1: 120,
          x2: 189,
          y2: 159,
          color: img.ColorRgb8(255, 255, 255),
        );
        final request = FocusedInpaintUtils.prepareRequest(
          sourceImage: Uint8List.fromList(img.encodePng(source)),
          maskImage: Uint8List.fromList(img.encodePng(mask)),
          minContextMegaPixels: 40,
        )!;
        final generated = img.Image(
          width: request.targetWidth,
          height: request.targetHeight,
          numChannels: 4,
        );
        img.fill(generated, color: img.ColorRgba8(255, 255, 255, 0));

        final artifacts = InpaintMaskUtils.prepareNovelAiInpaintMaskArtifacts(
          request.requestMaskImage,
          targetWidth: request.targetWidth,
          targetHeight: request.targetHeight,
        );
        final result = request.composeGeneratedImageArtifact(
          Uint8List.fromList(img.encodePng(generated)),
          artifacts,
        );
        final decoded = img.decodeImage(result.displayImageBytes)!;

        expect(decoded.numChannels, equals(4));
        expect(decoded.getPixel(170, 140).a.toInt(), equals(0));
        expect(decoded.getPixel(110, 80).a.toInt(), equals(255));
        expect(decoded.getPixel(110, 80).r.toInt(), equals(16));
        expect(decoded.getPixel(110, 80).g.toInt(), equals(32));
        expect(decoded.getPixel(110, 80).b.toInt(), equals(64));
      },
    );

    test(
      'composeGeneratedImageArtifact uses a soft edge and preserves distant pixels',
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

        final artifacts = InpaintMaskUtils.prepareNovelAiInpaintMaskArtifacts(
          request.requestMaskImage,
          targetWidth: request.targetWidth,
          targetHeight: request.targetHeight,
        );
        final result = request.composeGeneratedImageArtifact(
          Uint8List.fromList(img.encodePng(generated)),
          artifacts,
        );
        final decoded = img.decodeImage(result.displayImageBytes)!;

        expect(decoded.getPixel(150, 140).r.toInt(), greaterThan(245));
        expect(decoded.getPixel(149, 140).r.toInt(), inInclusiveRange(17, 254));
        expect(decoded.getPixel(190, 140).r.toInt(), inInclusiveRange(17, 254));
        expect(decoded.getPixel(110, 80).r.toInt(), equals(16));
        expect(decoded.getPixel(110, 80).g.toInt(), equals(32));
        expect(decoded.getPixel(110, 80).b.toInt(), equals(64));
      },
    );

    group('fixed context crop request', () {
      // 832x1216 原图向右下各扩 384/64 后的整张画布，框外两角从未生成过
      const frame = Rect.fromLTWH(384, 64, 832, 1216);

      img.Image buildCanvas() {
        final canvas = img.Image(width: 1216, height: 1280, numChannels: 4);
        img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
        img.fillRect(
          canvas,
          x1: 0,
          y1: 0,
          x2: 831,
          y2: 1215,
          color: img.ColorRgba8(16, 32, 64, 255),
        );
        return canvas;
      }

      img.Image buildExtensionMask() {
        final mask = img.Image(width: 1216, height: 1280);
        img.fill(mask, color: img.ColorRgb8(0, 0, 0));
        img.fillRect(
          mask,
          x1: 832,
          y1: 64,
          x2: 1215,
          y2: 1279,
          color: img.ColorRgb8(255, 255, 255),
        );
        img.fillRect(
          mask,
          x1: 384,
          y1: 1216,
          x2: 831,
          y2: 1279,
          color: img.ColorRgb8(255, 255, 255),
        );
        return mask;
      }

      Uint8List png(img.Image image) =>
          Uint8List.fromList(img.encodePng(image));

      test('crops exactly the frame and keeps transparent blanks', () {
        final request = FocusedInpaintUtils.prepareRequest(
          sourceImage: png(buildCanvas()),
          maskImage: png(buildExtensionMask()),
          contextCrop: frame,
          minContextMegaPixels: 96,
        )!;

        expect(request.crop.rect, frame);
        expect((request.targetWidth, request.targetHeight), (832, 1216));
        final sent = img.decodeImage(request.requestSourceImage)!;
        expect((sent.width, sent.height), (832, 1216));
        expect(sent.getPixel(0, 0).r.toInt(), 16);
        expect(sent.getPixel(0, 0).a.toInt(), 255);
        expect(sent.getPixel(600, 300).a.toInt(), 0);
      });

      test('returns null when the crop has nothing to generate', () {
        final source = png(buildCanvas());
        final mask = png(buildExtensionMask());

        expect(
          FocusedInpaintUtils.prepareRequest(
            sourceImage: source,
            maskImage: mask,
            contextCrop: const Rect.fromLTWH(0, 0, 768, 1152),
            minContextMegaPixels: 96,
          ),
          isNull,
        );
        expect(
          FocusedInpaintUtils.prepareRequest(
            sourceImage: source,
            maskImage: mask,
            contextCrop: const Rect.fromLTWH(448, 64, 832, 1216),
            minContextMegaPixels: 96,
          ),
          isNull,
        );
      });

      test('pastes only masked pixels back into the whole canvas', () {
        final canvas = buildCanvas();
        final request = FocusedInpaintUtils.prepareRequest(
          sourceImage: png(canvas),
          maskImage: png(buildExtensionMask()),
          contextCrop: frame,
          minContextMegaPixels: 96,
        )!;
        final generated = img.Image(
          width: request.targetWidth,
          height: request.targetHeight,
        );
        img.fill(generated, color: img.ColorRgb8(255, 255, 255));
        final artifacts = InpaintMaskUtils.prepareNovelAiInpaintMaskArtifacts(
          request.requestMaskImage,
          targetWidth: request.targetWidth,
          targetHeight: request.targetHeight,
        );

        final display = img.decodeImage(
          request
              .composeGeneratedImageArtifact(png(generated), artifacts)
              .displayImageBytes,
        )!;

        expect((display.width, display.height), (1216, 1280));
        for (final point in const [(100, 100), (600, 600)]) {
          final pixel = display.getPixel(point.$1, point.$2);
          expect(
            (
              pixel.r.toInt(),
              pixel.g.toInt(),
              pixel.b.toInt(),
              pixel.a.toInt(),
            ),
            (16, 32, 64, 255),
            reason: 'original pixel at $point',
          );
        }
        final generatedPixel = display.getPixel(1000, 600);
        expect(generatedPixel.r.toInt(), 255);
        expect(generatedPixel.a.toInt(), 255);
        expect(display.getPixel(1000, 20).a.toInt(), 0);
        expect(display.getPixel(100, 1250).a.toInt(), 0);
      });
    });

    test('prepareRequest should prefer explicit focused selection rect', () {
      final source = img.Image(width: 1000, height: 1000);
      img.fill(source, color: img.ColorRgb8(0, 0, 0));

      final mask = img.Image(width: 1000, height: 1000);
      img.fill(mask, color: img.ColorRgb8(0, 0, 0));
      for (var y = 620; y < 700; y++) {
        for (var x = 700; x < 780; x++) {
          mask.setPixelRgb(x, y, 255, 255, 255);
        }
      }

      final maskDrivenCrop = FocusedInpaintUtils.prepareRequest(
        sourceImage: Uint8List.fromList(img.encodePng(source)),
        maskImage: Uint8List.fromList(img.encodePng(mask)),
        minContextMegaPixels: 32,
      )!.crop;
      final focusedCrop = FocusedInpaintUtils.prepareRequest(
        sourceImage: Uint8List.fromList(img.encodePng(source)),
        maskImage: Uint8List.fromList(img.encodePng(mask)),
        focusedSelectionRect: const Rect.fromLTWH(120, 160, 240, 280),
        minContextMegaPixels: 48,
      )!.crop;

      expect(maskDrivenCrop.x, greaterThan(400));
      expect(maskDrivenCrop.y, greaterThan(300));
      expect(focusedCrop.x, lessThan(400));
      expect(focusedCrop.y, lessThan(400));
    });

    test(
      'selection geometry should expand the crop by the requested context band',
      () {
        final crop = FocusedInpaintUtils.resolveGeometryForSelection(
          sourceWidth: 1200,
          sourceHeight: 800,
          selectionRect: const Rect.fromLTWH(420, 180, 120, 96),
          minContextMegaPixels: 88,
        )!.contextCrop;

        expect(crop.x, equals(332));
        expect(crop.y, equals(92));
        expect(crop.width, equals(296));
        expect(crop.height, equals(272));
      },
    );

    test('selection geometry should enforce the minimum context band', () {
      final crop = FocusedInpaintUtils.resolveGeometryForSelection(
        sourceWidth: 1200,
        sourceHeight: 800,
        selectionRect: const Rect.fromLTWH(420, 180, 120, 96),
        minContextMegaPixels: 0,
      )!.contextCrop;

      expect(crop.x, equals(404));
      expect(crop.y, equals(164));
      expect(crop.width, equals(152));
      expect(crop.height, equals(128));
    });

    test(
      'selection geometry should match the focused request target size without decoding images',
      () {
        const selectionRect = Rect.fromLTWH(420, 180, 120, 96);
        final geometry = FocusedInpaintUtils.resolveGeometryForSelection(
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

        expect(geometry, isNotNull);
        expect(request, isNotNull);
        expect(geometry!.requestWidth, equals(request!.targetWidth));
        expect(geometry.requestHeight, equals(request.targetHeight));
      },
    );

    test(
      'mask extent geometry should match prepareRequest for irregular masks',
      () {
        // 宽幅画布配大上下文时裁切区会被画布高度截住
        for (final (width, height, minContext) in const [
          (1024, 768, 88.0),
          (1536, 640, 192.0),
        ]) {
          final source = img.Image(width: width, height: height);
          img.fill(source, color: img.ColorRgb8(0, 0, 0));
          final mask = _buildIrregularMask(width: width, height: height);
          final sourceBytes = Uint8List.fromList(img.encodePng(source));
          final maskBytes = Uint8List.fromList(img.encodePng(mask));

          final extent = FocusedInpaintUtils.resolveMaskExtent(maskBytes);
          final lightweight = FocusedInpaintUtils.resolveGeometryForMaskExtent(
            extent!,
            minContextMegaPixels: minContext,
          );
          final request = FocusedInpaintUtils.prepareRequest(
            sourceImage: sourceBytes,
            maskImage: maskBytes,
            minContextMegaPixels: minContext,
          );

          expect(lightweight, isNotNull);
          expect(request, isNotNull);
          expect(lightweight!.requestWidth, equals(request!.targetWidth));
          expect(lightweight.requestHeight, equals(request.targetHeight));
          expect(lightweight.contextCrop.rect, request.crop.rect);
        }
      },
    );

    test('resolveMaskExtent should return null for empty masks', () {
      final mask = img.Image(width: 320, height: 240);
      img.fill(mask, color: img.ColorRgb8(0, 0, 0));

      final extent = FocusedInpaintUtils.resolveMaskExtent(
        Uint8List.fromList(img.encodePng(mask)),
      );

      expect(extent, isNull);
    });

    test(
      'resolveGeometryForMaskAsync should match the sync geometry',
      () async {
        final mask = _buildIrregularMask(width: 640, height: 480);
        final maskBytes = Uint8List.fromList(img.encodePng(mask));
        final empty = img.Image(width: 64, height: 48);
        img.fill(empty, color: img.ColorRgb8(0, 0, 0));

        final syncGeometry = FocusedInpaintUtils.resolveGeometryForMask(
          maskImage: maskBytes,
          minContextMegaPixels: 40,
        )!;
        final asyncGeometry =
            await FocusedInpaintUtils.resolveGeometryForMaskAsync(
              maskImage: maskBytes,
              minContextMegaPixels: 40,
            );

        expect(asyncGeometry, isNotNull);
        expect(asyncGeometry!.requestWidth, syncGeometry.requestWidth);
        expect(asyncGeometry.requestHeight, syncGeometry.requestHeight);
        expect(asyncGeometry.requestMode, syncGeometry.requestMode);
        expect(asyncGeometry.focusBounds.rect, syncGeometry.focusBounds.rect);
        expect(asyncGeometry.contextCrop.rect, syncGeometry.contextCrop.rect);
        expect(
          await FocusedInpaintUtils.resolveGeometryForMaskAsync(
            maskImage: Uint8List.fromList(img.encodePng(empty)),
            minContextMegaPixels: 40,
          ),
          isNull,
        );
      },
    );

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
      },
    );

    test('crops an EXIF-rotated webp source on its displayed axes', () {
      for (final orientation in [1, 2, 3, 4, 5, 6, 7, 8]) {
        final (width, height) = orientation >= 5 ? (400, 600) : (600, 400);
        final mask = img.Image(width: width, height: height);
        img.fill(mask, color: img.ColorRgb8(0, 0, 0));
        img.fillRect(
          mask,
          x1: 180,
          y1: 180,
          x2: 219,
          y2: 219,
          color: img.ColorRgb8(255, 255, 255),
        );

        final request = FocusedInpaintUtils.prepareRequest(
          sourceImage: orientedMarkedWebp(
            width: 600,
            height: 400,
            orientation: orientation,
          ),
          maskImage: Uint8List.fromList(img.encodePng(mask)),
          minContextMegaPixels: 1,
        );

        expect(request, isNotNull, reason: '$orientation');
        expect(
          (request!.originalSourceWidth, request.originalSourceHeight),
          (width, height),
          reason: '$orientation',
        );
      }
    });
  });

  group('resolveRequestGeometry matches what prepareRequest sends', () {
    Uint8List png(img.Image image) => Uint8List.fromList(img.encodePng(image));
    img.Image black(int width, int height) => img.fill(
      img.Image(width: width, height: height),
      color: img.ColorRgb8(0, 0, 0),
    );
    final source = png(black(1200, 800));
    final mask = png(_buildIrregularMask(width: 1200, height: 800));

    final focusModes = <String, ({Rect? selection, Rect? crop})>{
      'mask bounds': (selection: null, crop: null),
      'explicit selection': (
        selection: const Rect.fromLTWH(120, 160, 240, 280),
        crop: null,
      ),
      'context crop': (
        selection: null,
        crop: const Rect.fromLTWH(300, 100, 640, 512),
      ),
    };
    for (final MapEntry(key: name, value: focus) in focusModes.entries) {
      test(name, () {
        final request = FocusedInpaintUtils.prepareRequest(
          sourceImage: source,
          maskImage: mask,
          focusedSelectionRect: focus.selection,
          contextCrop: focus.crop,
          minContextMegaPixels: 88,
        )!;
        final geometry = FocusedInpaintUtils.resolveRequestGeometry(
          sourceImage: source,
          maskImage: mask,
          focusedSelectionRect: focus.selection,
          contextCrop: focus.crop,
          minContextMegaPixels: 88,
        )!;

        expect(
          (geometry.requestWidth, geometry.requestHeight),
          (request.targetWidth, request.targetHeight),
        );
        expect(
          (
            geometry.contextCrop.x,
            geometry.contextCrop.y,
            geometry.contextCrop.width,
            geometry.contextCrop.height,
          ),
          (
            request.crop.x,
            request.crop.y,
            request.crop.width,
            request.crop.height,
          ),
        );
      });
    }

    test('is null exactly when prepareRequest sends no focused request', () {
      final rejected = <String, ({Uint8List mask, Rect? crop})>{
        'empty mask': (mask: png(black(1200, 800)), crop: null),
        'mask size differs': (mask: png(black(600, 400)), crop: null),
        'crop without masked pixels': (
          mask: mask,
          crop: const Rect.fromLTWH(0, 0, 128, 128),
        ),
      };
      for (final MapEntry(key: name, value: input) in rejected.entries) {
        expect(
          FocusedInpaintUtils.prepareRequest(
            sourceImage: source,
            maskImage: input.mask,
            contextCrop: input.crop,
            minContextMegaPixels: 88,
          ),
          isNull,
          reason: name,
        );
        expect(
          FocusedInpaintUtils.resolveRequestGeometry(
            sourceImage: source,
            maskImage: input.mask,
            contextCrop: input.crop,
            minContextMegaPixels: 88,
          ),
          isNull,
          reason: name,
        );
      }
    });
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
