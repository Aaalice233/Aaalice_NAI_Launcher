import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/clone_source_marker_painter.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/clone_stamp_tool.dart';

const _viewport = Size(400, 300);

const _arms = [Offset(1, 0), Offset(-1, 0), Offset(0, 1), Offset(0, -1)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('没有源点准星时不绘制', () {
    final state = _editorState();
    final tool = CloneStampTool();

    expect(_drawnLines(state, tool), isEmpty);
  });

  test('准星压在图层渲染出的同一像素上，旋转叠加镜像也不偏', () {
    final state = _editorState();
    final controller = state.canvasController
      ..setViewportSize(_viewport)
      ..setScale(2.5)
      ..setOffset(const Offset(30, 40))
      ..rotateRight(degrees: 30)
      ..toggleMirrorHorizontal();
    expect(controller.rotation, isNot(0));
    final tool = CloneStampTool();
    const source = Offset(20, 12);
    tool.onPointerDown(const PointerDownEvent(position: source), state);

    final center = _renderedScreenPoint(state, source);
    final lines = _drawnLines(state, tool);

    expect(lines, hasLength(8), reason: '黑色垫底与白色细线各四臂');
    for (final (index, line) in lines.indexed) {
      final arm = _arms[index % 4];
      expect(line.p1, _near(center + arm * 3), reason: '中心留空 $index');
      expect(line.p2, _near(center + arm * 11), reason: '臂长按屏幕像素 $index');
      expect(
        line.paint.color,
        index < 4 ? Colors.black : Colors.white,
        reason: '先画黑色垫底 $index',
      );
    }
  });

  test('准星移动、视图变换与取景框变化都会触发重绘', () {
    final state = _editorState();
    final tool = CloneStampTool();
    final painter = CloneSourceMarkerPainter(state: state, tool: tool);
    var repaints = 0;
    void listener() => repaints++;
    painter.addListener(listener);
    addTearDown(() => painter.removeListener(listener));

    tool.onPointerDown(const PointerDownEvent(position: Offset(8, 8)), state);
    expect(repaints, 1, reason: '准星移动');

    state.canvasController.pan(const Offset(5, 0));
    expect(repaints, 2, reason: '视图平移');

    state.setCanvasSize(const Size(80, 64));
    expect(repaints, greaterThanOrEqualTo(3), reason: '取景框改变旋转枢轴');
  });

  test('只在换了状态或工具实例时要求重绘', () {
    final state = _editorState();
    final tool = CloneStampTool();
    final painter = CloneSourceMarkerPainter(state: state, tool: tool);

    expect(
      painter.shouldRepaint(CloneSourceMarkerPainter(state: state, tool: tool)),
      isFalse,
    );
    expect(
      painter.shouldRepaint(
        CloneSourceMarkerPainter(state: state, tool: CloneStampTool()),
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

List<({Offset p1, Offset p2, Paint paint})> _drawnLines(
  EditorState state,
  CloneStampTool tool,
) {
  final canvas = TestRecordingCanvas();
  CloneSourceMarkerPainter(state: state, tool: tool).paint(canvas, _viewport);
  return [
    for (final recorded in canvas.invocations)
      if (recorded.invocation.memberName == #drawLine)
        (
          p1: recorded.invocation.positionalArguments[0] as Offset,
          p2: recorded.invocation.positionalArguments[1] as Offset,
          paint: recorded.invocation.positionalArguments[2] as Paint,
        ),
  ];
}

// 以图层实际使用的画布变换求屏幕位置，不经 canvasToScreen
Offset _renderedScreenPoint(EditorState state, Offset documentPoint) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  state.canvasController.applyViewTransform(canvas, state.frame);
  final matrix = Matrix4.fromFloat64List(canvas.getTransform());
  recorder.endRecording().dispose();
  return MatrixUtils.transformPoint(matrix, documentPoint);
}

// 引擎返回的画布矩阵是单精度，参照点带约 1e-6 的舍入
Matcher _near(Offset expected) => isA<Offset>()
    .having(
      (offset) => offset.dx,
      'dx',
      moreOrLessEquals(expected.dx, epsilon: 1e-3),
    )
    .having(
      (offset) => offset.dy,
      'dy',
      moreOrLessEquals(expected.dy, epsilon: 1e-3),
    );
