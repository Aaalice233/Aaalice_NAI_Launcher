import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/inpaint_outpaint_utils.dart';

void main() {
  group('InpaintOutpaintUtils.resolveExpansionGeometry', () {
    test(
      'resolves requested, snapped, applied, and source offset geometry',
      () {
        final geometry = InpaintOutpaintUtils.resolveExpansionGeometry(
          sourceWidth: 1024,
          sourceHeight: 1216,
          edges: const OutpaintEdges(
            left: 200,
            top: 200,
            right: 200,
            bottom: 200,
          ),
          horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
          verticalSnapTarget: OutpaintVerticalSnapTarget.top,
        );

        expect(geometry.sourceWidth, equals(1024));
        expect(geometry.sourceHeight, equals(1216));
        expect(geometry.requestedWidth, equals(1424));
        expect(geometry.requestedHeight, equals(1616));
        expect(geometry.width, equals(1472));
        expect(geometry.height, equals(1664));
        expect(geometry.sourceOffsetX, equals(248));
        expect(geometry.sourceOffsetY, equals(248));
        expect(geometry.requestedEdges.left, equals(200));
        expect(geometry.requestedEdges.top, equals(200));
        expect(geometry.requestedEdges.right, equals(200));
        expect(geometry.requestedEdges.bottom, equals(200));
        expect(geometry.appliedEdges.left, equals(248));
        expect(geometry.appliedEdges.top, equals(248));
        expect(geometry.appliedEdges.right, equals(200));
        expect(geometry.appliedEdges.bottom, equals(200));
      },
    );

    test('preserves requested geometry when snapping is disabled', () {
      final geometry = InpaintOutpaintUtils.resolveExpansionGeometry(
        sourceWidth: 128,
        sourceHeight: 96,
        edges: const OutpaintEdges(left: 17, top: 23, right: 31, bottom: 41),
        snapTo64: false,
      );

      expect(geometry.requestedWidth, equals(176));
      expect(geometry.requestedHeight, equals(160));
      expect(geometry.width, equals(176));
      expect(geometry.height, equals(160));
      expect(geometry.sourceOffsetX, equals(17));
      expect(geometry.sourceOffsetY, equals(23));
      expect(geometry.appliedEdges.left, equals(17));
      expect(geometry.appliedEdges.top, equals(23));
      expect(geometry.appliedEdges.right, equals(31));
      expect(geometry.appliedEdges.bottom, equals(41));
    });

    test('rejects negative outpaint edges with expand-compatible message', () {
      expect(
        () => InpaintOutpaintUtils.resolveExpansionGeometry(
          sourceWidth: 128,
          sourceHeight: 96,
          edges: const OutpaintEdges(top: -1),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Outpaint edges must be non-negative',
          ),
        ),
      );
    });

    test('rejects snapped dimensions above the 4096 limit', () {
      expect(
        () => InpaintOutpaintUtils.resolveExpansionGeometry(
          sourceWidth: 4096,
          sourceHeight: 4096,
          edges: const OutpaintEdges(right: 1),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Expanded image dimensions exceed 4096',
          ),
        ),
      );
    });

    test('matches expand result metadata', () {
      final sourceImage = _sourcePng(128, 96);
      const edges = OutpaintEdges(left: 24, top: 10, right: 13, bottom: 9);
      final geometry = InpaintOutpaintUtils.resolveExpansionGeometry(
        sourceWidth: 128,
        sourceHeight: 96,
        edges: edges,
        horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
        verticalSnapTarget: OutpaintVerticalSnapTarget.top,
      );

      final result = InpaintOutpaintUtils.expand(
        sourceImage: sourceImage,
        edges: edges,
        horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
        verticalSnapTarget: OutpaintVerticalSnapTarget.top,
      );

      expect(result.width, geometry.width);
      expect(result.height, geometry.height);
      expect(result.sourceOffsetX, geometry.sourceOffsetX);
      expect(result.sourceOffsetY, geometry.sourceOffsetY);
      expect(result.requestedEdges.left, geometry.requestedEdges.left);
      expect(result.requestedEdges.top, geometry.requestedEdges.top);
      expect(result.requestedEdges.right, geometry.requestedEdges.right);
      expect(result.requestedEdges.bottom, geometry.requestedEdges.bottom);
      expect(result.appliedEdges.left, geometry.appliedEdges.left);
      expect(result.appliedEdges.top, geometry.appliedEdges.top);
      expect(result.appliedEdges.right, geometry.appliedEdges.right);
      expect(result.appliedEdges.bottom, geometry.appliedEdges.bottom);
    });
  });

  group('InpaintOutpaintUtils.expand', () {
    test('expands source without snapping and masks only outpaint edges', () {
      final sourceImage = _sourcePng(4, 4);

      final result = InpaintOutpaintUtils.expand(
        sourceImage: sourceImage,
        edges: const OutpaintEdges(left: 2, top: 1, right: 3, bottom: 2),
        snapTo64: false,
      );

      expect(result.width, equals(9));
      expect(result.height, equals(7));
      expect(result.sourceOffsetX, equals(2));
      expect(result.sourceOffsetY, equals(1));
      expect(result.appliedEdges.left, equals(2));
      expect(result.appliedEdges.top, equals(1));
      expect(result.appliedEdges.right, equals(3));
      expect(result.appliedEdges.bottom, equals(2));

      final expandedSource = img.decodeImage(result.sourceImage)!;
      final shiftedSourcePixel = expandedSource.getPixel(2, 1);
      expect(shiftedSourcePixel.r.toInt(), equals(24));
      expect(shiftedSourcePixel.g.toInt(), equals(48));
      expect(shiftedSourcePixel.b.toInt(), equals(72));
      expect(shiftedSourcePixel.a.toInt(), equals(255));
      expect(expandedSource.getPixel(0, 0).a.toInt(), equals(0));

      final expandedMask = img.decodeImage(result.maskImage)!;
      expect(expandedMask.getPixel(0, 0).r.toInt(), equals(255));
      expect(expandedMask.getPixel(2, 1).r.toInt(), equals(0));
      expect(expandedMask.getPixel(5, 4).r.toInt(), equals(0));
      expect(expandedMask.getPixel(6, 1).r.toInt(), equals(255));
      expect(expandedMask.getPixel(2, 5).r.toInt(), equals(255));
    });

    test('normalizes expanded source to 8-bit RGBA before copying pixels', () {
      final source = img.Image(
        width: 1,
        height: 1,
        format: img.Format.uint16,
        numChannels: 4,
      );
      source.setPixelRgba(0, 0, 0xffff, 0x8000, 0x4000, 0x8000);

      final result = InpaintOutpaintUtils.expand(
        sourceImage: Uint8List.fromList(img.encodePng(source)),
        edges: const OutpaintEdges(left: 1, top: 1),
        snapTo64: false,
      );

      final expandedSource = img.decodeImage(result.sourceImage)!;
      final shiftedPixel = expandedSource.getPixel(1, 1);
      expect(shiftedPixel.r.toInt(), equals(255));
      expect(shiftedPixel.g.toInt(), equals(128));
      expect(shiftedPixel.b.toInt(), equals(64));
      expect(shiftedPixel.a.toInt(), equals(128));
      expect(expandedSource.getPixel(0, 0).a.toInt(), equals(0));
    });

    test(
      'shifts existing normalized mask pixels into expanded coordinates',
      () {
        final sourceImage = _sourcePng(4, 4);
        final existingMask = img.Image(width: 4, height: 4);
        img.fill(existingMask, color: img.ColorRgba8(0, 0, 0, 255));
        existingMask.setPixelRgba(1, 2, 255, 255, 255, 255);

        final result = InpaintOutpaintUtils.expand(
          sourceImage: sourceImage,
          existingMask: Uint8List.fromList(img.encodePng(existingMask)),
          edges: const OutpaintEdges(left: 2, top: 1),
          snapTo64: false,
        );

        final expandedMask = img.decodeImage(result.maskImage)!;
        expect(expandedMask.getPixel(3, 3).r.toInt(), equals(255));
        expect(expandedMask.getPixel(2, 1).r.toInt(), equals(0));
      },
    );

    test('snaps expanded dimensions to 64 multiples on right and bottom', () {
      final sourceImage = _sourcePng(1024, 1216);

      final result = InpaintOutpaintUtils.expand(
        sourceImage: sourceImage,
        edges: const OutpaintEdges(
          left: 200,
          top: 200,
          right: 200,
          bottom: 200,
        ),
      );

      expect(result.width, equals(1472));
      expect(result.height, equals(1664));
      expect(result.appliedEdges.left, equals(200));
      expect(result.appliedEdges.top, equals(200));
      expect(result.appliedEdges.right, equals(248));
      expect(result.appliedEdges.bottom, equals(248));
      expect(result.sourceOffsetX, equals(200));
      expect(result.sourceOffsetY, equals(200));
    });

    test('snaps remainders to left and top when requested', () {
      final sourceImage = _sourcePng(1024, 1216);

      final result = InpaintOutpaintUtils.expand(
        sourceImage: sourceImage,
        edges: const OutpaintEdges(
          left: 200,
          top: 200,
          right: 200,
          bottom: 200,
        ),
        horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
        verticalSnapTarget: OutpaintVerticalSnapTarget.top,
      );

      expect(result.width, equals(1472));
      expect(result.height, equals(1664));
      expect(result.appliedEdges.left, equals(248));
      expect(result.appliedEdges.top, equals(248));
      expect(result.appliedEdges.right, equals(200));
      expect(result.appliedEdges.bottom, equals(200));
      expect(result.sourceOffsetX, equals(248));
      expect(result.sourceOffsetY, equals(248));

      final expandedSource = img.decodeImage(result.sourceImage)!;
      final shiftedSourcePixel = expandedSource.getPixel(248, 248);
      expect(shiftedSourcePixel.r.toInt(), equals(24));
      expect(shiftedSourcePixel.g.toInt(), equals(48));
      expect(shiftedSourcePixel.b.toInt(), equals(72));
      expect(shiftedSourcePixel.a.toInt(), equals(255));
      expect(expandedSource.getPixel(247, 248).a.toInt(), equals(0));
      expect(expandedSource.getPixel(248, 247).a.toInt(), equals(0));

      final expandedMask = img.decodeImage(result.maskImage)!;
      expect(expandedMask.getPixel(248, 248).r.toInt(), equals(0));
      expect(expandedMask.getPixel(1271, 1463).r.toInt(), equals(0));
      expect(expandedMask.getPixel(247, 248).r.toInt(), equals(255));
      expect(expandedMask.getPixel(248, 247).r.toInt(), equals(255));
      expect(expandedMask.getPixel(1272, 248).r.toInt(), equals(255));
      expect(expandedMask.getPixel(248, 1464).r.toInt(), equals(255));
    });

    test('async expansion matches sync expansion result', () async {
      final sourceImage = _sourcePng(128, 96);
      final existingMask = img.Image(width: 128, height: 96);
      img.fill(existingMask, color: img.ColorRgba8(0, 0, 0, 255));
      existingMask.setPixelRgba(4, 5, 255, 255, 255, 255);

      final syncResult = InpaintOutpaintUtils.expand(
        sourceImage: sourceImage,
        existingMask: Uint8List.fromList(img.encodePng(existingMask)),
        edges: const OutpaintEdges(left: 24, top: 10, right: 13, bottom: 9),
        horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
        verticalSnapTarget: OutpaintVerticalSnapTarget.top,
      );
      final asyncResult = await InpaintOutpaintUtils.expandAsync(
        sourceImage: sourceImage,
        existingMask: Uint8List.fromList(img.encodePng(existingMask)),
        edges: const OutpaintEdges(left: 24, top: 10, right: 13, bottom: 9),
        horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
        verticalSnapTarget: OutpaintVerticalSnapTarget.top,
      );

      expect(asyncResult.width, syncResult.width);
      expect(asyncResult.height, syncResult.height);
      expect(asyncResult.sourceOffsetX, syncResult.sourceOffsetX);
      expect(asyncResult.sourceOffsetY, syncResult.sourceOffsetY);
      expect(asyncResult.appliedEdges.left, syncResult.appliedEdges.left);
      expect(asyncResult.appliedEdges.top, syncResult.appliedEdges.top);
      expect(asyncResult.appliedEdges.right, syncResult.appliedEdges.right);
      expect(asyncResult.appliedEdges.bottom, syncResult.appliedEdges.bottom);
      expect(asyncResult.sourceImage, syncResult.sourceImage);
      expect(asyncResult.maskImage, syncResult.maskImage);
    });

    test('async expansion can include editor overlay bytes', () async {
      final sourceImage = _sourcePng(128, 96);

      final result = await InpaintOutpaintUtils.expandAsync(
        sourceImage: sourceImage,
        edges: const OutpaintEdges(left: 32),
        includeEditorOverlay: true,
      );

      expect(result.editorOverlayImage, isNotNull);
      final overlay = img.decodeImage(result.editorOverlayImage!)!;
      expect(overlay.width, result.width);
      expect(overlay.height, result.height);
      expect(overlay.getPixel(0, 0).a.toInt(), greaterThan(0));
      expect(
        overlay.getPixel(result.appliedEdges.left, 0).a.toInt(),
        equals(0),
      );
    });

    test('rejects negative outpaint edges', () {
      final sourceImage = _sourcePng(4, 4);

      expect(
        () => InpaintOutpaintUtils.expand(
          sourceImage: sourceImage,
          edges: const OutpaintEdges(left: -1),
          snapTo64: false,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Outpaint edges must be non-negative',
          ),
        ),
      );
    });

    test('rejects negative edges before decoding invalid source bytes', () {
      expect(
        () => InpaintOutpaintUtils.expand(
          sourceImage: Uint8List.fromList([1, 2, 3, 4]),
          edges: const OutpaintEdges(left: -1),
          snapTo64: false,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Outpaint edges must be non-negative',
          ),
        ),
      );
    });

    test('rejects existing mask with mismatched dimensions', () {
      final sourceImage = _sourcePng(4, 4);
      final existingMask = _sourcePng(5, 4);

      expect(
        () => InpaintOutpaintUtils.expand(
          sourceImage: sourceImage,
          existingMask: existingMask,
          edges: const OutpaintEdges(),
          snapTo64: false,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'Existing mask dimensions must match source image dimensions',
          ),
        ),
      );
    });

    test('rejects invalid existing mask before max dimension validation', () {
      final sourceImage = _sourcePng(4096, 1);

      expect(
        () => InpaintOutpaintUtils.expand(
          sourceImage: sourceImage,
          existingMask: Uint8List.fromList([1, 2, 3, 4]),
          edges: const OutpaintEdges(right: 1),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Unable to decode existing mask',
          ),
        ),
      );
    });

    test('rejects invalid source image bytes with decode message', () {
      final malformedPngHeader = Uint8List.fromList([
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
        0x00,
        0x00,
        0x00,
        0x0d,
        0x49,
        0x48,
        0x44,
        0x52,
      ]);

      for (final invalidBytes in [
        Uint8List.fromList([1, 2, 3, 4]),
        malformedPngHeader,
      ]) {
        expect(
          () => InpaintOutpaintUtils.expand(
            sourceImage: invalidBytes,
            edges: const OutpaintEdges(),
            snapTo64: false,
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'Unable to decode source image',
            ),
          ),
        );
      }
    });

    test('rejects invalid existing mask bytes with decode message', () {
      final sourceImage = _sourcePng(4, 4);
      final malformedPngHeader = Uint8List.fromList([
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
        0x00,
        0x00,
        0x00,
        0x0d,
        0x49,
        0x48,
        0x44,
        0x52,
      ]);

      for (final invalidMask in [
        Uint8List.fromList([1, 2, 3, 4]),
        malformedPngHeader,
      ]) {
        expect(
          () => InpaintOutpaintUtils.expand(
            sourceImage: sourceImage,
            existingMask: invalidMask,
            edges: const OutpaintEdges(),
            snapTo64: false,
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'Unable to decode existing mask',
            ),
          ),
        );
      }
    });
  });

  group('InpaintOutpaintUtils.resizeFrame', () {
    test('keeps small signed frame drags at the original 64 multiple', () {
      final rightOut = InpaintOutpaintUtils.resolveFrameGeometry(
        sourceWidth: 128,
        sourceHeight: 128,
        delta: const OutpaintFrameDelta(right: 31),
      );
      final rightIn = InpaintOutpaintUtils.resolveFrameGeometry(
        sourceWidth: 128,
        sourceHeight: 128,
        delta: const OutpaintFrameDelta(right: -31),
      );
      final leftOut = InpaintOutpaintUtils.resolveFrameGeometry(
        sourceWidth: 128,
        sourceHeight: 128,
        delta: const OutpaintFrameDelta(left: 31),
        horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
      );
      final leftIn = InpaintOutpaintUtils.resolveFrameGeometry(
        sourceWidth: 128,
        sourceHeight: 128,
        delta: const OutpaintFrameDelta(left: -31),
        horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
      );

      for (final geometry in [rightOut, rightIn, leftOut, leftIn]) {
        expect(geometry.width, equals(128));
        expect(geometry.height, equals(128));
        expect(geometry.appliedFrameLeft, equals(0));
        expect(geometry.appliedFrameRight, equals(128));
        expect(geometry.hasAppliedChange, isFalse);
      }
    });

    test(
      'snaps signed frame drags beyond half a cell to the next 64 multiple',
      () {
        final rightOut = InpaintOutpaintUtils.resolveFrameGeometry(
          sourceWidth: 128,
          sourceHeight: 128,
          delta: const OutpaintFrameDelta(right: 33),
        );
        final rightIn = InpaintOutpaintUtils.resolveFrameGeometry(
          sourceWidth: 128,
          sourceHeight: 128,
          delta: const OutpaintFrameDelta(right: -33),
        );

        expect(rightOut.width, equals(192));
        expect(rightOut.appliedExpansionEdges.right, equals(64));
        expect(rightIn.width, equals(64));
        expect(rightIn.appliedCropEdges.right, equals(64));
      },
    );

    test('crops an inward right edge resize to the previous 64 multiple', () {
      final sourceImage = _horizontalGradientPng(128, 128);

      final result = InpaintOutpaintUtils.resizeFrame(
        sourceImage: sourceImage,
        delta: const OutpaintFrameDelta(right: -33),
      );

      expect(result.width, equals(64));
      expect(result.height, equals(128));
      expect(result.appliedExpansionEdges.isEmpty, isTrue);
      expect(result.appliedCropEdges.left, equals(0));
      expect(result.appliedCropEdges.right, equals(64));

      final croppedSource = img.decodeImage(result.sourceImage)!;
      expect(croppedSource.width, equals(64));
      expect(croppedSource.getPixel(0, 0).r.toInt(), equals(0));
      expect(croppedSource.getPixel(63, 0).r.toInt(), equals(63));

      final croppedMask = img.decodeImage(result.maskImage)!;
      expect(croppedMask.width, equals(64));
      expect(croppedMask.getPixel(0, 0).r.toInt(), equals(0));
      expect(croppedMask.getPixel(63, 127).r.toInt(), equals(0));
    });

    test('crops an inward left edge resize from the source origin', () {
      final sourceImage = _horizontalGradientPng(128, 128);

      final result = InpaintOutpaintUtils.resizeFrame(
        sourceImage: sourceImage,
        delta: const OutpaintFrameDelta(left: -33),
        horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
      );

      expect(result.width, equals(64));
      expect(result.height, equals(128));
      expect(result.appliedCropEdges.left, equals(64));
      expect(result.appliedCropEdges.right, equals(0));

      final croppedSource = img.decodeImage(result.sourceImage)!;
      expect(croppedSource.getPixel(0, 0).r.toInt(), equals(64));
      expect(croppedSource.getPixel(63, 0).r.toInt(), equals(127));
    });

    test('outward resize matches expand output dimensions and mask', () {
      final sourceImage = _sourcePng(128, 96);

      final expanded = InpaintOutpaintUtils.expand(
        sourceImage: sourceImage,
        edges: const OutpaintEdges(right: 33),
      );
      final resized = InpaintOutpaintUtils.resizeFrame(
        sourceImage: sourceImage,
        delta: const OutpaintFrameDelta(right: 33),
      );

      expect(resized.width, equals(expanded.width));
      expect(resized.height, equals(expanded.height));
      expect(resized.sourceImage, equals(expanded.sourceImage));
      expect(resized.maskImage, equals(expanded.maskImage));
      expect(resized.appliedExpansionEdges.right, equals(64));
      expect(resized.appliedExpansionEdges.bottom, equals(32));
      expect(resized.appliedCropEdges.isEmpty, isTrue);
    });
  });

  group('OutpaintVirtualFrame', () {
    test('expands left then returns to the original source frame', () {
      final frame = OutpaintVirtualFrame.fromSource(
        sourceWidth: 128,
        sourceHeight: 128,
      );

      final expanded = frame.applyDelta(
        const OutpaintFrameDelta(left: 33),
        horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
      );
      expect(expanded.frame.canvasSize, equals(const Size(192, 128)));
      expect(expanded.frame.sourceDrawOffset, equals(const Offset(64, 0)));
      expect(expanded.contentShift, equals(const Offset(64, 0)));
      expect(
        expanded.outpaintMaskRects,
        equals([const Rect.fromLTWH(0, 0, 65, 128)]),
      );

      final restored = expanded.frame.applyDelta(
        const OutpaintFrameDelta(left: -33),
        horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
      );
      expect(restored.frame.canvasSize, equals(const Size(128, 128)));
      expect(restored.frame.sourceDrawOffset, Offset.zero);
      expect(restored.contentShift, equals(const Offset(-64, 0)));
      expect(restored.frame.hasOutpaintChanges, isFalse);
    });

    test('applies a corner expansion as one coherent virtual frame', () {
      final frame = OutpaintVirtualFrame.fromSource(
        sourceWidth: 128,
        sourceHeight: 96,
      );
      final expectedGeometry = InpaintOutpaintUtils.resolveFrameGeometry(
        sourceWidth: frame.width,
        sourceHeight: frame.height,
        delta: const OutpaintFrameDelta(left: 33, top: 33),
        horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
        verticalSnapTarget: OutpaintVerticalSnapTarget.top,
      );

      final result = frame.applyDelta(
        const OutpaintFrameDelta(left: 33, top: 33),
        horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
        verticalSnapTarget: OutpaintVerticalSnapTarget.top,
      );

      expect(result.geometry.width, expectedGeometry.width);
      expect(result.geometry.height, expectedGeometry.height);
      expect(
        result.geometry.appliedFrameLeft,
        expectedGeometry.appliedFrameLeft,
      );
      expect(result.geometry.appliedFrameTop, expectedGeometry.appliedFrameTop);
      expect(
        result.geometry.appliedFrameRight,
        expectedGeometry.appliedFrameRight,
      );
      expect(
        result.geometry.appliedFrameBottom,
        expectedGeometry.appliedFrameBottom,
      );
      expect(result.frame.canvasSize, equals(const Size(192, 128)));
      expect(result.frame.sourceDrawOffset, equals(const Offset(64, 32)));
      expect(result.contentShift, equals(const Offset(64, 32)));
      expect(
        result.outpaintMaskRects,
        equals([
          const Rect.fromLTWH(0, 0, 192, 33),
          const Rect.fromLTWH(0, 32, 65, 96),
        ]),
      );
    });

    test(
      'crops the current frame without mutating original source dimensions',
      () {
        final frame = OutpaintVirtualFrame.fromSource(
          sourceWidth: 128,
          sourceHeight: 128,
        );

        final result = frame.applyDelta(const OutpaintFrameDelta(right: -33));

        expect(result.frame.sourceWidth, equals(128));
        expect(result.frame.sourceHeight, equals(128));
        expect(result.frame.canvasSize, equals(const Size(64, 128)));
        expect(result.frame.sourceDrawOffset, Offset.zero);
        expect(result.contentShift, Offset.zero);
        expect(result.frame.hasOutpaintChanges, isTrue);
      },
    );

    test('materializes a virtual right expansion like resizeFrame', () async {
      final sourceImage = _sourcePng(128, 96);
      final frame = OutpaintVirtualFrame.fromSource(
        sourceWidth: 128,
        sourceHeight: 96,
      );
      final applied = frame.applyDelta(const OutpaintFrameDelta(right: 33));

      final virtualResult =
          await InpaintOutpaintUtils.materializeVirtualFrameAsync(
            sourceImage: sourceImage,
            frame: applied.frame,
          );
      final resizeResult = await InpaintOutpaintUtils.resizeFrameAsync(
        sourceImage: sourceImage,
        delta: const OutpaintFrameDelta(right: 33),
      );

      expect(virtualResult.sourceImage, equals(resizeResult.sourceImage));
      expect(virtualResult.width, equals(resizeResult.width));
      expect(virtualResult.height, equals(resizeResult.height));
    });

    test('materializes a virtual left crop like resizeFrame', () async {
      final sourceImage = _horizontalGradientPng(128, 128);
      final frame = OutpaintVirtualFrame.fromSource(
        sourceWidth: 128,
        sourceHeight: 128,
      );
      final applied = frame.applyDelta(
        const OutpaintFrameDelta(left: -33),
        horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
      );

      final virtualResult =
          await InpaintOutpaintUtils.materializeVirtualFrameAsync(
            sourceImage: sourceImage,
            frame: applied.frame,
          );
      final resizeResult = await InpaintOutpaintUtils.resizeFrameAsync(
        sourceImage: sourceImage,
        delta: const OutpaintFrameDelta(left: -33),
        horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
      );

      expect(virtualResult.sourceImage, equals(resizeResult.sourceImage));
      expect(virtualResult.width, equals(64));
      expect(virtualResult.height, equals(128));
    });

    test(
      'materializes and Pica-resizes a virtual frame before one PNG encode',
      () async {
        final sourceImage = _sourcePng(128, 128);
        final frame = OutpaintVirtualFrame.fromSource(
          sourceWidth: 128,
          sourceHeight: 128,
        ).applyDelta(const OutpaintFrameDelta(right: 64)).frame;

        final result = await InpaintOutpaintUtils.materializeVirtualFrameAsync(
          sourceImage: sourceImage,
          frame: frame,
          targetWidth: 128,
          targetHeight: 64,
        );
        final decoded = img.decodeImage(result.sourceImage)!;

        expect((result.width, result.height), (128, 64));
        expect((decoded.width, decoded.height), (128, 64));
        expect(decoded.getPixel(0, 32).a, 255);
        expect(decoded.getPixel(127, 32).a, 0);
      },
    );

    test('rejects malformed virtual frame dimensions before materializing', () {
      final sourceImage = _sourcePng(128, 128);
      final malformedFrames = [
        const OutpaintVirtualFrame(
          sourceWidth: 128,
          sourceHeight: 128,
          frameLeft: 32,
          frameTop: 0,
          frameRight: 32,
          frameBottom: 128,
        ),
        const OutpaintVirtualFrame(
          sourceWidth: 128,
          sourceHeight: 128,
          frameLeft: 0,
          frameTop: 96,
          frameRight: 128,
          frameBottom: 64,
        ),
      ];

      for (final frame in malformedFrames) {
        expect(
          () => InpaintOutpaintUtils.materializeVirtualFrame(
            sourceImage: sourceImage,
            frame: frame,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.message,
              'message',
              'Virtual frame dimensions must be positive',
            ),
          ),
        );
      }
    });
  });
}

Uint8List _sourcePng(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgba8(24, 48, 72, 255));
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _horizontalGradientPng(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(x, y, x, 48, 72, 255);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}
