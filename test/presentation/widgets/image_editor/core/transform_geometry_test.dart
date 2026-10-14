import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/transform_geometry.dart';

const _source = Rect.fromLTWH(10, 20, 100, 50);
const _metrics = TransformHandleMetrics(hitRadius: 6, rotateHandleOffset: 20);

Matcher _offsetCloseTo(Offset expected) => isA<Offset>()
    .having((o) => o.dx, 'dx', closeTo(expected.dx, 1e-9))
    .having((o) => o.dy, 'dy', closeTo(expected.dy, 1e-9));

Matcher _rectCloseTo(Rect expected) => isA<Rect>()
    .having((r) => r.left, 'left', closeTo(expected.left, 1e-9))
    .having((r) => r.top, 'top', closeTo(expected.top, 1e-9))
    .having((r) => r.right, 'right', closeTo(expected.right, 1e-9))
    .having((r) => r.bottom, 'bottom', closeTo(expected.bottom, 1e-9));

void main() {
  group('TransformParams', () {
    test('identity maps the source onto itself', () {
      final params = TransformParams.identity(_source);
      expect(params.isIdentity, isTrue);
      expect(params.bounds, _rectCloseTo(_source));
      expect(params.corners, [
        _source.topLeft,
        _source.topRight,
        _source.bottomRight,
        _source.bottomLeft,
      ]);
      expect(params.unitOf(_source.bottomRight), const Offset(1, 1));
    });

    test('fitInside shrinks oversized images and centers them', () {
      const frame = Rect.fromLTWH(0, 0, 512, 512);
      final params = TransformParams.fitInside(
        const Rect.fromLTWH(0, 0, 2048, 1024),
        frame,
      );
      expect(params.scaleX, 0.25);
      expect(params.scaleY, 0.25);
      expect(
        params.bounds,
        _rectCloseTo(const Rect.fromLTWH(0, 128, 512, 256)),
      );
    });

    test('fitInside keeps small images at native size on whole pixels', () {
      const frame = Rect.fromLTWH(0, 0, 512, 512);
      final params = TransformParams.fitInside(
        const Rect.fromLTWH(0, 0, 101, 64),
        frame,
      );
      expect(params.scaleX, 1);
      final topLeft = params.bounds.topLeft;
      expect(topLeft.dx, topLeft.dx.roundToDouble());
      expect(topLeft.dy, topLeft.dy.roundToDouble());
      expect((params.center - frame.center).distance, lessThanOrEqualTo(0.5));
    });

    test('corner drag with the aspect locked scales both axes', () {
      final params = TransformParams.identity(_source).scaledBy(
        TransformHandle.bottomRight,
        const Offset(210, 120),
        keepAspect: true,
        fromCenter: false,
      );
      expect(params.scaleX, closeTo(2, 1e-9));
      expect(params.scaleY, closeTo(2, 1e-9));
      expect(
        params.pointAt(const Offset(-1, -1)),
        _offsetCloseTo(_source.topLeft),
      );

      // 指针偏离对角线时投影到对角线上，宽高比不变
      final projected = TransformParams.identity(_source).scaledBy(
        TransformHandle.bottomRight,
        const Offset(210, 70),
        keepAspect: true,
        fromCenter: false,
      );
      expect(projected.scaleX, closeTo(projected.scaleY, 1e-9));
      expect(projected.scaleX, closeTo(1.8, 1e-9));
    });

    test('corner drag without the lock follows the pointer on each axis', () {
      final params = TransformParams.identity(_source).scaledBy(
        TransformHandle.bottomRight,
        const Offset(60, 120),
        keepAspect: false,
        fromCenter: false,
      );
      expect(params.scaleX, closeTo(0.5, 1e-9));
      expect(params.scaleY, closeTo(2, 1e-9));
      expect(params.bounds, _rectCloseTo(const Rect.fromLTRB(10, 20, 60, 120)));
    });

    test('edge drag only changes its own axis and keeps the opposite edge', () {
      final params = TransformParams.identity(_source).scaledBy(
        TransformHandle.right,
        const Offset(160, 999),
        keepAspect: true,
        fromCenter: false,
      );
      expect(params.scaleX, closeTo(1.5, 1e-9));
      expect(params.scaleY, 1);
      expect(params.bounds, _rectCloseTo(const Rect.fromLTRB(10, 20, 160, 70)));
    });

    test('scaling from the center keeps the center in place', () {
      final params = TransformParams.identity(_source).scaledBy(
        TransformHandle.right,
        const Offset(160, 45),
        keepAspect: false,
        fromCenter: true,
      );
      expect(params.center, _source.center);
      expect(params.scaleX, closeTo(2, 1e-9));
    });

    test('dragging past the opposite edge mirrors the content', () {
      final params = TransformParams.identity(_source).scaledBy(
        TransformHandle.right,
        const Offset(-40, 45),
        keepAspect: false,
        fromCenter: false,
      );
      expect(params.scaleX, closeTo(-0.5, 1e-9));
      expect(params.bounds, _rectCloseTo(const Rect.fromLTRB(-40, 20, 10, 70)));
    });

    test('scale never collapses below one pixel', () {
      final params = TransformParams.identity(_source).scaledBy(
        TransformHandle.right,
        const Offset(10, 45),
        keepAspect: false,
        fromCenter: false,
      );
      expect(params.size.width, closeTo(1, 1e-9));
    });

    test('rotation follows the pointer around the center and snaps', () {
      final start = TransformParams.identity(_source);
      final center = _source.center;
      final rotated = start.rotatedTowards(
        center + const Offset(100, 0),
        center + const Offset(0, 100),
        snap: false,
      );
      expect(rotated.rotation, closeTo(math.pi / 2, 1e-9));

      final snapped = start.rotatedTowards(
        center + const Offset(100, 0),
        center + Offset.fromDirection(0.3, 100),
        snap: true,
      );
      expect(snapped.rotation, closeTo(math.pi / 12, 1e-9));
    });

    test('pinch keeps the content under the fingers', () {
      final start = TransformParams.identity(_source);
      const from = Offset(30, 30);
      const to = Offset(50, 60);
      final pinched = start.pinched(from: from, to: to, scale: 2, turn: 0.4);
      // 手势起点处的内容点跟随手指落到 to
      final local = start.unitOf(from);
      expect(pinched.pointAt(local), _offsetCloseTo(to));
      expect(pinched.scaleX, closeTo(2, 1e-9));
      expect(pinched.rotation, closeTo(0.4, 1e-9));
    });

    test('flip mirrors along the box axes without moving the center', () {
      final start = TransformParams.identity(_source).withRotation(0.5);
      final flipped = start.flipped(horizontal: true);
      expect(flipped.scaleX, -1);
      expect(flipped.center, start.center);
      expect(flipped.flipped(horizontal: true), start);
    });

    test('numeric scale keeps the mirror direction', () {
      final mirrored = TransformParams.identity(
        _source,
      ).flipped(horizontal: false);
      final scaled = mirrored.withScale(x: 2, y: 0.5);
      expect(scaled.scaleX, 2);
      expect(scaled.scaleY, -0.5);
    });

    test('quarter turns use exact matrices and land on whole pixels', () {
      // 奇偶不同的尺寸绕中心转 90° 会落在半像素上
      final params = TransformParams.identity(
        const Rect.fromLTWH(0, 0, 8, 5),
      ).withRotation(math.pi / 2).pixelAligned();
      final storage = params.matrix.storage;
      expect(storage[0], 0);
      expect(storage[1], 1);
      expect(storage[4], -1);
      expect(storage[5], 0);
      final origin = MatrixUtils.transformPoint(params.matrix, Offset.zero);
      expect(origin.dx, origin.dx.roundToDouble());
      expect(origin.dy, origin.dy.roundToDouble());
      expect(params.size, const Size(8, 5));
      expect(
        (params.center - const Offset(4, 2.5)).distance,
        lessThanOrEqualTo(0.75),
      );
    });

    test('sampling skips interpolation whenever pixels map one to one', () {
      final identity = TransformParams.identity(
        const Rect.fromLTWH(0, 0, 8, 5),
      );
      expect(identity.sampling, FilterQuality.none);
      expect(
        identity.translated(const Offset(3, -2)).sampling,
        FilterQuality.none,
      );
      expect(identity.flipped(horizontal: true).sampling, FilterQuality.none);
      expect(
        identity.withRotation(math.pi / 2).pixelAligned().sampling,
        FilterQuality.none,
      );
      // 未对齐的 90° 落在半像素上，必须插值
      expect(identity.withRotation(math.pi / 2).sampling, FilterQuality.high);
      expect(identity.withScale(x: 0.5, y: 0.5).sampling, FilterQuality.medium);
      expect(identity.withScale(x: 2, y: 2).sampling, FilterQuality.high);
      expect(identity.withRotation(0.3).sampling, FilterQuality.high);
    });

    test('pixel alignment leaves free rotation and scaling alone', () {
      final rotated = TransformParams.identity(_source).withRotation(0.3);
      expect(rotated.pixelAligned(), rotated);
      final scaled = TransformParams.identity(_source).withScale(x: 1.5);
      expect(scaled.pixelAligned(), scaled);
      final identity = TransformParams.identity(
        const Rect.fromLTWH(0.5, 0.25, 9, 9),
      );
      expect(identity.pixelAligned(), identity);
    });

    test('angles normalise into (-π, π]', () {
      expect(
        TransformParams.normalizeAngle(3 * math.pi / 2),
        closeTo(-math.pi / 2, 1e-9),
      );
      expect(TransformParams.normalizeAngle(-math.pi), closeTo(math.pi, 1e-9));
      expect(TransformParams.normalizeAngle(math.pi), closeTo(math.pi, 1e-9));
    });
  });

  group('hitTest', () {
    final params = TransformParams.identity(_source);

    test('corners win over edges and the rotate handle sits above the top', () {
      expect(
        params.hitTest(const Offset(12, 22), _metrics, rotateOutside: false),
        (grip: TransformGrip.scale, handle: TransformHandle.topLeft),
      );
      expect(
        params.hitTest(const Offset(60, 72), _metrics, rotateOutside: false),
        (grip: TransformGrip.scale, handle: TransformHandle.bottom),
      );
      expect(
        params.hitTest(const Offset(60, 1), _metrics, rotateOutside: false),
        (grip: TransformGrip.rotate, handle: null),
      );
    });

    test('inside moves; outside rotates only while a transform is active', () {
      expect(
        params.hitTest(const Offset(60, 45), _metrics, rotateOutside: false),
        (grip: TransformGrip.move, handle: null),
      );
      expect(
        params.hitTest(const Offset(300, 300), _metrics, rotateOutside: false),
        isNull,
      );
      expect(
        params.hitTest(const Offset(300, 300), _metrics, rotateOutside: true),
        (grip: TransformGrip.rotate, handle: null),
      );
    });

    test('handles follow the rotated box', () {
      final rotated = params.withRotation(math.pi / 2);
      final corner = rotated.pointAt(const Offset(1, 1));
      expect(rotated.hitTest(corner, _metrics, rotateOutside: true), (
        grip: TransformGrip.scale,
        handle: TransformHandle.bottomRight,
      ));
    });

    test('document metrics shrink with the view zoom', () {
      final metrics = TransformHandleMetrics.touch.inDocument(4);
      expect(metrics.hitRadius, TransformHandleMetrics.touch.hitRadius / 4);
    });
  });
}
