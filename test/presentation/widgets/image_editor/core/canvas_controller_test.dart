import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/canvas_controller.dart';

const _frames = [Rect.fromLTWH(0, 0, 64, 64), Rect.fromLTWH(-64, 32, 256, 192)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('坐标换算与渲染变换一致', () {
    for (final frame in _frames) {
      for (final degrees in const [0.0, 30.0, 90.0, 180.0, -45.0, 217.0]) {
        for (final mirrored in const [false, true]) {
          test('frame=$frame 旋转=$degrees° 镜像=$mirrored', () {
            for (final scale in const [0.35, 1.0, 2.5]) {
              for (final offset in const [
                Offset.zero,
                Offset(30, 40),
                Offset(-120, 75.5),
              ]) {
                final controller = _controller(
                  scale: scale,
                  offset: offset,
                  degrees: degrees,
                  mirrored: mirrored,
                );
                final rendered = _renderMatrix(controller, frame);

                for (final point in _probePoints(frame)) {
                  final reason = '缩放=$scale 偏移=$offset 文档点=$point';
                  final screen = controller.canvasToScreen(point, frame: frame);
                  expect(
                    screen,
                    _near(MatrixUtils.transformPoint(rendered, point), 1e-3),
                    reason: 'canvasToScreen $reason',
                  );
                  expect(
                    MatrixUtils.transformPoint(
                      controller.getTransformMatrix(frame),
                      point,
                    ),
                    _near(screen, 1e-9),
                    reason: 'getTransformMatrix $reason',
                  );
                  expect(
                    controller.screenToCanvas(screen, frame: frame),
                    _near(point, 1e-6),
                    reason: '往返 $reason',
                  );
                }
              }
            }
          });
        }
      }
    }
  });

  test('旋转叠加镜像时文档点先镜像再旋转', () {
    const frame = Rect.fromLTWH(0, 0, 64, 64);
    const point = Offset(20, 12);
    final controller = _controller(
      scale: 2.5,
      offset: const Offset(30, 40),
      degrees: 30,
      mirrored: true,
    );

    final screen = controller.canvasToScreen(point, frame: frame);

    expect(screen, _near(const Offset(160.9808, 91.6987), 1e-3));
    expect(controller.screenToCanvas(screen, frame: frame), _near(point, 1e-9));
  });

  test('无旋转无镜像时走直接换算，数值与平移缩放公式完全相同', () {
    const frame = Rect.fromLTWH(-64, 32, 256, 192);
    const scale = 2.5;
    const offset = Offset(30.25, -40.5);
    final controller = _controller(
      scale: scale,
      offset: offset,
      degrees: 0,
      mirrored: false,
    );

    for (final point in _probePoints(frame)) {
      expect(
        controller.canvasToScreen(point, frame: frame),
        point * scale + offset,
      );
      expect(
        controller.screenToCanvas(point, frame: frame),
        (point - offset) / scale,
      );
    }
  });

  group('viewportBounds', () {
    const viewport = Size(400, 300);

    test('视口尺寸未知时为空矩形', () {
      final controller = CanvasController();
      addTearDown(controller.dispose);

      expect(controller.viewportBounds(_frames.first), Rect.zero);
    });

    test('无旋转时等于视口两角换算出的矩形', () {
      final controller = _controller(
        scale: 2.5,
        offset: const Offset(30, 40),
        degrees: 0,
        mirrored: false,
      )..setViewportSize(viewport);

      final bounds = controller.viewportBounds(_frames.first);

      expect(bounds.left, moreOrLessEquals(-12));
      expect(bounds.top, moreOrLessEquals(-16));
      expect(bounds.right, moreOrLessEquals(148));
      expect(bounds.bottom, moreOrLessEquals(104));
    });

    for (final frame in _frames) {
      for (final mirrored in const [false, true]) {
        test('旋转后包住视口四角 frame=$frame 镜像=$mirrored', () {
          final controller = _controller(
            scale: 2.5,
            offset: const Offset(30, 40),
            degrees: 30,
            mirrored: mirrored,
          )..setViewportSize(viewport);

          final bounds = controller.viewportBounds(frame);
          final corners = [
            Offset.zero,
            Offset(viewport.width, 0),
            Offset(0, viewport.height),
            Offset(viewport.width, viewport.height),
          ].map((corner) => controller.screenToCanvas(corner, frame: frame));

          const epsilon = 1e-6;
          for (final corner in corners) {
            expect(
              bounds.inflate(epsilon).contains(corner),
              isTrue,
              reason: '$corner',
            );
          }
          expect(
            corners.map((c) => c.dx).reduce(math.min),
            moreOrLessEquals(bounds.left, epsilon: epsilon),
          );
          expect(
            corners.map((c) => c.dx).reduce(math.max),
            moreOrLessEquals(bounds.right, epsilon: epsilon),
          );
          expect(
            corners.map((c) => c.dy).reduce(math.min),
            moreOrLessEquals(bounds.top, epsilon: epsilon),
          );
          expect(
            corners.map((c) => c.dy).reduce(math.max),
            moreOrLessEquals(bounds.bottom, epsilon: epsilon),
          );
        });
      }
    }
  });
}

CanvasController _controller({
  required double scale,
  required Offset offset,
  required double degrees,
  required bool mirrored,
}) {
  final controller = CanvasController()
    ..setScale(scale)
    ..setOffset(offset);
  if (degrees != 0) controller.rotateRight(degrees: degrees);
  if (mirrored) controller.toggleMirrorHorizontal();
  addTearDown(controller.dispose);
  return controller;
}

List<Offset> _probePoints(Rect frame) => [
  const Offset(20, 12),
  frame.topLeft,
  frame.bottomRight,
  frame.center,
  const Offset(-7.5, 91.25),
];

// 以图层实际使用的画布变换为准，不经被测的换算函数
Matrix4 _renderMatrix(CanvasController controller, Rect frame) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  controller.applyViewTransform(canvas, frame);
  final matrix = Matrix4.fromFloat64List(canvas.getTransform());
  recorder.endRecording().dispose();
  return matrix;
}

// 引擎返回的画布矩阵是单精度
Matcher _near(Offset expected, double epsilon) => isA<Offset>()
    .having(
      (offset) => offset.dx,
      'dx',
      moreOrLessEquals(expected.dx, epsilon: epsilon),
    )
    .having(
      (offset) => offset.dy,
      'dy',
      moreOrLessEquals(expected.dy, epsilon: epsilon),
    );
