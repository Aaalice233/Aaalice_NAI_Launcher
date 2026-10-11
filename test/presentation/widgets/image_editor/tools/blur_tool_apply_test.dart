import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/layer_role_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/blur_tool.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../layers/layer_pixel_test_helpers.dart';

const _canvas = Rect.fromLTWH(0, 0, 64, 64);
const _red = [255, 0, 0, 255];

void main() {
  // EditorState 构造时会异步读取工具设置
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('back-to-back strokes both land and undo one at a time', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (state, layer) = await _splitCanvas();
      final tool = _blurTool();

      _stroke(tool, state, const [Offset(24, 16), Offset(40, 16)]);
      _stroke(tool, state, const [Offset(24, 48), Offset(40, 48)]);

      expect(state.historyManager.undoStackSize, 2, reason: '松手当帧写回');
      var pixels = await LayerPixels.of(layer, _canvas);
      _expectBlurred(pixels.at(30, 16), reason: '笔刷圆与线段重叠处同样模糊');
      _expectBlurred(pixels.at(30, 48), reason: '第二笔没有被丢弃');
      expect(pixels.at(30, 32), _red, reason: '两笔之间不受影响');

      state.undo();
      pixels = await LayerPixels.of(layer, _canvas);
      _expectBlurred(pixels.at(30, 16));
      expect(pixels.at(30, 48), _red);

      state.undo();
      pixels = await LayerPixels.of(layer, _canvas);
      expect(pixels.at(30, 16), _red);
    });
  });

  testWidgets('switching tools right after release keeps the stroke', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (state, layer) = await _splitCanvas();
      state.setToolById('blur');
      final tool = state.currentTool! as BlurTool
        ..setSize(16)
        ..setIntensity(1);

      _stroke(tool, state, const [Offset(24, 16), Offset(40, 16)]);
      state.setToolById('brush');

      final pixels = await LayerPixels.of(layer, _canvas);
      _expectBlurred(pixels.at(30, 16));
    });
    await tester.pump();
  });

  testWidgets('the source layer keeps its extent in an inpaint session', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (state, source) = await _splitCanvas(size: const Size(32, 32));
      state.setRolePolicy(LayerRolePolicy.inpaint(protectedLayerId: source.id));
      final tool = _blurTool();

      _stroke(tool, state, const [Offset(16, 16), Offset(60, 16)]);

      expect(state.historyManager.undoStackSize, 1);
      expect(source.contentBounds, const Rect.fromLTWH(0, 0, 32, 32));
      final pixels = await LayerPixels.of(source, _canvas);
      _expectBlurred(pixels.at(15, 16));
      expect(pixels.alphaAt(40, 16), 0, reason: '原图区域外不写入像素');
    });
  });
}

BlurTool _blurTool() => BlurTool()
  ..setSize(16)
  ..setIntensity(1);

/// 左红右蓝的底图，[size] 默认铺满画布
Future<(EditorState, Layer)> _splitCanvas({
  Size size = const Size(64, 64),
}) async {
  final state = EditorState()..setCanvasSize(_canvas.size);
  addTearDown(state.dispose);
  final layer = state.layerManager.addLayer(name: 'layer');
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final half = size.width / 2;
  canvas.drawRect(
    Rect.fromLTWH(0, 0, half, size.height),
    Paint()..color = const Color(0xFFFF0000),
  );
  canvas.drawRect(
    Rect.fromLTWH(half, 0, half, size.height),
    Paint()..color = const Color(0xFF0000FF),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.round(), size.height.round());
  picture.dispose();
  state.layerManager.replaceLayerBaseImageSync(layer.id, image, null);
  return (state, layer);
}

void _stroke(BlurTool tool, EditorState state, List<Offset> points) {
  tool.onPointerDown(PointerDownEvent(position: points.first), state);
  for (final point in points.skip(1)) {
    tool.onPointerMove(PointerMoveEvent(position: point), state);
  }
  tool.onPointerUp(PointerUpEvent(position: points.last), state);
}

/// 红蓝交界附近被模糊后两种颜色互相渗入
void _expectBlurred(List<int> pixel, {String? reason}) {
  expect(pixel[0], inExclusiveRange(0, 255), reason: reason);
  expect(pixel[2], inExclusiveRange(0, 255), reason: reason);
}
