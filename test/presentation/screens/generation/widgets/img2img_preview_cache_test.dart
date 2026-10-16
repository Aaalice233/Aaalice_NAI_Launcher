import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/focused_inpaint_utils.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/img2img_preview_cache.dart';

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
    late _PendingOverlays pending;
    late int updates;
    late Img2ImgPreviewCache cache;

    setUp(() {
      pending = _PendingOverlays();
      updates = 0;
      cache = Img2ImgPreviewCache(
        onUpdated: () => updates += 1,
        maskOverlayBuilder: pending.overlay,
      );
    });

    tearDown(() => cache.dispose());

    Img2ImgPreviewDerivedData resolve(
      Uint8List source,
      Uint8List? mask, {
      AsyncValue<FocusedInpaintMaskExtent?> extent = const AsyncData(null),
      Rect? selection,
      Rect? crop,
      double minContext = 88,
    }) => cache.resolve(
      sourceImage: source,
      maskImage: mask,
      maskExtent: extent,
      focusedInpaintEnabled: true,
      focusedSelectionRect: selection,
      focusedContextCrop: crop,
      minContextMegaPixels: minContext,
      sourceWidth: 1024,
      sourceHeight: 1024,
    );

    test('derives each mask overlay once in the background', () async {
      final source = Uint8List.fromList([1, 2, 3]);
      final mask = Uint8List.fromList([4, 5, 6]);

      final first = resolve(source, mask);
      resolve(source, mask);
      expect(first.maskOverlayBytes, isNull);
      expect(pending.calls, 1);

      final overlay = Uint8List.fromList([9]);
      pending.complete(mask, overlay);
      await pumpEventQueue();
      expect(updates, 1);

      expect(
        identical(resolve(source, mask).maskOverlayBytes, overlay),
        isTrue,
      );
      expect(pending.calls, 1);
    });

    test('frames the mask from the shared extent', () {
      final source = Uint8List.fromList([1]);
      final mask = Uint8List.fromList([4]);
      final extent = AsyncData(
        _extentOf(const Rect.fromLTWH(100, 100, 40, 40)),
      );

      final small = resolve(source, mask, extent: extent, minContext: 16);
      final again = resolve(source, mask, extent: extent, minContext: 16);
      final large = resolve(source, mask, extent: extent, minContext: 192);

      expect(identical(again.focusedFrame, small.focusedFrame), isTrue);
      expect(
        large.focusedFrame!.contextCrop.rect,
        FocusedInpaintUtils.resolveGeometryForMaskExtent(
          extent.value,
          minContextMegaPixels: 192,
        )!.contextCrop.rect,
      );
      expect(
        large.focusedFrame!.contextCrop.rect,
        isNot(small.focusedFrame!.contextCrop.rect),
      );
      expect(
        resolve(
          source,
          mask,
          extent: AsyncError<FocusedInpaintMaskExtent?>(
            StateError('decode failed'),
            StackTrace.empty,
          ),
        ).focusedFrame,
        isNull,
      );
    });

    test('keeps the previous results on the same source', () async {
      final source = Uint8List.fromList([1, 2, 3]);
      final firstMask = Uint8List.fromList([4]);
      final secondMask = Uint8List.fromList([5]);
      final firstExtent = AsyncData(_extentOf(const Rect.fromLTWH(0, 0, 8, 8)));
      resolve(source, firstMask, extent: firstExtent);
      pending.complete(firstMask, Uint8List.fromList([7]));
      await pumpEventQueue();
      final first = resolve(source, firstMask, extent: firstExtent);

      final decoding = resolve(
        source,
        secondMask,
        extent: _reloading(firstExtent),
      );
      expect(
        identical(decoding.maskOverlayBytes, first.maskOverlayBytes),
        isTrue,
      );
      expect(identical(decoding.focusedFrame, first.focusedFrame), isTrue);

      pending.complete(secondMask, Uint8List.fromList([8]));
      await pumpEventQueue();
      final second = resolve(
        source,
        secondMask,
        extent: AsyncData(_extentOf(const Rect.fromLTWH(300, 300, 400, 400))),
      );
      expect(second.maskOverlayBytes, [8]);
      expect(second.focusedFrame!.focusBounds.x, 300);
    });

    test('a cleared mask does not resurface under the next mask', () async {
      final source = Uint8List.fromList([1]);
      final clearedMask = Uint8List.fromList([4]);
      resolve(source, clearedMask);
      pending.complete(clearedMask, Uint8List.fromList([7]));
      await pumpEventQueue();
      expect(resolve(source, clearedMask).maskOverlayBytes, [7]);

      expect(resolve(source, null).maskOverlayBytes, isNull);
      final redrawn = resolve(source, Uint8List.fromList([5]));

      expect(redrawn.maskOverlayBytes, isNull);
    });

    test('drops stale results when the source changes', () async {
      final firstMask = Uint8List.fromList([4]);
      final firstExtent = AsyncData(_extentOf(const Rect.fromLTWH(0, 0, 8, 8)));
      resolve(Uint8List.fromList([1]), firstMask, extent: firstExtent);
      pending.complete(firstMask, Uint8List.fromList([7]));
      await pumpEventQueue();

      final replaced = Uint8List.fromList([2]);
      final secondMask = Uint8List.fromList([5]);
      final reloading = _reloading(firstExtent);
      final first = resolve(replaced, secondMask, extent: reloading);
      final second = resolve(replaced, secondMask, extent: reloading);

      for (final data in [first, second]) {
        expect(data.maskOverlayBytes, isNull);
        expect(data.focusedFrame, isNull);
      }
    });

    test('ignores overlays of superseded masks and after dispose', () async {
      final source = Uint8List.fromList([1]);
      final firstMask = Uint8List.fromList([4]);
      final secondMask = Uint8List.fromList([5]);
      resolve(source, firstMask);
      resolve(source, secondMask);

      pending.complete(firstMask, Uint8List.fromList([7]));
      await pumpEventQueue();
      expect(updates, 0);
      expect(resolve(source, secondMask).maskOverlayBytes, isNull);

      cache.dispose();
      pending.complete(secondMask, Uint8List.fromList([8]));
      await pumpEventQueue();
      expect(updates, 0);
    });

    test('selection and crop frames take precedence over the mask', () {
      final source = Uint8List.fromList([1, 2, 3]);
      final mask = Uint8List.fromList([4, 5, 6]);
      final extent = AsyncData(_extentOf(const Rect.fromLTWH(0, 0, 8, 8)));

      final selected = resolve(
        source,
        mask,
        extent: extent,
        selection: const Rect.fromLTWH(10, 20, 30, 40),
      );
      final framed = resolve(
        source,
        mask,
        extent: extent,
        crop: const Rect.fromLTWH(384, 0, 640, 1024),
      );
      final framedAgain = resolve(
        source,
        mask,
        extent: extent,
        crop: const Rect.fromLTWH(384, 0, 640, 1024),
      );
      final moved = resolve(
        source,
        mask,
        extent: extent,
        crop: const Rect.fromLTWH(320, 0, 640, 1024),
      );

      expect(
        selected.focusedFrame!.focusBounds.rect,
        FocusedInpaintUtils.resolveGeometryForSelection(
          sourceWidth: 1024,
          sourceHeight: 1024,
          selectionRect: const Rect.fromLTWH(10, 20, 30, 40),
          minContextMegaPixels: 88,
        )!.focusBounds.rect,
      );
      expect(
        framed.focusedFrame!.contextCrop.rect,
        const Rect.fromLTWH(384, 0, 640, 1024),
      );
      expect(identical(framedAgain.focusedFrame, framed.focusedFrame), isTrue);
      expect(moved.focusedFrame!.contextCrop.x, 320);
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

/// provider 换蒙版重算时的状态：仍在加载，但带着上一张蒙版的结果。
AsyncValue<FocusedInpaintMaskExtent?> _reloading(
  AsyncData<FocusedInpaintMaskExtent?> previous,
) => const AsyncLoading<FocusedInpaintMaskExtent?>().copyWithPrevious(
  previous,
  isRefresh: false,
);

/// 按蒙版引用挂起的叠加图计算，由测试决定何时完成。
class _PendingOverlays {
  final _overlays = <Uint8List, Completer<Uint8List>>{};
  var calls = 0;

  Future<Uint8List> overlay(Uint8List mask) {
    calls += 1;
    return (_overlays[mask] = Completer<Uint8List>()).future;
  }

  void complete(Uint8List mask, Uint8List overlay) =>
      _overlays[mask]!.complete(overlay);
}
