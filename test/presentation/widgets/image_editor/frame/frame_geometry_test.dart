import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/inpaint_outpaint_utils.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/frame/frame_geometry.dart';

void main() {
  const source = Rect.fromLTWH(0, 0, 1024, 768);

  group('virtualFrame', () {
    test('frame equal to source has no outpaint area', () {
      final frame = EditorFrameGeometry.virtualFrame(
        frame: source,
        sourceRect: source,
      );
      expect(frame.hasOutpaintChanges, isFalse);
      expect(frame.outpaintMaskRects, isEmpty);
    });

    test('frame extended left maps to negative source-relative left', () {
      final frame = EditorFrameGeometry.virtualFrame(
        frame: const Rect.fromLTWH(-128, 0, 1152, 768),
        sourceRect: source,
      );
      expect(frame.frameLeft, -128);
      expect(frame.frameRight, 1024);
      expect(frame.width, 1152);
      expect(frame.outpaintMaskRects, [const Rect.fromLTRB(0, 0, 129, 768)]);
    });

    test('moved source keeps the frame relative to the source', () {
      final frame = EditorFrameGeometry.virtualFrame(
        frame: const Rect.fromLTWH(64, 64, 512, 512),
        sourceRect: const Rect.fromLTWH(64, 0, 512, 768),
      );
      expect(frame.frameLeft, 0);
      expect(frame.frameTop, 64);
      expect(frame.hasOutpaintChanges, isTrue);
      expect(frame.outpaintMaskRects, isEmpty);
    });
  });

  group('output canvas', () {
    test('is the union of the source and the frame', () {
      const frame = Rect.fromLTWH(384, 128, 832, 768);
      final canvas = EditorFrameGeometry.outputCanvas(
        frame: frame,
        sourceRect: source,
      );
      expect(canvas, const Rect.fromLTWH(0, 0, 1216, 896));
      expect(
        EditorFrameGeometry.frameInCanvas(frame: frame, canvas: canvas),
        frame,
      );
    });

    test(
      'frame position is local to a canvas that starts left of the source',
      () {
        const frame = Rect.fromLTWH(-256, -64, 512, 512);
        final canvas = EditorFrameGeometry.outputCanvas(
          frame: frame,
          sourceRect: source,
        );
        expect(canvas, const Rect.fromLTRB(-256, -64, 1024, 768));
        expect(
          EditorFrameGeometry.frameInCanvas(frame: frame, canvas: canvas),
          const Rect.fromLTWH(0, 0, 512, 512),
        );
      },
    );

    test('a frame covering the source is its own canvas', () {
      const frame = Rect.fromLTWH(-64, -64, 1152, 896);
      expect(
        EditorFrameGeometry.outputCanvas(frame: frame, sourceRect: source),
        frame,
      );
    });
  });

  group('isFrameAllowed', () {
    test('requires at least 64 px of overlap on both axes', () {
      expect(
        EditorFrameGeometry.isFrameAllowed(
          const Rect.fromLTWH(960, 0, 512, 512),
          sourceRect: source,
        ),
        isTrue,
      );
      expect(
        EditorFrameGeometry.isFrameAllowed(
          const Rect.fromLTWH(1024 - 32, 0, 512, 512),
          sourceRect: source,
        ),
        isFalse,
      );
      expect(
        EditorFrameGeometry.isFrameAllowed(
          const Rect.fromLTWH(0, -480, 512, 512),
          sourceRect: source,
        ),
        isFalse,
      );
    });

    test('caps the combined canvas at the outpaint limit', () {
      const wide = Rect.fromLTWH(0, 0, 2560, 1024);
      expect(
        EditorFrameGeometry.isFrameAllowed(
          const Rect.fromLTWH(1536, 0, 2560, 1024),
          sourceRect: wide,
        ),
        isTrue,
      );
      expect(
        EditorFrameGeometry.isFrameAllowed(
          const Rect.fromLTWH(1600, 0, 2560, 1024),
          sourceRect: wide,
        ),
        isFalse,
      );
    });
  });

  group('resize', () {
    test('expanding the left edge moves only the frame origin', () {
      final resized = EditorFrameGeometry.resize(
        source,
        const OutpaintFrameDelta(left: 64),
        horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
        verticalSnapTarget: OutpaintVerticalSnapTarget.bottom,
      );
      expect(resized, const Rect.fromLTWH(-64, 0, 1088, 768));
    });

    test('resize snaps to 64 and keeps the anchor edge', () {
      final resized = EditorFrameGeometry.resize(
        const Rect.fromLTWH(128, 64, 512, 512),
        const OutpaintFrameDelta(right: 40, bottom: -20),
        horizontalSnapTarget: OutpaintHorizontalSnapTarget.right,
        verticalSnapTarget: OutpaintVerticalSnapTarget.bottom,
      );
      expect(resized, const Rect.fromLTWH(128, 64, 576, 512));
    });

    test('empty or no-op deltas return the frame unchanged', () {
      expect(
        EditorFrameGeometry.resize(
          source,
          const OutpaintFrameDelta(),
          horizontalSnapTarget: OutpaintHorizontalSnapTarget.right,
          verticalSnapTarget: OutpaintVerticalSnapTarget.bottom,
        ),
        source,
      );
      expect(
        EditorFrameGeometry.resize(
          source,
          const OutpaintFrameDelta(right: 10),
          horizontalSnapTarget: OutpaintHorizontalSnapTarget.right,
          verticalSnapTarget: OutpaintVerticalSnapTarget.bottom,
        ),
        source,
      );
    });

    test('resize beyond 4096 is rejected', () {
      expect(
        EditorFrameGeometry.resize(
          source,
          const OutpaintFrameDelta(right: 4096),
          horizontalSnapTarget: OutpaintHorizontalSnapTarget.right,
          verticalSnapTarget: OutpaintVerticalSnapTarget.bottom,
        ),
        isNull,
      );
    });
  });

  group('move', () {
    test('quantizes to 64 px steps from the source origin', () {
      final moved = EditorFrameGeometry.move(
        const Rect.fromLTWH(0, 0, 512, 512),
        const Offset(100.4, 31),
        sourceRect: source,
      );
      expect(moved, const Rect.fromLTWH(128, 0, 512, 512));
    });

    test('the grid follows a source that no longer starts at the origin', () {
      final moved = EditorFrameGeometry.move(
        const Rect.fromLTWH(96, 32, 256, 256),
        const Offset(70, 0),
        sourceRect: const Rect.fromLTWH(32, 32, 512, 512),
      );
      expect(moved.left, 160);
      expect((moved.left - 32) % EditorFrameGeometry.moveStep, 0);
    });

    test('keeps at least 64 px of overlap with the source', () {
      final farRight = EditorFrameGeometry.move(
        const Rect.fromLTWH(0, 0, 512, 512),
        const Offset(5000, 0),
        sourceRect: source,
      );
      expect(farRight.left, 1024 - EditorFrameGeometry.minimumSourceOverlap);

      final farUp = EditorFrameGeometry.move(
        const Rect.fromLTWH(0, 0, 512, 512),
        const Offset(0, -5000),
        sourceRect: source,
      );
      expect(
        farUp.bottom,
        source.top + EditorFrameGeometry.minimumSourceOverlap,
      );
    });

    test('overlap requirement shrinks for sources smaller than 64 px', () {
      final moved = EditorFrameGeometry.move(
        const Rect.fromLTWH(0, 0, 512, 512),
        const Offset(5000, 0),
        sourceRect: const Rect.fromLTWH(0, 0, 32, 32),
      );
      expect(moved.left, 0);
    });

    test('stops before the combined canvas exceeds the outpaint limit', () {
      const wide = Rect.fromLTWH(0, 0, 2560, 1024);
      final moved = EditorFrameGeometry.move(
        const Rect.fromLTWH(0, 0, 2560, 1024),
        const Offset(3000, 0),
        sourceRect: wide,
      );
      expect(moved.left, InpaintOutpaintUtils.maxDimension - 2560);
      expect(
        EditorFrameGeometry.outputCanvas(frame: moved, sourceRect: wide).width,
        InpaintOutpaintUtils.maxDimension,
      );
    });
  });

  group('restore', () {
    test('keeps an aligned frame as it was', () {
      expect(
        EditorFrameGeometry.restore(
          const Rect.fromLTWH(384, 0, 832, 768),
          sourceRect: source,
        ),
        const Rect.fromLTWH(384, 0, 832, 768),
      );
    });

    test('snaps scaled edges back onto the 64 grid', () {
      expect(
        EditorFrameGeometry.restore(
          const Rect.fromLTRB(323.4, 10, 1024, 700.2),
          sourceRect: source,
        ),
        const Rect.fromLTRB(320, 0, 1024, 704),
      );
    });

    test('pulls a frame that lost its overlap back into range', () {
      final restored = EditorFrameGeometry.restore(
        const Rect.fromLTWH(1500, 0, 512, 512),
        sourceRect: source,
      );
      expect(restored, const Rect.fromLTWH(960, 0, 512, 512));
      expect(
        EditorFrameGeometry.isFrameAllowed(restored, sourceRect: source),
        isTrue,
      );
    });
  });

  test('fitToSource aligns to the source and rounds up to 64', () {
    expect(
      EditorFrameGeometry.fitToSource(const Rect.fromLTWH(-64, 32, 1000, 700)),
      const Rect.fromLTWH(-64, 32, 1024, 704),
    );
  });

  test('exceedsFrame ignores empty content and detects any overflow', () {
    const frame = Rect.fromLTWH(0, 0, 100, 100);
    expect(EditorFrameGeometry.exceedsFrame(Rect.zero, frame), isFalse);
    expect(
      EditorFrameGeometry.exceedsFrame(
        const Rect.fromLTWH(10, 10, 80, 80),
        frame,
      ),
      isFalse,
    );
    expect(
      EditorFrameGeometry.exceedsFrame(
        const Rect.fromLTWH(-1, 10, 20, 20),
        frame,
      ),
      isTrue,
    );
  });

  test('document and frame-local coordinates convert both ways', () {
    const frame = Rect.fromLTWH(-64, 32, 512, 512);
    const point = Offset(10, 40);
    final local = EditorFrameGeometry.toLocal(frame, point);
    expect(local, const Offset(74, 8));
    expect(EditorFrameGeometry.toDocument(frame, local), point);
  });
}
