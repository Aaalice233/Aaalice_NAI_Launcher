import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/focused_inpaint_utils.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/img2img_preview_cache.dart';

void main() {
  group('resolveSourcePreviewDimensions', () {
    test(
      'prefers encoded source dimensions over request bucket dimensions',
      () {
        final sourceBytes = Uint8List.fromList(
          img.encodePng(img.Image(width: 1500, height: 900)),
        );

        final dimensions = resolveSourcePreviewDimensions(
          sourceBytes: sourceBytes,
          fallbackWidth: 1472,
          fallbackHeight: 896,
        );

        expect(dimensions.$1, equals(1500));
        expect(dimensions.$2, equals(900));
      },
    );

    test('uses fallback request dimensions when source decode fails', () {
      final dimensions = resolveSourcePreviewDimensions(
        sourceBytes: Uint8List.fromList([1, 2, 3]),
        fallbackWidth: 1472,
        fallbackHeight: 896,
      );

      expect(dimensions.$1, equals(1472));
      expect(dimensions.$2, equals(896));
    });
  });

  group('Img2ImgPreviewCache', () {
    test('should reuse heavy preview results when inputs stay unchanged', () {
      var maskOverlayCalls = 0;
      var focusedFrameCalls = 0;
      final cache = Img2ImgPreviewCache(
        maskOverlayBuilder: (maskImage) {
          maskOverlayCalls += 1;
          return Uint8List.fromList([maskOverlayCalls]);
        },
        focusedFrameResolver:
            ({
              required Uint8List sourceImage,
              Uint8List? maskImage,
              Rect? focusedSelectionRect,
              required double minContextMegaPixels,
            }) {
              focusedFrameCalls += 1;
              return const FocusedInpaintFrame(
                focusBounds: FocusedInpaintCrop(
                  x: 1,
                  y: 2,
                  width: 3,
                  height: 4,
                ),
                contextCrop: FocusedInpaintCrop(
                  x: 5,
                  y: 6,
                  width: 7,
                  height: 8,
                ),
              );
            },
      );
      final sourceImage = Uint8List.fromList([1, 2, 3]);
      final maskImage = Uint8List.fromList([4, 5, 6]);
      const focusedSelectionRect = Rect.fromLTWH(10, 20, 30, 40);

      final first = cache.resolve(
        sourceImage: sourceImage,
        maskImage: maskImage,
        focusedInpaintEnabled: true,
        focusedSelectionRect: focusedSelectionRect,
        minContextMegaPixels: 88,
      );
      final second = cache.resolve(
        sourceImage: sourceImage,
        maskImage: maskImage,
        focusedInpaintEnabled: true,
        focusedSelectionRect: focusedSelectionRect,
        minContextMegaPixels: 88,
      );

      expect(maskOverlayCalls, equals(1));
      expect(focusedFrameCalls, equals(1));
      expect(
        identical(second.maskOverlayBytes, first.maskOverlayBytes),
        isTrue,
      );
      expect(identical(second.focusedFrame, first.focusedFrame), isTrue);
    });

    test(
      'should prefer lightweight selection frame resolver when dimensions are known',
      () {
        var heavyFrameCalls = 0;
        var selectionFrameCalls = 0;
        final cache = Img2ImgPreviewCache(
          focusedFrameResolver:
              ({
                required Uint8List sourceImage,
                Uint8List? maskImage,
                Rect? focusedSelectionRect,
                required double minContextMegaPixels,
              }) {
                heavyFrameCalls += 1;
                return null;
              },
          selectionPreviewFrameResolver:
              ({
                required int sourceWidth,
                required int sourceHeight,
                required Rect selectionRect,
                required double minContextMegaPixels,
              }) {
                selectionFrameCalls += 1;
                return const FocusedInpaintFrame(
                  focusBounds: FocusedInpaintCrop(
                    x: 10,
                    y: 20,
                    width: 30,
                    height: 40,
                  ),
                  contextCrop: FocusedInpaintCrop(
                    x: 5,
                    y: 15,
                    width: 50,
                    height: 60,
                  ),
                );
              },
          maskOverlayBuilder: (maskImage) => maskImage,
        );

        final result = cache.resolve(
          sourceImage: Uint8List.fromList([1, 2, 3]),
          maskImage: Uint8List.fromList([4, 5, 6]),
          focusedInpaintEnabled: true,
          focusedSelectionRect: const Rect.fromLTWH(10, 20, 30, 40),
          minContextMegaPixels: 88,
          sourceWidth: 1536,
          sourceHeight: 2304,
        );

        expect(selectionFrameCalls, equals(1));
        expect(heavyFrameCalls, equals(0));
        expect(result.focusedFrame, isNotNull);
      },
    );

    test(
      'should only recompute focused frame when focused inputs actually change',
      () {
        var focusedFrameCalls = 0;
        final cache = Img2ImgPreviewCache(
          maskOverlayBuilder: (maskImage) => maskImage,
          focusedFrameResolver:
              ({
                required Uint8List sourceImage,
                Uint8List? maskImage,
                Rect? focusedSelectionRect,
                required double minContextMegaPixels,
              }) {
                focusedFrameCalls += 1;
                return null;
              },
        );
        final sourceImage = Uint8List.fromList([1, 2, 3]);
        final maskImage = Uint8List.fromList([4, 5, 6]);

        cache.resolve(
          sourceImage: sourceImage,
          maskImage: maskImage,
          focusedInpaintEnabled: false,
          focusedSelectionRect: null,
          minContextMegaPixels: 88,
        );
        cache.resolve(
          sourceImage: sourceImage,
          maskImage: maskImage,
          focusedInpaintEnabled: true,
          focusedSelectionRect: const Rect.fromLTWH(10, 20, 30, 40),
          minContextMegaPixels: 88,
        );
        cache.resolve(
          sourceImage: sourceImage,
          maskImage: maskImage,
          focusedInpaintEnabled: true,
          focusedSelectionRect: const Rect.fromLTWH(10, 20, 30, 40),
          minContextMegaPixels: 120,
        );

        expect(focusedFrameCalls, equals(2));
      },
    );
  });
}
