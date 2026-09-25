import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/painters/focused_context_overlay_painter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _focus = Rect.fromLTWH(8, 12, 20, 16);
const _context = Rect.fromLTWH(0, 4, 40, 36);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // EditorState 构造时会异步读取工具设置
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (degrees, mirrored) in const [(0.0, false), (30.0, true)]) {
    test('聚焦框与上下文框落在图层渲染的位置 旋转=$degrees° 镜像=$mirrored', () {
      final state = _editorState();
      state.canvasController
        ..setScale(2.5)
        ..setOffset(const Offset(30, 40))
        ..rotateRight(degrees: degrees);
      if (mirrored) state.canvasController.toggleMirrorHorizontal();

      final outlines = _strokedPaths(
        FocusedContextOverlayPainter(
          state: state,
          focusAreaRect: _focus,
          contextCrop: _context,
        ),
      );
      final rendered = _renderMatrix(state);

      expect(outlines, hasLength(2), reason: '上下文框与聚焦框各一条描边');
      expect(
        outlines[0].getBounds(),
        _nearRect(MatrixUtils.transformRect(rendered, _context)),
      );
      expect(
        outlines[1].getBounds(),
        _nearRect(MatrixUtils.transformRect(rendered, _focus)),
      );
    });
  }

  test('只在换了状态或区域时要求重绘', () {
    final state = _editorState();
    final painter = FocusedContextOverlayPainter(
      state: state,
      focusAreaRect: _focus,
      contextCrop: _context,
    );

    expect(
      painter.shouldRepaint(
        FocusedContextOverlayPainter(
          state: state,
          focusAreaRect: _focus,
          contextCrop: _context,
        ),
      ),
      isFalse,
    );
    expect(
      painter.shouldRepaint(
        FocusedContextOverlayPainter(
          state: state,
          focusAreaRect: _focus.shift(const Offset(1, 0)),
          contextCrop: _context,
        ),
      ),
      isTrue,
    );
    expect(
      painter.shouldRepaint(
        FocusedContextOverlayPainter(
          state: _editorState(),
          focusAreaRect: _focus,
          contextCrop: _context,
        ),
      ),
      isTrue,
    );
  });
}

EditorState _editorState() {
  final state = EditorState()..setCanvasSize(const Size(64, 64));
  addTearDown(state.dispose);
  return state;
}

List<Path> _strokedPaths(CustomPainter painter) {
  final canvas = TestRecordingCanvas();
  painter.paint(canvas, const Size(400, 300));
  return [
    for (final recorded in canvas.invocations)
      if (recorded.invocation.memberName == #drawPath &&
          (recorded.invocation.positionalArguments[1] as Paint).style ==
              PaintingStyle.stroke)
        recorded.invocation.positionalArguments[0] as Path,
  ];
}

// 以图层实际使用的画布变换为准
Matrix4 _renderMatrix(EditorState state) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  state.canvasController.applyViewTransform(canvas, state.frame);
  final matrix = Matrix4.fromFloat64List(canvas.getTransform());
  recorder.endRecording().dispose();
  return matrix;
}

// 路径与引擎画布矩阵都是单精度
Matcher _nearRect(Rect expected) => isA<Rect>()
    .having(
      (rect) => rect.left,
      'left',
      moreOrLessEquals(expected.left, epsilon: 1e-2),
    )
    .having(
      (rect) => rect.top,
      'top',
      moreOrLessEquals(expected.top, epsilon: 1e-2),
    )
    .having(
      (rect) => rect.right,
      'right',
      moreOrLessEquals(expected.right, epsilon: 1e-2),
    )
    .having(
      (rect) => rect.bottom,
      'bottom',
      moreOrLessEquals(expected.bottom, epsilon: 1e-2),
    );
