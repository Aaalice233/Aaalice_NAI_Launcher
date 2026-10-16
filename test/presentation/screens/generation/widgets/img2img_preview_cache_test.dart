import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/focused_inpaint_utils.dart';
import 'package:nai_launcher/core/utils/inpaint_mask_utils.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/img2img_preview_cache.dart';

import '../../../../helpers/shared_compute_gate.dart';

void main() {
  group('resolveSourcePreviewDimensions', () {
    test('uses known source dimensions without reading image bytes', () {
      var imageSizeReadCount = 0;

      final dimensions = resolveSourcePreviewDimensions(
        sourceBytes: Uint8List.fromList([1, 2, 3]),
        sourceWidth: 8000,
        sourceHeight: 6000,
        fallbackWidth: 1216,
        fallbackHeight: 896,
        imageSizeReader: (_) {
          imageSizeReadCount += 1;
          return (1, 1);
        },
      );

      expect(dimensions, equals((8000, 6000)));
      expect(imageSizeReadCount, isZero);
    });

    test(
      'reads encoded source dimensions instead of request bucket dimensions',
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

    test(
      'uses fallback request dimensions when encoded size is unreadable',
      () {
        final dimensions = resolveSourcePreviewDimensions(
          sourceBytes: Uint8List.fromList([1, 2, 3]),
          fallbackWidth: 1472,
          fallbackHeight: 896,
        );

        expect(dimensions.$1, equals(1472));
        expect(dimensions.$2, equals(896));
      },
    );
  });

  group('Img2ImgPreviewCache', () {
    late _PendingDerivations pending;
    late int updates;
    late Img2ImgPreviewCache cache;

    setUp(() {
      pending = _PendingDerivations();
      updates = 0;
      cache = Img2ImgPreviewCache(
        onUpdated: () => updates += 1,
        maskOverlayBuilder: pending.overlay,
        maskExtentResolver: pending.extent,
      );
    });

    tearDown(() => cache.dispose());

    Img2ImgPreviewDerivedData resolve(
      Uint8List source,
      Uint8List? mask, {
      Rect? selection,
      Rect? crop,
      double minContext = 88,
    }) => cache.resolve(
      sourceImage: source,
      maskImage: mask,
      focusedInpaintEnabled: true,
      focusedSelectionRect: selection,
      focusedContextCrop: crop,
      minContextMegaPixels: minContext,
      sourceWidth: 1024,
      sourceHeight: 1024,
    );

    test('derives each mask once in the background', () async {
      final source = Uint8List.fromList([1, 2, 3]);
      final mask = Uint8List.fromList([4, 5, 6]);

      final first = resolve(source, mask);
      resolve(source, mask);
      expect(first.maskOverlayBytes, isNull);
      expect(first.focusedFrame, isNull);
      expect(pending.overlayCalls, 1);
      expect(pending.extentCalls, 1);

      final overlay = Uint8List.fromList([9]);
      pending.completeOverlay(mask, overlay);
      pending.completeExtent(mask, _extentOf(const Rect.fromLTWH(1, 2, 3, 4)));
      await pumpEventQueue();
      expect(updates, 2);

      final ready = resolve(source, mask);
      final again = resolve(source, mask);
      expect(identical(ready.maskOverlayBytes, overlay), isTrue);
      expect(
        ready.focusedFrame!.contextCrop.rect,
        FocusedInpaintUtils.resolveGeometryForMaskExtent(
          _extentOf(const Rect.fromLTWH(1, 2, 3, 4)),
          minContextMegaPixels: 88,
        )!.contextCrop.rect,
      );
      expect(identical(again.focusedFrame, ready.focusedFrame), isTrue);
      expect(pending.overlayCalls, 1);
      expect(pending.extentCalls, 1);
    });

    test('keeps the previous results on the same source', () async {
      final source = Uint8List.fromList([1, 2, 3]);
      final firstMask = Uint8List.fromList([4]);
      final secondMask = Uint8List.fromList([5]);
      resolve(source, firstMask);
      pending.completeOverlay(firstMask, Uint8List.fromList([7]));
      pending.completeExtent(
        firstMask,
        _extentOf(const Rect.fromLTWH(0, 0, 8, 8)),
      );
      await pumpEventQueue();
      final first = resolve(source, firstMask);

      final decoding = resolve(source, secondMask);
      expect(
        identical(decoding.maskOverlayBytes, first.maskOverlayBytes),
        isTrue,
      );
      expect(identical(decoding.focusedFrame, first.focusedFrame), isTrue);

      pending.completeOverlay(secondMask, Uint8List.fromList([8]));
      pending.completeExtent(
        secondMask,
        _extentOf(const Rect.fromLTWH(300, 300, 400, 400)),
      );
      await pumpEventQueue();
      final second = resolve(source, secondMask);
      expect(second.maskOverlayBytes, [8]);
      expect(second.focusedFrame!.focusBounds.x, 300);
    });

    test('a cleared mask does not resurface under the next mask', () async {
      final source = Uint8List.fromList([1]);
      final clearedMask = Uint8List.fromList([4]);
      resolve(source, clearedMask);
      pending.completeOverlay(clearedMask, Uint8List.fromList([7]));
      await pumpEventQueue();
      expect(resolve(source, clearedMask).maskOverlayBytes, [7]);

      expect(resolve(source, null).maskOverlayBytes, isNull);
      final redrawn = resolve(source, Uint8List.fromList([5]));

      expect(redrawn.maskOverlayBytes, isNull);
    });

    test('drops stale results when the source changes', () async {
      final firstMask = Uint8List.fromList([4]);
      resolve(Uint8List.fromList([1]), firstMask);
      pending.completeOverlay(firstMask, Uint8List.fromList([7]));
      pending.completeExtent(
        firstMask,
        _extentOf(const Rect.fromLTWH(0, 0, 8, 8)),
      );
      await pumpEventQueue();

      final replaced = Uint8List.fromList([2]);
      final secondMask = Uint8List.fromList([5]);
      final first = resolve(replaced, secondMask);
      final second = resolve(replaced, secondMask);

      for (final data in [first, second]) {
        expect(data.maskOverlayBytes, isNull);
        expect(data.focusedFrame, isNull);
      }
    });

    test('context size changes reuse the mask extent', () async {
      final source = Uint8List.fromList([1]);
      final mask = Uint8List.fromList([4]);
      final extent = _extentOf(const Rect.fromLTWH(100, 100, 40, 40));
      resolve(source, mask);
      pending.completeOverlay(mask, Uint8List.fromList([7]));
      pending.completeExtent(mask, extent);
      await pumpEventQueue();
      final small = resolve(source, mask, minContext: 16);

      final large = resolve(source, mask, minContext: 192);

      expect(pending.extentCalls, 1);
      expect(
        large.focusedFrame!.contextCrop.rect,
        FocusedInpaintUtils.resolveGeometryForMaskExtent(
          extent,
          minContextMegaPixels: 192,
        )!.contextCrop.rect,
      );
      expect(
        large.focusedFrame!.contextCrop.rect,
        isNot(small.focusedFrame!.contextCrop.rect),
      );
    });

    test('ignores results of superseded masks and after dispose', () async {
      final source = Uint8List.fromList([1]);
      final firstMask = Uint8List.fromList([4]);
      final secondMask = Uint8List.fromList([5]);
      resolve(source, firstMask);
      resolve(source, secondMask);

      pending.completeOverlay(firstMask, Uint8List.fromList([7]));
      pending.completeExtent(
        firstMask,
        _extentOf(const Rect.fromLTWH(0, 0, 8, 8)),
      );
      await pumpEventQueue();
      expect(updates, 0);
      expect(resolve(source, secondMask).maskOverlayBytes, isNull);

      cache.dispose();
      pending.completeOverlay(secondMask, Uint8List.fromList([8]));
      await pumpEventQueue();
      expect(updates, 0);
    });

    test('selection and crop frames stay synchronous', () {
      var selectionCalls = 0;
      var cropCalls = 0;
      final synchronous = Img2ImgPreviewCache(
        onUpdated: () {},
        maskOverlayBuilder: pending.overlay,
        maskExtentResolver: pending.extent,
        selectionPreviewFrameResolver:
            ({
              required int sourceWidth,
              required int sourceHeight,
              required Rect selectionRect,
              required double minContextMegaPixels,
            }) {
              selectionCalls += 1;
              return FocusedInpaintUtils.resolvePreviewFrameForSelection(
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight,
                selectionRect: selectionRect,
                minContextMegaPixels: minContextMegaPixels,
              );
            },
        cropPreviewFrameResolver:
            ({
              required int sourceWidth,
              required int sourceHeight,
              required Rect crop,
            }) {
              cropCalls += 1;
              return FocusedInpaintUtils.resolveGeometryForCrop(
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight,
                crop: crop,
              );
            },
      );
      addTearDown(synchronous.dispose);
      final source = Uint8List.fromList([1, 2, 3]);
      final mask = Uint8List.fromList([4, 5, 6]);
      Img2ImgPreviewDerivedData resolveWith({Rect? selection, Rect? crop}) =>
          synchronous.resolve(
            sourceImage: source,
            maskImage: mask,
            focusedInpaintEnabled: true,
            focusedSelectionRect: selection,
            focusedContextCrop: crop,
            minContextMegaPixels: 88,
            sourceWidth: 1216,
            sourceHeight: 1216,
          );

      final selected = resolveWith(
        selection: const Rect.fromLTWH(10, 20, 30, 40),
      );
      final framed = resolveWith(crop: const Rect.fromLTWH(384, 0, 832, 1216));
      final framedAgain = resolveWith(
        crop: const Rect.fromLTWH(384, 0, 832, 1216),
      );
      final moved = resolveWith(crop: const Rect.fromLTWH(320, 0, 832, 1216));

      expect(selected.focusedFrame, isNotNull);
      expect(
        framed.focusedFrame!.contextCrop.rect,
        const Rect.fromLTWH(384, 0, 832, 1216),
      );
      expect(identical(framedAgain.focusedFrame, framed.focusedFrame), isTrue);
      expect(moved.focusedFrame!.contextCrop.x, 320);
      expect(selectionCalls, 1);
      expect(cropCalls, 2);
      expect(pending.extentCalls, 0);
    });

    test('default derivations wait for the shared compute gate', () async {
      final source = _encodedImage(width: 640, height: 480);
      final maskImage = img.Image(width: 640, height: 480);
      img.fill(maskImage, color: img.ColorRgba8(0, 0, 0, 255));
      img.fillRect(
        maskImage,
        x1: 200,
        y1: 150,
        x2: 260,
        y2: 210,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
      final mask = Uint8List.fromList(img.encodePng(maskImage));
      final ready = StreamController<void>();
      var completed = 0;
      final defaults = Img2ImgPreviewCache(
        onUpdated: () {
          completed += 1;
          ready.add(null);
        },
      );
      addTearDown(defaults.dispose);
      Img2ImgPreviewDerivedData resolveDefaults() => defaults.resolve(
        sourceImage: source,
        maskImage: mask,
        focusedInpaintEnabled: true,
        minContextMegaPixels: 88,
        sourceWidth: 640,
        sourceHeight: 480,
      );

      final release = holdSharedComputeGate();
      try {
        resolveDefaults();
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(completed, 0, reason: 'mask decoding skipped ComputeGate');
      } finally {
        await release();
      }
      await ready.stream.take(2).drain<void>();
      final data = resolveDefaults();

      expect(data.maskOverlayBytes, InpaintMaskUtils.maskToEditorOverlay(mask));
      final request = FocusedInpaintUtils.prepareRequest(
        sourceImage: source,
        maskImage: mask,
        minContextMegaPixels: 88,
      )!;
      expect(data.focusedFrame!.contextCrop.rect, request.crop.rect);
      expect(
        data.focusedFrame!.focusBounds.rect,
        request.geometry.focusBounds.rect,
      );
    });
  });
}

FocusedInpaintMaskExtent _extentOf(Rect bounds) => FocusedInpaintMaskExtent(
  maskWidth: 1024,
  maskHeight: 1024,
  bounds: FocusedInpaintCrop(
    x: bounds.left.toInt(),
    y: bounds.top.toInt(),
    width: bounds.width.toInt(),
    height: bounds.height.toInt(),
  ),
);

Uint8List _encodedImage({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(40, 80, 120));
  return Uint8List.fromList(img.encodePng(image));
}

/// 按蒙版引用挂起的后台派生，由测试决定何时完成。
class _PendingDerivations {
  final _overlays = <Uint8List, Completer<Uint8List>>{};
  final _extents = <Uint8List, Completer<FocusedInpaintMaskExtent?>>{};
  var overlayCalls = 0;
  var extentCalls = 0;

  Future<Uint8List> overlay(Uint8List mask) {
    overlayCalls += 1;
    return (_overlays[mask] = Completer<Uint8List>()).future;
  }

  Future<FocusedInpaintMaskExtent?> extent(Uint8List mask) {
    extentCalls += 1;
    return (_extents[mask] = Completer<FocusedInpaintMaskExtent?>()).future;
  }

  void completeOverlay(Uint8List mask, Uint8List overlay) =>
      _overlays[mask]!.complete(overlay);

  void completeExtent(Uint8List mask, FocusedInpaintMaskExtent? extent) =>
      _extents[mask]!.complete(extent);
}
